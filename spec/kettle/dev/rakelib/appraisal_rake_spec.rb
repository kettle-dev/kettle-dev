# frozen_string_literal: true

require "spec_helper"
require "ripper"

RSpec.describe "appraisal rake tasks" do # rubocop:disable RSpec/DescribeClass
  include_context "with rake", "appraisal" do
    let(:task_dir) { "lib/kettle/dev/rakelib" }
    let(:rakelib) { File.expand_path("../../../../lib/kettle/dev/rakelib", __dir__) }
  end

  let(:quiet_env) do
    {
      "KETTLE_JEM_QUIET" => "true",
      "KETTLE_JEM_DEBUG" => "false",
      "KETTLE_DEV_DEBUG" => "false",
      "STRUCTUREDMERGE_DEBUG" => "false",
      "DEBUG" => nil,
      "BUNDLE_QUIET" => "true",
      "BUNDLE_DEBUG" => "false",
      "BUNDLER_DEBUG" => "false",
      "BUNDLE_VERBOSE" => "false",
      "DEBUG_RESOLVER" => nil,
      "DEBUG_RESOLVER_TREE" => nil,
      "BUNDLER_DEBUG_RESOLVER" => nil,
      "BUNDLER_DEBUG_RESOLVER_TREE" => nil,
      "DEBUG_COMPACT_INDEX" => nil,
      "MOLINILLO_DEBUG" => nil,
      "BUNDLE_SILENCE_DEPRECATIONS" => "true",
      "BUNDLE_SILENCE_ROOT_WARNING" => "true",
      "BUNDLE_SUPPRESS_INSTALL_USING_MESSAGES" => "true"
    }
  end
  let(:unbundled_env) do
    Kettle::Dev::LockfileReset::UNBUNDLED_ENV_KEYS.each_with_object({}) do |key, env|
      env[key] = nil
    end
  end
  let(:appraisal_env) do
    quiet_env
      .merge(Kettle::Dev::LockfileReset::DEFAULT_DISABLED_ENV)
      .merge(unbundled_env)
      .merge(
        "BUNDLE_GEMFILE" => "Appraisal.root.gemfile",
        "BUNDLE_LOCKFILE" => "Appraisal.root.gemfile.lock"
      )
  end
  let(:bundle_install_call) { [appraisal_env, "bundle", "install", "--quiet"] }

  def expect_system_calls(*expected_commands)
    expect(system_calls.length).to eq(expected_commands.length)
    system_calls.zip(expected_commands).each do |actual, expected|
      actual_env, *actual_command = actual
      expected_env, *expected_command = expected
      expect(actual_env).to include(expected_env)
      expect(actual_command).to eq(expected_command)
    end
  end

  describe "rake appraisal:generate" do
    let(:task_name) { "appraisal:generate" }
    let(:system_calls) { [] }

    before do
      allow(Bundler).to receive(:with_unbundled_env).and_yield
      allow_any_instance_of(Object).to receive(:system) do |_receiver, *args| # rubocop:disable RSpec/AnyInstance
        system_calls << args
        true
      end
    end

    it "generates appraisal gemfiles in the Appraisal root bundle context" do
      invoke

      expect_system_calls(
        bundle_install_call,
        [appraisal_env, "bundle", "exec", "appraisal", "generate"]
      )
    end
  end

  it "keeps appraisal task env construction compatible with Ruby 2.4" do
    source = File.read(File.expand_path("../../../../lib/kettle/dev/rakelib/appraisal.rake", __dir__))
    sexp = Ripper.sexp(source)
    multi_argument_merges = []

    walker = lambda do |node|
      next unless node.is_a?(Array)

      if node.first == :method_add_arg && node[1].is_a?(Array) && node[1].first == :call && node[1][3].is_a?(Array) && node[1][3][1] == "merge"
        args = node.dig(2, 1)
        multi_argument_merges << node if args.is_a?(Array) && args.count { |arg| arg.is_a?(Array) && arg.first != :@comma } > 1
      end
      node.each { |child| walker.call(child) }
    end
    walker.call(sexp)

    expect(multi_argument_merges).to be_empty
  end

  it "uses the template-aware appraisal normalization environment" do
    source = File.read(File.expand_path("../../../../lib/kettle/dev/rakelib/appraisal.rake", __dir__))

    expect(source).to include(".appraisal_normalization_env")
  end

  describe "rake appraisal:install" do
    let(:task_name) { "appraisal:install" }
    let(:appraisal_install_call) { [appraisal_env, "bundle", "exec", "appraisal", "generate-install"] }
    let(:failed_calls) { [] }
    let(:system_calls) { [] }

    before do
      allow(Bundler).to receive(:with_unbundled_env).and_yield
      allow_any_instance_of(Object).to receive(:system) do |_receiver, *args| # rubocop:disable RSpec/AnyInstance
        system_calls << args
        !failed_calls.include?(args)
      end
    end

    it "generates and installs appraisal gemfiles" do
      invoke

      expect_system_calls(
        bundle_install_call,
        appraisal_install_call
      )
    end

    context "when appraisal install fails" do
      let(:failed_calls) { [appraisal_install_call] }

      it "falls back to generating appraisal gemfiles" do
        invoke

        expect_system_calls(
          bundle_install_call,
          appraisal_install_call,
          bundle_install_call,
          [appraisal_env, "bundle", "exec", "appraisal", "generate"]
        )
      end
    end
  end

  describe "rake appraisal:update" do
    let(:task_name) { "appraisal:update" }
    let(:appraisal_update_call) { [appraisal_env, "bundle", "exec", "appraisal", "generate-update"] }
    let(:failed_calls) { [] }
    let(:system_calls) { [] }

    before do
      allow(Bundler).to receive(:with_unbundled_env).and_yield
      allow_any_instance_of(Object).to receive(:system) do |_receiver, *args| # rubocop:disable RSpec/AnyInstance
        system_calls << args
        !failed_calls.include?(args)
      end
    end

    it "installs the Appraisal root bundle before updating Bundler" do
      invoke

      expect_system_calls(
        bundle_install_call,
        [appraisal_env, "bundle", "update", "--bundler=#{Bundler::VERSION}"],
        bundle_install_call,
        appraisal_update_call
      )
    end

    context "when appraisal update fails" do
      let(:failed_calls) { [appraisal_update_call] }

      it "falls back to generating appraisal gemfiles" do
        invoke

        expect_system_calls(
          bundle_install_call,
          [appraisal_env, "bundle", "update", "--bundler=#{Bundler::VERSION}"],
          bundle_install_call,
          appraisal_update_call,
          bundle_install_call,
          [appraisal_env, "bundle", "exec", "appraisal", "generate"]
        )
      end
    end
  end
end
