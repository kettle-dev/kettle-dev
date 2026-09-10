# frozen_string_literal: true

# rubocop:disable RSpec/ReceiveMessages, RSpec/StubbedMock
RSpec.describe Kettle::Dev::ReleaseCLI do
  around do |example|
    # Keep both release-only environment switches isolated from each example.
    previous_skip_changelog = ENV.delete("KETTLE_DEV_SKIP_CHANGELOG")
    previous_skip_changelog_dependency = ENV.delete("KETTLE_DEV_SKIP_CHANGELOG_DEPENDENCY")
    previous_family_member_publish = ENV.delete("KETTLE_RELEASE_FAMILY_MEMBER_PUBLISH")
    previous_family_member_finalize = ENV.delete("KETTLE_RELEASE_FAMILY_MEMBER_FINALIZE")
    begin
      example.run
    ensure
      if previous_skip_changelog.nil?
        ENV.delete("KETTLE_DEV_SKIP_CHANGELOG")
      else
        # rubocop:disable Env/Assign -- restore the inherited release flag after example isolation
        ENV["KETTLE_DEV_SKIP_CHANGELOG"] = previous_skip_changelog
        # rubocop:enable Env/Assign
      end
      if previous_skip_changelog_dependency.nil?
        ENV.delete("KETTLE_DEV_SKIP_CHANGELOG_DEPENDENCY")
      else
        # rubocop:disable Env/Assign -- restore the inherited dependency flag after example isolation
        ENV["KETTLE_DEV_SKIP_CHANGELOG_DEPENDENCY"] = previous_skip_changelog_dependency
        # rubocop:enable Env/Assign
      end
      if previous_family_member_publish.nil?
        ENV.delete("KETTLE_RELEASE_FAMILY_MEMBER_PUBLISH")
      else
        # rubocop:disable Env/Assign -- restore the inherited family worker flag after example isolation
        ENV["KETTLE_RELEASE_FAMILY_MEMBER_PUBLISH"] = previous_family_member_publish
        # rubocop:enable Env/Assign
      end
      if previous_family_member_finalize.nil?
        ENV.delete("KETTLE_RELEASE_FAMILY_MEMBER_FINALIZE")
      else
        # rubocop:disable Env/Assign -- restore the inherited family finalizer flag after example isolation
        ENV["KETTLE_RELEASE_FAMILY_MEMBER_FINALIZE"] = previous_family_member_finalize
        # rubocop:enable Env/Assign
      end
    end
  end

  describe "core behaviors" do
    let(:ci_helpers) { Kettle::Dev::CIHelpers }
    let(:cli) { described_class.new }

    before do |example|
      next if example.metadata[:real_release_lockfiles]

      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(described_class).to receive(:prepare_release_lockfiles_for_commit!)
      allow_any_instance_of(described_class).to receive(:prepare_release_lockfiles_for_release_tasks!)
      allow_any_instance_of(described_class).to receive(:materialize_release_lockfiles_for_release_tasks!)
      allow_any_instance_of(described_class).to receive(:validate_release_lockfiles!)
      allow_any_instance_of(described_class).to receive(:update_bundler_and_commit!)
      # rubocop:enable RSpec/AnyInstance
    end

    def write_style_local(root, ruby_gem)
      gemfile_dir = File.join(root, "gemfiles", "modular")
      FileUtils.mkdir_p(gemfile_dir)
      File.write(File.join(gemfile_dir, "style_local.gemfile"), <<~RUBY)
        # frozen_string_literal: true

        local_gems = %w[rubocop-lts rubocop-lts-rspec #{ruby_gem} standard-rubocop-lts]
      RUBY
    end

    def stub_checksum_artifact(release_cli, version, gem_name = "mygem")
      gem_path = File.join(Dir.pwd, "pkg", "#{gem_name}-#{version}.gem")
      allow(release_cli).to receive(:checksum_gem_path_for_version!).with(version).and_return(gem_path)
      gem_path
    end

    it "detects version and gem name from a temporary project root" do
      Dir.mktmpdir do |root|
        # Arrange version file
        lib_dir = File.join(root, "lib", "mygem")
        FileUtils.mkdir_p(lib_dir)
        File.write(File.join(lib_dir, "version.rb"), <<~RB)
          module Mygem
            VERSION = "1.2.3"
          end
        RB

        # Arrange gemspec
        File.write(File.join(root, "mygem.gemspec"), <<~G)
          Gem::Specification.new do |spec|
            spec.name = "mygem"
          end
        G

        # Stub project root used by ReleaseCLI
        allow(ci_helpers).to receive(:project_root).and_return(root)

        local_cli = described_class.new
        ver = local_cli.send(:detect_version)
        name = local_cli.send(:detect_gem_name)

        expect(ver).to eq("1.2.3")
        expect(name).to eq("mygem")
      end
    end

    it "uses an explicit version override when no version.rb is present" do
      Dir.mktmpdir do |root|
        allow(ci_helpers).to receive(:project_root).and_return(root)
        local_cli = described_class.new(version: "4.5.6")
        expect(local_cli.send(:detect_version)).to eq("4.5.6")
      end
    end

    it "publishes a prepared family member without touching shared release steps" do
      # rubocop:disable Env/Assign -- opt into the explicit family worker contract for this example
      ENV["KETTLE_RELEASE_FAMILY_MEMBER_PUBLISH"] = "true"
      # rubocop:enable Env/Assign
      local_cli = described_class.new

      allow(local_cli).to receive(:detect_version).and_return("1.2.3")
      allow(local_cli).to receive(:detect_gem_name).and_return("mygem")
      allow(local_cli).to receive(:signing_enabled?).and_return(false)
      allow(local_cli).to receive(:build_release_candidate).with("mygem", "1.2.3").and_return(double)
      allow(local_cli).to receive(:with_unpublished_candidate_cleanup).and_yield

      expect(local_cli).to receive(:prepare_release_lockfiles_for_release_tasks!).ordered
      expect(local_cli).to receive(:ensure_signing_setup_or_skip!).ordered
      expect(local_cli).to receive(:run_cmd!).with(a_string_including("bundle exec rake build")).ordered
      expect(local_cli).to receive(:publish_built_gem!).with("1.2.3").ordered
      expect(local_cli).not_to receive(:run_pre_release_checks!)
      expect(local_cli).not_to receive(:commit_release_prep!)
      expect(local_cli).not_to receive(:push!)
      expect(local_cli).not_to receive(:push_tags!)
      expect(local_cli).not_to receive(:maybe_create_github_release!)

      local_cli.send(:run_with_release_environment)
    end

    it "finalizes member checksums without running release or GitHub steps" do
      # rubocop:disable Env/Assign -- opt into the explicit family finalizer contract for this example
      ENV["KETTLE_RELEASE_FAMILY_MEMBER_FINALIZE"] = "true"
      # rubocop:enable Env/Assign
      local_cli = described_class.new

      allow(local_cli).to receive(:detect_version).and_return("1.2.3")
      allow(local_cli).to receive(:detect_gem_name).and_return("mygem")
      allow(local_cli).to receive(:checksum_gem_path_for_version!).with("1.2.3").and_return("pkg/mygem-1.2.3.gem")

      expect(local_cli).to receive(:run_cmd!).with(a_string_including("bin/gem_checksums pkg/mygem-1.2.3.gem")).ordered
      expect(local_cli).to receive(:validate_checksums!).with("1.2.3", stage: "after family member publish").ordered
      expect(local_cli).not_to receive(:run_pre_release_checks!)
      expect(local_cli).not_to receive(:release_gem_and_tag_locally!)
      expect(local_cli).not_to receive(:push!)
      expect(local_cli).not_to receive(:push_tags!)
      expect(local_cli).not_to receive(:maybe_create_github_release!)

      local_cli.send(:run_with_release_environment)
    end

    it "maps common release commands to stable command step names" do
      local_cli = described_class.new

      names = [
        "env -u BUNDLE_GEMFILE bundle update --bundler",
        "env -u BUNDLE_GEMFILE BUNDLE_GEMFILE=/repo/Gemfile bundle lock --update --add-checksums",
        "KETTLE_DEV_SKIP_TESTS=true bin/rake",
        "bin/rake appraisal:generate",
        "bin/rake yard",
        "bundle exec rake build",
        "bundle exec rake release",
        "bin/gem_checksums /repo/pkg/example-1.2.3.gem",
        "git fetch origin main",
        "git push origin main"
      ].map { |command| local_cli.send(:command_event_name, command) }

      expect(names).to eq(
        %w[
          bundle_update
          bundle_lock
          default_task
          appraisal_generate
          yard
          gem_build
          gem_release
          gem_checksums
          git_fetch
          git_push
        ]
      )
    end

    it "supports skipping appraisal generation without skipping documentation" do
      local_cli = described_class.new(skip_appraisals: true)

      expect(local_cli.send(:skip_appraisals?)).to be(true)
      expect(local_cli.send(:skip_changelog?)).to be(false)
    end

    it "summarizes common release command steps" do
      local_cli = described_class.new

      summaries = [
        "BUNDLE_GEMFILE=/repo/Appraisal.root.gemfile BUNDLE_LOCKFILE=/repo/Appraisal.root.gemfile.lock bundle update --bundler",
        "env -u BUNDLE_GEMFILE BUNDLE_GEMFILE=/repo/Gemfile bundle lock --update --add-checksums",
        "KETTLE_DEV_SKIP_TESTS=true bin/rake",
        "bin/rake appraisal:generate",
        "bin/rake yard",
        "bundle exec rake build",
        "bundle exec rake release",
        "bin/gem_checksums /repo/pkg/example-1.2.3.gem",
        "git fetch origin main",
        "git push origin main"
      ].map { |command| local_cli.send(:command_event_summary, command) }

      expect(summaries).to eq(
        [
          "bundle update",
          "Gemfile",
          "default task",
          "appraisals",
          "documentation",
          "build gem",
          "publish gem",
          "checksums",
          "origin",
          "origin"
        ]
      )
    end

    describe "#run_cmd! (signing env injection)", :real_release_rake do
      it "emits command step events around child commands" do
        io = StringIO.new
        event_stream = Kettle::Ndjson.event_stream(io, types: "command_step")
        local_cli = described_class.new(event_stream: event_stream)
        status = instance_double(Process::Status, success?: true, exitstatus: 0)
        allow(Open3).to receive(:capture3).and_return(["", "", status])

        local_cli.send(:run_cmd!, "bin/setup")

        events = io.string.lines.map { |line| JSON.parse(line) }
        expect(events).to contain_exactly(
          include("type" => "command_step", "status" => "started", "command" => "bin/setup", "mark" => ">"),
          include("type" => "command_step", "status" => "ok", "command" => "bin/setup", "mark" => ".")
        )
      end

      it "emits the logical release step separately from command event ordering" do
        status = instance_double(Process::Status, success?: true, exitstatus: 0)
        allow(Open3).to receive(:capture3).and_return(["", "", status])
        emitted_steps = []
        allow(Kettle::Ndjson).to receive(:emit_step_event) { |_recorder, _type, step, **_| emitted_steps << step }

        cli.send(:with_release_resume_step, 15) do
          cli.send(:run_cmd!, "bin/setup")
        end

        expect(emitted_steps).to all(include(resume_step: 15))
      end

      it "prefixes SKIP_GEM_SIGNING for 'bundle exec rake build' when env set" do
        stub_env("SKIP_GEM_SIGNING" => "true")
        status = instance_double(Process::Status, success?: true, exitstatus: 0)
        expect(Open3).to receive(:capture3).with(kind_of(Hash), "SKIP_GEM_SIGNING=true bundle exec rake build").and_return(["", "", status])
        cli.send(:run_cmd!, "bundle exec rake build")
      end

      it "disables noisy Bundler and debug environment for release child commands" do
        stub_env(
          "DEBUG" => "true",
          "BUNDLE_DEBUG" => "true",
          "BUNDLER_DEBUG" => "true",
          "BUNDLE_VERBOSE" => "true",
          "DEBUG_RESOLVER" => "true"
        )
        allow(ENV).to receive(:to_hash).and_return(ENV.to_hash.merge(
          "DEBUG" => "true",
          "BUNDLE_DEBUG" => "true",
          "BUNDLER_DEBUG" => "true",
          "BUNDLE_VERBOSE" => "true",
          "DEBUG_RESOLVER" => "true"
        ))
        status = instance_double(Process::Status, success?: true, exitstatus: 0)
        expect(Open3).to receive(:capture3) do |env, command|
          expect(command).to eq("bin/setup")
          expect(env).to include(
            "DEBUG" => nil,
            "BUNDLE_QUIET" => "true",
            "BUNDLE_DEBUG" => "false",
            "BUNDLER_DEBUG" => "false",
            "BUNDLE_VERBOSE" => "false",
            "DEBUG_RESOLVER" => nil,
            "BUNDLER_DEBUG_RESOLVER" => nil,
            "BUNDLE_SUPPRESS_INSTALL_USING_MESSAGES" => "true"
          )
          ["", "", status]
        end

        cli.send(:run_cmd!, "bin/setup")
      end

      it "does not leak the release tool bundle into project rake commands" do
        stub_env("BUNDLE_GEMFILE" => "/var/home/pboling/src/my/kettle-dev/Gemfile")
        status = instance_double(Process::Status, success?: true, exitstatus: 0)
        expect(Open3).to receive(:capture3) do |env, command|
          expect(command).to eq("bin/rake")
          expect(env).to include("BUNDLE_GEMFILE" => nil, "BUNDLE_LOCKFILE" => nil)
          ["", "", status]
        end

        cli.send(:run_cmd!, "bin/rake")
      end

      it "runs setup with inherited Bundler and Ruby bootstrap env unset" do
        command = cli.send(:release_setup_command)

        expect(command).to include("env")
        expect(command).to include("-u BUNDLE_GEMFILE")
        expect(command).to include("-u BUNDLE_LOCKFILE")
        expect(command).to include("-u BUNDLER_SETUP")
        expect(command).to include("-u RUBYLIB")
        expect(command).to include("-u RUBYOPT")
        expect(command).to include("KETTLE_DEV_DEV=false")
        expect(command).to include("STRUCTUREDMERGE_DEV=false")
        expect(command).to end_with(" bin/setup")
      end

      it "sets bundle audit skip env for release child commands when requested" do
        previous_skip_bundle_audit = ENV["KETTLE_DEV_SKIP_BUNDLE_AUDIT"]
        local_cli = described_class.new(skip_bundle_audit: true)
        status = instance_double(Process::Status, success?: true, exitstatus: 0)
        expect(Open3).to receive(:capture3) do |env, command|
          expect(command).to eq("KETTLE_DEV_SKIP_BUNDLE_AUDIT=true bin/rake")
          expect(env.fetch("KETTLE_DEV_SKIP_BUNDLE_AUDIT")).to eq("true")
          ["", "", status]
        end

        local_cli.send(:run_cmd!, "bin/rake")
        expect(ENV["KETTLE_DEV_SKIP_BUNDLE_AUDIT"]).to eq(previous_skip_bundle_audit)
      end

      it "sets bundle audit skip env around the full release run" do
        previous_skip_bundle_audit = ENV["KETTLE_DEV_SKIP_BUNDLE_AUDIT"]
        local_cli = described_class.new(skip_bundle_audit: true, skip_steps: "1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19")
        expect(local_cli).to receive(:run_pre_release_checks!) do
          expect(ENV.fetch("KETTLE_DEV_SKIP_BUNDLE_AUDIT")).to eq("true")
        end

        local_cli.run
        expect(ENV["KETTLE_DEV_SKIP_BUNDLE_AUDIT"]).to eq(previous_skip_bundle_audit)
      end

      it "preserves noisy environment when release debug is explicitly enabled" do
        stub_env(
          "KETTLE_DEV_DEBUG" => "true",
          "DEBUG" => "true",
          "BUNDLE_DEBUG" => "true",
          "BUNDLER_DEBUG" => "true",
          "BUNDLE_VERBOSE" => "true",
          "DEBUG_RESOLVER" => "true"
        )
        allow(ENV).to receive(:to_hash).and_return(ENV.to_hash.merge(
          "KETTLE_DEV_DEBUG" => "true",
          "DEBUG" => "true",
          "BUNDLE_DEBUG" => "true",
          "BUNDLER_DEBUG" => "true",
          "BUNDLE_VERBOSE" => "true",
          "DEBUG_RESOLVER" => "true"
        ))
        status = instance_double(Process::Status, success?: true, exitstatus: 0)
        expect(Open3).to receive(:capture3) do |env, command|
          expect(command).to eq("bin/setup")
          expect(env).to include(
            "KETTLE_DEV_DEBUG" => "true",
            "DEBUG" => "true",
            "BUNDLE_DEBUG" => "true",
            "BUNDLER_DEBUG" => "true",
            "BUNDLE_VERBOSE" => "true",
            "DEBUG_RESOLVER" => "true"
          )
          ["", "", status]
        end

        cli.send(:run_cmd!, "bin/setup")
      end

      it "runs kettle-changelog with the current TTY so its confirmation prompt is visible" do
        allow(described_class).to receive(:system).with(kind_of(Hash), "bundle exec kettle-changelog").and_return(true)
        expect(Open3).not_to receive(:capture3)

        cli.send(:run_cmd!, "bundle exec kettle-changelog")
      end

      it "removes the parent bundle environment for standalone changelog commands" do
        stub_env("BUNDLE_GEMFILE" => "/release-tool/Gemfile", "BUNDLE_LOCKFILE" => "/release-tool/Gemfile.lock")
        expect(described_class.send(:command_env_for, "bundle exec kettle-changelog")).to include(
          "BUNDLE_GEMFILE" => nil,
          "BUNDLE_LOCKFILE" => nil,
          "KETTLE_RELEASE_SECRETS_PROVIDER" => nil,
          "KETTLE_RELEASE_SECRETS_BROKER" => nil,
          "KETTLE_PRE_RELEASE_GHA_SHA_PINS_OFFLINE" => nil
        )
      end

      it "removes the parent bundle environment from gem publication commands" do
        stub_env("BUNDLE_GEMFILE" => "/release-tool/Gemfile", "BUNDLE_LOCKFILE" => "/release-tool/Gemfile.lock")

        expect(described_class.send(:command_env_for, "gem push pkg/example-1.2.3.gem")).to include(
          "BUNDLE_GEMFILE" => nil,
          "BUNDLE_LOCKFILE" => nil
        )
      end

      it "uses the configured release secrets provider for prompt-bearing release commands" do
        provider = instance_double(Kettle::Dev::ReleaseSecrets::OnePassword)
        local_cli = described_class.new(secrets_provider: provider)
        runner = instance_double(Kettle::Dev::InteractiveReleaseCommand)
        status = instance_double(Process::Status, success?: true, exitstatus: 0)
        allow(provider).to receive(:keepalive!).with(elapsed: nil).and_return(true)
        expect(Kettle::Dev::InteractiveReleaseCommand)
          .to receive(:new)
          .with(secrets_provider: provider, secret_event_handler: kind_of(Proc))
          .and_return(runner)
        expect(runner).to receive(:call).with(kind_of(Hash), "bundle exec rake release").and_return(["", "", status])
        expect(Open3).not_to receive(:capture3)

        local_cli.send(:run_cmd!, "bundle exec rake release")
        expect(provider).to have_received(:keepalive!).with(elapsed: nil)
      end

      it "uses the configured release secrets provider when release commands have an env prefix" do
        provider = instance_double(Kettle::Dev::ReleaseSecrets::OnePassword)
        local_cli = described_class.new(secrets_provider: provider)
        runner = instance_double(Kettle::Dev::InteractiveReleaseCommand)
        status = instance_double(Process::Status, success?: true, exitstatus: 0)
        command = "env -u BUNDLE_GEMFILE KETTLE_DEV_DEV=false bundle exec rake release"
        allow(provider).to receive(:keepalive!).with(elapsed: nil).and_return(true)
        expect(Kettle::Dev::InteractiveReleaseCommand)
          .to receive(:new)
          .with(secrets_provider: provider, secret_event_handler: kind_of(Proc))
          .and_return(runner)
        expect(runner).to receive(:call).with(kind_of(Hash), command).and_return(["", "", status])
        expect(Open3).not_to receive(:capture3)

        local_cli.send(:run_cmd!, command)
        expect(provider).to have_received(:keepalive!).with(elapsed: nil)
      end

      it "retries the existing gem when RubyGems rejects an expired-edge OTP" do
        provider = instance_double(Kettle::Dev::ReleaseSecrets::OnePassword)
        local_cli = described_class.new(secrets_provider: provider)
        runner = instance_double(Kettle::Dev::InteractiveReleaseCommand)
        failed_status = instance_double(Process::Status, success?: false, exitstatus: 1)
        allow(provider).to receive(:keepalive!).with(elapsed: nil).and_return(true)
        allow(Kettle::Dev::InteractiveReleaseCommand).to receive(:new)
          .with(secrets_provider: provider, secret_event_handler: kind_of(Proc))
          .and_return(runner)
        gem_path = __FILE__
        allow(local_cli).to receive(:gem_file_for_version).with(kind_of(String)).and_return(gem_path)
        allow(runner).to receive(:call).and_return([
          "Your OTP code is incorrect. Please check it and retry.",
          "",
          failed_status
        ])
        expect(local_cli).to receive(:sleep).with(2).ordered
        expect(local_cli).to receive(:run_cmd!).with("gem push #{gem_path}").ordered

        local_cli.send(
          :run_command_with_release_secrets!,
          "env -u BUNDLE_GEMFILE KETTLE_DEV_DEV=false bundle exec rake release"
        )
      end

      it "does not retry a release failure unrelated to the RubyGems OTP response" do
        provider = instance_double(Kettle::Dev::ReleaseSecrets::OnePassword)
        local_cli = described_class.new(secrets_provider: provider)
        runner = instance_double(Kettle::Dev::InteractiveReleaseCommand)
        failed_status = instance_double(Process::Status, success?: false, exitstatus: 1)
        allow(provider).to receive(:keepalive!).with(elapsed: nil).and_return(true)
        allow(Kettle::Dev::InteractiveReleaseCommand).to receive(:new)
          .with(secrets_provider: provider, secret_event_handler: kind_of(Proc))
          .and_return(runner)
        allow(runner).to receive(:call).and_return(["RubyGems service unavailable", "", failed_status])
        expect(local_cli).not_to receive(:run_cmd!).with(start_with("gem push"))

        expect {
          local_cli.send(:run_command_with_release_secrets!, "bundle exec rake release")
        }.to raise_error(MockSystemExit, /Command failed: bundle exec rake release/)
      end

      it "treats the real 1Password provider as configured" do
        provider = Kettle::Dev::ReleaseSecrets::OnePassword.new(
          "gem_signing_passphrase_source" => "cached"
        )
        local_cli = described_class.new(secrets_provider: provider)

        expect(local_cli.send(:release_secrets_configured?)).to be(true)
        expect(local_cli.send(:release_secrets_provider_label)).to eq("OnePassword")
      end

      it "treats the base release secrets provider as interactive" do
        local_cli = described_class.new(secrets_provider: Kettle::Dev::ReleaseSecrets::Provider.new)

        expect(local_cli.send(:release_secrets_configured?)).to be(false)
        expect(local_cli.send(:release_secrets_provider_label)).to eq("interactive")
      end

      it "skips duplicate test and coverage work in the default task after changelog coverage runs" do
        local_cli = described_class.new
        allow(local_cli).to receive(:run_cmd!)

        local_cli.send(:run_changelog!)

        expect(local_cli.send(:release_default_task_command)).to match(/KETTLE_DEV_SKIP_TESTS=true bin\/rake\z/)
      end

      it "skips changelog coverage while retaining the normal default task" do
        local_cli = described_class.new(skip_changelog: true)
        pre_release = instance_double(Kettle::Dev::PreReleaseCLI, run: nil)
        allow(Kettle::Dev::PreReleaseCLI).to receive(:new).and_return(pre_release)

        expect(local_cli).not_to receive(:run_changelog!)
        local_cli.send(:run_pre_release_checks!)

        expect(local_cli.send(:skip_changelog?)).to be(true)
        expect(local_cli.send(:release_default_task_command)).to match(/bin\/rake\z/)
        expect(local_cli.send(:release_default_task_command)).not_to include("KETTLE_DEV_SKIP_TESTS=true")
      end

      it "exports the changelog skip to lockfile and project commands" do
        local_cli = described_class.new(skip_changelog: true)

        expect(ENV).not_to have_key("KETTLE_DEV_SKIP_CHANGELOG")
        local_cli.send(:with_skip_changelog_env) do
          expect(ENV["KETTLE_DEV_SKIP_CHANGELOG"]).to eq("true")
        end
        expect(ENV).not_to have_key("KETTLE_DEV_SKIP_CHANGELOG")
      end

      it "derives changelog coverage policy from the project coverage setting" do
        allow(ENV).to receive(:[]).with("K_SOUP_COV_MIN_HARD").and_return("false")
        local_cli = described_class.new
        expect(local_cli).to receive(:run_cmd!) do
          expect(ENV["K_CHANGELOG_COVERAGE_HARD"]).to eq("false")
        end

        local_cli.send(:run_changelog!)

        expect(ENV["K_CHANGELOG_COVERAGE_HARD"]).to be_nil
      end

      it "runs the standalone changelog through a configured alternate bundle" do
        Dir.mktmpdir do |root|
          allow(ci_helpers).to receive(:project_root).and_return(root)
          gemfile = File.join(root, "Gemfile")
          lockfile = File.join(root, "Gemfile.lock")
          File.write(gemfile, "source 'https://gem.coop'\n")
          File.write(lockfile, "PLATFORMS\n  x86_64-linux\n")
          stub_env("K_RELEASE_CHANGELOG_GEMFILE" => gemfile)
          local_cli = described_class.new
          coverage_lockfile = File.join(root, "tmp", "kettle-release", "lockfiles", "Gemfile-#{Process.pid}.lock")

          expect(local_cli).to receive(:run_cmd!).with(
            a_string_ending_with(
              "BUNDLE_GEMFILE=#{Shellwords.escape(gemfile)} " \
              "KETTLE_CHANGELOG_COVERAGE_LOCKFILE=#{Shellwords.escape(coverage_lockfile)} " \
              "bundle exec kettle-changelog"
            )
          )

          local_cli.send(:run_changelog!)
          expect(File.read(coverage_lockfile)).to eq(File.read(lockfile))
          local_cli.send(:cleanup_release_task_lockfile!)
        end
      end

      it "runs changelog coverage through the generated coverage bundle when present" do
        Dir.mktmpdir do |root|
          allow(ci_helpers).to receive(:project_root).and_return(root)
          release_gemfile = File.join(root, "Gemfile")
          coverage_gemfile = File.join(root, "gemfiles", "coverage.gemfile")
          coverage_lockfile = "#{coverage_gemfile}.lock"
          FileUtils.mkdir_p(File.dirname(coverage_gemfile))
          File.write(release_gemfile, "source 'https://gem.coop'\n")
          File.write(coverage_gemfile, "source 'https://gem.coop'\n")
          File.write(coverage_lockfile, "PLATFORMS\n  x86_64-linux\n")
          stub_env("K_RELEASE_CHANGELOG_GEMFILE" => release_gemfile)
          local_cli = described_class.new
          disposable_lockfile = File.join(root, "tmp", "kettle-release", "lockfiles", "coverage.gemfile-#{Process.pid}.lock")

          expect(local_cli).to receive(:run_cmd!).with(
            a_string_ending_with(
              "BUNDLE_GEMFILE=#{Shellwords.escape(release_gemfile)} " \
              "K_CHANGELOG_COVERAGE_GEMFILE=#{Shellwords.escape(coverage_gemfile)} " \
              "KETTLE_CHANGELOG_COVERAGE_LOCKFILE=#{Shellwords.escape(disposable_lockfile)} " \
              "bundle exec kettle-changelog"
            )
          )

          local_cli.send(:run_changelog!)
          expect(File.read(disposable_lockfile)).to eq(File.read(coverage_lockfile))
          local_cli.send(:cleanup_release_task_lockfile!)
        end
      end

      it "derives the alternate changelog bundle from a local kettle-dev workspace" do
        Dir.mktmpdir do |root|
          changelog_root = File.join(root, "kettle-changelog")
          FileUtils.mkdir_p(changelog_root)
          gemfile = File.join(changelog_root, "Gemfile")
          File.write(gemfile, "source 'https://gem.coop'\n")
          stub_env("KETTLE_DEV_DEV" => root, "K_RELEASE_CHANGELOG_GEMFILE" => nil)
          local_cli = described_class.new

          expect(local_cli).to receive(:run_cmd!).with(
            a_string_matching(
              /\Aenv .*KETTLE_DEV_DEV=false.*K_JEM_TEMPLATING=false.*BUNDLE_GEMFILE=#{Regexp.escape(Shellwords.escape(gemfile))}.*KETTLE_CHANGELOG_DEV_ROOT=#{Regexp.escape(Shellwords.escape(root))}.*bundle exec kettle-changelog\z/
            )
          )

          local_cli.send(:run_changelog!)
        end
      end

      it "keeps the full default task for resumed releases that did not run changelog coverage" do
        local_cli = described_class.new(start_step: 4)

        expect(local_cli.send(:release_default_task_command)).to match(/env .* bin\/rake\z/)
      end

      it "isolates the lockfile used by gem build and release tasks" do
        Dir.mktmpdir do |root|
          allow(ci_helpers).to receive(:project_root).and_return(root)
          lockfile = File.join(root, "Gemfile.lock")
          File.write(lockfile, "PLATFORMS\n  x86_64-linux\n  x86_64-linux-musl\n")
          local_cli = described_class.new

          build_command = local_cli.send(:release_project_command, "bundle exec rake build")
          isolated_lockfile = Dir[File.join(root, "tmp", "kettle-release", "lockfiles", "Gemfile-*.lock")].fetch(0)

          expect(build_command).not_to include("KETTLE_DEV_SKIP_CHANGELOG_DEPENDENCY")
          expect(build_command).to include("BUNDLE_LOCKFILE=#{Shellwords.escape(isolated_lockfile)}")
          expect(File.read(isolated_lockfile)).to eq(File.read(lockfile))

          release_command = local_cli.send(:release_project_command, "bundle exec rake release")
          expect(release_command).to include("BUNDLE_LOCKFILE=#{Shellwords.escape(isolated_lockfile)}")

          local_cli.send(:cleanup_release_task_lockfile!)
          expect(File).not_to exist(isolated_lockfile)
        end
      end

      it "keeps canonical commands and Git hooks off the caller's local bundle" do
        stub_env(
          "KETTLE_DEV_DEV" => "/workspace/kettle-dev",
          "BUNDLER_ORIG_BUNDLE_GEMFILE" => "/workspace/family/Gemfile"
        )
        local_cli = described_class.new

        command = local_cli.send(:release_project_command, "bin/rake")
        environment = local_cli.send(:release_git_hook_environment)

        expect(command).to include("KETTLE_DEV_DEV=false")
        expect(command).to include("-u BUNDLER_ORIG_BUNDLE_GEMFILE")
        expect(command).not_to include("BUNDLE_LOCKFILE=")
        expect(environment).to include(
          "KETTLE_DEV_DEV" => "false",
          "BUNDLE_GEMFILE" => nil,
          "BUNDLER_ORIG_BUNDLE_GEMFILE" => nil
        )
      end

      it "preserves the declared CI-resident monorepo graph for release children" do
        Dir.mktmpdir do |root|
          allow(ci_helpers).to receive(:project_root).and_return(root)
          monorepo_gems = File.join(root, "gems")
          FileUtils.mkdir_p(monorepo_gems)
          stub_env(
            "KETTLE_DEV_DEV" => "/workspace/kettle-dev",
            "STRUCTUREDMERGE_DEV" => monorepo_gems,
            "KETTLE_RELEASE_GRAPH_CONTRACT_JSON" => {
              "name" => "monorepo_ci_local",
              "ci_root" => root,
              "local_path_roots" => [monorepo_gems],
              "selector_env" => {"STRUCTUREDMERGE_DEV" => monorepo_gems}
            }.to_json
          )
          local_cli = described_class.new

          environment = local_cli.send(:release_child_environment)

          expect(environment).to include(
            "KETTLE_DEV_DEV" => "false",
            "STRUCTUREDMERGE_DEV" => monorepo_gems
          )
        end
      end

      it "builds a runnable env command with unset options before assignments" do
        stub_env("KETTLE_DEV_DEV" => "/workspace/kettle-dev", "BUNDLE_GEMFILE" => "/workspace/family/Gemfile")
        local_cli = described_class.new
        command = local_cli.send(:release_child_command, "ruby -e 'print ENV.fetch(%q[KETTLE_DEV_DEV])'")

        output, status = Open3.capture2(command)

        expect(status).to be_success
        expect(output).to eq("false")
      end

      it "fails early when configured release secrets cannot provide the signing passphrase" do
        provider = instance_double(Kettle::Dev::ReleaseSecrets::OnePassword, gem_signing_passphrase: nil)
        local_cli = described_class.new(secrets_provider: provider, yes: true)
        allow(provider).to receive(:keepalive!).with(elapsed: nil).and_return(true)

        expect {
          local_cli.send(:ensure_release_secrets_ready_for_signing!)
        }.to raise_error(MockSystemExit, /Secret prompts are not allowed when --secrets-provider is set/)
      end
    end

    describe "machine-readable release reports" do
      it "emits run start and summary events and writes the final JSON report" do
        Dir.mktmpdir do |root|
          allow(ci_helpers).to receive(:project_root).and_return(root)
          FileUtils.mkdir_p(File.join(root, "lib", "mygem"))
          File.write(File.join(root, "lib", "mygem", "version.rb"), "module Mygem; VERSION = \"1.2.3\"; end\n")
          File.write(File.join(root, "mygem.gemspec"), "Gem::Specification.new { |spec| spec.name = \"mygem\" }\n")
          event_io = StringIO.new
          json_io = StringIO.new
          report_path = File.join(root, "tmp", "release-report.json")
          local_cli = described_class.new(
            skip_steps: "0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19",
            event_stream: Kettle::Ndjson.event_stream(event_io, types: "run_start,summary"),
            json_output: true,
            json_io: json_io,
            report_path: report_path
          )

          local_cli.run

          events = event_io.string.lines.map { |line| JSON.parse(line) }
          expect(events).to contain_exactly(
            include("type" => "run_start", "command" => "release", "root" => root),
            include("type" => "summary", "command" => "release", "status" => "ok", "version" => "1.2.3", "gem_name" => "mygem")
          )
          expect(JSON.parse(json_io.string)).to include("status" => "ok", "version" => "1.2.3", "gem_name" => "mygem")
          expect(JSON.parse(File.read(report_path))).to include("status" => "ok", "version" => "1.2.3", "gem_name" => "mygem")
        end
      end
    end

    describe "#ensure_bundler_2_7_plus!" do
      it "aborts when bundler is missing" do
        hide_const("Bundler") if defined?(Bundler)
        allow(cli).to receive(:require).with("bundler").and_raise(LoadError)
        expect { cli.send(:ensure_bundler_2_7_plus!) }.to raise_error(MockSystemExit, /Bundler is required/)
      end

      it "aborts when bundler version is too low" do
        stub_const("Bundler", Class.new)
        stub_const("Bundler::VERSION", "2.6.9")
        expect { cli.send(:ensure_bundler_2_7_plus!) }.to raise_error(MockSystemExit, /requires Bundler >= 2.7.0/)
      end

      it "passes when bundler meets minimum" do
        stub_const("Bundler", Class.new)
        stub_const("Bundler::VERSION", "2.7.1")
        expect { cli.send(:ensure_bundler_2_7_plus!) }.not_to raise_error
      end
    end

    describe "#update_bundler_and_commit!" do
      it "updates the primary and appraisal bundles before committing only lockfiles" do
        Dir.mktmpdir do |root|
          allow(ci_helpers).to receive(:project_root).and_return(root)
          File.write(File.join(root, "Appraisal.root.gemfile"), "source \"https://rubygems.org\"\n")
          local_cli = described_class.new
          allow(local_cli).to receive(:update_bundler_and_commit!).and_call_original
          git = local_cli.instance_variable_get(:@git)
          paths = ["Gemfile.lock", "Appraisal.root.gemfile.lock"]

          allow(local_cli).to receive(:release_project_command) { |command| "release #{command}" }
          allow(local_cli).to receive(:changed_bundle_lockfile_paths).and_return(paths)
          expect(local_cli).to receive(:run_cmd!).with("release bundle update --bundler").ordered
          expect(local_cli).to receive(:run_cmd!).with(
            "release BUNDLE_GEMFILE=#{Shellwords.escape(File.join(root, "Appraisal.root.gemfile"))} " \
              "BUNDLE_LOCKFILE=#{Shellwords.escape(File.join(root, "Appraisal.root.gemfile.lock"))} bundle update --bundler"
          ).ordered
          expect(local_cli).to receive(:run_cmd!).with("release bundle exec rake appraisal:reset").ordered
          expect(git).to receive(:add_repository_paths).with(paths).and_return(true)
          expect(git).to receive(:commit_staged)
            .with("🔒️ Update bundle", env: hash_including("KETTLE_DEV_DEV" => "false"))
            .and_return(true)
          expect(local_cli).to receive(:reconcile_bundle_update_commit!)

          expect { local_cli.send(:update_bundler_and_commit!) }.not_to raise_error
        end
      end

      it "refuses to mix already-staged non-lockfile changes into the bundle commit" do
        local_cli = described_class.new
        allow(local_cli).to receive(:changed_bundle_lockfile_paths).and_return(["Gemfile.lock"])
        allow(local_cli).to receive(:staged_paths).and_return(["lib/kettle/dev/release_cli.rb"])

        expect { local_cli.send(:commit_bundle_update!) }.to raise_error(
          MockSystemExit,
          /unrelated files are already staged.*release_cli\.rb/m
        )
      end
    end

    describe "#latest_released_versions" do
      let(:response_class) do
        Class.new do
          attr_reader :body
          def initialize(body)
            @body = body
          end

          def is_a?(k)
            k == Net::HTTPSuccess
          end
        end
      end

      it "parses versions and filters prereleases and letters; computes series" do
        versions = [
          {"number" => "1.2.3"},
          {"number" => "1.2.4.pre"},
          {"number" => "1.3.0"},
          {"number" => "2.0.0"},
          {"number" => "1.2.10"},
          {"number" => "1.2.9-alpha"}
        ]
        allow(Kettle::Dev::RubyGemsVersions).to receive(:fetch).with("gemx", version_hint: "1.2.0").and_return(versions)
        overall, series = cli.send(:latest_released_versions, "gemx", "1.2.0")
        expect(overall).to eq("2.0.0")
        expect(series).to eq("1.2.10")
      end

      it "returns [nil, nil] on errors" do
        allow(Kettle::Dev::RubyGemsVersions).to receive(:fetch).and_raise(StandardError)
        overall, series = cli.send(:latest_released_versions, "gemx", "1.2.3")
        expect(overall).to be_nil
        expect(series).to be_nil
      end
    end

    describe "#run_pre_release_checks!" do
      it "normalizes and materializes release lockfiles before changelog coverage can run" do
        release_cli = described_class.new(start_step: 0, skip_steps: "1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19")

        expect(release_cli).to receive(:prepare_release_lockfiles_for_release_tasks!).ordered
        expect(release_cli).to receive(:materialize_release_lockfiles_for_release_tasks!).ordered
        expect(release_cli).to receive(:run_pre_release_checks!).ordered

        expect { release_cli.run }.not_to raise_error
      end

      it "installs each normalized release bundle through a disposable lockfile", :real_release_lockfiles do
        Dir.mktmpdir do |root|
          allow(ci_helpers).to receive(:project_root).and_return(root)
          root_gemfile = File.join(root, "Gemfile")
          root_lockfile = File.join(root, "Gemfile.lock")
          appraisal_gemfile = File.join(root, "Appraisal.root.gemfile")
          appraisal_lockfile = File.join(root, "Appraisal.root.gemfile.lock")
          File.write(root_gemfile, "")
          File.write(appraisal_gemfile, "")
          File.write(root_lockfile, "PLATFORMS\n  x86_64-linux-gnu\n")
          File.write(appraisal_lockfile, "PLATFORMS\n  ruby\n")
          canonical_lockfiles = {
            root_lockfile => File.read(root_lockfile),
            appraisal_lockfile => File.read(appraisal_lockfile)
          }
          release_cli = described_class.new

          expect(release_cli).to receive(:run_cmd!).with(
            a_string_matching(/BUNDLE_GEMFILE=.*Appraisal\.root\.gemfile.*BUNDLE_LOCKFILE=.*tmp\/kettle-release\/lockfiles\/Appraisal\.root\.gemfile-.*\.lock.*bundle install/)
          ).ordered do |command|
            task_lockfile = Shellwords.split(command).find { |part| part.start_with?("BUNDLE_LOCKFILE=") }.delete_prefix("BUNDLE_LOCKFILE=")
            File.write(task_lockfile, "PLATFORMS\n  x86_64-linux\n")
          end
          expect(release_cli).to receive(:run_cmd!).with(
            a_string_matching(/BUNDLE_GEMFILE=.*Gemfile.*BUNDLE_LOCKFILE=.*tmp\/kettle-release\/lockfiles\/Gemfile-.*\.lock.*bundle install/)
          ).ordered do |command|
            task_lockfile = Shellwords.split(command).find { |part| part.start_with?("BUNDLE_LOCKFILE=") }.delete_prefix("BUNDLE_LOCKFILE=")
            File.write(task_lockfile, "PLATFORMS\n  x86_64-linux\n")
          end

          release_cli.send(:materialize_release_lockfiles_for_release_tasks!)

          canonical_lockfiles.each do |path, contents|
            expect(File.read(path)).to eq(contents)
          end
        end
      end

      it "runs kettle-pre-release checks from the beginning and invokes kettle-changelog" do
        pre_release = instance_double(Kettle::Dev::PreReleaseCLI, run: nil)
        expect(Kettle::Dev::PreReleaseCLI).to receive(:new).with(check_num: 1, event_recorder: anything).and_return(pre_release)
        expect(cli).to receive(:run_cmd!).with(a_string_ending_with("bundle exec kettle-changelog"))

        cli.send(:run_pre_release_checks!)
      end

      it "passes an explicit version override to kettle-changelog" do
        versioned_cli = described_class.new(version: "3.2.1")
        pre_release = instance_double(Kettle::Dev::PreReleaseCLI, run: nil)
        expect(Kettle::Dev::PreReleaseCLI).to receive(:new).with(check_num: 1, event_recorder: anything).and_return(pre_release)
        expect(versioned_cli).to receive(:run_cmd!).with(a_string_ending_with("bundle exec kettle-changelog --version 3.2.1"))

        versioned_cli.send(:run_pre_release_checks!)
      end

      it "passes --yes to kettle-changelog when release auto-approval is enabled" do
        yes_cli = described_class.new(yes: true)
        pre_release = instance_double(Kettle::Dev::PreReleaseCLI, run: nil)
        expect(Kettle::Dev::PreReleaseCLI).to receive(:new).with(check_num: 1, event_recorder: anything).and_return(pre_release)
        expect(yes_cli).to receive(:run_cmd!).with(a_string_ending_with("bundle exec kettle-changelog --yes"))

        yes_cli.send(:run_pre_release_checks!)
      end

      it "requests changelog events when release events are enabled" do
        io = StringIO.new
        event_stream = Kettle::Ndjson.event_stream(io, types: "changelog")
        evented_cli = described_class.new(yes: true, event_stream: event_stream)
        pre_release = instance_double(Kettle::Dev::PreReleaseCLI, run: nil)
        expect(Kettle::Dev::PreReleaseCLI).to receive(:new).with(check_num: 1, event_recorder: anything).and_return(pre_release)
        expect(evented_cli).to receive(:run_cmd!).with(a_string_ending_with("bundle exec kettle-changelog --yes --events=changelog"))

        evented_cli.send(:run_pre_release_checks!)
      end
    end

    describe "latest_released_versions (integration with RubyGems.org via VCR)" do
      it "fetches real versions for kettle-dev and does not report a 1.2.x series", :check_output do
        # Use VCR to record once then replay. We avoid making any strong assertion on the exact
        # version numbers to keep the test resilient, but we do assert no 1.2.x appears for this gem.
        cassette = "ruby_gems_versions_kettle_dev"
        overall, series = nil, nil
        # Ensure any previous stubs on Net::HTTP from unit tests do not apply here; we want a real HTTP call (recorded by VCR)
        allow(Net::HTTP).to receive(:get_response).and_call_original
        VCR.use_cassette(cassette) do
          overall, series = cli.send(:latest_released_versions, "kettle-dev", "1.0.0")
        end
        # Basic sanity
        expect(overall).to be_a(String).or be_nil
        expect(series).to be_a(String).or be_nil
        # The reported bug was seeing a 1.2.x. Assert that does not occur for this gem.
        expect(overall&.start_with?("1.2.")).to be(false)
        expect(series&.start_with?("1.2.")).to be(false)
      end
    end

    describe "#commit_release_prep!" do
      it "returns false when no changes" do
        git = cli.instance_variable_get(:@git)
        expect(git).to receive(:add_all).and_return(true)
        allow(cli).to receive(:git_output).with(%w[status --porcelain]).and_return(["", true])
        expect(cli.send(:commit_release_prep!, "1.0.0")).to be false
      end

      it "commits and returns true when there are changes" do
        git = cli.instance_variable_get(:@git)
        allow(cli).to receive(:git_output).with(%w[status --porcelain]).and_return([" M file", true], ["", true])
        expect(git).to receive(:add_all).and_return(true)
        expect(git).to receive(:commit_all)
          .with("🔖 Prepare release v1.0.0", env: hash_including("KETTLE_DEV_DEV" => "false"))
          .and_return(true)
        expect(git).not_to receive(:commit_amend_no_edit)
        expect(cli.send(:commit_release_prep!, "1.0.0")).to be true
      end

      it "marks aggregate family validation and member release commits explicitly" do
        stub_env("KETTLE_RELEASE_FAMILY_CI_MODE" => "validation")
        expect(cli.send(:release_prep_ci_marker)).to eq(" [kettle-family:aggregate-ci]")

        stub_env("KETTLE_RELEASE_FAMILY_CI_MODE" => "member")
        expect(cli.send(:release_prep_ci_marker)).to eq(" [kettle-family:aggregate-member]")
      end
    end

    describe "#push!" do
      it "aborts when branch is unknown" do
        allow(cli).to receive(:current_branch).and_return(nil)
        expect { cli.send(:push!) }.to raise_error(MockSystemExit, /Could not determine current branch/)
      end

      it "pushes to 'all' and force-pushes on failure" do
        allow(cli).to receive(:current_branch).and_return("feat")
        allow(cli).to receive(:has_remote?).with("all").and_return(true)
        git = cli.instance_variable_get(:@git)
        expect(git).to receive(:push).with("all", "feat").and_return(false)
        expect(git).to receive(:push).with("all", "feat", force: true)
        cli.send(:push!)
      end

      it "pushes branch with no remotes and force on failure" do
        allow(cli).to receive(:current_branch).and_return("feat")
        allow(cli).to receive(:has_remote?).with("all").and_return(false)
        allow(cli).to receive(:has_remote?).with("origin").and_return(false)
        allow(cli).to receive(:github_remote_candidates).and_return([])
        allow(cli).to receive(:gitlab_remote_candidates).and_return([])
        allow(cli).to receive(:codeberg_remote_candidates).and_return([])
        git = cli.instance_variable_get(:@git)
        expect(git).to receive(:push).with(nil, "feat").and_return(false)
        expect(git).to receive(:push).with(nil, "feat", force: true)
        cli.send(:push!)
      end

      it "pushes to multiple remotes and force on failures" do
        allow(cli).to receive(:current_branch).and_return("feat")
        allow(cli).to receive(:has_remote?).with("all").and_return(false)
        allow(cli).to receive(:has_remote?).with("origin").and_return(true)
        allow(cli).to receive(:github_remote_candidates).and_return(["github"])
        allow(cli).to receive(:gitlab_remote_candidates).and_return(["gitlab"])
        allow(cli).to receive(:codeberg_remote_candidates).and_return([])
        git = cli.instance_variable_get(:@git)
        expect(git).to receive(:push).with("origin", "feat").and_return(true)
        expect(git).to receive(:push).with("github", "feat").and_return(false)
        expect(git).to receive(:push).with("github", "feat", force: true)
        expect(git).to receive(:push).with("gitlab", "feat").and_return(true)
        cli.send(:push!)
      end

      it "does not push through the all aggregate when remotes are skipped" do
        cli = described_class.new(skip_remotes: "cb")
        allow(cli).to receive(:current_branch).and_return("feat")
        allow(cli).to receive(:has_remote?).with("all").and_return(true)
        allow(cli).to receive(:has_remote?).with("origin").and_return(true)
        allow(cli).to receive(:github_remote_candidates).and_return(["origin", "gh"])
        allow(cli).to receive(:gitlab_remote_candidates).and_return(["gl"])
        allow(cli).to receive(:codeberg_remote_candidates).and_return([])
        git = cli.instance_variable_get(:@git)
        expect(git).not_to receive(:push).with("all", "feat")
        expect(git).to receive(:push).with("origin", "feat").and_return(true)
        expect(git).to receive(:push).with("gh", "feat").and_return(true)
        expect(git).to receive(:push).with("gl", "feat").and_return(true)
        cli.send(:push!)
      end
    end

    describe "git and system helpers" do
      it "detects trunk branch from origin remote output (still via git command)" do
        out = "Remote HEAD branch: main\n  HEAD branch: main\n"
        allow(cli).to receive(:git_output).with(%w[remote show origin]).and_return([out, true])
        expect(cli.send(:detect_trunk_branch)).to eq("main")
      end

      it "parses remotes_with_urls and candidates" do
        git = cli.instance_variable_get(:@git)
        allow(git).to receive(:remotes_with_urls).and_return({
          "origin" => "git@github.com:me/repo.git",
          "github" => "https://github.com/me/repo.git",
          "gl" => "https://gitlab.com/me/repo",
          "cb" => "git@codeberg.org:me/repo.git"
        })
        urls = cli.send(:remotes_with_urls)
        expect(urls["origin"]).to include("github.com")
        expect(cli.send(:github_remote_candidates)).to include("origin", "github")
        expect(cli.send(:gitlab_remote_candidates)).to include("gl")
        expect(cli.send(:codeberg_remote_candidates)).to include("cb")
        expect(cli.send(:preferred_github_remote)).to eq("github")
      end

      it "filters skipped remotes from candidates" do
        cli = described_class.new(skip_remotes: "cb,github")
        git = cli.instance_variable_get(:@git)
        allow(git).to receive(:remotes_with_urls).and_return({
          "origin" => "git@github.com:me/repo.git",
          "github" => "https://github.com/me/repo.git",
          "cb" => "git@codeberg.org:me/repo.git"
        })

        expect(cli.send(:github_remote_candidates)).to eq(["origin"])
        expect(cli.send(:codeberg_remote_candidates)).to be_empty
      end

      it "parses github owner/repo from ssh and https and fails otherwise" do
        expect(cli.send(:parse_github_owner_repo, "git@github.com:user/repo.git")).to eq(%w[user repo])
        expect(cli.send(:parse_github_owner_repo, "git+ssh://git@github.com/user/repo.git")).to eq(%w[user repo])
        expect(cli.send(:parse_github_owner_repo, "ssh://git@github.com/user/repo.git")).to eq(%w[user repo])
        expect(cli.send(:parse_github_owner_repo, "https://github.com/user/repo")).to eq(%w[user repo])
        expect(cli.send(:parse_github_owner_repo, "ssh://gitlab.com/user/repo")).to eq([nil, nil])
      end

      it "computes ahead/behind from git output and handles empty" do
        allow(cli).to receive(:git_output).and_return(["3\t2", true], ["", false])
        expect(cli.send(:ahead_behind_counts, "a", "b")).to eq([3, 2])
        expect(cli.send(:ahead_behind_counts, "a", "b")).to eq([0, 0])
      end

      it "checks trunk_behind_remote? based on remote branch and counts" do
        allow(cli).to receive(:remote_branch_exists?).with("origin", "main").and_return(true)
        allow(cli).to receive(:ahead_behind_counts).with("main", "origin/main").and_return([0, 1])
        expect(cli.send(:trunk_behind_remote?, "main", "origin")).to be true
      end

      it "skips GitHub pull request setup when releasing from trunk" do
        allow(cli).to receive(:current_branch).and_return("main")
        allow(cli).to receive(:detect_trunk_branch).and_return("main")
        expect(cli).not_to receive(:github_pull_request_for_branch)

        cli.send(:ensure_github_pull_request_for_ci!)
      end

      it "reuses an open GitHub pull request before CI monitoring", :check_output do
        allow(cli).to receive(:current_branch).and_return("feature/release")
        allow(cli).to receive(:detect_trunk_branch).and_return("main")
        allow(cli).to receive(:preferred_github_remote).and_return("origin")
        allow(cli).to receive(:remote_url).with("origin").and_return("git@github.com:me/repo.git")
        allow(cli).to receive(:github_pull_request_for_branch).with(
          owner: "me",
          repo: "repo",
          branch: "feature/release",
          base: "main"
        ).and_return({"number" => 42, "url" => "https://github.com/me/repo/pull/42"})
        expect(cli).not_to receive(:create_github_pull_request!)

        cli.send(:ensure_github_pull_request_for_ci!)
      end

      it "creates a GitHub pull request before CI monitoring when none is open" do
        allow(cli).to receive(:current_branch).and_return("feature/release")
        allow(cli).to receive(:detect_trunk_branch).and_return("main")
        allow(cli).to receive(:preferred_github_remote).and_return("origin")
        allow(cli).to receive(:remote_url).with("origin").and_return("git@github.com:me/repo.git")
        allow(cli).to receive(:github_pull_request_for_branch).and_return(nil)

        expect(cli).to receive(:create_github_pull_request!).with(
          owner: "me",
          repo: "repo",
          branch: "feature/release",
          base: "main"
        )

        cli.send(:ensure_github_pull_request_for_ci!)
      end

      it "git_output trims and returns success flag" do
        # Ensure GitAdapter is used and its output is trimmed
        adapter = instance_double(Kettle::Dev::GitAdapter)
        allow(Kettle::Dev::GitAdapter).to receive(:new).and_return(adapter)
        allow(adapter).to receive(:capture).with(["rev-parse"]).and_return([" abc\n", true])
        cli = described_class.new
        out, ok = cli.send(:git_output, ["rev-parse"])
        expect(out).to eq("abc")
        expect(ok).to be(true)
      end

      it "maybe_run_local_ci_before_push! handles missing act command", :check_output do
        Dir.mktmpdir do |root|
          allow(ci_helpers).to receive(:project_root).and_return(root)
          FileUtils.mkdir_p(File.join(root, ".github", "workflows"))
          # Enable run
          cli = described_class.new
          # Raise from system("act", "--version", ...)
          allow(cli).to receive(:system).and_wrap_original do |orig, *args|
            if args[0] == "act" && args[1] == "--version"
              raise "no act"
            else
              orig.call(*args)
            end
          end
          stub_env("K_RELEASE_LOCAL_CI" => "true")
          expect { cli.send(:maybe_run_local_ci_before_push!, false) }.to output(/Skipping local CI: 'act' command not found/).to_stdout
        end
      end

      it "selects workflow via ENV without extension (adds .yml) and prefers .yaml for locked_deps", :check_output do
        Dir.mktmpdir do |root|
          allow(ci_helpers).to receive(:project_root).and_return(root)
          dir = File.join(root, ".github", "workflows")
          FileUtils.mkdir_p(dir)
          File.write(File.join(dir, "ci.yml"), "name: CI\n")
          File.write(File.join(dir, "locked_deps.yaml"), "name: Lock\n")

          cli = described_class.new
          # Make "act --version" succeed and capture the -W <path> invocation
          ran_paths = []
          allow(cli).to receive(:system).and_wrap_original do |orig, *args|
            if args[0] == "act" && args[1] == "--version"
              true
            elsif args[0] == "act" && args[1] == "-W"
              ran_paths << args[2]
              true # pretend local CI succeeded
            else
              orig.call(*args)
            end
          end

          # Case 1: ENV chooses "ci" -> should append .yml
          # Case 1: ENV chooses "ci" -> should append .yml
          stub_env("K_RELEASE_LOCAL_CI" => "true", "K_RELEASE_LOCAL_CI_WORKFLOW" => "ci")
          expect { cli.send(:maybe_run_local_ci_before_push!, false) }.not_to raise_error
          expect(ran_paths.last).to end_with("/ci.yml")

          # Case 2: No ENV, candidates include locked_deps.yaml -> choose .yaml variant
          ran_paths.clear
          stub_env("K_RELEASE_LOCAL_CI" => "true", "K_RELEASE_LOCAL_CI_WORKFLOW" => "")
          expect { cli.send(:maybe_run_local_ci_before_push!, false) }.not_to raise_error
          expect(ran_paths.last).to end_with("/locked_deps.yaml")
        end
      end

      it "preferred_github_remote returns origin when present" do
        cli = described_class.new
        expect(cli.send(:preferred_github_remote)).to eq("origin")
      end

      it "remote_branch_exists? reflects git show-ref success flag" do
        cli = described_class.new
        allow(cli).to receive(:git_output).and_return(["", false])
        expect(cli.send(:remote_branch_exists?, "origin", "main")).to be(false)
      end
    end

    describe "#ensure_trunk_synced_before_push!" do
      it "enforces strict parity when remote 'all' is present and aborts if missing commits" do
        allow(cli).to receive(:has_remote?).with("all").and_return(true)
        allow(cli).to receive(:list_remotes).and_return(%w[all origin github])
        expect(cli).to receive(:run_cmd!).with("git fetch origin")
        expect(cli).to receive(:run_cmd!).with("git fetch github")
        allow(cli).to receive(:remote_branch_exists?).with("origin", "main").and_return(true)
        allow(cli).to receive(:ahead_behind_counts).with("main", "origin/main").and_return([0, 1])
        allow(cli).to receive(:remote_branch_exists?).with("github", "main").and_return(true)
        allow(cli).to receive(:ahead_behind_counts).with("main", "github/main").and_return([0, 0])
        expect { cli.send(:ensure_trunk_synced_before_push!, "main", "feat") }.to raise_error(MockSystemExit, /missing commits present on: origin/)
      end

      it "reports parity when all remotes are synced" do
        allow(cli).to receive(:has_remote?).with("all").and_return(true)
        allow(cli).to receive(:list_remotes).and_return(%w[all origin])
        expect(cli).to receive(:run_cmd!).with("git fetch origin")
        allow(cli).to receive(:remote_branch_exists?).with("origin", "main").and_return(true)
        allow(cli).to receive(:ahead_behind_counts).with("main", "origin/main").and_return([0, 0])
        expect { cli.send(:ensure_trunk_synced_before_push!, "main", "feat") }.not_to raise_error
      end

      it "skips a non-required active remote that cannot be fetched" do
        allow(cli).to receive(:has_remote?).with("all").and_return(true)
        allow(cli).to receive(:list_remotes).and_return(%w[all origin cb])
        allow(cli).to receive(:remote_fetch_parity_attempts).and_return(2)
        allow(cli).to receive(:remote_fetch_parity_interval).and_return(0)
        expect(cli).to receive(:run_cmd!).with("git fetch origin")
        expect(cli).to receive(:run_cmd!).with("git fetch cb").twice.and_raise(MockSystemExit, "Command failed: git fetch cb (exit 128)")
        expect(cli).to receive(:sleep).with(0).once
        allow(cli).to receive(:remote_branch_exists?).with("origin", "main").and_return(true)
        allow(cli).to receive(:ahead_behind_counts).with("main", "origin/main").and_return([0, 0])
        expect(cli).not_to receive(:remote_branch_exists?).with("cb", "main")

        expect { cli.send(:ensure_trunk_synced_before_push!, "main", "feat") }.not_to raise_error
      end

      it "emits remote parity events for skipped optional remotes" do
        io = StringIO.new
        event_stream = Kettle::Ndjson.event_stream(io, types: "remote_parity")
        local_cli = described_class.new(event_stream: event_stream)
        allow(local_cli).to receive(:has_remote?).with("all").and_return(true)
        allow(local_cli).to receive(:list_remotes).and_return(%w[all origin cb])
        allow(local_cli).to receive(:remote_fetch_parity_attempts).and_return(1)
        expect(local_cli).to receive(:run_cmd!).with("git fetch origin")
        expect(local_cli).to receive(:run_cmd!).with("git fetch cb").and_raise(MockSystemExit, "Command failed: git fetch cb (exit 128)")
        allow(local_cli).to receive(:remote_branch_exists?).with("origin", "main").and_return(true)
        allow(local_cli).to receive(:ahead_behind_counts).with("main", "origin/main").and_return([0, 0])

        expect { local_cli.send(:ensure_trunk_synced_before_push!, "main", "feat") }.not_to raise_error

        events = io.string.lines.map { |line| JSON.parse(line) }
        expect(events).to include(
          include("type" => "remote_parity", "action" => "start", "status" => "started", "trunk" => "main"),
          include("type" => "remote_parity", "action" => "fetch", "remote" => "origin", "status" => "ok", "required" => true),
          include("type" => "remote_parity", "action" => "skip", "remote" => "cb", "status" => "skipped", "required" => false),
          include("type" => "remote_parity", "action" => "ok", "status" => "ok", "trunk" => "main")
        )
      end

      it "blocks release when a required active remote cannot be fetched" do
        cli = described_class.new(required_remotes: "origin,cb")
        allow(cli).to receive(:has_remote?).with("all").and_return(true)
        allow(cli).to receive(:list_remotes).and_return(%w[all origin cb])
        allow(cli).to receive(:remote_fetch_parity_attempts).and_return(2)
        allow(cli).to receive(:remote_fetch_parity_interval).and_return(0)
        expect(cli).to receive(:run_cmd!).with("git fetch origin")
        expect(cli).to receive(:run_cmd!).with("git fetch cb").twice.and_raise(MockSystemExit, "Command failed: git fetch cb (exit 128)")
        expect(cli).to receive(:sleep).with(0).once

        expect do
          cli.send(:ensure_trunk_synced_before_push!, "main", "feat")
        end.to raise_error(MockSystemExit) { |error|
          expect(error.message).to include("Unable to fetch required git remote 'cb'")
          expect(error.message).to include("kettle-release --skip-remotes cb")
          expect(error.message).to include("K_RELEASE_SKIP_REMOTES=cb kettle-release")
          expect(error.message).to include("Command failed: git fetch cb")
        }
      end

      it "emits remote parity failure events for failed required remotes" do
        io = StringIO.new
        event_stream = Kettle::Ndjson.event_stream(io, types: "remote_parity")
        local_cli = described_class.new(event_stream: event_stream, required_remotes: "origin,cb")
        allow(local_cli).to receive(:has_remote?).with("all").and_return(true)
        allow(local_cli).to receive(:list_remotes).and_return(%w[all origin cb])
        allow(local_cli).to receive(:remote_fetch_parity_attempts).and_return(1)
        expect(local_cli).to receive(:run_cmd!).with("git fetch origin")
        expect(local_cli).to receive(:run_cmd!).with("git fetch cb").and_raise(MockSystemExit, "Command failed: git fetch cb (exit 128)")

        expect do
          local_cli.send(:ensure_trunk_synced_before_push!, "main", "feat")
        end.to raise_error(MockSystemExit)

        events = io.string.lines.map { |line| JSON.parse(line) }
        expect(events).to include(
          include("type" => "remote_parity", "action" => "fetch", "remote" => "cb", "status" => "failed", "required" => true)
        )
      end

      it "retries transient remote fetch failures before checking parity" do
        allow(cli).to receive(:has_remote?).with("all").and_return(true)
        allow(cli).to receive(:list_remotes).and_return(%w[all cb])
        allow(cli).to receive(:remote_fetch_parity_attempts).and_return(3)
        allow(cli).to receive(:remote_fetch_parity_interval).and_return(0)
        expect(cli).to receive(:run_cmd!).with("git fetch cb").ordered.and_raise(MockSystemExit, "transient")
        expect(cli).to receive(:sleep).with(0).ordered
        expect(cli).to receive(:run_cmd!).with("git fetch cb").ordered
        allow(cli).to receive(:remote_branch_exists?).with("cb", "main").and_return(true)
        allow(cli).to receive(:ahead_behind_counts).with("main", "cb/main").and_return([0, 0])

        expect { cli.send(:ensure_trunk_synced_before_push!, "main", "feat") }.not_to raise_error
      end

      it "skips configured remotes while enforcing all-remote parity" do
        cli = described_class.new(skip_remotes: "cb")
        allow(cli).to receive(:has_remote?).with("all").and_return(true)
        allow(cli).to receive(:list_remotes).and_return(%w[all origin cb])
        expect(cli).to receive(:run_cmd!).with("git fetch origin")
        expect(cli).not_to receive(:run_cmd!).with("git fetch cb")
        allow(cli).to receive(:remote_branch_exists?).with("origin", "main").and_return(true)
        allow(cli).to receive(:ahead_behind_counts).with("main", "origin/main").and_return([0, 0])
        expect(cli).not_to receive(:remote_branch_exists?).with("cb", "main")

        expect { cli.send(:ensure_trunk_synced_before_push!, "main", "feat") }.not_to raise_error
      end

      it "rebases when trunk is behind origin and then rebases feature" do
        allow(cli).to receive(:has_remote?).with("all").and_return(false)
        # Allow additional run_cmd! calls (e.g., fetching a GitHub remote) without failing this example
        allow(cli).to receive(:run_cmd!)

        allow(cli).to receive(:trunk_behind_remote?).with("main", "origin").and_return(true)
        allow(cli).to receive(:current_branch).and_return("feat")
        expect(cli).to receive(:checkout!).with("main")
        expect(cli).to receive(:checkout!).with("feat")

        cli.send(:ensure_trunk_synced_before_push!, "main", "feat")

        # Assert key run_cmd! invocations happened, regardless of any extra fetches against other remotes
        expect(cli).to have_received(:run_cmd!).with("git fetch origin main")
        expect(cli).to have_received(:run_cmd!).with("git pull --rebase origin main")
        expect(cli).to have_received(:run_cmd!).with("git rebase main")
      end

      it "handles github remote sync fast-forward case" do
        allow(cli).to receive(:has_remote?).with("all").and_return(false)
        expect(cli).to receive(:run_cmd!).with("git fetch origin main")
        allow(cli).to receive(:trunk_behind_remote?).and_return(false)
        allow(cli).to receive(:preferred_github_remote).and_return("github")
        expect(cli).to receive(:run_cmd!).with("git fetch github main")
        allow(cli).to receive(:ahead_behind_counts).with("origin/main", "github/main").and_return([0, 2])
        expect(cli).to receive(:checkout!).with("main")
        expect(cli).to receive(:run_cmd!).with("git pull --rebase origin main")
        expect(cli).to receive(:run_cmd!).with("git merge --ff-only github/main")
        expect(cli).to receive(:run_cmd!).with("git push origin main")
        cli.send(:ensure_trunk_synced_before_push!, "main", "feat")
      end

      it "prints no action when origin ahead of github" do
        allow(cli).to receive(:has_remote?).with("all").and_return(false)
        expect(cli).to receive(:run_cmd!).with("git fetch origin main")
        allow(cli).to receive(:trunk_behind_remote?).and_return(false)
        allow(cli).to receive(:preferred_github_remote).and_return("github")
        expect(cli).to receive(:run_cmd!).with("git fetch github main")
        allow(cli).to receive(:ahead_behind_counts).with("origin/main", "github/main").and_return([3, 0])
        expect(cli).to receive(:checkout!).with("main")
        expect(cli).to receive(:run_cmd!).with("git pull --rebase origin main")
        cli.send(:ensure_trunk_synced_before_push!, "main", "feat")
      end
    end

    describe "#merge_feature_into_trunk_and_push!" do
      it "no-ops when feature is trunk" do
        expect(cli.send(:merge_feature_into_trunk_and_push!, "main", "main")).to be_nil
      end

      it "merges and pushes when feature differs" do
        expect(cli).to receive(:checkout!).with("main")
        expect(cli).to receive(:run_cmd!).with("git pull --rebase origin main")
        expect(cli).to receive(:run_cmd!).with("git merge feat")
        expect(cli).to receive(:run_cmd!).with("git push origin main")
        cli.send(:merge_feature_into_trunk_and_push!, "main", "feat")
      end
    end

    describe "kettle-family branch stack releases" do
      it "detects local release target branches from .kettle-family.yml" do
        Dir.mktmpdir do |root|
          File.write(File.join(root, ".kettle-family.yml"), <<~YAML)
            release:
              target_branches:
                - r1_8-even-v0
                - main
          YAML
          allow(ci_helpers).to receive(:project_root).and_return(root)
          local_cli = described_class.new

          expect(local_cli.send(:branch_stack_release_branch?, "r1_8-even-v0", "main")).to be(true)
          expect(local_cli.send(:branch_stack_release_branch?, "main", "main")).to be(false)
          expect(local_cli.send(:branch_stack_release_branch?, "feature", "main")).to be(false)
        end
      end

      it "skips trunk sync, merge, and checkout for a local branch-stack release branch" do
        Dir.mktmpdir do |root|
          File.write(File.join(root, ".kettle-family.yml"), <<~YAML)
            release:
              target_branches:
                - r1_8-even-v0
                - main
          YAML
          allow(ci_helpers).to receive(:project_root).and_return(root)
          local_cli = described_class.new(start_step: 8, skip_steps: "9,10,13,14,15,16,17,18,19")
          allow(local_cli).to receive(:detect_trunk_branch).and_return("main")
          allow(local_cli).to receive(:current_branch).and_return("r1_8-even-v0")
          allow(local_cli).to receive(:push!)
          allow(local_cli).to receive(:monitor_workflows_after_push!)
          allow(local_cli).to receive(:ensure_signing_setup_or_skip!)
          allow(local_cli).to receive(:validate_checksums!)
          allow(local_cli).to receive(:push_tags!)

          expect(local_cli).not_to receive(:ensure_trunk_synced_before_push!)
          expect(local_cli).not_to receive(:merge_feature_into_trunk_and_push!)
          expect(local_cli).not_to receive(:checkout!)
          expect(local_cli).not_to receive(:pull!)

          expect { local_cli.run }.not_to raise_error
        end
      end
    end

    describe "#ensure_signing_setup_or_skip!" do
      it "returns early when SKIP_GEM_SIGNING is set to true" do
        stub_env("SKIP_GEM_SIGNING" => "true")
        expect(cli.send(:ensure_signing_setup_or_skip!)).to be_nil
      end

      it "aborts when cert is missing and signing enabled" do
        Dir.mktmpdir do |root|
          allow(ci_helpers).to receive(:project_root).and_return(root)
          other = described_class.new
          stub_env("SKIP_GEM_SIGNING" => "false", "GEM_CERT_USER" => "alice", "USER" => "bob")
          expect { other.send(:ensure_signing_setup_or_skip!) }.to raise_error(MockSystemExit, /no public cert/)
        end
      end

      it "passes when cert exists" do
        Dir.mktmpdir do |root|
          FileUtils.mkdir_p(File.join(root, "certs"))
          File.write(File.join(root, "certs", "bob.pem"), "cert")
          allow(ci_helpers).to receive(:project_root).and_return(root)
          other = described_class.new
          stub_env("SKIP_GEM_SIGNING" => nil, "GEM_CERT_USER" => nil, "USER" => "bob")
          expect { other.send(:ensure_signing_setup_or_skip!) }.not_to raise_error
        end
      end
    end

    describe "checksums helpers" do
      it "validates checksums success and failure and locates gem by version" do
        Dir.mktmpdir do |root|
          pkg = File.join(root, "pkg")
          chks = File.join(root, "checksums")
          FileUtils.mkdir_p(pkg)
          FileUtils.mkdir_p(chks)
          gem_a = File.join(pkg, "mygem-1.0.0.gem")
          File.write(gem_a, "hello world")
          expected = Digest::SHA256.hexdigest("hello world")
          File.write(File.join(chks, "mygem-1.0.0.gem.sha256"), expected)
          allow(ci_helpers).to receive(:project_root).and_return(root)
          local_cli = described_class.new
          expect { local_cli.send(:validate_checksums!, "1.0.0", stage: "stage") }.not_to raise_error
          File.write(File.join(chks, "mygem-1.0.0.gem.sha256"), "deadbeef")
          expect { local_cli.send(:validate_checksums!, "1.0.0", stage: "stage") }.to raise_error(MockSystemExit, /SHA256 mismatch/)
        end
      end

      it "compute_sha256 falls back to Digest when no sha utilities" do
        Dir.mktmpdir do |root|
          file = File.join(root, "file.bin")
          File.binwrite(file, "abc")
          allow(cli).to receive(:system).with("which sha256sum > /dev/null 2>&1").and_return(false)
          allow(cli).to receive(:system).with("which shasum > /dev/null 2>&1").and_return(false)
          expect(cli.send(:compute_sha256, file)).to eq(Digest::SHA256.hexdigest("abc"))
        end
      end
    end

    describe "#monitor_workflows_after_push!" do
      before do
        allow(cli).to receive(:ensure_github_pull_request_for_ci!)
        allow(ci_helpers).to receive(:project_root).and_return(Dir.pwd)
        allow(ci_helpers).to receive(:current_branch).and_return("feat")
        allow(Kettle::Dev::CIMonitor).to receive(:preferred_github_remote).and_return("origin")
        allow(Kettle::Dev::CIMonitor).to receive(:remote_url).with("origin").and_return("git@github.com:me/repo.git")
      end

      it "aborts when branch cannot be determined" do
        allow(ci_helpers).to receive(:current_branch).and_return(nil)
        expect { cli.send(:monitor_workflows_after_push!) }.to raise_error(MockSystemExit, /Could not determine current branch/)
      end

      it "passes when GitHub workflows all succeed" do
        allow(ci_helpers).to receive(:workflows_list).and_return(%w[ci.yml lint.yml])
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(File.join(Dir.pwd, ".gitlab-ci.yml")).and_return(false)
        run1 = {"html_url" => "http://example/1"}
        run2 = {"html_url" => "http://example/2"}
        allow(ci_helpers).to receive(:current_head_sha).and_return("abc123")
        allow(ci_helpers).to receive(:latest_run).with(owner: "me", repo: "repo", workflow_file: "ci.yml", branch: "feat", require_head: true, head_sha: "abc123").and_return(run1)
        allow(ci_helpers).to receive(:latest_run).with(owner: "me", repo: "repo", workflow_file: "lint.yml", branch: "feat", require_head: true, head_sha: "abc123").and_return(run2)
        allow(ci_helpers).to receive(:success?).and_return(true)
        expect { cli.send(:monitor_workflows_after_push!) }.not_to raise_error
        expect(cli).to have_received(:ensure_github_pull_request_for_ci!)
      end

      it "passes an explicit normalized workflow subset to the CI monitor" do
        release_cli = described_class.new(ci_workflows: "current,style.yml")
        allow(release_cli).to receive(:ensure_github_pull_request_for_ci!)
        allow(Kettle::Dev::CIMonitor).to receive(:monitor_all!) do |event_recorder:, **_kwargs|
          Kettle::Ndjson.emit_event(
            event_recorder,
            "ci_monitor",
            action: "github_wait",
            provider: "github",
            status: "started",
            completed: 0,
            total: 1,
            mark: ">"
          )
        end

        release_cli.send(:monitor_workflows_after_push!)

        expect(Kettle::Dev::CIMonitor).to have_received(:monitor_all!).with(
          restart_hint: "bundle exec kettle-release --start-step 10",
          workflows: %w[current.yml style.yml],
          keepalive: nil,
          event_recorder: anything
        )
      end

      it "emits CI monitor events when workflows pass" do
        io = StringIO.new
        event_stream = Kettle::Ndjson.event_stream(io, types: "ci_monitor")
        release_cli = described_class.new(ci_workflows: "current", event_stream: event_stream)
        allow(release_cli).to receive(:ensure_github_pull_request_for_ci!)
        allow(Kettle::Dev::CIMonitor).to receive(:monitor_all!) do |event_recorder:, **_kwargs|
          Kettle::Ndjson.emit_event(
            event_recorder,
            "ci_monitor",
            action: "github_wait",
            provider: "github",
            status: "started",
            completed: 0,
            total: 1,
            mark: ">"
          )
        end

        release_cli.send(:monitor_workflows_after_push!)

        events = io.string.lines.map { |line| JSON.parse(line) }
        expect(events).to contain_exactly(
          include(
            "type" => "ci_monitor",
            "action" => "start",
            "status" => "started",
            "workflows" => ["current.yml"],
            "mark" => ">"
          ),
          include(
            "type" => "ci_monitor",
            "action" => "github_wait",
            "status" => "started",
            "provider" => "github",
            "completed" => 0,
            "total" => 1,
            "mark" => ">"
          ),
          include(
            "type" => "ci_monitor",
            "action" => "finish",
            "status" => "ok",
            "workflows" => ["current.yml"],
            "mark" => "."
          )
        )
      end

      it "emits CI monitor failure events when workflows fail" do
        io = StringIO.new
        event_stream = Kettle::Ndjson.event_stream(io, types: "ci_monitor")
        release_cli = described_class.new(event_stream: event_stream)
        allow(release_cli).to receive(:ensure_github_pull_request_for_ci!)
        allow(Kettle::Dev::CIMonitor).to receive(:monitor_all!).and_raise(MockSystemExit, "Workflow failed: ci.yml")

        expect { release_cli.send(:monitor_workflows_after_push!) }.to raise_error(MockSystemExit, /Workflow failed/)

        events = io.string.lines.map { |line| JSON.parse(line) }
        expect(events).to include(
          include("type" => "ci_monitor", "action" => "finish", "status" => "failed", "reason" => include("Workflow failed: ci.yml"), "mark" => "!")
        )
      end

      it "uses K_RELEASE_CI_WORKFLOWS when no explicit workflow subset is passed" do
        stub_env("K_RELEASE_CI_WORKFLOWS" => "current,style.yml")
        release_cli = described_class.new
        allow(release_cli).to receive(:ensure_github_pull_request_for_ci!)
        allow(Kettle::Dev::CIMonitor).to receive(:monitor_all!)

        release_cli.send(:monitor_workflows_after_push!)

        expect(Kettle::Dev::CIMonitor).to have_received(:monitor_all!).with(
          restart_hint: "bundle exec kettle-release --start-step 10",
          workflows: %w[current.yml style.yml],
          keepalive: nil,
          event_recorder: anything
        )
      end

      it "keeps configured release secrets alive while monitoring CI" do
        provider = instance_double(Kettle::Dev::ReleaseSecrets::OnePassword)
        release_cli = described_class.new(secrets_provider: provider)
        allow(provider).to receive(:keepalive_required?).and_return(true)
        allow(provider).to receive(:keepalive!).with(elapsed: nil).and_return(true)
        allow(release_cli).to receive(:ensure_github_pull_request_for_ci!)
        allow(Kettle::Dev::CIMonitor).to receive(:monitor_all!)

        release_cli.send(:monitor_workflows_after_push!)

        expect(provider).to have_received(:keepalive!).with(elapsed: nil).once
        expect(Kettle::Dev::CIMonitor).to have_received(:monitor_all!).with(
          restart_hint: "bundle exec kettle-release --start-step 10",
          workflows: [],
          keepalive: kind_of(Proc),
          event_recorder: anything
        )
      end

      it "passes overall release elapsed time to release secret keepalive" do
        provider = instance_double(Kettle::Dev::ReleaseSecrets::OnePassword)
        release_cli = described_class.new(secrets_provider: provider)
        allow(provider).to receive(:keepalive_required?).and_return(true)
        release_cli.instance_variable_set(:@started_at, 100.0)
        allow(release_cli).to receive(:monotonic_time).and_return(223.4)
        allow(provider).to receive(:keepalive!).with(elapsed: "02:03").and_return(true)

        release_cli.send(:keep_release_secrets_alive!, "test")

        expect(provider).to have_received(:keepalive!).with(elapsed: "02:03")
      end

      it "emits secret provider events around release secret keepalive" do
        io = StringIO.new
        event_stream = Kettle::Ndjson.event_stream(io, types: "secret_provider")
        provider = instance_double(Kettle::Dev::ReleaseSecrets::OnePassword)
        release_cli = described_class.new(secrets_provider: provider, event_stream: event_stream)
        allow(provider).to receive(:keepalive_required?).and_return(true)
        allow(provider).to receive(:keepalive!).with(elapsed: nil).and_return(true)

        release_cli.send(:keep_release_secrets_alive!, "test")

        events = io.string.lines.map { |line| JSON.parse(line) }
        expect(events).to contain_exactly(
          include("type" => "secret_provider", "action" => "keepalive", "status" => "started", "purpose" => "test", "mark" => ">"),
          include("type" => "secret_provider", "action" => "keepalive", "status" => "ok", "purpose" => "test", "mark" => ".")
        )
      end

      it "aborts when a GitHub workflow fails" do
        allow(ci_helpers).to receive(:workflows_list).and_return(["ci.yml"])
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(File.join(Dir.pwd, ".gitlab-ci.yml")).and_return(false)
        allow(Kettle::Dev::CIMonitor).to receive(:gitlab_remote_candidates).and_return([])
        allow(ci_helpers).to receive(:current_head_sha).and_return("abc123")
        run = {"html_url" => "http://example/ci"}
        allow(ci_helpers).to receive(:latest_run).and_return(run)
        allow(ci_helpers).to receive(:success?).and_return(false)
        allow(ci_helpers).to receive(:failed?).and_return(true)
        expect { cli.send(:monitor_workflows_after_push!) }.to raise_error(MockSystemExit, /Workflow failed: .*--start-step 10/)
      end

      it "continues the release when CI failures are explicitly allowed" do
        stub_env("K_RELEASE_CI_CONTINUE" => "true")
        io = StringIO.new
        event_stream = Kettle::Ndjson.event_stream(io, types: "ci_monitor")
        release_cli = described_class.new(event_stream: event_stream)
        allow(release_cli).to receive(:ensure_github_pull_request_for_ci!)
        allow(Kettle::Dev::CIMonitor).to receive(:monitor_all!).and_return(false)

        expect { release_cli.send(:monitor_workflows_after_push!) }.not_to raise_error
        expect(io.string).to include('"status":"continued"')
      end

      it "handles GitLab pipeline success" do
        allow(Kettle::Dev::CIMonitor).to receive(:preferred_github_remote).and_return(nil)
        allow(ci_helpers).to receive(:workflows_list).and_return([])
        allow(File).to receive(:exist?).with(File.join(Dir.pwd, ".gitlab-ci.yml")).and_return(true)
        allow(ci_helpers).to receive(:repo_info_gitlab).and_return(%w[me repo])
        pipe = {"web_url" => "http://gitlab/pipeline"}
        allow(ci_helpers).to receive(:gitlab_latest_pipeline).and_return(pipe)
        allow(ci_helpers).to receive(:gitlab_success?).and_return(true)
        allow(ci_helpers).to receive(:gitlab_failed?).and_return(false)
        allow(Kettle::Dev::CIMonitor).to receive(:gitlab_remote_candidates).and_return(["gitlab"])
        expect { cli.send(:monitor_workflows_after_push!) }.not_to raise_error
      end

      it "aborts when GitLab pipeline fails" do
        allow(Kettle::Dev::CIMonitor).to receive(:preferred_github_remote).and_return(nil)
        allow(ci_helpers).to receive(:workflows_list).and_return([])
        allow(File).to receive(:exist?).with(File.join(Dir.pwd, ".gitlab-ci.yml")).and_return(true)
        allow(ci_helpers).to receive(:repo_info_gitlab).and_return(%w[me repo])
        pipe = {"web_url" => "http://gitlab/pipeline"}
        allow(ci_helpers).to receive(:gitlab_latest_pipeline).and_return(pipe)
        allow(ci_helpers).to receive(:gitlab_success?).and_return(false)
        allow(ci_helpers).to receive(:gitlab_failed?).and_return(true)
        allow(Kettle::Dev::CIMonitor).to receive(:gitlab_remote_candidates).and_return(["gitlab"])
        expect { cli.send(:monitor_workflows_after_push!) }.to raise_error(MockSystemExit, /Pipeline failed: .*--start-step 10/)
      end

      it "aborts when no CI configured" do
        allow(ci_helpers).to receive(:workflows_list).and_return([])
        allow(File).to receive(:exist?).with(File.join(Dir.pwd, ".gitlab-ci.yml")).and_return(false)
        allow(Kettle::Dev::CIMonitor).to receive(:preferred_github_remote).and_return(nil)
        allow(Kettle::Dev::CIMonitor).to receive(:gitlab_remote_candidates).and_return([])
        expect { cli.send(:monitor_workflows_after_push!) }.to raise_error(MockSystemExit, /CI configuration not detected/)
      end
    end

    describe "release lockfile validation", :real_release_lockfiles do
      def with_release_root
        Dir.mktmpdir do |root|
          allow(ci_helpers).to receive(:project_root).and_return(root)
          yield(root, described_class.new)
        end
      end

      it "flags local path remotes and registry checksums without sha256 while allowing path source gems" do
        with_release_root do |root, local_cli|
          File.write(File.join(root, "Gemfile.lock"), <<~LOCK)
            PATH
              remote: .
              specs:
                demo (0.1.0)

            PATH
              remote: /home/pboling/src/my/kettle-dev/kettle-soup-cover
              specs:
                kettle-soup-cover (3.0.5)

            GEM
              remote: https://gem.coop/
              specs:
                addressable (2.9.0)
                rack (3.2.1)

            CHECKSUMS
              addressable (2.9.0) sha256=abc123
              demo (0.1.0)
              kettle-soup-cover (3.0.5)
              rack (3.2.1)

            BUNDLED WITH
               4.0.17
          LOCK

          diagnostics = local_cli.send(:release_lockfile_diagnostics, File.join(root, "Gemfile.lock"))

          expect(diagnostics.join("\n")).to include("has local path remote")
          expect(diagnostics.join("\n")).to include("CHECKSUMS has no sha256 for rack 3.2.1")
          expect(diagnostics.join("\n")).not_to include("CHECKSUMS has no sha256 for kettle-soup-cover 3.0.5")
          expect(diagnostics.join("\n")).not_to include("CHECKSUMS has no sha256 for demo 0.1.0")
        end
      end

      it "normalizes dirty release lockfiles before validating the release prep commit" do
        with_release_root do |root, local_cli|
          File.write(File.join(root, "Gemfile"), "source \"https://rubygems.org\"\n")
          File.write(File.join(root, "Gemfile.lock"), <<~LOCK)
            GEM
              remote: https://rubygems.org/
              specs:
                addressable (2.9.0)
                kettle-soup-cover (3.0.5)

            CHECKSUMS
              addressable (2.9.0) sha256=abc123
              kettle-soup-cover (3.0.5)

            BUNDLED WITH
               4.0.17
          LOCK

          expect(local_cli).to receive(:run_cmd!).with(
            a_string_matching(/KETTLE_DEV_DEV=false.*BUNDLE_GEMFILE=.*Gemfile.*bundle lock .*--update.*bundle update --bundler=.*bundle lock --add-checksums/)
          ) do
            File.write(File.join(root, "Gemfile.lock"), <<~LOCK)
              GEM
                remote: https://rubygems.org/
                specs:
                  kettle-soup-cover (3.0.4)

              CHECKSUMS
                kettle-soup-cover (3.0.4) sha256=abc123

              BUNDLED WITH
                 4.0.17
            LOCK
          end
          expect(local_cli).not_to receive(:run_cmd!).with(a_string_matching(/bundle lock --update kettle-soup-cover/))

          expect { local_cli.send(:prepare_release_lockfiles_for_commit!) }.not_to raise_error
        end
      end

      it "normalizes the appraisal root lockfile instead of writing the default Gemfile.lock" do
        with_release_root do |root, local_cli|
          File.write(File.join(root, "Gemfile"), "source \"https://rubygems.org\"\n")
          File.write(File.join(root, "Gemfile.lock"), <<~LOCK)
            GEM
              remote: https://rubygems.org/
              specs:
                rake (13.4.2)

            CHECKSUMS
              rake (13.4.2) sha256=abc123

            BUNDLED WITH
               4.0.17
          LOCK
          File.write(File.join(root, "Appraisal.root.gemfile"), "source \"https://rubygems.org\"\n")
          File.write(File.join(root, "Appraisal.root.gemfile.lock"), <<~LOCK)
            PATH
              remote: .
              specs:
                demo (0.1.0)

            GEM
              remote: https://rubygems.org/
              specs:
                rake (13.4.2)

            CHECKSUMS
              demo (0.1.0)
              rake (13.4.2)

            BUNDLED WITH
               4.0.17
          LOCK

          expect(local_cli).to receive(:run_cmd!).with(
            a_string_matching(
              /BUNDLE_GEMFILE=.*Appraisal\.root\.gemfile.*BUNDLE_LOCKFILE=.*Appraisal\.root\.gemfile\.lock.*bundle lock .*--update.*bundle update --bundler=.*bundle lock --add-checksums/
            )
          ).ordered do
            File.write(File.join(root, "Appraisal.root.gemfile.lock"), <<~LOCK)
              GEM
                remote: https://rubygems.org/
                specs:
                  rake (13.4.2)

              CHECKSUMS
                rake (13.4.2) sha256=abc123

              BUNDLED WITH
                 4.0.17
            LOCK
          end
          expect(local_cli).to receive(:run_cmd!).with(
            a_string_matching(/BUNDLE_GEMFILE=.*Gemfile.*BUNDLE_LOCKFILE=.*Gemfile\.lock.*bundle lock .*--update.*bundle update --bundler=.*bundle lock --add-checksums/)
          ).ordered do
            File.write(File.join(root, "Gemfile.lock"), <<~LOCK)
              GEM
                remote: https://rubygems.org/
                specs:
                  rake (13.4.2)

              CHECKSUMS
                rake (13.4.2) sha256=abc123

              BUNDLED WITH
                 4.0.17
            LOCK
          end
          expect(local_cli).not_to receive(:run_cmd!).with(a_string_matching(/bundle lock --update rake/))

          expect { local_cli.send(:prepare_release_lockfiles_for_commit!) }.not_to raise_error
        end
      end

      it "retries release task lockfile resets when the configured source has not caught up yet" do
        with_release_root do |_root, local_cli|
          io = StringIO.new
          event_stream = Kettle::Ndjson.event_stream(io, types: "release_lockfile")
          local_cli.instance_variable_set(:@event_recorder, Kettle::Ndjson.event_recorder(event_stream, phase_timings: []))
          resetter = instance_double(Kettle::Dev::LockfileReset)
          attempts = 0
          allow(resetter).to receive(:reset) do
            attempts += 1
            raise "Bundler::GemNotFound: Could not find gem 'gitmoji-regex (~> 2.0, >= 2.0.7)' in locally installed gems." if attempts == 1

            []
          end
          allow(local_cli).to receive(:lockfile_reset).and_return(resetter)
          allow(local_cli).to receive(:release_lockfile_paths).and_return([])
          allow(local_cli).to receive(:release_availability_probe_attempts).and_return(2)
          allow(local_cli).to receive(:release_availability_probe_interval).and_return(0)
          expect(local_cli).to receive(:sleep).with(0).once

          expect do
            local_cli.send(:reset_release_lockfiles!, stage: "before release task bundle installs")
          end.to output(/attempt 1\/2.*could not resolve a gem.*attempt 2\/2.*reset complete/m).to_stdout
          expect(attempts).to eq(2)
          events = io.string.lines.map { |line| JSON.parse(line) }
          expect(events).to include(
            include(
              "type" => "release_lockfile",
              "action" => "reset",
              "status" => "started",
              "attempt" => 1,
              "attempts" => 2,
              "mark" => ">"
            ),
            include(
              "type" => "release_lockfile",
              "action" => "reset",
              "status" => "retrying",
              "attempt" => 1,
              "attempts" => 2,
              "mark" => ">"
            ),
            include(
              "type" => "release_lockfile",
              "action" => "reset",
              "status" => "ok",
              "attempt" => 2,
              "attempts" => 2,
              "mark" => "."
            ),
            include("type" => "release_lockfile", "action" => "validate", "status" => "ok", "count" => 0, "mark" => ".")
          )
        end
      end

      it "retries reset validation while a newly published workspace gem propagates" do
        with_release_root do |_root, local_cli|
          resetter = instance_double(Kettle::Dev::LockfileReset)
          attempts = 0
          allow(resetter).to receive(:reset) do
            attempts += 1
            if attempts == 1
              raise Kettle::Dev::Error, <<~MESSAGE
                Reset release-lockfiles failed validation:
                  - Gemfile.lock locks local workspace gem kettle-dev 3.0.15 as a registry gem, but that version is not resolvable from the configured gem source at line 164
              MESSAGE
            end

            []
          end
          allow(local_cli).to receive(:lockfile_reset).and_return(resetter)
          allow(local_cli).to receive(:release_lockfile_paths).and_return([])
          allow(local_cli).to receive(:release_availability_probe_attempts).and_return(2)
          allow(local_cli).to receive(:release_availability_probe_interval).and_return(0)
          expect(local_cli).to receive(:sleep).with(0).once

          expect do
            local_cli.send(:reset_release_lockfiles!, stage: "before release task bundle installs")
          end.to output(/attempt 1\/2.*newly published workspace gem.*attempt 2\/2.*reset complete/m).to_stdout
          expect(attempts).to eq(2)
        end
      end

      it "ignores generated appraisal lockfiles outside the release lockfile set" do
        with_release_root do |root, local_cli|
          gemfiles_dir = File.join(root, "gemfiles")
          FileUtils.mkdir_p(gemfiles_dir)
          File.write(File.join(root, "Gemfile.lock"), <<~LOCK)
            GEM
              remote: https://rubygems.org/
              specs:
                rake (13.4.2)

            CHECKSUMS
              rake (13.4.2) sha256=abc123

            BUNDLED WITH
               4.0.17
          LOCK
          File.write(File.join(gemfiles_dir, "dep_heads.gemfile.lock"), <<~LOCK)
            GEM
              remote: https://rubygems.org/
              specs:
                benchmark (0.5.0)
                rake (13.4.2)

            CHECKSUMS
              benchmark (0.5.0)
              rake (13.4.2) sha256=abc123

            BUNDLED WITH
               4.0.17
          LOCK

          expect(local_cli.send(:release_lockfile_paths)).to eq([File.join(root, "Gemfile.lock")])
          expect { local_cli.send(:validate_release_lockfiles!, stage: "before push") }.not_to raise_error
        end
      end

      it "converts lockfile reset command aborts into retryable adapter errors", :real_exit_adapter do
        with_release_root do |_root, local_cli|
          expect(local_cli).to receive(:run_cmd!).with("bundle lock --update --add-checksums").and_raise(
            SystemExit,
            "Command failed: bundle lock --update --add-checksums (exit 1)\nBundler::GemNotFound: Could not find gem 'kettle-family (= 1.2.1)' in locally installed gems."
          )

          expect do
            local_cli.send(:run_lockfile_reset_command!, "bundle lock --update --add-checksums")
          end.to raise_error(Kettle::Dev::ExitAdapter::AbortError, /Bundler::GemNotFound/)
        end
      end

      it "aborts before release prep commit when normalization cannot repair registry checksums" do
        with_release_root do |root, local_cli|
          File.write(File.join(root, "Gemfile"), "source \"https://rubygems.org\"\n")
          File.write(File.join(root, "Gemfile.lock"), <<~LOCK)
            GEM
              remote: https://rubygems.org/
              specs:
                addressable (2.9.0)
                kettle-soup-cover (3.0.5)

            CHECKSUMS
              addressable (2.9.0) sha256=abc123
              kettle-soup-cover (3.0.5)

            BUNDLED WITH
               4.0.17
          LOCK

          allow(local_cli).to receive(:run_cmd!)

          expect do
            local_cli.send(:prepare_release_lockfiles_for_commit!)
          end.to raise_error(MockSystemExit, /Release lockfile validation failed before release prep commit/)
        end
      end

      it "resets and amends release lockfiles that become invalid before push" do
        with_release_root do |root, local_cli|
          File.write(File.join(root, "Gemfile"), "source \"https://rubygems.org\"\n")
          File.write(File.join(root, "Gemfile.lock"), <<~LOCK)
            PATH
              remote: ../demo
              specs:
                demo (0.1.0)

            GEM
              remote: https://rubygems.org/
              specs:
                kettle-soup-cover (3.0.5)

            CHECKSUMS
              kettle-soup-cover (3.0.5)
              rake (13.4.2) sha256=abc123

            BUNDLED WITH
               4.0.17
          LOCK

          expect(local_cli).to receive(:run_cmd!).with(
            a_string_matching(/bundle lock .*--update.*bundle update --bundler=.*bundle lock --add-checksums/)
          ) do
            File.write(File.join(root, "Gemfile.lock"), <<~LOCK)
              GEM
                remote: https://rubygems.org/
                specs:
                  demo (0.1.0)
                  kettle-soup-cover (3.0.5)

              CHECKSUMS
                demo (0.1.0) sha256=abc123
                kettle-soup-cover (3.0.5) sha256=def456

              BUNDLED WITH
                 4.0.17
            LOCK
          end
          resetter = Kettle::Dev::LockfileReset.new(root: root, command_runner: ->(command) { local_cli.send(:run_cmd!, command) })
          allow(resetter).to receive(:local_workspace_gem_names).and_return(Set.new)
          local_cli.instance_variable_set(:@lockfile_reset, resetter)
          git = local_cli.instance_variable_get(:@git)
          allow(git).to receive(:diff_head_quiet?).with(File.join(root, "Gemfile.lock")).and_return(false)
          expect(git).to receive(:add_paths).with([File.join(root, "Gemfile.lock")]).and_return(true)
          expect(git).to receive(:commit_amend_no_edit)
            .with(env: hash_including("KETTLE_DEV_DEV" => "false"))
            .and_return(true)

          expect do
            local_cli.send(:validate_release_lockfiles!, stage: "before push")
          end.to output(/Release lockfile validation found 2 issue\(s\) before push:.*has local path remote.*Running one fallback release lockfile reset before push.*diagnostics cleared; amending release prep commit with 1 lockfile\(s\)/m).to_stdout
        end
      end

      it "reports when the fallback reset restores dirty lockfiles to the release prep commit" do
        with_release_root do |root, local_cli|
          File.write(File.join(root, "Gemfile"), "source \"https://rubygems.org\"\n")
          File.write(File.join(root, "Gemfile.lock"), <<~LOCK)
            PATH
              remote: ../demo
              specs:
                demo (0.1.0)

            GEM
              remote: https://rubygems.org/
              specs:
                kettle-soup-cover (3.0.5)

            CHECKSUMS
              kettle-soup-cover (3.0.5)
              rake (13.4.2) sha256=abc123

            BUNDLED WITH
               4.0.17
          LOCK

          expect(local_cli).to receive(:run_cmd!).with(
            a_string_matching(/bundle lock .*--update.*bundle update --bundler=.*bundle lock --add-checksums/)
          ) do
            File.write(File.join(root, "Gemfile.lock"), <<~LOCK)
              GEM
                remote: https://rubygems.org/
                specs:
                  demo (0.1.0)
                  kettle-soup-cover (3.0.5)

              CHECKSUMS
                demo (0.1.0) sha256=abc123
                kettle-soup-cover (3.0.5) sha256=def456

              BUNDLED WITH
                 4.0.17
            LOCK
          end
          git = local_cli.instance_variable_get(:@git)
          resetter = Kettle::Dev::LockfileReset.new(root: root, command_runner: local_cli.method(:run_cmd!))
          allow(resetter).to receive(:local_workspace_gem_names).and_return(Set.new)
          local_cli.instance_variable_set(:@lockfile_reset, resetter)
          allow(git).to receive(:diff_head_quiet?).with(File.join(root, "Gemfile.lock")).and_return(false, true)
          expect(git).not_to receive(:add_paths)
          expect(git).not_to receive(:commit_amend_no_edit)

          expect do
            local_cli.send(:validate_release_lockfiles!, stage: "before push")
          end.to output(/Release lockfile validation found 2 issue\(s\) before push:.*diagnostics cleared by restoring tracked lockfiles to the release prep commit; no amend is needed/m).to_stdout
        end
      end

      it "reports unrepaired release lockfile diagnostics before push" do
        with_release_root do |root, local_cli|
          File.write(File.join(root, "Gemfile"), "source \"https://rubygems.org\"\n")
          File.write(File.join(root, "Gemfile.lock"), <<~LOCK)
            PATH
              remote: ../demo
              specs:
                demo (0.1.0)

            GEM
              remote: https://rubygems.org/
              specs:
                kettle-soup-cover (3.0.5)

            CHECKSUMS
              kettle-soup-cover (3.0.5)
              rake (13.4.2) sha256=abc123

            BUNDLED WITH
               4.0.17
          LOCK

          allow(local_cli).to receive(:run_cmd!)

          expect do
            expect do
              local_cli.send(:validate_release_lockfiles!, stage: "before push")
            end.to raise_error(MockSystemExit, /Release lockfile validation failed before push/)
          end.to output(/Release lockfile validation found 2 issue\(s\) before push:.*Release lockfile reset did not repair all before-push issues:.*has local path remote/m).to_stdout
        end
      end

      it "runs the release lockfile guard before committing release prep" do
        local_cli = described_class.new(start_step: 6, skip_steps: "7,8,9,10,11,12,13,14,15,16,17,18,19")
        allow(local_cli).to receive(:detect_version).and_return("9.9.9")
        allow(local_cli).to receive(:detect_gem_name).and_return("mygem")

        expect(local_cli).to receive(:prepare_release_lockfiles_for_commit!).ordered
        expect(local_cli).to receive(:ensure_git_user!).ordered
        expect(local_cli).to receive(:commit_release_prep!).with("9.9.9").ordered.and_return(false)

        expect { local_cli.run }.not_to raise_error
      end

      it "renormalizes lockfiles after release tasks even when preflight already reset them" do
        local_cli = described_class.new
        local_cli.instance_variable_set(:@release_lockfiles_reset_for_release_tasks, true)

        expect(local_cli).to receive(:reset_release_lockfiles!).with(stage: "before release prep commit")
        expect(local_cli).to receive(:validate_release_lockfiles!).with(stage: "before release prep commit")

        local_cli.send(:prepare_release_lockfiles_for_commit!)
      end

      it "repairs a stale appraisal root lock before appraisal generation can install it" do
        Dir.mktmpdir do |root|
          allow(ci_helpers).to receive(:project_root).and_return(root)
          local_cli = described_class.new(start_step: 5, skip_steps: "6,7,8,9,10,11,12,13,14,15,16,17,18,19")
          File.write(File.join(root, "Appraisals"), "# appraisals\n")
          File.write(File.join(root, "Gemfile"), "source \"https://rubygems.org\"\n")
          File.write(File.join(root, "Gemfile.lock"), <<~LOCK)
            GEM
              remote: https://rubygems.org/
              specs:
                rake (13.4.2)

            CHECKSUMS
              rake (13.4.2) sha256=abc123
          LOCK
          File.write(File.join(root, "Appraisal.root.gemfile"), "source \"https://rubygems.org\"\n")
          File.write(File.join(root, "Appraisal.root.gemfile.lock"), <<~LOCK)
            GEM
              remote: https://rubygems.org/
              specs:
                kettle-starfish (9.9.9)

            CHECKSUMS
              kettle-starfish (9.9.9) sha256=localonly
          LOCK
          commands = []
          command_runner = lambda do |command|
            commands << command
            if command.include?("BUNDLE_LOCKFILE=#{File.join(root, "Appraisal.root.gemfile.lock")}")
              File.write(File.join(root, "Appraisal.root.gemfile.lock"), <<~LOCK)
                GEM
                  remote: https://rubygems.org/
                  specs:
                    rake (13.4.2)

                CHECKSUMS
                  rake (13.4.2) sha256=abc123
              LOCK
            elsif command.include?("BUNDLE_LOCKFILE=#{File.join(root, "Gemfile.lock")}")
              File.write(File.join(root, "Gemfile.lock"), <<~LOCK)
                GEM
                  remote: https://rubygems.org/
                  specs:
                    rake (13.4.2)

                CHECKSUMS
                rake (13.4.2) sha256=abc123
              LOCK
            end
          end
          resetter = Kettle::Dev::LockfileReset.new(root: root, command_runner: command_runner)
          allow(resetter).to receive(:local_workspace_gem_names).and_return(Set["kettle-starfish"])
          local_cli.instance_variable_set(:@lockfile_reset, resetter)
          allow(local_cli).to receive(:run_cmd!) do |command|
            commands << command
          end

          expect { local_cli.run }.not_to raise_error
          appraisal_reset_index = commands.index { |command| command.include?("BUNDLE_LOCKFILE=#{File.join(root, "Appraisal.root.gemfile.lock")}") }
          appraisal_generate_index = commands.index { |command| command.end_with?(" bin/rake appraisal:generate") }
          expect(appraisal_reset_index).not_to be_nil
          expect(appraisal_generate_index).not_to be_nil
          expect(appraisal_reset_index).to be < appraisal_generate_index
        end
      end

      it "validates lockfiles before monitoring CI on a step 10 resume" do
        local_cli = described_class.new(start_step: 10, skip_steps: "11,12,13,14,15,16,17,18,19")
        allow(local_cli).to receive(:detect_version).and_return("9.9.9")
        allow(local_cli).to receive(:detect_gem_name).and_return("mygem")

        expect(local_cli).to receive(:validate_release_lockfiles!).with(stage: "before CI monitoring").ordered
        expect(local_cli).to receive(:monitor_workflows_after_push!).ordered

        expect { local_cli.run }.not_to raise_error
      end
    end

    describe "#run" do
      around do |ex|
        orig_stdin = $stdin
        begin
          ex.run
        ensure
          $stdin = orig_stdin
        end
      end

      it "aborts when current version is not greater than latest released for series" do
        allow(cli).to receive(:run_pre_release_checks!)
        allow(cli).to receive(:ensure_bundler_2_7_plus!) # skip real check
        allow(cli).to receive(:detect_version).and_return("1.2.3")
        allow(cli).to receive(:detect_gem_name).and_return("mygem")
        allow(cli).to receive(:latest_released_versions).and_return(%w[1.2.3 1.2.3]) # equal -> abort
        # First prompt will not be reached because we abort earlier
        expect { cli.run }.to raise_error(MockSystemExit, /version bump required/)
      end

      it "runs happy path when RubyGems.org is offline and Appraisals exist and SKIP_GEM_SIGNING is set", :jruby_head_release_flow do
        # Make prompts auto-accept via input adapter
        allow(Kettle::Dev::InputAdapter).to receive(:gets).and_return("y\n")

        stub_env("SKIP_GEM_SIGNING" => "true")

        allow(cli).to receive(:run_pre_release_checks!)
        allow(cli).to receive(:ensure_bundler_2_7_plus!)
        allow(cli).to receive(:detect_version).and_return("9.9.9")
        allow(cli).to receive(:detect_gem_name).and_return("mygem")
        gem_path = stub_checksum_artifact(cli, "9.9.9")
        allow(cli).to receive(:latest_released_versions).and_return([nil, nil])
        allow(cli).to receive(:validate_copyright_years!)
        allow(cli).to receive(:update_readme_kloc_badge!)
        allow(cli).to receive(:update_rakefile_example_header!)

        # Stub commands that would actually run
        allow(cli).to receive(:run_cmd!).and_return(true)
        allow(cli).to receive(:ensure_git_user!)
        allow(cli).to receive(:commit_release_prep!).and_return(true)
        allow(cli).to receive(:maybe_run_local_ci_before_push!)
        allow(cli).to receive(:detect_trunk_branch).and_return("main")
        allow(cli).to receive(:current_branch).and_return("feature/my-work")
        allow(cli).to receive(:ensure_trunk_synced_before_push!)
        allow(cli).to receive(:push!)
        allow(cli).to receive(:monitor_workflows_after_push!)
        allow(cli).to receive(:merge_feature_into_trunk_and_push!)
        allow(cli).to receive(:checkout!)
        allow(cli).to receive(:pull!)
        allow(cli).to receive(:ensure_signing_setup_or_skip!)
        allow(cli).to receive(:push_tags!)
        allow(cli).to receive(:confirm_release_candidate_available!)
        expect(cli).to receive(:validate_checksums!).with("9.9.9", stage: "after release")

        # Appraisals exists at repo root; ensure truthy branch executes
        expect { cli.run }.not_to raise_error

        # Ensure the initial build/release commands were attempted
        expect(cli).to have_received(:run_pre_release_checks!)
        expect(cli).to have_received(:run_cmd!).with(a_string_matching(/\Aenv .* bin\/setup\z/))
        expect(cli).to have_received(:run_cmd!).with(a_string_matching(/env .* bin\/rake\z/))
        expect(cli).to have_received(:run_cmd!).with(a_string_matching(/env .* bin\/rake appraisal:generate\z/))
        expect(cli).to have_received(:run_cmd!).with(a_string_matching(/env .* bin\/rake yard\z/))
        expect(cli).to have_received(:run_cmd!).with(a_string_matching(/env .* bundle exec rake build\z/))
        expect(cli).to have_received(:run_cmd!).with(a_string_matching(/env .* bundle exec rake release\z/))
        expect(cli).to have_received(:run_cmd!).with(a_string_matching(/\Aenv .* bin\/gem_checksums #{Regexp.escape(gem_path)}\z/))
      end

      it "runs local-ci mode without pushing until after the gem is published", :jruby_head_release_flow do
        local_cli = described_class.new(local_ci: true)
        allow(Kettle::Dev::InputAdapter).to receive(:gets).and_return("y\n")
        stub_env("SKIP_GEM_SIGNING" => "true", "GITHUB_TOKEN" => nil)

        allow(local_cli).to receive(:run_pre_release_checks!)
        allow(local_cli).to receive(:ensure_bundler_2_7_plus!)
        allow(local_cli).to receive(:detect_version).and_return("9.9.9")
        allow(local_cli).to receive(:detect_gem_name).and_return("mygem")
        stub_checksum_artifact(local_cli, "9.9.9")
        allow(local_cli).to receive(:latest_released_versions).and_return([nil, nil])
        allow(local_cli).to receive(:validate_copyright_years!)
        allow(local_cli).to receive(:update_readme_kloc_badge!)
        allow(local_cli).to receive(:update_rakefile_example_header!)
        allow(local_cli).to receive(:run_cmd!).and_return(true)
        allow(local_cli).to receive(:ensure_git_user!)
        allow(local_cli).to receive(:commit_release_prep!).and_return(true)
        allow(local_cli).to receive(:ensure_signing_setup_or_skip!)
        allow(local_cli).to receive(:validate_checksums!)
        allow(local_cli).to receive(:maybe_create_github_release!)

        expect(local_cli).to receive(:maybe_run_local_ci_before_push!).with(true, force: true).ordered
        expect(local_cli).not_to receive(:ensure_trunk_synced_before_push!)
        expect(local_cli).not_to receive(:monitor_workflows_after_push!)
        expect(local_cli).not_to receive(:merge_feature_into_trunk_and_push!)
        expect(local_cli).not_to receive(:checkout!)
        expect(local_cli).not_to receive(:pull!)
        expect(local_cli).to receive(:release_gem_and_tag_locally!).with("9.9.9").ordered
        expect(local_cli).to receive(:push!).ordered
        expect(local_cli).to receive(:push_tags!).ordered

        expect { local_cli.run }.not_to raise_error
        expect(local_cli).to have_received(:run_pre_release_checks!)
        expect(local_cli).to have_received(:run_cmd!).with(a_string_matching(/env .* bundle exec rake build\z/))
        expect(local_cli).not_to have_received(:run_cmd!).with(a_string_matching(/env .* bundle exec rake release\z/))
      end

      it "uses appraisal:update when explicitly requested", :jruby_head_release_flow do
        update_cli = described_class.new(appraisal_task: "appraisal:update")
        allow(Kettle::Dev::InputAdapter).to receive(:gets).and_return("y\n")
        stub_env("SKIP_GEM_SIGNING" => "true")

        allow(update_cli).to receive(:run_pre_release_checks!)
        allow(update_cli).to receive(:ensure_bundler_2_7_plus!)
        allow(update_cli).to receive(:detect_version).and_return("9.9.9")
        allow(update_cli).to receive(:detect_gem_name).and_return("mygem")
        stub_checksum_artifact(update_cli, "9.9.9")
        allow(update_cli).to receive(:latest_released_versions).and_return([nil, nil])
        allow(update_cli).to receive(:validate_copyright_years!)
        allow(update_cli).to receive(:update_readme_kloc_badge!)
        allow(update_cli).to receive(:update_rakefile_example_header!)
        allow(update_cli).to receive(:run_cmd!).and_return(true)
        allow(update_cli).to receive(:ensure_git_user!)
        allow(update_cli).to receive(:commit_release_prep!).and_return(true)
        allow(update_cli).to receive(:maybe_run_local_ci_before_push!)
        allow(update_cli).to receive(:detect_trunk_branch).and_return("main")
        allow(update_cli).to receive(:current_branch).and_return("feature/my-work")
        allow(update_cli).to receive(:ensure_trunk_synced_before_push!)
        allow(update_cli).to receive(:push!)
        allow(update_cli).to receive(:monitor_workflows_after_push!)
        allow(update_cli).to receive(:merge_feature_into_trunk_and_push!)
        allow(update_cli).to receive(:checkout!)
        allow(update_cli).to receive(:pull!)
        allow(update_cli).to receive(:ensure_signing_setup_or_skip!)
        allow(update_cli).to receive(:push_tags!)
        allow(update_cli).to receive(:validate_checksums!)
        allow(update_cli).to receive(:confirm_release_candidate_available!)

        expect { update_cli.run }.not_to raise_error

        expect(update_cli).to have_received(:run_cmd!).with(a_string_matching(/env .* bin\/rake appraisal:update\z/))
      end

      it "skips appraisal generation when Appraisals file missing", :jruby_head_release_flow do
        # Accept initial prompt via input adapter
        allow(Kettle::Dev::InputAdapter).to receive(:gets).and_return("y\n")

        stub_env("SKIP_GEM_SIGNING" => "true")

        allow(cli).to receive(:run_pre_release_checks!)
        allow(cli).to receive(:ensure_bundler_2_7_plus!)
        allow(cli).to receive(:detect_version).and_return("9.9.9")
        allow(cli).to receive(:detect_gem_name).and_return("mygem")
        stub_checksum_artifact(cli, "9.9.9")
        allow(cli).to receive(:latest_released_versions).and_return([nil, nil])
        allow(cli).to receive(:validate_copyright_years!)
        allow(cli).to receive(:update_readme_kloc_badge!)
        allow(cli).to receive(:update_rakefile_example_header!)
        allow(cli).to receive(:run_cmd!).and_return(true)
        allow(cli).to receive(:ensure_git_user!)
        allow(cli).to receive(:commit_release_prep!).and_return(false)
        allow(cli).to receive(:maybe_run_local_ci_before_push!)
        allow(cli).to receive(:detect_trunk_branch).and_return("main")
        allow(cli).to receive(:current_branch).and_return("feat")
        allow(cli).to receive(:ensure_trunk_synced_before_push!)
        allow(cli).to receive(:push!)
        allow(cli).to receive(:monitor_workflows_after_push!)
        allow(cli).to receive(:merge_feature_into_trunk_and_push!)
        allow(cli).to receive(:checkout!)
        allow(cli).to receive(:pull!)
        allow(cli).to receive(:ensure_signing_setup_or_skip!)
        allow(cli).to receive(:push_tags!)
        allow(cli).to receive(:validate_checksums!)
        allow(cli).to receive(:confirm_release_candidate_available!)

        # Force File.file?(Appraisals) false just for that path
        appraisals_path = File.join(Kettle::Dev::CIHelpers.project_root, "Appraisals")
        allow(File).to receive(:file?).and_wrap_original do |m, path|
          if path == appraisals_path
            false
          else
            m.call(path)
          end
        end

        expect { cli.run }.not_to raise_error
        expect(cli).to have_received(:run_cmd!).with(a_string_matching(/\Aenv .* bin\/setup\z/))
        expect(cli).to have_received(:run_cmd!).with(a_string_matching(/env .* bin\/rake\z/))
        expect(cli).not_to have_received(:run_cmd!).with("bin/rake appraisal:generate")
        expect(cli).to have_received(:run_cmd!).with(a_string_matching(/env .* bin\/rake yard\z/))
      end

      it "aborts when signing enabled on tty and user declines prompt", :jruby_head_release_flow do
        allow(Kettle::Dev::InputAdapter).to receive(:tty?).and_return(true)
        # Two prompts: first we answer 'y' to proceed, second we answer 'n' to abort signing
        allow(Kettle::Dev::InputAdapter).to receive(:gets).and_return("y\n", "n\n")

        stub_env("SKIP_GEM_SIGNING" => nil, "CI" => "true")

        allow(cli).to receive(:run_pre_release_checks!)
        allow(cli).to receive(:ensure_bundler_2_7_plus!)
        allow(cli).to receive(:detect_version).and_return("9.9.9")
        allow(cli).to receive(:detect_gem_name).and_return("mygem")
        allow(cli).to receive(:latest_released_versions).and_return([nil, nil])
        allow(cli).to receive(:validate_copyright_years!)
        allow(cli).to receive(:update_readme_kloc_badge!)
        allow(cli).to receive(:update_rakefile_example_header!)

        # Stub through to the signing gate
        allow(cli).to receive(:run_cmd!).and_return(true)
        allow(cli).to receive(:ensure_git_user!)
        allow(cli).to receive(:commit_release_prep!).and_return(true)
        allow(cli).to receive(:maybe_run_local_ci_before_push!)
        allow(cli).to receive(:detect_trunk_branch).and_return("main")
        allow(cli).to receive(:current_branch).and_return("feat")
        allow(cli).to receive(:ensure_trunk_synced_before_push!)
        allow(cli).to receive(:push!)
        allow(cli).to receive(:monitor_workflows_after_push!)
        allow(cli).to receive(:merge_feature_into_trunk_and_push!)
        allow(cli).to receive(:checkout!)
        allow(cli).to receive(:pull!)

        expect { cli.run }.to raise_error(MockSystemExit, /SKIP_GEM_SIGNING=true/)
      end

      it "auto-approves release confirmation prompts when yes mode is enabled", :jruby_head_release_flow do
        yes_cli = described_class.new(yes: true)
        allow(Kettle::Dev::InputAdapter).to receive(:tty?).and_return(true)
        expect(Kettle::Dev::InputAdapter).not_to receive(:gets)

        stub_env("SKIP_GEM_SIGNING" => nil, "CI" => "true")

        allow(yes_cli).to receive(:run_pre_release_checks!)
        allow(yes_cli).to receive(:ensure_bundler_2_7_plus!)
        allow(yes_cli).to receive(:detect_version).and_return("9.9.9")
        allow(yes_cli).to receive(:detect_gem_name).and_return("mygem")
        stub_checksum_artifact(yes_cli, "9.9.9")
        allow(yes_cli).to receive(:latest_released_versions).and_return([nil, nil])
        allow(yes_cli).to receive(:validate_copyright_years!)
        allow(yes_cli).to receive(:update_readme_kloc_badge!)
        allow(yes_cli).to receive(:update_rakefile_example_header!)
        allow(yes_cli).to receive(:run_cmd!).and_return(true)
        allow(yes_cli).to receive(:ensure_git_user!)
        allow(yes_cli).to receive(:commit_release_prep!).and_return(true)
        allow(yes_cli).to receive(:maybe_run_local_ci_before_push!)
        allow(yes_cli).to receive(:detect_trunk_branch).and_return("main")
        allow(yes_cli).to receive(:current_branch).and_return("feat")
        allow(yes_cli).to receive(:ensure_trunk_synced_before_push!)
        allow(yes_cli).to receive(:push!)
        allow(yes_cli).to receive(:monitor_workflows_after_push!)
        allow(yes_cli).to receive(:merge_feature_into_trunk_and_push!)
        allow(yes_cli).to receive(:checkout!)
        allow(yes_cli).to receive(:pull!)
        allow(yes_cli).to receive(:ensure_signing_setup_or_skip!)
        allow(yes_cli).to receive(:push_tags!)
        allow(yes_cli).to receive(:validate_checksums!)
        allow(yes_cli).to receive(:confirm_release_candidate_available!)

        expect { yes_cli.run }.not_to raise_error
      end

      it "aborts before release setup when pre-release checks fail" do
        expect(cli).to receive(:run_pre_release_checks!).and_raise(MockSystemExit.new("pre-release failed"))
        expect(cli).not_to receive(:ensure_bundler_2_7_plus!)

        expect { cli.run }.to raise_error(MockSystemExit, /pre-release failed/)
      end

      it "skips pre-release checks when resuming at step 1" do
        resumed_cli = described_class.new(start_step: 1)
        allow(Kettle::Dev::InputAdapter).to receive(:gets).and_return("n\n")
        allow(resumed_cli).to receive(:ensure_bundler_2_7_plus!)
        allow(resumed_cli).to receive(:detect_version).and_return("9.9.9")
        allow(resumed_cli).to receive(:detect_gem_name).and_return("mygem")
        allow(resumed_cli).to receive(:latest_released_versions).and_return([nil, nil])
        expect(resumed_cli).not_to receive(:run_pre_release_checks!)

        expect { resumed_cli.run }.to raise_error(MockSystemExit, /please update version.rb/)
      end

      it "skips pre-release checks when resuming after step 1" do
        resumed_cli = described_class.new(start_step: 2)
        allow(Kettle::Dev::InputAdapter).to receive(:gets).and_return("n\n")
        allow(resumed_cli).to receive(:ensure_bundler_2_7_plus!)
        allow(resumed_cli).to receive(:detect_version).and_return("9.9.9")
        allow(resumed_cli).to receive(:detect_gem_name).and_return("mygem")
        allow(resumed_cli).to receive(:latest_released_versions).and_return([nil, nil])
        expect(resumed_cli).not_to receive(:run_pre_release_checks!)

        expect { resumed_cli.run }.to raise_error(MockSystemExit, /please update version.rb/)
      end
    end

    describe "#run version sanity messaging and rescue" do
      around do |ex|
        orig_stdin = $stdin
        begin
          ex.run
        ensure
          $stdin = orig_stdin
        end
      end

      it "prints series info when latest overall is different series and continues", :jruby_head_release_flow do
        allow(Kettle::Dev::InputAdapter).to receive(:gets).and_return("y\n")
        allow(cli).to receive(:run_pre_release_checks!)
        allow(cli).to receive(:ensure_bundler_2_7_plus!)
        allow(cli).to receive(:detect_version).and_return("1.2.10")
        allow(cli).to receive(:detect_gem_name).and_return("mygem")
        stub_checksum_artifact(cli, "1.2.10")
        allow(cli).to receive(:latest_released_versions).and_return(%w[1.3.0 1.2.9]) # triggers line 36 and 47 branch
        allow(cli).to receive(:validate_copyright_years!)
        allow(cli).to receive(:update_readme_kloc_badge!)
        allow(cli).to receive(:update_rakefile_example_header!)
        allow(cli).to receive(:run_cmd!).and_return(true)
        allow(cli).to receive(:ensure_git_user!)
        allow(cli).to receive(:commit_release_prep!).and_return(false)
        allow(cli).to receive(:maybe_run_local_ci_before_push!)
        allow(cli).to receive(:detect_trunk_branch).and_return("main")
        allow(cli).to receive(:current_branch).and_return("main")
        allow(cli).to receive(:ensure_trunk_synced_before_push!)
        allow(cli).to receive(:push!)
        allow(cli).to receive(:monitor_workflows_after_push!)
        allow(cli).to receive(:merge_feature_into_trunk_and_push!)
        allow(cli).to receive(:checkout!)
        allow(cli).to receive(:pull!)
        stub_env("SKIP_GEM_SIGNING" => "true")
        allow(cli).to receive(:ensure_signing_setup_or_skip!)
        allow(cli).to receive(:validate_checksums!)
        allow(cli).to receive(:confirm_release_candidate_available!)
        expect { cli.run }.not_to raise_error
      end

      it "rescues failures from RubyGems.org release check and proceeds to user prompt" do
        allow(Kettle::Dev::InputAdapter).to receive(:gets).and_return("n\n")
        allow(cli).to receive(:run_pre_release_checks!)
        allow(cli).to receive(:ensure_bundler_2_7_plus!)
        allow(cli).to receive(:detect_version).and_return("1.2.3")
        allow(cli).to receive(:detect_gem_name).and_raise(StandardError.new("boom"))
        expect { cli.run }.to raise_error(MockSystemExit, /please update version.rb/)
      end
    end

    describe "#run sanity-check branches" do
      it "aborts on downgrade when latest target is higher", :check_output do
        cli = described_class.new
        allow(cli).to receive(:run_pre_release_checks!)
        allow(cli).to receive(:ensure_bundler_2_7_plus!)
        allow(cli).to receive(:detect_version).and_return("1.2.3")
        allow(cli).to receive(:detect_gem_name).and_return("kettle-dev")
        # overall is higher than current series; no series-specific latest -> target=nil would skip, so provide same-series higher
        allow(cli).to receive(:latest_released_versions).and_return(%w[1.2.4 1.2.4]) # [overall, for_series]
        expect do
          cli.run
        end.to raise_error(MockSystemExit, /version must be bumped above 1.2.4/)
      end

      it "prints offline message when target cannot be determined even though overall present", :check_output, :jruby_head_release_flow do
        cli = described_class.new
        allow(cli).to receive(:run_pre_release_checks!)
        allow(cli).to receive(:ensure_bundler_2_7_plus!)
        allow(cli).to receive(:detect_version).and_return("1.2.3")
        allow(cli).to receive(:detect_gem_name).and_return("kettle-dev")
        stub_checksum_artifact(cli, "1.2.3", "kettle-dev")
        # Simulate overall from a newer series (2.0.0) but no latest for current series -> target=nil
        allow(cli).to receive(:latest_released_versions).and_return(["2.0.0", nil])
        # Proceed past the prompt and subsequent steps quickly
        allow(Kettle::Dev::InputAdapter).to receive(:gets).and_return("y")
        allow(cli).to receive(:validate_copyright_years!)
        allow(cli).to receive(:update_readme_kloc_badge!)
        allow(cli).to receive(:update_rakefile_example_header!)
        # Skip remaining heavy steps
        allow(cli).to receive(:run_cmd!)
        allow(cli).to receive(:ensure_git_user!)
        allow(cli).to receive(:detect_trunk_branch).and_return("main")
        allow(cli).to receive(:current_branch).and_return("feature")
        allow(cli).to receive(:monitor_workflows_after_push!)
        allow(cli).to receive(:merge_feature_into_trunk_and_push!)
        allow(cli).to receive(:checkout!)
        allow(cli).to receive(:pull!)
        allow(cli).to receive(:ensure_signing_setup_or_skip!)
        allow(cli).to receive(:validate_checksums!)
        allow(cli).to receive(:maybe_create_github_release!)
        allow(cli).to receive(:push_tags!)
        allow(cli).to receive(:confirm_release_candidate_available!)
        # Make final detection trivial
        allow(cli).to receive(:detect_gem_name).and_return("kettle-dev")

        # Ensure the offline message was printed during run
        expect { cli.run }.to output(/Could not determine latest released version from RubyGems.org/).to_stdout
      end

      it "prints fallback final message when gem name detection fails", :check_output do
        cli = described_class.new(start_step: 19)
        allow(cli).to receive(:ensure_bundler_2_7_plus!)
        allow(cli).to receive(:detect_version).and_return("3.2.1")
        # Make detect_gem_name raise so rescue branch prints fallback line
        allow(cli).to receive(:detect_gem_name).and_raise(StandardError, "boom")

        expect { cli.run }.to output(/Release v3.2.1 Complete/).to_stdout
      end
    end

    describe "#ensure_git_user!" do
      it "passes when name and email are configured" do
        allow(cli).to receive(:git_output).with(%w[config user.name]).and_return(["Alice", true])
        allow(cli).to receive(:git_output).with(%w[config user.email]).and_return(["alice@example.com", true])
        expect { cli.send(:ensure_git_user!) }.not_to raise_error
      end

      it "aborts when missing name or email" do
        allow(cli).to receive(:git_output).with(%w[config user.name]).and_return(["", true])
        allow(cli).to receive(:git_output).with(%w[config user.email]).and_return(["", false])
        expect { cli.send(:ensure_git_user!) }.to raise_error(MockSystemExit, /Git user.name or user.email/)
      end
    end

    describe "#maybe_run_local_ci_before_push!" do
      it "returns immediately when mode is disabled" do
        stub_env("K_RELEASE_LOCAL_CI" => nil)
        expect(cli.send(:maybe_run_local_ci_before_push!, true)).to be_nil
      end

      it "asks the user and proceeds on default yes, but skips when act not found" do
        stub_env("K_RELEASE_LOCAL_CI" => "ask")
        allow($stdin).to receive(:gets).and_return("\n") # default yes
        allow(cli).to receive(:system).with("act", "--version", out: File::NULL, err: File::NULL).and_return(false)
        expect { cli.send(:maybe_run_local_ci_before_push!, true) }.not_to raise_error
      end

      it "runs with act when chosen workflow is nil due to no candidates" do
        stub_env("K_RELEASE_LOCAL_CI" => "true")
        allow(cli).to receive(:system).with("act", "--version", out: File::NULL, err: File::NULL).and_return(true)
        allow(ci_helpers).to receive(:project_root).and_return(Dir.pwd)
        allow(ci_helpers).to receive(:workflows_list).and_return([])
        expect { cli.send(:maybe_run_local_ci_before_push!, false) }.not_to raise_error
      end

      it "skips when selected workflow file does not exist" do
        Dir.mktmpdir do |root|
          stub_env("K_RELEASE_LOCAL_CI" => "true")
          allow(cli).to receive(:system).with("act", "--version", out: File::NULL, err: File::NULL).and_return(true)
          allow(ci_helpers).to receive(:project_root).and_return(root)
          # Create workflows dir but not the chosen file
          wf_dir = File.join(root, ".github", "workflows")
          FileUtils.mkdir_p(wf_dir)
          allow(ci_helpers).to receive(:workflows_list).and_return(["ci.yml"]) # chosen => first
          expect { cli.send(:maybe_run_local_ci_before_push!, false) }.not_to raise_error
        end
      end

      it "runs act successfully on an existing workflow" do
        Dir.mktmpdir do |root|
          stub_env("K_RELEASE_LOCAL_CI" => "true")
          allow(cli).to receive(:system).with("act", "--version", out: File::NULL, err: File::NULL).and_return(true)
          allow(ci_helpers).to receive(:project_root).and_return(root)
          wf_dir = File.join(root, ".github", "workflows")
          FileUtils.mkdir_p(wf_dir)
          file_path = File.join(wf_dir, "locked_deps.yml")
          File.write(file_path, "name: demo")
          allow(ci_helpers).to receive(:workflows_list).and_return(["locked_deps.yml"]) # will pick locked_deps.yml
          expect(cli).to receive(:system).with("act", "-W", file_path).and_return(true)
          expect { cli.send(:maybe_run_local_ci_before_push!, false) }.not_to raise_error
        end
      end

      it "aborts on act failure and rolls back when committed" do
        Dir.mktmpdir do |root|
          stub_env("K_RELEASE_LOCAL_CI" => "true")
          allow(cli).to receive(:system).with("act", "--version", out: File::NULL, err: File::NULL).and_return(true)
          allow(ci_helpers).to receive(:project_root).and_return(root)
          wf_dir = File.join(root, ".github", "workflows")
          FileUtils.mkdir_p(wf_dir)
          file_path = File.join(wf_dir, "ci.yml")
          File.write(file_path, "name: ci")
          allow(ci_helpers).to receive(:workflows_list).and_return(["ci.yml"])
          expect(cli).to receive(:system).with("act", "-W", file_path).and_return(false)
          git = cli.instance_variable_get(:@git)
          expect(git).to receive(:reset_soft).with("HEAD^").and_return(true)
          expect { cli.send(:maybe_run_local_ci_before_push!, true) }.to raise_error(MockSystemExit, /local CI failure/)
        end
      end

      it "aborts when forced and act is unavailable" do
        allow(cli).to receive(:system).with("act", "--version", out: File::NULL, err: File::NULL).and_return(false)
        expect { cli.send(:maybe_run_local_ci_before_push!, false, force: true) }.to raise_error(MockSystemExit, /Local CI requires 'act'/)
      end

      it "aborts when forced and no workflows are available" do
        allow(cli).to receive(:system).with("act", "--version", out: File::NULL, err: File::NULL).and_return(true)
        allow(ci_helpers).to receive(:project_root).and_return(Dir.pwd)
        allow(ci_helpers).to receive(:workflows_list).and_return([])
        expect { cli.send(:maybe_run_local_ci_before_push!, false, force: true) }.to raise_error(MockSystemExit, /requires at least one workflow/)
      end
    end

    describe "#release_gem_and_tag_locally!" do
      it "creates a local tag and pushes the built gem without pushing git refs" do
        Dir.mktmpdir do |root|
          allow(ci_helpers).to receive(:project_root).and_return(root)
          pkg = File.join(root, "pkg")
          FileUtils.mkdir_p(pkg)
          gem_path = File.join(pkg, "mygem-1.2.3.gem")
          File.write(gem_path, "gem")
          local_cli = described_class.new

          allow(local_cli).to receive(:git_output).with(["rev-parse", "-q", "--verify", "refs/tags/v1.2.3"]).and_return(["", false])
          git = local_cli.instance_variable_get(:@git)
          expect(git).to receive(:tag_annotated).with("v1.2.3", "v1.2.3").ordered.and_return(true)
          expect(local_cli).to receive(:run_cmd!).with("gem push #{gem_path}").ordered
          expect(local_cli).to receive(:run_release_availability_probe).ordered do |candidate|
            expect(candidate.published).to be(true)
            true
          end
          expect(Kettle::Dev::RubyGemsVersions).to receive(:mark_released).with("mygem", "1.2.3")

          local_cli.send(:release_gem_and_tag_locally!, "1.2.3")
        end
      end

      it "does not recreate an existing local tag" do
        Dir.mktmpdir do |root|
          allow(ci_helpers).to receive(:project_root).and_return(root)
          pkg = File.join(root, "pkg")
          FileUtils.mkdir_p(pkg)
          gem_path = File.join(pkg, "mygem-1.2.3.gem")
          File.write(gem_path, "gem")
          local_cli = described_class.new

          allow(local_cli).to receive(:git_output).with(["rev-parse", "-q", "--verify", "refs/tags/v1.2.3"]).and_return(["abc", true])
          git = local_cli.instance_variable_get(:@git)
          expect(git).not_to receive(:tag_annotated)
          expect(local_cli).to receive(:run_cmd!).with("gem push #{gem_path}")
          expect(local_cli).to receive(:run_release_availability_probe) do |candidate|
            expect(candidate.published).to be(true)
            true
          end

          local_cli.send(:release_gem_and_tag_locally!, "1.2.3")
        end
      end

      it "preserves hyphenated gem names when deriving the published gem name" do
        local_cli = described_class.new

        expect(local_cli.send(:gem_name_from_gem_path, "pkg/my-gem-1.2.3.gem", "1.2.3")).to eq("my-gem")
      end

      it "does not clean up a candidate once registry availability has been validated" do
        local_cli = described_class.new
        candidate = Kettle::Dev::ReleaseCLI::ReleaseCandidate.new(
          gem_name: "mygem",
          version: "1.2.3",
          installed_before: false,
          published: false
        )

        expect(local_cli).to receive(:run_release_availability_probe).with(candidate).and_return(true)
        expect(local_cli.send(:confirm_release_candidate_available!, candidate)).to be(true)
        expect(candidate.published).to be(true)
      end

      it "validates availability with the shared Bundler inline source probe sourced from gem.coop" do
        local_cli = described_class.new
        candidate = Kettle::Dev::ReleaseCLI::ReleaseCandidate.new(
          gem_name: "mygem",
          version: "1.2.3",
          installed_before: false,
          published: false
        )

        script = local_cli.send(:release_availability_probe_script, candidate)

        expect(script).to include("require \"bundler/inline\"")
        expect(script).to include("source \"https://gem.coop\"")
        expect(script).to include("gem gem_name, \"= \#{version}\", require: false")
        expect(script).to include("Gem::Specification.find_all_by_name")
        expect(script).not_to include("Bundler.load")
        expect(script).not_to include("Gem.loaded_specs")
      end

      it "isolates the availability probe from activated local gems" do
        Dir.mktmpdir do |root|
          allow(ci_helpers).to receive(:project_root).and_return(root)
          local_cli = described_class.new
          candidate = Kettle::Dev::ReleaseCLI::ReleaseCandidate.new(
            gem_name: "mygem",
            version: "1.2.3",
            installed_before: false,
            published: false
          )
          script_path = File.join(root, "probe.rb")
          File.write(script_path, "probe")
          passed = instance_double(Process::Status, success?: true, exitstatus: 0)

          allow(local_cli).to receive(:write_release_availability_probe).with(candidate).and_return(script_path)
          allow(local_cli).to receive(:release_availability_probe_attempts).and_return(1)
          allow(local_cli).to receive(:release_availability_probe_initial_delay).and_return(0)
          allow(local_cli).to receive(:sleep)
          expect(Open3).to receive(:capture3) do |environment, ruby, path|
            expect(environment.fetch("GEM_HOME")).to start_with(File.join(root, "tmp", "kettle-release", "probe-gem-home-"))
            expect(environment.fetch("GEM_PATH")).to eq(environment.fetch("GEM_HOME"))
            expect(ruby).to eq(Gem.ruby)
            expect(path).to eq(script_path)
          end.and_return(["validated\n", "", passed])

          expect(local_cli.send(:run_release_availability_probe, candidate)).to be(true)
        end
      end

      it "retries the gem.coop availability probe until the release resolves" do
        Dir.mktmpdir do |root|
          io = StringIO.new
          event_stream = Kettle::Ndjson.event_stream(io, types: "release_probe")
          local_cli = described_class.new(event_stream: event_stream)
          candidate = Kettle::Dev::ReleaseCLI::ReleaseCandidate.new(
            gem_name: "mygem",
            version: "1.2.3",
            installed_before: false,
            published: false
          )
          script_path = File.join(root, "probe.rb")
          File.write(script_path, "probe")
          failed = instance_double(Process::Status, success?: false, exitstatus: 1)
          passed = instance_double(Process::Status, success?: true, exitstatus: 0)

          allow(local_cli).to receive(:write_release_availability_probe).with(candidate).and_return(script_path)
          allow(local_cli).to receive(:release_availability_probe_attempts).and_return(3)
          allow(local_cli).to receive(:release_availability_probe_initial_delay).and_return(5)
          allow(local_cli).to receive(:release_availability_probe_interval).and_return(0)
          expect(local_cli).to receive(:sleep).with(5).ordered
          expect(Open3).to receive(:capture3).ordered.and_return(["", "missing", failed])
          expect(local_cli).to receive(:sleep).with(0).ordered
          expect(Open3).to receive(:capture3).ordered.and_return(["validated\n", "", passed])

          expect { expect(local_cli.send(:run_release_availability_probe, candidate)).to be(true) }
            .to output(/attempt 1\/3.*attempt 2\/3.*validated/m).to_stdout
          events = io.string.lines.map { |line| JSON.parse(line) }
          expect(events).to include(
            include(
              "type" => "release_probe",
              "action" => "availability",
              "status" => "started",
              "gem" => "mygem",
              "version" => "1.2.3",
              "attempt" => 1,
              "attempts" => 3,
              "mark" => ">"
            ),
            include(
              "type" => "release_probe",
              "action" => "availability",
              "status" => "retrying",
              "gem" => "mygem",
              "version" => "1.2.3",
              "attempt" => 1,
              "attempts" => 3,
              "reason" => "exit 1",
              "mark" => ">"
            ),
            include(
              "type" => "release_probe",
              "action" => "availability",
              "status" => "ok",
              "gem" => "mygem",
              "version" => "1.2.3",
              "attempt" => 2,
              "attempts" => 3,
              "mark" => "."
            )
          )
        end
      end

      it "fails the gem.coop availability probe only after retry exhaustion" do
        Dir.mktmpdir do |root|
          local_cli = described_class.new
          candidate = Kettle::Dev::ReleaseCLI::ReleaseCandidate.new(
            gem_name: "mygem",
            version: "1.2.3",
            installed_before: false,
            published: false
          )
          script_path = File.join(root, "probe.rb")
          File.write(script_path, "probe")
          failed = instance_double(Process::Status, success?: false, exitstatus: 1)

          allow(local_cli).to receive(:write_release_availability_probe).with(candidate).and_return(script_path)
          allow(local_cli).to receive(:release_availability_probe_attempts).and_return(2)
          allow(local_cli).to receive(:release_availability_probe_initial_delay).and_return(5)
          allow(local_cli).to receive(:release_availability_probe_interval).and_return(0)
          expect(local_cli).to receive(:sleep).with(5).ordered
          expect(Open3).to receive(:capture3).ordered.and_return(["", "still missing", failed])
          expect(local_cli).to receive(:sleep).with(0).ordered
          expect(Open3).to receive(:capture3).ordered.and_return(["", "still missing", failed])

          expect do
            local_cli.send(:run_release_availability_probe, candidate)
          end.to raise_error(MockSystemExit, /after 2 attempt\(s\).*still missing/m)
        end
      end

      it "uninstalls a newly installed local candidate when registry availability cannot be validated" do
        local_cli = described_class.new
        candidate = Kettle::Dev::ReleaseCLI::ReleaseCandidate.new(
          gem_name: "mygem",
          version: "1.2.3",
          installed_before: false,
          published: false
        )
        local_cli.instance_variable_set(:@release_candidate, candidate)

        allow(local_cli).to receive(:gem_version_installed?).with("mygem", "1.2.3").and_return(true)
        expect(local_cli).to receive(:run_cmd!).with("gem uninstall mygem -v 1.2.3 -x -I --ignore-dependencies")

        expect do
          local_cli.send(:with_unpublished_candidate_cleanup) { raise(MockSystemExit, "publish failed") }
        end.to raise_error(MockSystemExit, /publish failed/)
      end

      it "does not uninstall a candidate after the gem push succeeds" do
        local_cli = described_class.new
        candidate = Kettle::Dev::ReleaseCLI::ReleaseCandidate.new(
          gem_name: "mygem",
          version: "1.2.3",
          installed_before: false,
          published: true
        )
        local_cli.instance_variable_set(:@release_candidate, candidate)

        expect(local_cli).not_to receive(:run_cmd!).with(/gem uninstall/)

        expect do
          local_cli.send(:with_unpublished_candidate_cleanup) { raise(MockSystemExit, "probe failed") }
        end.to raise_error(MockSystemExit, /probe failed/)
      end

      it "does not uninstall a candidate that was already installed before the release attempt" do
        local_cli = described_class.new
        candidate = Kettle::Dev::ReleaseCLI::ReleaseCandidate.new(
          gem_name: "mygem",
          version: "1.2.3",
          installed_before: true,
          published: false
        )
        local_cli.instance_variable_set(:@release_candidate, candidate)

        expect(local_cli).not_to receive(:run_cmd!).with(/gem uninstall/)

        expect do
          local_cli.send(:with_unpublished_candidate_cleanup) { raise(MockSystemExit, "publish failed") }
        end.to raise_error(MockSystemExit, /publish failed/)
      end
    end

    describe "push_tags!" do
      it "pushes tags only to 'all' when present" do
        allow(cli).to receive(:has_remote?).with("all").and_return(true)
        git = cli.instance_variable_get(:@git)
        expect(git).to receive(:push_tags).with("all")
        cli.send(:push_tags!)
      end

      it "pushes tags to each remote when 'all' missing" do
        allow(cli).to receive(:has_remote?).with("all").and_return(false)
        allow(cli).to receive(:list_remotes).and_return(%w[origin github]) # includes two remotes
        git = cli.instance_variable_get(:@git)
        expect(git).to receive(:push_tags).with("origin")
        expect(git).to receive(:push_tags).with("github")
        cli.send(:push_tags!)
      end

      it "pushes tags without specifying remote when no remotes configured" do
        allow(cli).to receive(:has_remote?).with("all").and_return(false)
        allow(cli).to receive(:list_remotes).and_return([])
        git = cli.instance_variable_get(:@git)
        expect(git).to receive(:push_tags).with(nil)
        cli.send(:push_tags!)
      end
    end

    describe "direct git wrappers" do
      it "runs checkout! and pull! via GitAdapter" do
        git = cli.instance_variable_get(:@git)
        expect(git).to receive(:checkout).with("main").and_return(true)
        cli.send(:checkout!, "main")
        expect(git).to receive(:pull).with("origin", "main").and_return(true)
        cli.send(:pull!, "main")
      end

      it "returns current_branch and lists remotes via GitAdapter" do
        git = cli.instance_variable_get(:@git)
        allow(git).to receive(:current_branch).and_return("feat")
        expect(cli.send(:current_branch)).to eq("feat")
        allow(git).to receive(:remotes).and_return(%w[origin github])
        expect(cli.send(:list_remotes)).to include("origin", "github")
      end

      it "fetches remote_url and prefers origin when appropriate via GitAdapter" do
        git = cli.instance_variable_get(:@git)
        allow(git).to receive(:remotes_with_urls).and_return({"origin" => "https://github.com/me/repo.git"})
        expect(cli.send(:remote_url, "origin")).to include("github.com")
        expect(cli.send(:preferred_github_remote)).to eq("origin")
      end

      it "checks remote presence (list_remotes) still works" do
        allow(cli).to receive(:list_remotes).and_return(["origin"])
        expect(cli.send(:has_remote?, "origin")).to be true
        expect(cli.send(:has_remote?, "github")).to be false
      end
    end

    describe "ensure_trunk_synced_before_push! divergence reconciliation" do
      around do |ex|
        orig_stdin = $stdin
        begin
          ex.run
        ensure
          $stdin = orig_stdin
        end
      end

      it "rebases when user selects r" do
        allow(cli).to receive(:has_remote?).with("all").and_return(false)
        expect(cli).to receive(:run_cmd!).with("git fetch origin main")
        allow(cli).to receive(:trunk_behind_remote?).and_return(false)
        allow(cli).to receive(:preferred_github_remote).and_return("github")
        expect(cli).to receive(:run_cmd!).with("git fetch github main")
        allow(cli).to receive(:ahead_behind_counts).with("origin/main", "github/main").and_return([1, 1])
        expect(cli).to receive(:checkout!).with("main").at_least(:once)
        expect(cli).to receive(:run_cmd!).with("git pull --rebase origin main")
        allow(Kettle::Dev::InputAdapter).to receive(:gets).and_return("r\n")
        expect(cli).to receive(:run_cmd!).with("git rebase github/main")
        expect(cli).to receive(:run_cmd!).with("git push origin main")
        cli.send(:ensure_trunk_synced_before_push!, "main", "feat")
      end

      it "merges when user selects m" do
        allow(cli).to receive(:has_remote?).with("all").and_return(false)
        expect(cli).to receive(:run_cmd!).with("git fetch origin main")
        allow(cli).to receive(:trunk_behind_remote?).and_return(false)
        allow(cli).to receive(:preferred_github_remote).and_return("github")
        expect(cli).to receive(:run_cmd!).with("git fetch github main")
        allow(cli).to receive(:ahead_behind_counts).with("origin/main", "github/main").and_return([1, 1])
        expect(cli).to receive(:checkout!).with("main").at_least(:once)
        expect(cli).to receive(:run_cmd!).with("git pull --rebase origin main")
        allow(Kettle::Dev::InputAdapter).to receive(:gets).and_return("m\n")
        expect(cli).to receive(:run_cmd!).with("git merge --no-ff github/main")
        expect(cli).to receive(:run_cmd!).with("git push origin main")
        expect(cli).to receive(:run_cmd!).with("git push github main")
        cli.send(:ensure_trunk_synced_before_push!, "main", "feat")
      end

      it "aborts when user selects a (abort)" do
        allow(cli).to receive(:has_remote?).with("all").and_return(false)
        expect(cli).to receive(:run_cmd!).with("git fetch origin main")
        allow(cli).to receive(:trunk_behind_remote?).and_return(false)
        allow(cli).to receive(:preferred_github_remote).and_return("github")
        expect(cli).to receive(:run_cmd!).with("git fetch github main")
        allow(cli).to receive(:ahead_behind_counts).with("origin/main", "github/main").and_return([1, 1])
        expect(cli).to receive(:checkout!).with("main").at_least(:once)
        expect(cli).to receive(:run_cmd!).with("git pull --rebase origin main")
        allow(Kettle::Dev::InputAdapter).to receive(:gets).and_return("a\n")
        expect { cli.send(:ensure_trunk_synced_before_push!, "main", "feat") }.to raise_error(MockSystemExit, /Aborted by user/)
      end

      it "returns early when origin and github trunks are in sync" do
        allow(cli).to receive(:has_remote?).with("all").and_return(false)
        expect(cli).to receive(:run_cmd!).with("git fetch origin main")
        allow(cli).to receive(:trunk_behind_remote?).and_return(false)
        allow(cli).to receive(:preferred_github_remote).and_return("github")
        expect(cli).to receive(:run_cmd!).with("git fetch github main")
        allow(cli).to receive(:ahead_behind_counts).with("origin/main", "github/main").and_return([0, 0])
        expect { cli.send(:ensure_trunk_synced_before_push!, "main", "feat") }.not_to raise_error
      end
    end

    describe "#validate_checksums! error cases" do
      it "aborts when built gem cannot be found" do
        allow(cli).to receive(:gem_file_for_version).with("0.0.1").and_return(nil)
        expect { cli.send(:validate_checksums!, "0.0.1", stage: "stage") }.to raise_error(MockSystemExit, /Unable to locate built gem/)
      end

      it "aborts when checksum file is missing" do
        Dir.mktmpdir do |root|
          allow(ci_helpers).to receive(:project_root).and_return(root)
          other = described_class.new
          # create gem in pkg
          pkg = File.join(root, "pkg")
          FileUtils.mkdir_p(pkg)
          gem_file = File.join(pkg, "mygem-0.1.0.gem")
          File.write(gem_file, "data")
          expect { other.send(:validate_checksums!, "0.1.0", stage: "stage") }.to raise_error(MockSystemExit, /Expected checksum file not found/)
        end
      end
    end

    describe "#compute_sha256 shasum path" do
      it "uses shasum when available" do
        Dir.mktmpdir do |root|
          file = File.join(root, "f.bin")
          File.binwrite(file, "xyz")
          allow(cli).to receive(:system).with("which sha256sum > /dev/null 2>&1").and_return(false)
          allow(cli).to receive(:system).with("which shasum > /dev/null 2>&1").and_return(true)
          allow(Open3).to receive(:capture2e).with("shasum", "-a", "256", file).and_return(["abc123 #{file}", instance_double(Process::Status)])
          expect(cli.send(:compute_sha256, file)).to eq("abc123")
        end
      end
    end

    describe "#monitor_workflows_after_push! gitlab loop nil then success" do
      it "sleeps when pipeline initially missing then proceeds" do
        allow(ci_helpers).to receive(:project_root).and_return(Dir.pwd)
        allow(ci_helpers).to receive(:current_branch).and_return("feat")
        allow(Kettle::Dev::CIMonitor).to receive(:preferred_github_remote).and_return(nil)
        allow(ci_helpers).to receive(:workflows_list).and_return([])
        allow(File).to receive(:exist?).with(File.join(Dir.pwd, ".gitlab-ci.yml")).and_return(true)
        allow(Kettle::Dev::CIMonitor).to receive(:gitlab_remote_candidates).and_return(["gitlab"])
        allow(ci_helpers).to receive(:repo_info_gitlab).and_return(%w[me repo])
        # first returns nil, then a success
        allow(ci_helpers).to receive(:gitlab_latest_pipeline).and_return(nil, {"web_url" => "http://gitlab/pipeline"})
        allow(ci_helpers).to receive(:gitlab_success?).and_return(true)
        allow(ci_helpers).to receive(:gitlab_failed?).and_return(false)
        allow(cli).to receive(:ensure_github_pull_request_for_ci!)
        expect { cli.send(:monitor_workflows_after_push!) }.not_to raise_error
      end
    end

    describe "start_step skipping" do
      it "skips initial steps when start_step is 10 (CI validation)", :jruby_head_release_flow do
        allow(Kettle::Dev::InputAdapter).to receive(:tty?).and_return(false)
        # Ensure optional GitHub release (step 17) is a no-op to avoid real HTTP
        stub_env("GITHUB_TOKEN" => nil)
        local_cli = described_class.new(start_step: 10)
        allow(local_cli).to receive(:detect_version).and_return("2.2.22")
        stub_checksum_artifact(local_cli, "2.2.22", "kettle-dev")
        allow(local_cli).to receive(:ensure_bundler_2_7_plus!)
        # Spy on run_cmd! to ensure early commands are not invoked
        allow(local_cli).to receive(:run_cmd!)
        # Prevent later phases from doing real work
        allow(local_cli).to receive(:monitor_workflows_after_push!)
        allow(local_cli).to receive(:merge_feature_into_trunk_and_push!)
        allow(local_cli).to receive(:checkout!)
        allow(local_cli).to receive(:pull!)
        allow(local_cli).to receive(:ensure_signing_setup_or_skip!)
        allow(local_cli).to receive(:validate_checksums!)
        allow(local_cli).to receive(:push_tags!)
        allow(local_cli).to receive(:detect_trunk_branch).and_return("main")
        allow(local_cli).to receive(:current_branch).and_return("feat")
        allow(local_cli).to receive(:confirm_release_candidate_available!)

        expect { local_cli.run }.not_to raise_error

        expect(local_cli).not_to have_received(:run_cmd!).with(a_string_matching(/bin\/setup/))
        expect(local_cli).not_to have_received(:run_cmd!).with(a_string_matching(/env .* bin\/rake\z/))
        expect(local_cli).not_to have_received(:run_cmd!).with("bin/rake appraisal:generate")
      end

      it "skips selected numbered steps while running later steps", :jruby_head_release_flow do
        allow(Kettle::Dev::InputAdapter).to receive(:tty?).and_return(false)
        stub_env("GITHUB_TOKEN" => nil)
        local_cli = described_class.new(start_step: 10, skip_steps: "10")
        allow(local_cli).to receive(:detect_version).and_return("1.2.3")
        allow(local_cli).to receive(:detect_gem_name).and_return("example")
        stub_checksum_artifact(local_cli, "1.2.3", "example")
        allow(local_cli).to receive(:detect_trunk_branch).and_return("main")
        allow(local_cli).to receive(:current_branch).and_return("feat")
        allow(local_cli).to receive(:ensure_bundler_2_7_plus!)
        allow(local_cli).to receive(:monitor_workflows_after_push!)
        allow(local_cli).to receive(:merge_feature_into_trunk_and_push!)
        allow(local_cli).to receive(:checkout!)
        allow(local_cli).to receive(:pull!)
        allow(local_cli).to receive(:ensure_signing_setup_or_skip!)
        allow(local_cli).to receive(:run_cmd!)
        allow(local_cli).to receive(:validate_checksums!)
        allow(local_cli).to receive(:push_tags!)
        allow(local_cli).to receive(:confirm_release_candidate_available!)

        expect { local_cli.run }.not_to raise_error

        expect(local_cli).not_to have_received(:monitor_workflows_after_push!)
        expect(local_cli).to have_received(:merge_feature_into_trunk_and_push!).with("main", "feat")
        expect(local_cli).to have_received(:run_cmd!).with(a_string_matching(/env .* bundle exec rake build\z/))
      end

      it "rejects invalid skip step values" do
        expect { described_class.new(skip_steps: "10,nope") }
          .to raise_error(MockSystemExit, /Invalid skip_steps value "nope"/)
      end
    end

    describe "RUBOCOP_LTS_LOCAL release preflight" do
      it "switches the local RuboCop-LTS checkout to the selected wrapper branch" do
        Dir.mktmpdir do |root|
          write_style_local(root, "rubocop-ruby2_4")
          allow(ci_helpers).to receive(:project_root).and_return(root)
          local_cli = described_class.new
          git = instance_double(Kettle::Dev::GitAdapter)
          local_cli.instance_variable_set(:@git, git)
          checkout = File.join("/workspace/rubocop-lts", "rubocop-lts")
          stub_env("RUBOCOP_LTS_LOCAL" => "/workspace/rubocop-lts")

          expect(git).to receive(:capture)
            .with(["-C", checkout, "branch", "--show-current"])
            .and_return(["r1_8-even-v0", true])
          expect(git).to receive(:capture)
            .with(["-C", checkout, "switch", "r2_4-even-v12"])
            .and_return(["", true])

          expect { local_cli.send(:prepare_rubocop_lts_local_branch!) }.not_to raise_error
        end
      end

      it "does not switch when the local RuboCop-LTS checkout is already on the selected branch" do
        Dir.mktmpdir do |root|
          write_style_local(root, "rubocop-ruby3_2")
          allow(ci_helpers).to receive(:project_root).and_return(root)
          local_cli = described_class.new
          git = instance_double(Kettle::Dev::GitAdapter)
          local_cli.instance_variable_set(:@git, git)
          checkout = File.join("/workspace/rubocop-lts", "rubocop-lts")
          stub_env("RUBOCOP_LTS_LOCAL" => "/workspace/rubocop-lts")

          expect(git).to receive(:capture)
            .with(["-C", checkout, "branch", "--show-current"])
            .and_return(["r3_2-even-v24", true])
          expect(git).not_to receive(:capture).with(["-C", checkout, "switch", anything])

          expect { local_cli.send(:prepare_rubocop_lts_local_branch!) }.not_to raise_error
        end
      end

      it "does not switch an active local branch-stack checkout when releasing that checkout" do
        Dir.mktmpdir do |workspace|
          root = File.join(workspace, "rubocop-lts")
          FileUtils.mkdir_p(root)
          File.write(File.join(root, ".kettle-family.yml"), <<~YAML)
            release:
              target_branches:
                - r1_8-even-v0
          YAML
          write_style_local(root, "rubocop-ruby3_2")
          allow(ci_helpers).to receive(:project_root).and_return(root)
          local_cli = described_class.new
          git = instance_double(Kettle::Dev::GitAdapter)
          local_cli.instance_variable_set(:@git, git)
          stub_env("RUBOCOP_LTS_LOCAL" => workspace)

          expect(git).not_to receive(:capture)

          expect { local_cli.send(:prepare_rubocop_lts_local_branch!) }.not_to raise_error
        end
      end

      it "still switches a same-family local checkout when it is not a branch-stack release checkout" do
        Dir.mktmpdir do |workspace|
          root = File.join(workspace, "rubocop-lts")
          FileUtils.mkdir_p(root)
          write_style_local(root, "rubocop-ruby3_2")
          allow(ci_helpers).to receive(:project_root).and_return(root)
          local_cli = described_class.new
          git = instance_double(Kettle::Dev::GitAdapter)
          local_cli.instance_variable_set(:@git, git)
          stub_env("RUBOCOP_LTS_LOCAL" => workspace)

          expect(git).to receive(:capture)
            .with(["-C", root, "branch", "--show-current"])
            .and_return(["main", true])
          expect(git).to receive(:capture)
            .with(["-C", root, "switch", "r3_2-even-v24"])
            .and_return(["", true])

          expect { local_cli.send(:prepare_rubocop_lts_local_branch!) }.not_to raise_error
        end
      end

      it "aborts when the local RuboCop-LTS checkout cannot switch branches" do
        Dir.mktmpdir do |root|
          write_style_local(root, "rubocop-ruby2_4")
          allow(ci_helpers).to receive(:project_root).and_return(root)
          local_cli = described_class.new
          git = instance_double(Kettle::Dev::GitAdapter)
          local_cli.instance_variable_set(:@git, git)
          checkout = File.join("/workspace/rubocop-lts", "rubocop-lts")
          stub_env("RUBOCOP_LTS_LOCAL" => "/workspace/rubocop-lts")

          allow(git).to receive(:capture)
            .with(["-C", checkout, "branch", "--show-current"])
            .and_return(["r1_8-even-v0", true])
          allow(git).to receive(:capture)
            .with(["-C", checkout, "switch", "r2_4-even-v12"])
            .and_return(["", false])

          expect { local_cli.send(:prepare_rubocop_lts_local_branch!) }
            .to raise_error(MockSystemExit, /Cannot switch RUBOCOP_LTS_LOCAL checkout/)
        end
      end
    end

    describe "#update_rakefile_example_header!" do
      it "updates header line to current version and date when file exists", freeze: Time.local(2025, 8, 29) do
        Dir.mktmpdir do |root|
          # Arrange Rakefile.example with an older header and some content
          body = <<~RB
            # frozen_string_literal: true

            # kettle-dev Rakefile v0.9.0 - 2024-12-31
            puts "Hello"
          RB
          File.write(File.join(root, "Rakefile.example"), body)
          allow(ci_helpers).to receive(:project_root).and_return(root)
          local_cli = described_class.new

          local_cli.send(:update_rakefile_example_header!, "1.2.3")

          updated = File.read(File.join(root, "Rakefile.example"))
          expect(updated).to include("# kettle-dev Rakefile v1.2.3 - 2025-08-29")
          expect(updated).to include("# frozen_string_literal: true")
          expect(updated).to include("puts \"Hello\"")
        end
      end

      it "is a no-op when file is missing" do
        Dir.mktmpdir do |root|
          allow(ci_helpers).to receive(:project_root).and_return(root)
          local_cli = described_class.new
          expect { local_cli.send(:update_rakefile_example_header!, "1.2.3") }.not_to raise_error
        end
      end
    end

    describe "regression: Rakefile.example header uses version.rb even if RubyGems.org has higher overall" do
      it "injects the version from version.rb (e.g., 1.0.15) and not a higher 1.2.x from RubyGems.org", freeze: Time.new(2015, 12, 28, 13, 14, 15) do
        Dir.mktmpdir do |root|
          # Prepare a Rakefile.example with an outdated header
          File.write(File.join(root, "Rakefile.example"), <<~RB)
            # frozen_string_literal: true

            # kettle-dev Rakefile v0.0.0 - 2000-01-01
            puts "Hello"
          RB

          allow(ci_helpers).to receive(:project_root).and_return(root)
          cli = described_class.new(start_step: 2)

          # Force detect_version to desired next version and make RubyGems.org suggest a higher overall
          allow(cli).to receive(:detect_version).and_return("1.0.15")
          allow(cli).to receive(:detect_gem_name).and_return("kettle-dev")
          stub_checksum_artifact(cli, "1.0.15", "kettle-dev")
          allow(cli).to receive(:latest_released_versions).and_return(%w[1.2.10 1.2.10]) # overall and series
          allow(cli).to receive(:validate_copyright_years!)
          allow(cli).to receive(:update_readme_kloc_badge!)

          # Auto-confirm the prompt
          allow(Kettle::Dev::InputAdapter).to receive(:gets).and_return("y\n")

          # Stub out subsequent steps so we only execute step 2
          allow(cli).to receive(:run_cmd!)
          allow(cli).to receive(:validate_checksums!)
          allow(cli).to receive(:maybe_run_local_ci_before_push!)
          allow(cli).to receive(:ensure_bundler_2_7_plus!)
          allow(cli).to receive(:monitor_workflows_after_push!)
          allow(cli).to receive(:merge_feature_into_trunk_and_push!)
          allow(cli).to receive(:checkout!)
          allow(cli).to receive(:pull!)
          allow(cli).to receive(:ensure_signing_setup_or_skip!)
          allow(cli).to receive(:push_tags!)
          allow(cli).to receive(:detect_trunk_branch).and_return("main")
          allow(cli).to receive(:current_branch).and_return("feat")
          allow(cli).to receive(:confirm_release_candidate_available!)

          # Execute run starting at step 2 to cover header update path
          expect { cli.run }.not_to raise_error

          updated = File.read(File.join(root, "Rakefile.example"))
          expect(updated).to include("# kettle-dev Rakefile v1.0.15 - 2015-12-28")
          expect(updated).to include("puts \"Hello\"")
        end
      end
    end

    describe "update_readme_kloc_badge! and helpers" do
      it "updates README and README.example KLOC values based on CHANGELOG denominator", :check_output do
        Dir.mktmpdir do |root|
          # Prepare files
          FileUtils.mkdir_p(File.join(root, ".github", "workflows"))
          version = "9.9.9"
          changelog = <<~MD
            ## [#{version}] - 2025-08-28
            - COVERAGE: 97.70% -- 2125/2175 lines in 20 files
          MD
          File.write(File.join(root, "CHANGELOG.md"), changelog)
          readme = <<~MD
            [🧮kloc-img]: https://img.shields.io/badge/KLOC-0.000-FFDD67.svg?style=flat
          MD
          File.write(File.join(root, "README.md"), readme)
          File.write(File.join(root, "README.md.example"), readme)

          allow(ci_helpers).to receive(:project_root).and_return(root)
          cli = described_class.new
          allow(cli).to receive(:detect_version).and_return(version)
          allow(cli).to receive(:validate_copyright_years!)
          allow(cli).to receive(:update_rakefile_example_header!)

          expect { cli.send(:update_readme_kloc_badge!) }.not_to raise_error
          updated = File.read(File.join(root, "README.md"))
          updated_ex = File.read(File.join(root, "README.md.example"))
          # 2175 / 1000.0 => 2.175
          expect(updated).to include("KLOC-2.175-")
          expect(updated_ex).to include("KLOC-2.175-")
        end
      end

      it "skips when README.example missing and avoids rewriting when no change", :check_output do
        Dir.mktmpdir do |root|
          version = "9.9.8"
          File.write(File.join(root, "CHANGELOG.md"), <<~MD)
            ## [#{version}]
            - COVERAGE: 10.00% -- 100/1000 lines in 2 files
          MD
          orig = "[🧮kloc-img]: https://img.shields.io/badge/KLOC-1.000-FFDD67.svg?style=flat\n"
          File.write(File.join(root, "README.md"), orig)
          # No README.md.example
          allow(ci_helpers).to receive(:project_root).and_return(root)
          cli = described_class.new
          allow(cli).to receive(:detect_version).and_return(version)
          cli.send(:update_readme_kloc_badge!)
          # unchanged KLOC remains 1.000 so file should be untouched
          expect(File.read(File.join(root, "README.md"))).to eq(orig)
        end
      end
    end

    describe "copyright helpers edge cases" do
      it "extracts years from descending range by swapping endpoints" do
        Dir.mktmpdir do |root|
          path = File.join(root, "LICENSE.txt")
          File.write(path, "Copyright 2025-2023 Example")
          allow(ci_helpers).to receive(:project_root).and_return(root)
          cli = described_class.new
          years = cli.send(:extract_years_from_file, path)
          expect(years.to_a).to include(2023, 2024, 2025)
        end
      end

      it "collapses with trailing segment flush" do
        cli = described_class.new
        str = cli.send(:collapse_years, [2020, 2021, 2023])
        expect(str).to eq("2020-2021, 2023")
      end

      it "injects nothing when no year blob present" do
        Dir.mktmpdir do |root|
          path = File.join(root, "README.md")
          content = "Some text with Copyright notice but no years present."
          File.write(path, content)
          cli = described_class.new
          expect { cli.send(:inject_years_into_file!, path, Set.new([2020, 2021])) }.not_to raise_error
          expect(File.read(path)).to eq(content)
        end
      end

      # NOTE: Additional edge coverage for reformat is exercised indirectly by other specs.
    end

    describe "CHANGELOG and GitHub release helpers" do
      it "extract_changelog_for_version rescues parser errors" do
        Dir.mktmpdir do |root|
          allow(ci_helpers).to receive(:project_root).and_return(root)
          path = File.join(root, "CHANGELOG.md")
          File.write(path, "## [1.2.3]\n")
          cli = described_class.new
          # Force File.read to blow up to hit rescue
          allow(File).to receive(:read).with(path).and_raise(ArgumentError, "boom")
          section, a, b = cli.send(:extract_changelog_for_version, "1.2.3")
          expect(section).to be_nil
          expect(a).to be_nil
          expect(b).to be_nil
        end
      end

      it "github_create_release returns success on HTTPSuccess/Created and rescues exceptions" do
        cli = described_class.new
        # Success path
        success_res = Net::HTTPCreated.new("1.1", "201", "Created")
        http_double = instance_double(Net::HTTP)
        allow(Net::HTTP).to receive(:start).and_yield(http_double)
        allow(http_double).to receive(:request).and_return(success_res)
        ok, msg = cli.send(:github_create_release, owner: "me", repo: "r", token: "t", tag: "v1.0.0", title: "v1.0.0", body: "hi")
        expect(ok).to be(true)
        expect(msg).to eq("created")

        # Exception path
        allow(Net::HTTP).to receive(:start).and_raise(Timeout::Error, "timeout")
        ok2, msg2 = cli.send(:github_create_release, owner: "me", repo: "r", token: "t", tag: "v1.0.0", title: "v1.0.0", body: "hi")
        expect(ok2).to be(false)
        expect(msg2).to include("Timeout::Error")
      end
    end
  end

  # rubocop:enable RSpec/ReceiveMessages, RSpec/StubbedMock

  # Consolidated from release_cli_github_spec.rb and release_cli_github_footer_spec.rb and release_cli_copyright_spec.rb
  describe "GitHub release behaviors" do
    let(:ci_helpers) { Kettle::Dev::CIHelpers }

    describe "GitHub release creation" do
      it "skips when token present but CHANGELOG has no matching section" do
        Dir.mktmpdir do |root|
          File.write(File.join(root, "CHANGELOG.md"), "# Changelog\n\n## [Unreleased]\n\n")
          allow(ci_helpers).to receive(:project_root).and_return(root)
          local_cli = described_class.new
          allow(local_cli).to receive(:preferred_github_remote).and_return("origin")
          allow(local_cli).to receive(:remote_url).with("origin").and_return("git@github.com:me/repo.git")
          stub_env("GITHUB_TOKEN" => "tok")
          expect { local_cli.send(:maybe_create_github_release!, "9.9.9") }.not_to raise_error
        end
      end

      it "skips when GITHUB_TOKEN is missing" do
        stub_env("GITHUB_TOKEN" => nil)
        expect { described_class.new.send(:maybe_create_github_release!, "1.2.3") }.not_to raise_error
      end

      it "creates a release with title and body from CHANGELOG when token present", :aggregate_failures do
        Dir.mktmpdir do |root|
          # Minimal CHANGELOG with a section and links
          File.write(File.join(root, "CHANGELOG.md"), <<~MD)
            # Changelog

            ## [Unreleased]

            ## [1.2.3] - 2025-08-28
            - TAG: [v1.2.3][1.2.3t]
            - Added
              - Feature X

            [Unreleased]: https://github.com/me/repo/compare/v1.2.3...HEAD
            [1.2.3]: https://github.com/me/repo/compare/v1.2.2...v1.2.3
            [1.2.3t]: https://github.com/me/repo/releases/tag/v1.2.3
          MD
          allow(ci_helpers).to receive(:project_root).and_return(root)
          local_cli = described_class.new

          # Simulate GitHub remote
          allow(local_cli).to receive(:preferred_github_remote).and_return("origin")
          allow(local_cli).to receive(:remote_url).with("origin").and_return("https://github.com/me/repo.git")

          # Stub env and Net::HTTP
          stub_env("GITHUB_TOKEN" => "token123")

          response = instance_double(Net::HTTPCreated)
          allow(response).to receive_messages(code: "201", body: "{\"id\":1}")

          http = instance_double(Net::HTTP)
          allow(http).to receive(:request).with(instance_of(Net::HTTP::Post)).and_return(response)

          allow(Net::HTTP).to receive(:start).with("api.github.com", 443, use_ssl: true).and_yield(http)

          expect { local_cli.send(:maybe_create_github_release!, "1.2.3") }.not_to raise_error
          expect(http).to have_received(:request).with(instance_of(Net::HTTP::Post))
          expect(Net::HTTP).to have_received(:start).with("api.github.com", 443, use_ssl: true)
        end
      end

      it "treats 422 already_exists as success", :aggregate_failures do
        Dir.mktmpdir do |root|
          File.write(File.join(root, "CHANGELOG.md"), <<~MD)
            # Changelog

            ## [Unreleased]

            ## [2.0.0] - 2025-08-28
            - TAG: [v2.0.0][2.0.0t]

            [Unreleased]: https://github.com/me/repo/compare/v2.0.0...HEAD
            [2.0.0]: https://github.com/me/repo/compare/v1.9.9...v2.0.0
            [2.0.0t]: https://github.com/me/repo/releases/tag/v2.0.0
          MD
          allow(ci_helpers).to receive(:project_root).and_return(root)
          local_cli = described_class.new
          allow(local_cli).to receive(:preferred_github_remote).and_return("origin")
          allow(local_cli).to receive(:remote_url).with("origin").and_return("https://github.com/me/repo")
          stub_env("GITHUB_TOKEN" => "token123")

          resp = instance_double(Net::HTTPUnprocessableEntity)
          allow(resp).to receive_messages(code: "422", body: "{\"errors\":[{\"code\":\"already_exists\"}]}")

          http = instance_double(Net::HTTP)
          allow(http).to receive(:request).with(instance_of(Net::HTTP::Post)).and_return(resp)
          allow(Net::HTTP).to receive(:start).with("api.github.com", 443, use_ssl: true).and_yield(http)

          expect { local_cli.send(:maybe_create_github_release!, "2.0.0") }.not_to raise_error
          expect(http).to have_received(:request).with(instance_of(Net::HTTP::Post))
          expect(Net::HTTP).to have_received(:start).with("api.github.com", 443, use_ssl: true)
        end
      end

      it "uploads only missing assets when a release already exists", :aggregate_failures do
        cli = described_class.new
        existing_release = {"id" => 42, "assets" => [{"name" => "already.gem"}]}
        already_exists = instance_double(Net::HTTPUnprocessableEntity, code: "422", body: "{\"errors\":[{\"code\":\"already_exists\"}]}")
        http = instance_double(Net::HTTP)
        allow(http).to receive(:request).with(instance_of(Net::HTTP::Post)).and_return(already_exists)
        allow(Net::HTTP).to receive(:start).with("api.github.com", 443, use_ssl: true).and_yield(http)
        allow(cli).to receive_messages(
          github_release_for_tag: [existing_release, nil],
          github_update_release_by_id: [true, "updated"],
          github_upload_release_asset: [true, "missing.gem"]
        )

        result = cli.send(
          :github_create_release,
          owner: "me",
          repo: "repo",
          token: "token",
          tag: "v1.2.3",
          title: "v1.2.3",
          body: "notes",
          assets: ["/artifacts/already.gem", "/artifacts/missing.gem"]
        )

        expect(result).to eq([true, "updated existing release with 1 asset uploaded"])
        expect(cli).to have_received(:github_release_for_tag).with(owner: "me", repo: "repo", token: "token", tag: "v1.2.3")
        expect(cli).to have_received(:github_update_release_by_id).with(42, owner: "me", repo: "repo", token: "token", title: "v1.2.3", body: "notes")
        expect(cli).to have_received(:github_upload_release_asset).with(42, owner: "me", repo: "repo", token: "token", path: "/artifacts/missing.gem")
        expect(cli).not_to have_received(:github_upload_release_asset).with(42, owner: "me", repo: "repo", token: "token", path: "/artifacts/already.gem")
      end

      it "retries a transient TLS failure while uploading a release asset", :aggregate_failures do
        cli = described_class.new
        allow(Kettle::Ndjson).to receive(:emit_event)
        Dir.mktmpdir do |directory|
          path = File.join(directory, "release.gem")
          File.binwrite(path, "gem")
          response = Net::HTTPCreated.new("1.1", "201", "Created")
          http = instance_double(Net::HTTP, request: response)
          calls = 0
          allow(Net::HTTP).to receive(:start) do |_host, _port, **_options, &block|
            calls += 1
            raise OpenSSL::SSL::SSLError, "tlsv1 alert protocol version" if calls == 1

            block.call(http)
          end
          allow(cli).to receive(:sleep)

          result = cli.send(:github_upload_release_asset, 42, owner: "me", repo: "repo", token: "token", path: path)

          expect(result).to eq([true, "release.gem"])
          expect(Net::HTTP).to have_received(:start).twice
          expect(cli).to have_received(:sleep).with(1).once
          expect(Kettle::Ndjson).to have_received(:emit_event).with(
            anything,
            "github_release",
            hash_including(action: "asset_upload", status: "retrying", asset: "release.gem", attempt: 1, attempts: 3)
          )
          expect(Kettle::Ndjson).to have_received(:emit_event).with(
            anything,
            "github_release",
            hash_including(action: "asset_upload", status: "ok", asset: "release.gem", attempt: 2, attempts: 3)
          )
        end
      end

      it "reports every failed release asset", :aggregate_failures do
        cli = described_class.new
        result = cli.send(
          :github_release_asset_result,
          [[false, "asset one.gem: timeout"], [false, "asset two.gem: HTTP 503"]],
          "created"
        )

        expect(result).to eq([false, "asset one.gem: timeout; asset two.gem: HTTP 503"])
      end

      it "uses origin when preferred remote is nil", :aggregate_failures do
        Dir.mktmpdir do |root|
          File.write(File.join(root, "CHANGELOG.md"), <<~MD)
            # Changelog

            ## [Unreleased]

            ## [3.0.0] - 2025-08-28
            - TAG: [v3.0.0][3.0.0t]

            [Unreleased]: https://github.com/me/repo/compare/v3.0.0...HEAD
            [3.0.0]: https://github.com/me/repo/compare/v2.9.9...v3.0.0
            [3.0.0t]: https://github.com/me/repo/releases/tag/v3.0.0
          MD
          allow(ci_helpers).to receive(:project_root).and_return(root)
          local_cli = described_class.new
          allow(local_cli).to receive(:preferred_github_remote).and_return(nil)
          allow(local_cli).to receive(:remote_url).with("origin").and_return("git@github.com:me/repo.git")
          stub_env("GITHUB_TOKEN" => "tok")

          response = instance_double(Net::HTTPInternalServerError)
          allow(response).to receive_messages(code: "500", body: "oops")
          http = instance_double(Net::HTTP)
          allow(http).to receive(:request).with(instance_of(Net::HTTP::Post)).and_return(response)
          allow(Net::HTTP).to receive(:start).with("api.github.com", 443, use_ssl: true).and_yield(http)

          expect { local_cli.send(:maybe_create_github_release!, "3.0.0") }.not_to raise_error
          expect(http).to have_received(:request).with(instance_of(Net::HTTP::Post))
          expect(Net::HTTP).to have_received(:start).with("api.github.com", 443, use_ssl: true)
        end
      end

      it "warns and skips when owner/repo cannot be determined" do
        stub_env("GITHUB_TOKEN" => "secret")
        cli = described_class.new
        allow(cli).to receive_messages(preferred_github_remote: nil, remote_url: "ssh://gitlab.com/user/repo")
        expect { cli.send(:maybe_create_github_release!, "1.0.0") }.not_to raise_error
      end
    end

    describe "release notes footer from FUNDING.md" do
      it "appends footer from FUNDING.md between tags with a leading blank line", :aggregate_failures do
        Dir.mktmpdir do |root|
          # CHANGELOG with basic section and links
          File.write(File.join(root, "CHANGELOG.md"), <<~MD)
            # Changelog

            ## [1.0.0] - 2025-08-29
            - TAG: [v1.0.0][1.0.0t]

            [1.0.0]: https://github.com/me/repo/compare/v0.9.9...v1.0.0
            [1.0.0t]: https://github.com/me/repo/releases/tag/v1.0.0
          MD

          # FUNDING with markers
          File.write(File.join(root, "FUNDING.md"), <<~MD)
            <!-- RELEASE-NOTES-FOOTER-START -->

            Support the project ❤️

            [Sponsor](https://github.com/sponsors/me)
            <!-- RELEASE-NOTES-FOOTER-END -->
          MD

          allow(ci_helpers).to receive(:project_root).and_return(root)
          cli = described_class.new
          allow(cli).to receive(:preferred_github_remote).and_return("origin")
          allow(cli).to receive(:remote_url).with("origin").and_return("https://github.com/me/repo")
          stub_env("GITHUB_TOKEN" => "tok")

          # Capture the body sent to GitHub
          captured_body = nil
          http = instance_double(Net::HTTP)
          allow(Net::HTTP).to receive(:start).with("api.github.com", 443, use_ssl: true).and_yield(http)
          allow(http).to receive(:request) do |req|
            payload = JSON.parse(req.body)
            captured_body = payload["body"]
            instance_double(Net::HTTPCreated, code: "201", body: "{}")
          end

          expect { cli.send(:maybe_create_github_release!, "1.0.0") }.not_to raise_error

          # Verify footer appended and preceded by a single blank line
          expect(captured_body).to include("[1.0.0t]: https://github.com/me/repo/releases/tag/v1.0.0")
          expect(captured_body).to match(/\n\n\[1.0.0\]: .*\n\[1.0.0t\]: .*\n\nSupport the project/m)
          # Ensure the footer content itself does not include the HTML markers
          expect(captured_body).not_to include("RELEASE-NOTES-FOOTER-START")
          expect(captured_body).not_to include("RELEASE-NOTES-FOOTER-END")
        end
      end

      it "handles missing FUNDING.md gracefully" do
        Dir.mktmpdir do |root|
          File.write(File.join(root, "CHANGELOG.md"), <<~MD)
            ## [1.2.3]
            [1.2.3]: url
            [1.2.3t]: url
          MD
          allow(ci_helpers).to receive(:project_root).and_return(root)
          cli = described_class.new
          allow(cli).to receive(:preferred_github_remote).and_return("origin")
          allow(cli).to receive(:remote_url).with("origin").and_return("https://github.com/me/repo")
          stub_env("GITHUB_TOKEN" => "tok")

          http = instance_double(Net::HTTP)
          allow(Net::HTTP).to receive(:start).with("api.github.com", 443, use_ssl: true).and_yield(http)
          allow(http).to receive(:request).and_return(instance_double(Net::HTTPCreated, code: "201", body: "{}"))

          expect { cli.send(:maybe_create_github_release!, "1.2.3") }.not_to raise_error
        end
      end
    end

    describe "copyright years validation" do
      it "passes when README.md and LICENSE.txt have identical year sets and include current year" do
        Dir.mktmpdir do |root|
          File.write(File.join(root, "README.md"), <<~MD)
            # Title

            ### © Copyright

            Copyright (c) 2023-2025 Example
          MD
          File.write(File.join(root, "LICENSE.txt"), <<~MD)
            The MIT License (MIT)

            Copyright (c) 2023, 2024, 2025 Example
          MD
          allow(ci_helpers).to receive(:project_root).and_return(root)
          cli = described_class.new
          expect { cli.send(:validate_copyright_years!) }.not_to raise_error
        end
      end

      it "rewrites consecutive years into a range in both files", :aggregate_failures, freeze: Time.local(2026, 7, 21) do
        Dir.mktmpdir do |root|
          # Build a list of consecutive years ending at the frozen current year
          # so validate_copyright_years! only reformats (no injection needed).
          start_year = 2024
          years_list = (start_year..2026).to_a.join(", ")
          File.write(File.join(root, "README.md"), "Copyright (c) #{years_list} Example")
          File.write(File.join(root, "LICENSE.txt"), "The MIT License (MIT)\nCopyright (c) #{years_list} Example")
          allow(ci_helpers).to receive(:project_root).and_return(root)
          cli = described_class.new
          expect { cli.send(:validate_copyright_years!) }.not_to raise_error
          expect(File.read(File.join(root, "README.md"))).to include("#{start_year}-2026")
          expect(File.read(File.join(root, "LICENSE.txt"))).to include("#{start_year}-2026")
        end
      end

      it "aborts when sets differ (mismatch)" do
        Dir.mktmpdir do |root|
          File.write(File.join(root, "README.md"), "Copyright (c) 2023, 2025 Example\n")
          File.write(File.join(root, "LICENSE.txt"), "The MIT License (MIT)\nCopyright 2023-2024 Example\n")
          allow(ci_helpers).to receive(:project_root).and_return(root)
          cli = described_class.new
          expect { cli.send(:validate_copyright_years!) }.to raise_error(MockSystemExit, /Mismatched copyright years/)
        end
      end

      it "is skipped silently if either file is missing" do
        Dir.mktmpdir do |root|
          File.write(File.join(root, "README.md"), "Copyright (c) 2024")
          allow(ci_helpers).to receive(:project_root).and_return(root)
          cli = described_class.new
          expect { cli.send(:validate_copyright_years!) }.not_to raise_error
        end
      end

      it "injects current year into both files when missing and sets match", :aggregate_failures, freeze: Time.local(2026, 7, 21) do
        Dir.mktmpdir do |root|
          last_year = 2025
          File.write(File.join(root, "README.md"), "Copyright (c) #{last_year} Example")
          File.write(File.join(root, "LICENSE.txt"), "The MIT License (MIT)\nCopyright (c) #{last_year} Example")
          allow(ci_helpers).to receive(:project_root).and_return(root)
          cli = described_class.new
          expect { cli.send(:validate_copyright_years!) }.not_to raise_error
          expect(File.read(File.join(root, "README.md"))).to include("#{last_year}-2026")
          expect(File.read(File.join(root, "LICENSE.txt"))).to include("#{last_year}-2026")
        end
      end
    end
  end
end
