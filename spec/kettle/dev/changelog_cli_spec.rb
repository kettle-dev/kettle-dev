# frozen_string_literal: true

require "open3"

# Kettle::Dev::ChangelogCLI is a deprecated transition shim from the
# kettle-changelog extraction (removal planned for kettle-dev 4.0). Behavior
# coverage lives in the kettle-changelog gem's suite; this file covers only
# the deprecation contract.
RSpec.describe Kettle::Dev::ChangelogCLI do
  it "loads with a deprecation warning pointing at the kettle-changelog gem" do
    _stdout, stderr, status = Open3.capture3(
      RbConfig.ruby, "-Ilib", "-e",
      'require "kettle/dev/changelog_cli"; exit(Kettle::Dev::ChangelogCLI.is_a?(Class) ? 0 : 1)',
      chdir: Kettle::Dev::GEM_ROOT
    )

    expect(status.exitstatus).to eq(0)
    expect(stderr).to include("Kettle::Dev::ChangelogCLI is deprecated")
    expect(stderr).to include("kettle-changelog")
  end
end
