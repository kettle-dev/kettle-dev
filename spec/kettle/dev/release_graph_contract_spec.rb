# frozen_string_literal: true

require "tmpdir"

RSpec.describe Kettle::Dev::ReleaseGraphContract do
  around do |example|
    Dir.mktmpdir("kettle-dev-release-graph-contract-spec") do |root|
      @ci_root = root
      @member_root = File.join(root, "gems", "member")
      FileUtils.mkdir_p(@member_root)
      example.run
    end
  end

  it "allows a subgem to use a declared path under the family CI root" do
    gems = File.join(@ci_root, "gems")
    contract = described_class.new(
      name: "monorepo_ci_local",
      root: @member_root,
      ci_root: @ci_root,
      local_path_roots: [gems],
      selector_env: {"STRUCTUREDMERGE_DEV" => gems}
    )

    expect(contract.allowed_path?(File.join(gems, "sibling"))).to be(true)
    expect(contract.normalization_environment).to eq("STRUCTUREDMERGE_DEV" => gems)
  end

  it "rejects a monorepo contract whose release child is outside the CI root" do
    outside_root = File.join(File.dirname(@ci_root), "outside-member")
    FileUtils.mkdir_p(outside_root)

    expect do
      described_class.new(
        name: "monorepo_ci_local",
        root: outside_root,
        ci_root: @ci_root,
        local_path_roots: [File.join(@ci_root, "gems")],
        selector_env: {"STRUCTUREDMERGE_DEV" => File.join(@ci_root, "gems")}
      )
    end.to raise_error(Kettle::Dev::Error, /release root .* outside CI root/)
  end

  it "defaults a direct release to registry-only" do
    stub_env(described_class::ENV_KEY => nil)
    contract = described_class.from_environment(root: @member_root)

    expect(contract.registry_only?).to be(true)
    expect(contract.local_paths?).to be(false)
  end

  it "rejects local paths in a terminal branch contract" do
    expect do
      described_class.new(
        name: "branch_terminal",
        root: @member_root,
        ci_root: @ci_root,
        local_path_roots: [File.join(@ci_root, "gems")],
        selector_env: {"RUBOCOP_LTS_DEV" => File.join(@ci_root, "gems")}
      )
    end.to raise_error(Kettle::Dev::Error, /cannot declare local paths or selectors/)
  end
end
