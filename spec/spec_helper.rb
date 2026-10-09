# frozen_string_literal: true

# Config for development dependencies of this library
# i.e., not configured by this library
#
# Simplecov & related config (must run BEFORE any other requires)
# NOTE: Gemfiles for older rubies won't have kettle-soup-cover.
#       The rescue LoadError handles that scenario.
begin
  require "kettle-soup-cover"
  if Kettle::Soup::Cover::DO_COV
    # Requiring simplecov loads `.simplecov`; keep that file configuration-only.
    require "simplecov"
    require "kettle/soup/cover/config"
    SimpleCov.start
  end
rescue LoadError => error
  # check the error message and re-raise when unexpected
  raise error unless error.message.include?("kettle")
end

# External RSpec & related config
require "rake"
require "kettle/test/rspec"
# `kettle/test/rspec` installs harness helpers documented in spec/README.md.

# Internal ENV config
require_relative "config/debug"
require_relative "config/vcr"

# this library
require "kettle-dev"
# Dog food autoload setup and ensure GitAdapter constant is available for global stubbing
# Dog food autoload setup and ensure ExitAdapter constant is available for potential stubbing
# Dog food autoload setup and ensure InputAdapter constant is available for stubbing

# Dog food autoload setup and ensure GitAdapter constant is available for global stubbing
# Dog food autoload setup and ensure ExitAdapter constant is available for potential stubbing
# Dog food autoload setup and ensure InputAdapter constant is available for stubbing

# Dog food autoload setup and ensure GitAdapter constant is available for global stubbing
# Dog food autoload setup and ensure ExitAdapter constant is available for potential stubbing
# Dog food autoload setup and ensure InputAdapter constant is available for stubbing

# Dog food autoload setup and ensure GitAdapter constant is available for global stubbing
# Dog food autoload setup and ensure ExitAdapter constant is available for potential stubbing
# Dog food autoload setup and ensure InputAdapter constant is available for stubbing

# Dog food autoload setup and ensure GitAdapter constant is available for global stubbing
# Dog food autoload setup and ensure ExitAdapter constant is available for potential stubbing
# Dog food autoload setup and ensure InputAdapter constant is available for stubbing

# Dog food autoload setup and ensure GitAdapter constant is available for global stubbing
# Dog food autoload setup and ensure ExitAdapter constant is available for potential stubbing
# Dog food autoload setup and ensure InputAdapter constant is available for stubbing

# Dog food autoload setup and ensure GitAdapter constant is available for global stubbing
# Dog food autoload setup and ensure ExitAdapter constant is available for potential stubbing
# Dog food autoload setup and ensure InputAdapter constant is available for stubbing

# Dog food autoload setup and ensure GitAdapter constant is available for global stubbing
# Dog food autoload setup and ensure ExitAdapter constant is available for potential stubbing
# Dog food autoload setup and ensure InputAdapter constant is available for stubbing

# Dog food autoload setup and ensure GitAdapter constant is available for global stubbing
# Dog food autoload setup and ensure ExitAdapter constant is available for potential stubbing
# Dog food autoload setup and ensure InputAdapter constant is available for stubbing

# Dog food autoload setup and ensure GitAdapter constant is available for global stubbing
# Dog food autoload setup and ensure ExitAdapter constant is available for potential stubbing
# Dog food autoload setup and ensure InputAdapter constant is available for stubbing

# Dog food autoload setup and ensure GitAdapter constant is available for global stubbing
# Dog food autoload setup and ensure ExitAdapter constant is available for potential stubbing
# Dog food autoload setup and ensure InputAdapter constant is available for stubbing

# Dog food autoload setup and ensure GitAdapter constant is available for global stubbing
# Dog food autoload setup and ensure ExitAdapter constant is available for potential stubbing
# Dog food autoload setup and ensure InputAdapter constant is available for stubbing

# Dog food autoload setup and ensure GitAdapter constant is available for global stubbing
# Dog food autoload setup and ensure ExitAdapter constant is available for potential stubbing
# Dog food autoload setup and ensure InputAdapter constant is available for stubbing

# Dog food autoload setup and ensure GitAdapter constant is available for global stubbing
# Dog food autoload setup and ensure ExitAdapter constant is available for potential stubbing
# Dog food autoload setup and ensure InputAdapter constant is available for stubbing

# Dog food autoload setup and ensure GitAdapter constant is available for global stubbing
# Dog food autoload setup and ensure ExitAdapter constant is available for potential stubbing
# Dog food autoload setup and ensure InputAdapter constant is available for stubbing

# Dog food autoload setup and ensure GitAdapter constant is available for global stubbing
# Dog food autoload setup and ensure ExitAdapter constant is available for potential stubbing
# Dog food autoload setup and ensure InputAdapter constant is available for stubbing

