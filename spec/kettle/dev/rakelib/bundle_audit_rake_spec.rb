# frozen_string_literal: true

require "spec_helper"
require "fileutils"

RSpec.describe "bundle audit rake tasks" do # rubocop:disable RSpec/DescribeClass
  let(:fake_load_path) { File.expand_path("../../../../tmp/fake_bundle_audit_load_path", __dir__) }
  let(:fake_task_file) { File.join(fake_load_path, "bundler/audit/task.rb") }

  around do |example|
    previous_application = Rake.application
    previous_defaults = Kettle::Dev.defaults
    begin
      Rake.application = Rake::Application.new
      Kettle::Dev.instance_variable_set(:@defaults, [].freeze)
      example.run
    ensure
      Rake.application = previous_application
      Kettle::Dev.instance_variable_set(:@defaults, previous_defaults)
      $LOAD_PATH.delete(fake_load_path)
      $LOADED_FEATURES.reject! { |feature| feature.end_with?("bundler/audit/task.rb") }
    end
  end

  def load_bundle_audit_tasks
    load File.expand_path("../../../../lib/kettle/dev/rakelib/bundle_audit.rake", __dir__)
  end

  it "registers bundler-audit tasks and defaults when bundler-audit is available" do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("KETTLE_DEV_SKIP_BUNDLE_AUDIT", "").and_return("")
    FileUtils.mkdir_p(File.dirname(fake_task_file))
    File.write(fake_task_file, <<~RUBY)
      # frozen_string_literal: true

      module Bundler
        module Audit
          class Task
            def initialize
              ::Rake::Task.define_task("bundle:audit")
              ::Rake::Task.define_task("bundle:audit:update")
            end
          end
        end
      end
    RUBY
    $LOAD_PATH.unshift(fake_load_path)

    load_bundle_audit_tasks

    expect(Rake::Task.task_defined?("bundle:audit")).to be true
    expect(Rake::Task.task_defined?("bundle:audit:update")).to be true
    expect(Kettle::Dev.defaults).to include("bundle:audit", "bundle:audit:update")
  end

  it "defines skipped audit tasks without adding them to defaults when disabled by environment" do
    stub_env("KETTLE_DEV_SKIP_BUNDLE_AUDIT" => "true")
    FileUtils.mkdir_p(File.dirname(fake_task_file))
    File.write(fake_task_file, <<~RUBY)
      # frozen_string_literal: true

      raise "bundler-audit should not load when disabled"
    RUBY
    $LOAD_PATH.unshift(fake_load_path)

    load_bundle_audit_tasks

    expect(Rake::Task.task_defined?("bundle:audit")).to be true
    expect(Rake::Task.task_defined?("bundle:audit:update")).to be true
    expect(Kettle::Dev.defaults).not_to include("bundle:audit", "bundle:audit:update")
    expect { Rake::Task["bundle:audit"].invoke }.to output(/bundle:audit skipped/).to_stderr
  end

  it "defines stub tasks when bundler-audit is unavailable" do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("KETTLE_DEV_SKIP_BUNDLE_AUDIT", "").and_return("")
    FileUtils.mkdir_p(File.dirname(fake_task_file))
    File.write(fake_task_file, <<~RUBY)
      # frozen_string_literal: true

      raise LoadError, "bundler-audit unavailable"
    RUBY
    $LOAD_PATH.unshift(fake_load_path)
    stub_const("Kettle::Dev::DEBUGGING", true)

    expect { load_bundle_audit_tasks }.to output(/failed to load bundle\/audit\/task/).to_stderr
    expect { Rake::Task["bundle:audit"].invoke }.to output(/bundler-audit isn't installed/).to_stderr
    expect { Rake::Task["bundle:audit:update"].invoke }.to output(/bundler-audit isn't installed/).to_stderr
  end

  describe "bundle:audit:update" do
    let(:db_dir) { Dir.mktmpdir("advisory-db-parent") }
    let(:db_path) { File.join(db_dir, "ruby-advisory-db") }

    before do
      require "bundler/audit/database"
      FileUtils.mkdir_p(File.dirname(fake_task_file))
      File.write(fake_task_file, <<~RUBY)
        module Bundler
          module Audit
            class Task
              def initialize
                ::Rake::Task.define_task("bundle:audit")
                ::Rake::Task.define_task("bundle:audit:update")
              end
            end
          end
        end
      RUBY
      $LOAD_PATH.unshift(fake_load_path)
      allow(Bundler::Audit::Database).to receive(:path).and_return(db_path)
    end

    after { FileUtils.rm_rf(db_dir) }

    def run_update
      load_bundle_audit_tasks
      Rake::Task["bundle:audit:update"].invoke
    end

    it "runs the update while holding an exclusive flock on a lock file next to the database" do
      held = nil
      allow_any_instance_of(Object).to receive(:system) do |_obj, *_args| # rubocop:disable RSpec/AnyInstance
        File.open("#{db_path}.lock", File::RDWR) do |f|
          held = f.flock(File::LOCK_EX | File::LOCK_NB) == false
        end
        true
      end
      run_update
      expect(held).to be true
    end

    it "blocks (rather than fails) while another process holds the lock" do
      FileUtils.mkdir_p(db_dir)
      lock_path = "#{db_path}.lock"
      other = File.open(lock_path, File::RDWR | File::CREAT)
      other.flock(File::LOCK_EX)
      started = false
      allow_any_instance_of(Object).to receive(:system).and_return(true) # rubocop:disable RSpec/AnyInstance
      t = Thread.new do # rubocop:disable ThreadSafety/NewThread
        started = true
        run_update
        Time.now
      end
      sleep 0.2 until started
      sleep 0.3
      expect(t.alive?).to be true
      released = Time.now
      other.flock(File::LOCK_UN)
      expect(t.value).to be >= released
      other.close
    end

    it "skips only the update when KETTLE_DEV_SKIP_AUDIT_UPDATE is truthy" do
      stub_env("KETTLE_DEV_SKIP_AUDIT_UPDATE" => "Yes")
      allow_any_instance_of(Object).to receive(:system).and_raise("must not run") # rubocop:disable RSpec/AnyInstance
      expect { run_update }.to output(/bundle:audit:update skipped because KETTLE_DEV_SKIP_AUDIT_UPDATE/).to_stderr
      expect(Rake::Task.task_defined?("bundle:audit")).to be true
      expect(Kettle::Dev.defaults).to include("bundle:audit")
    end

    it "warns and continues when the update fails but a local database exists" do
      allow(Bundler::Audit::Database).to receive(:exists?).with(db_path).and_return(true)
      allow_any_instance_of(Object).to receive(:system).and_return(false) # rubocop:disable RSpec/AnyInstance
      expect { run_update }.to output(/auditing with the existing local database/).to_stderr
    end

    it "fails when the update fails and no local database exists" do
      allow(Bundler::Audit::Database).to receive(:exists?).with(db_path).and_return(false)
      allow_any_instance_of(Object).to receive(:system).and_return(false) # rubocop:disable RSpec/AnyInstance
      expect { run_update }.to raise_error(SystemExit).and output(/no local advisory database/).to_stderr
    end
  end
end
