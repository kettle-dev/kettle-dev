# frozen_string_literal: true

require "rake"

RSpec.describe Kettle::Dev do
  describe described_class::Error do
    it "is a standard error" do
      expect { raise described_class }.to raise_error(StandardError)
    end
  end

  describe "::safe_load_yaml" do
    it "can load aliases when requested" do
      content = "defaults: &defaults\n  branch: main\ncopy: *defaults\n"

      expect(described_class.safe_load_yaml(content, aliases: true)).to eq(
        "defaults" => {"branch" => "main"},
        "copy" => {"branch" => "main"}
      )
    end

    it "uses the positional Psych API when keyword options are unsupported" do
      content = "branch: main\n"
      allow(YAML).to receive(:safe_load).with(content, permitted_classes: [], aliases: true).and_raise(ArgumentError)
      allow(YAML).to receive(:safe_load).with(content, [], [], true).and_return("branch" => "main")

      expect(described_class.safe_load_yaml(content, aliases: true)).to eq("branch" => "main")
      expect(YAML).to have_received(:safe_load).with(content, [], [], true)
    end
  end

  describe "::debug_error" do
    let(:error) do
      RuntimeError.new("boom").tap do |e|
        e.set_backtrace([
          "/tmp/project/lib/example.rb:10:in `call'",
          "/tmp/project/lib/example.rb:20:in `run'"
        ])
      end
    end

    before do
      stub_const("Kettle::Dev::DEBUGGING", true)
      allow(Kernel).to receive(:warn)
    end

    it "emits the backtrace by default" do
      described_class.debug_error(error, :example)

      expect(Kernel).to have_received(:warn).with("[example] RuntimeError: boom")
      expect(Kernel).to have_received(:warn).with("/tmp/project/lib/example.rb:10:in `call'\n/tmp/project/lib/example.rb:20:in `run'")
    end

    it "can suppress the backtrace for expected rescued errors" do
      described_class.debug_error(error, :example, backtrace: false)

      expect(Kernel).to have_received(:warn).with("[example] RuntimeError: boom")
      expect(Kernel).not_to have_received(:warn).with("/tmp/project/lib/example.rb:10:in `call'\n/tmp/project/lib/example.rb:20:in `run'")
    end
  end

  describe "::register_default" do
    it "adds task and enhances :default when defined" do
      stub_const("Rake::Task", Class.new)
      allow(Rake::Task).to receive(:task_defined?).with(:default).and_return(true)
      default_task = instance_double(Rake::Task)
      allow(Rake::Task).to receive(:[]).with(:default).and_return(default_task)
      allow(default_task).to receive(:enhance).with(["foo"]).and_return(nil)
      expect(described_class.register_default(:foo)).to include("foo")
      expect(default_task).to have_received(:enhance).with(["foo"])
    end

    # Helper to stub a :default task that raises on enhance
    def stub_default_task_raising
      stub_const("Rake::Task", Class.new)
      allow(Rake::Task).to receive(:task_defined?).with(:default).and_return(true)
      default_task = instance_double(Rake::Task)
      allow(Rake::Task).to receive(:[]).with(:default).and_return(default_task)
      allow(default_task).to receive(:enhance).and_raise(StandardError, "boom")
    end

    it "rescues and does not warn when DEBUGGING is false" do
      stub_const("Kettle::Dev::DEBUGGING", false)
      stub_default_task_raising
      allow(Kernel).to receive(:warn)
      described_class.register_default(:bar)
      expect(Kernel).not_to have_received(:warn)
    end

    it "rescues and warns when DEBUGGING is true" do
      stub_const("Kettle::Dev::DEBUGGING", true)
      stub_default_task_raising
      allow(Kernel).to receive(:warn)
      described_class.register_default(:qux)
      expect(Kernel).to have_received(:warn).with(include("kettle-dev: failed to enhance :default with qux: boom"))
    end

    it "does not enhance when :default is not defined" do
      stub_const("Rake::Task", Class.new)
      allow(Rake::Task).to receive(:task_defined?).with(:default).and_return(false)
      expect(described_class.register_default(:baz)).to include("baz")
    end
  end

  describe "::display_path" do
    it "normalizes /var/home to /home for user-facing output" do
      expect(described_class.display_path("/var/home/pboling/src/kettle-dev")).to eq("/home/pboling/src/kettle-dev")
      expect(described_class.display_path("/home/pboling/src/kettle-dev")).to eq("/home/pboling/src/kettle-dev")
    end
  end

  describe "linting and coverage tasks" do
    around do |example|
      defaults = described_class.defaults
      described_class.instance_variable_set(:@defaults, [].freeze)
      example.run
      described_class.instance_variable_set(:@defaults, defaults)
    end

    before do
      stub_const("Rubocop::Lts", Class.new)
      allow(Rubocop::Lts).to receive(:install_tasks)
      allow(described_class).to receive(:register_default).and_call_original
      allow(described_class).to receive(:require).and_call_original
      allow(described_class).to receive(:require).with("rubocop/lts").and_return(true)
    end

    it "registers autocorrect when not on CI" do
      stub_const("Kettle::Dev::IS_CI", false)
      described_class.send(:linting_tasks)
      expect(described_class.defaults).to include("rubocop_gradual:autocorrect")
    end

    it "registers check when on CI" do
      stub_const("Kettle::Dev::IS_CI", true)
      described_class.send(:linting_tasks)
      expect(described_class.defaults).to include("rubocop_gradual:check")
    end

    it "handles missing rubocop-lts (LoadError)" do
      allow(described_class).to receive(:require).with("rubocop/lts").and_raise(LoadError)
      expect { described_class.send(:linting_tasks) }.not_to raise_error
    end

    it "handles missing kettle-soup-cover (LoadError)" do
      allow(described_class).to receive(:require).with("kettle-soup-cover").and_raise(LoadError)
      expect { described_class.send(:coverage_tasks) }.not_to raise_error
    end

    it "registers coverage when kettle-soup-cover present and not CI" do
      stub_const("Kettle::Dev::IS_CI", false)
      allow(described_class).to receive(:require).with("kettle-soup-cover").and_return(true)
      stub_const("Kettle::Soup::Cover", double("Cover", install_tasks: true))
      described_class.send(:coverage_tasks)
      expect(described_class.defaults).to include("coverage")
    end
  end

  describe "::default_registered?" do
    it "returns false when task is not registered" do
      # ensure a name unlikely to collide with other specs
      expect(described_class.default_registered?("__never_before__")).to be false
    end

    it "returns true when task has been registered" do
      name = "__custom_task__"
      described_class.register_default(name)
      expect(described_class.default_registered?(name)).to be true
      # and symbol input should also work equivalently
      expect(described_class.default_registered?(name.to_sym)).to be true
    end
  end

  describe "::install_tasks" do
    subject(:install_tasks) { described_class.install_tasks }

    it "adds rubocop/rubyX_X/rakelib to Rake application's rakelib" do
      rakelibs = ["rakelib"]
      # rakelibs.push(%r{rubocop/ruby\d_\d/rakelib}) # This will only be present on the style CI workflow.
      rakelibs.push(%r{kettle/dev/rakelib})

      block_is_expected.to not_raise_error &
        change {
          Rake.application.options.rakelib
        }.from(["rakelib"]).to(include(*rakelibs))
    end
  end
end