# Dog food autoload setup and ensure GitAdapter constant is available for global stubbing
# Dog food autoload setup and ensure ExitAdapter constant is available for potential stubbing
# Dog food autoload setup and ensure InputAdapter constant is available for stubbing

# Dog food autoload setup and ensure GitAdapter constant is available for global stubbing
# Dog food autoload setup and ensure ExitAdapter constant is available for potential stubbing
# Dog food autoload setup and ensure InputAdapter constant is available for stubbing

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
  # Auto-skip examples that require Bundler >= 2.7 (which implies Ruby >= 3.2)
  config.before(:each, :bundler_27_only) do
    # Skip on Ruby < 3.2 using rspec-pending_for's version matcher
    skip_for(reason: "Requires Bundler >= 2.7 which is unavailable on Ruby < 3.2", versions: %w[2.4 2.5 2.6 2.7 3.0 3.1])
  end

  config.before(:each, :modern_tooling_only) do
    skip_for(
      reason: "Exercises Kettle Dev tooling supported on Ruby >= 3.2",
      versions: %w[2.4 2.5 2.6 2.7 3.0 3.1]
    )
  end

  # Auto-skip examples that require prism-merge (Ruby >= 2.7)
  config.before(:each, :prism_merge_only) do
    skip_for(reason: "Requires prism-merge which is unavailable on Ruby < 2.7", versions: %w[2.3 2.4 2.5 2.6])
  end

  config.before(:each, :jruby_head_release_flow) do
    skip_for(
      engine: "jruby",
      versions: "head",
      reason: "JRuby head repeatedly reloads jopenssl/load.rb during release-flow specs; see jruby/jruby-openssl#251"
    )
  end

  config.before(:each, :prism_only) do
    begin
      require "prism"
    rescue LoadError
      skip "Requires Prism, which is unavailable in this appraisal"
    end
  end

  config.before(:each, :markly_crispr) do
    begin
      require "ast/crispr/markdown/markly"
    rescue LoadError
      skip "Requires ast-crispr-markdown-markly, which is unavailable in this appraisal"
    end
  end

  config.before do
    stub_env(
      "KETTLE_RELEASE_SECRETS_PROVIDER" => nil,
      "KETTLE_RELEASE_GEM_SIGNING_PASSPHRASE" => nil,
      "KETTLE_RELEASE_GEM_SIGNING_PASSPHRASE_SOURCE" => nil,
      "KETTLE_RELEASE_1PASSWORD_ACCOUNT" => nil,
      "KETTLE_RELEASE_1PASSWORD_CLI" => nil,
      "KETTLE_RELEASE_1PASSWORD_ITEM" => nil,
      "KETTLE_RELEASE_1PASSWORD_GEM_SIGNING_PASSPHRASE_FIELD" => nil,
      "KETTLE_RELEASE_1PASSWORD_RUBYGEMS_OTP_FIELD" => nil,
      "KETTLE_RELEASE_1PASSWORD_GEM_SIGNING_PASSPHRASE_REFERENCE" => nil,
      "KETTLE_RELEASE_1PASSWORD_RUBYGEMS_OTP_REFERENCE" => nil
    )

    # Speed up polling loops
    allow(described_class).to receive(:sleep) unless described_class.nil?
  end
end

# Internal RSpec & related config
# Include the global mocked git adapter context
require_relative "support/shared_contexts/with_mocked_git_adapter"
# Include the global mocked exit adapter context
require_relative "support/shared_contexts/with_mocked_exit_adapter"
# Include skip context for TruffleRuby 3.1..3.2 incompatibilities
require_relative "support/shared_contexts/with_truffleruby_skip_31_32"
# Include mocked input adapter for all examples; it will skip when :real_input_adapter is set
require_relative "support/shared_contexts/with_mocked_input_adapter"
# Stub out the actual rake release command globally in specs
require_relative "support/shared_contexts/with_stubbed_release_rake"
# The test input machine is used when testing actual $stdin, by replacing it with the machine.
require_relative "support/classes/kettle_test_input_machine"

RSpec.configure do |config|
  # Include mocked git adapter for all examples; it will skip when :real_git_adapter is set
  config.include_context "with mocked git adapter"

  # Include mocked exit adapter for all examples; it will skip when :real_exit_adapter is set
  config.include_context "with mocked exit adapter"

  config.include_context "with mocked input adapter"

  # Include the stub so any spec that reaches ReleaseCLI.run_cmd!("bundle exec rake release") no-ops
  # it will skip when :real_rake_release is set
  config.include_context "with stubbed release rake"
end
