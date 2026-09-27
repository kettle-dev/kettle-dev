# frozen_string_literal: true

require "json"
require "open3"
require "stringio"

# rubocop:disable RSpec/VerifiedDoubles, RSpec/MessageSpies, ThreadSafety/ClassInstanceVariable

RSpec.describe Kettle::Dev::GhaShaPinsCLI do
  let(:workflow_root) { Dir.mktmpdir }
  let(:workflow_path) { File.join(workflow_root, ".github", "workflows", "ci.yml") }

  before do
    FileUtils.mkdir_p(File.dirname(workflow_path))
    File.write(
      workflow_path,
      <<~YAML
        name: ci
        on: [push]
        jobs:
          test:
            runs-on: ubuntu-latest
            steps:
              - uses: foo/bar@v1.2.0
      YAML
    )
  end

  after do
    FileUtils.rm_rf(workflow_root)
  end

  def stub_github_client(versions:, commit_shas: {})
    client = instance_double(described_class::GitHubClient)
    allow(described_class::GitHubClient).to receive(:new).and_return(client)
    allow(client).to receive(:versions_for_repo).and_return(versions)
    allow(client).to receive(:commit_sha) do |_repo, ref|
      commit_shas[ref]
    end
    client
  end

  it "falls back to a clear runtime failure when kettle-gha-pins is unavailable" do
    code = <<~RUBY
      module Kernel
        alias original_require require

        def require(path)
          raise LoadError, path if path == "kettle/gha/pins/cli"

          original_require(path)
        end
      end

      require "kettle/dev/gha_sha_pins_cli"
      exit Kettle::Dev::GhaShaPinsCLI.new([]).run!
    RUBY

    _stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-Ilib", "-e", code, chdir: Kettle::Dev::GEM_ROOT)

    expect(status.exitstatus).to eq(1)
    expect(stderr).to include("kettle-gha-pins is not available")
  end

  describe "CLI options" do
    it "defaults --upgrade to major" do
      cli = described_class.new(["--root", workflow_root])
      cli.send(:parse!)
      expect(cli.instance_variable_get(:@options)[:upgrade]).to eq("major")
    end

    it "accepts --refresh-cache and --cache-path" do
      cache_path = File.join(workflow_root, "gha-cache.json")
      cli = described_class.new(["--root", workflow_root, "--refresh-cache", "--cache-path", cache_path])

      cli.send(:parse!)

      options = cli.instance_variable_get(:@options)
      expect(options[:refresh_cache]).to be(true)
      expect(options[:cache_path]).to eq(cache_path)
    end

    it "defaults to the current project's .github/workflows directory" do
      allow(Dir).to receive(:pwd).and_return(workflow_root)
      cli = described_class.new([])
      cli.send(:parse!)

      expect(cli.instance_variable_get(:@options)[:root]).to eq(File.join(workflow_root, ".github", "workflows"))
    end

    it "accepts major, minor, and patch for --upgrade", :real_exit_adapter do
      cli_major = described_class.new(["--upgrade", "major", "--root", workflow_root])
      cli_minor = described_class.new(["--upgrade", "minor", "--root", workflow_root])
      cli_patch = described_class.new(["--upgrade", "patch", "--root", workflow_root])

      expect { cli_major.send(:parse!) }.not_to raise_error
      expect(cli_major.instance_variable_get(:@options)[:upgrade]).to eq("major")

      expect { cli_minor.send(:parse!) }.not_to raise_error
      expect(cli_minor.instance_variable_get(:@options)[:upgrade]).to eq("minor")

      expect { cli_patch.send(:parse!) }.not_to raise_error
      expect(cli_patch.instance_variable_get(:@options)[:upgrade]).to eq("patch")
    end

    it "aborts on invalid --upgrade values", :real_exit_adapter do
      cli = described_class.new(["--upgrade", "garbage", "--root", workflow_root])

      expect { cli.send(:parse!) }.to raise_error(SystemExit)
    end
  end

  describe "workflow discovery" do
    it "scans only the selected workflow directory when given a project root" do
      nested_workflow = File.join(workflow_root, "tmp", "template_test", "destination", ".github", "workflows", "ci.yml")
      FileUtils.mkdir_p(File.dirname(nested_workflow))
      File.write(nested_workflow, File.read(workflow_path))
      cli = described_class.new(["--root", workflow_root])

      expect(cli.send(:discover_workflow_files, workflow_root, Set.new)).to eq([File.realpath(workflow_path)])
    end

    it "accepts a workflow directory as the analysis root" do
      workflow_dir = File.dirname(workflow_path)
      cli = described_class.new(["--root", workflow_dir])

      expect(cli.send(:discover_workflow_files, workflow_dir, Set.new)).to eq([File.realpath(workflow_path)])
    end
  end

  describe "upgrade planning helpers" do
    let(:versions) do
      [
        {
          tag: "v1.2.0",
          version_obj: Gem::Version.new("1.2.0"),
          version: "1.2.0",
          sha: "777"
        },
        {
          tag: "v1.3.0",
          version_obj: Gem::Version.new("1.3.0"),
          version: "1.3.0",
          sha: "999"
        },
        {
          tag: "v1.2.3",
          version_obj: Gem::Version.new("1.2.3"),
          version: "1.2.3",
          sha: "aaa"
        },
        {
          tag: "v2.0.0",
          version_obj: Gem::Version.new("2.0.0"),
          version: "2.0.0",
          sha: "bbb"
        }
      ]
    end

    let(:client) { described_class::GitHubClient.new(token: nil, api_base: described_class::API_BASE, user_agent: "kettle-gha-pins") }
    let(:dummy_cli) { described_class.new(["--root", workflow_root]) }

    before do
      allow(client).to receive(:commit_sha).and_return("777")
    end

    it "selects minor-compatible upgrade target for minor strategy" do
      plan = dummy_cli.send(:determine_upgrade_plan, old_ref: "v1.2.0", repo_ref: "foo/bar", versions: versions, upgrade_level: "minor", client: client)
      expect(plan[:updates][:sha]).to eq("999")
      expect(plan[:updates][:version]).to eq("1.3.0")
      expect(plan[:reason]).to eq(described_class::UPGRADE_REASON)
      expect(plan[:current_version]).to eq("1.2.0")
      expect(plan[:is_outdated]).to be(true)
    end

    it "selects any higher version for major strategy" do
      plan = dummy_cli.send(:determine_upgrade_plan, old_ref: "v1.2.0", repo_ref: "foo/bar", versions: versions, upgrade_level: "major", client: client)
      expect(plan[:updates][:sha]).to eq("bbb")
      expect(plan[:updates][:version]).to eq("2.0.0")
      expect(plan[:reason]).to eq(described_class::UPGRADE_REASON)
    end

    it "selects major-line tag upgrades only for major strategy" do
      major_line_versions = [
        {tag: "v3", version_obj: Gem::Version.new("3"), version: "3", sha: "c" * 40},
        {tag: "v2", version_obj: Gem::Version.new("2"), version: "2", sha: "b" * 40}
      ]

      major_plan = dummy_cli.send(:determine_upgrade_plan, old_ref: "v2", repo_ref: "foo/bar", versions: major_line_versions, upgrade_level: "major", client: client)
      minor_plan = dummy_cli.send(:determine_upgrade_plan, old_ref: "v2", repo_ref: "foo/bar", versions: major_line_versions, upgrade_level: "minor", client: client)
      patch_plan = dummy_cli.send(:determine_upgrade_plan, old_ref: "v2", repo_ref: "foo/bar", versions: major_line_versions, upgrade_level: "patch", client: client)

      expect(major_plan[:updates]).to include(sha: "c" * 40, version: "3", reason: described_class::UPGRADE_REASON)
      expect(minor_plan[:updates]).to be_nil
      expect(patch_plan[:updates]).to be_nil
    end

    it "selects latest patch for patch strategy" do
      plan = dummy_cli.send(:determine_upgrade_plan, old_ref: "v1.2.0", repo_ref: "foo/bar", versions: versions, upgrade_level: "patch", client: client)
      expect(plan[:updates][:sha]).to eq("aaa")
      expect(plan[:updates][:version]).to eq("1.2.3")
      expect(plan[:reason]).to eq(described_class::UPGRADE_REASON)
      expect(plan[:latest_outdated][:version]).to eq("2.0.0")
    end

    it "parses release tags and matches version-like values" do
      expect(dummy_cli.send(:parse_release_version, "v1.2.3")).to eq(Gem::Version.new("1.2.3"))
      expect(dummy_cli.send(:parse_release_version, "v2")).to eq(Gem::Version.new("2"))
      expect(dummy_cli.send(:parse_release_version, "bad-tag")).to be_nil
    end

    it "delegates release version parsing to kettle-gha-pins" do
      allow(Kettle::Gha::Pins::VersionRubric).to receive(:parse).and_call_original

      expect(dummy_cli.send(:parse_release_version, "v1.2.3")).to eq(Gem::Version.new("1.2.3"))

      expect(Kettle::Gha::Pins::VersionRubric).to have_received(:parse).with("v1.2.3")
    end

    it "falls back to source scanning for Psych nodes without location APIs" do
      text = <<~YAML
        jobs:
          test:
            steps:
              - uses: foo/bar@v1.2.0
      YAML

      expect(dummy_cli.send(:fallback_uses_location, text, "foo/bar@v1.2.0", {})).to eq([3, 14])
    end

    it "reports higher-version outdated info even when patch is the write target" do
      plan = dummy_cli.send(:determine_upgrade_plan, old_ref: "v1.2.0", repo_ref: "foo/bar", versions: versions, upgrade_level: "patch", client: client)

      expect(plan[:updates][:version]).to eq("1.2.3")
      expect(plan[:latest_outdated][:version]).to eq("2.0.0")
      expect(plan[:is_outdated]).to be(true)
    end

    it "does not upgrade stable pins to prerelease-only tags" do
      prerelease_versions = [
        {tag: "v1.3.0.pre", version_obj: Gem::Version.new("1.3.0.pre"), version: "1.3.0.pre", sha: "pre"},
        {tag: "v1.2.0", version_obj: Gem::Version.new("1.2.0"), version: "1.2.0", sha: "777"}
      ]

      plan = dummy_cli.send(:determine_upgrade_plan, old_ref: "v1.2.0", repo_ref: "foo/bar", versions: prerelease_versions, upgrade_level: "major", client: client)

      expect(plan[:updates]).to be_nil
      expect(plan[:latest_outdated]).to be_nil
      expect(plan[:is_outdated]).to be(false)
    end

    it "does not treat a version-equivalent but unresolved ref as a valid release tag" do
      allow(client).to receive(:commit_sha).with("foo/bar", "1.2.3").and_return(nil)

      plan = dummy_cli.send(:determine_upgrade_plan, old_ref: "1.2.3", repo_ref: "foo/bar", versions: versions, upgrade_level: "patch", client: client)

      expect(plan[:updates]).to include(sha: "aaa", version: nil, reason: described_class::NON_SHA_REASON)
      expect(plan[:current_version]).to eq("1.2.3")
      expect(plan[:is_outdated]).to be(true)
    end
  end

  describe described_class::GitHubClient do
    it "follows GitHub API redirects for transferred action repositories" do
      client = described_class.new(token: nil, api_base: Kettle::Dev::GhaShaPinsCLI::API_BASE, user_agent: "kettle-gha-pins")
      redirect = instance_double(Net::HTTPMovedPermanently, code: "301")
      success = instance_double(Net::HTTPOK, code: "200", body: JSON.generate("ok" => true))
      first_http = instance_double(Net::HTTP)
      second_http = instance_double(Net::HTTP)
      allow(redirect).to receive(:[]).with("location").and_return("https://api.github.com/repositories/123/releases")
      [first_http, second_http].each do |http|
        allow(http).to receive(:use_ssl=).with(true)
        allow(http).to receive(:open_timeout=).with(Kettle::Dev::GhaShaPinsCLI::DEFAULT_HTTP_OPEN_TIMEOUT_SECONDS)
        allow(http).to receive(:read_timeout=).with(Kettle::Dev::GhaShaPinsCLI::DEFAULT_HTTP_READ_TIMEOUT_SECONDS)
        allow(http).to receive(:respond_to?).with(:ssl_timeout=).and_return(true)
        allow(http).to receive(:ssl_timeout=).with(Kettle::Dev::GhaShaPinsCLI::DEFAULT_HTTP_OPEN_TIMEOUT_SECONDS)
      end
      allow(first_http).to receive(:start).and_yield(first_http)
      allow(second_http).to receive(:start).and_yield(second_http)
      allow(first_http).to receive(:request).and_return(redirect)
      allow(second_http).to receive(:request).and_return(success)
      allow(Net::HTTP).to receive(:new).and_return(first_http, second_http)

      expect(client.send(:request_json, "/repos/old/action/releases")).to eq("ok" => true)
    end

    it "bounds live GitHub refreshes and falls back to stale cache on timeout", freeze: Time.utc(2026, 6, 8, 12, 0, 1) do
      cache_path = File.join(workflow_root, "gha-cache.json")
      Timecop.freeze(Time.utc(2026, 6, 7, 11, 59, 0)) do
        Kettle::Dev::GhaShaPinsCLI::PersistentActionCache.new(path: cache_path).write_versions(
          "foo/bar",
          [{tag: "v1.2.0", version_obj: Gem::Version.new("1.2.0"), version: "1.2.0", sha: "a" * 40}]
        )
      end
      client = described_class.new(
        token: nil,
        api_base: Kettle::Dev::GhaShaPinsCLI::API_BASE,
        user_agent: "kettle-gha-pins",
        persistent_cache: Kettle::Dev::GhaShaPinsCLI::PersistentActionCache.new(path: cache_path),
        open_timeout: 1,
        read_timeout: 2
      )
      http = instance_double(Net::HTTP)
      allow(http).to receive(:use_ssl=).with(true)
      allow(http).to receive(:open_timeout=).with(1)
      allow(http).to receive(:read_timeout=).with(2)
      allow(http).to receive(:respond_to?).with(:ssl_timeout=).and_return(true)
      allow(http).to receive(:ssl_timeout=).with(1)
      allow(http).to receive(:start).and_raise(Timeout::Error, "execution expired")
      allow(Net::HTTP).to receive(:new).with("api.github.com", 443).and_return(http)

      versions = client.versions_for_repo("foo/bar")

      expect(versions.map { |entry| entry[:version] }).to eq(["1.2.0"])
    end

    it "loads release tag SHAs through matching refs instead of resolving every release commit" do
      client = described_class.new(token: nil, api_base: Kettle::Dev::GhaShaPinsCLI::API_BASE, user_agent: "kettle-gha-pins")
      releases = [
        {"tag_name" => "v1.2.0", "prerelease" => false},
        {"tag_name" => "v1.3.0", "prerelease" => false}
      ]
      refs = [
        {"ref" => "refs/tags/v1.2.0", "object" => {"type" => "commit", "sha" => "a" * 40}},
        {"ref" => "refs/tags/v1.3.0", "object" => {"type" => "commit", "sha" => "b" * 40}}
      ]
      allow(client).to receive(:request_json).with("/repos/foo/bar/releases?per_page=100").and_return(releases)
      allow(client).to receive(:request_json).with("/repos/foo/bar/git/matching-refs/tags/").and_return(refs)
      expect(client).not_to receive(:commit_sha)

      versions = client.versions_for_repo("foo/bar")

      expect(versions.map { |entry| entry[:sha] }).to contain_exactly("a" * 40, "b" * 40)
    end

    it "includes version-like and major-line tags that do not have GitHub releases" do
      client = described_class.new(token: nil, api_base: Kettle::Dev::GhaShaPinsCLI::API_BASE, user_agent: "kettle-gha-pins")
      allow(client).to receive(:request_json).with("/repos/foo/bar/releases?per_page=100").and_return([
        {"tag_name" => "v1.0.0", "prerelease" => false}
      ])
      allow(client).to receive(:request_json).with("/repos/foo/bar/git/matching-refs/tags/").and_return([
        {"ref" => "refs/tags/v1.0.0", "object" => {"type" => "commit", "sha" => "a" * 40}},
        {"ref" => "refs/tags/v1.0.1", "object" => {"type" => "commit", "sha" => "b" * 40}},
        {"ref" => "refs/tags/v1", "object" => {"type" => "commit", "sha" => "c" * 40}},
        {"ref" => "refs/tags/v2", "object" => {"type" => "commit", "sha" => "d" * 40}}
      ])

      versions = client.versions_for_repo("foo/bar")

      expect(versions).to match([
        include(tag: "v2", version: "2", sha: "d" * 40),
        include(tag: "v1.0.1", version: "1.0.1", sha: "b" * 40),
        include(tag: "v1.0.0", version: "1.0.0", sha: "a" * 40),
        include(tag: "v1", version: "1", sha: "c" * 40)
      ])
    end

    it "canonicalizes equivalent release and major-line tags to the more explicit version spelling" do
      client = described_class.new(token: nil, api_base: Kettle::Dev::GhaShaPinsCLI::API_BASE, user_agent: "kettle-gha-pins")
      allow(client).to receive(:request_json).with("/repos/foo/bar/releases?per_page=100").and_return([
        {"tag_name" => "v7.0.0", "prerelease" => false}
      ])
      allow(client).to receive(:request_json).with("/repos/foo/bar/git/matching-refs/tags/").and_return([
        {"ref" => "refs/tags/v7", "object" => {"type" => "commit", "sha" => "a" * 40}},
        {"ref" => "refs/tags/v7.0.0", "object" => {"type" => "commit", "sha" => "a" * 40}}
      ])

      versions = client.versions_for_repo("foo/bar")

      expect(versions).to contain_exactly(
        include(tag: "v7.0.0", version: "7.0.0", sha: "a" * 40)
      )
    end

    it "prefers the concrete patch tag when a moving major-line tag points to the same SHA" do
      client = described_class.new(token: nil, api_base: Kettle::Dev::GhaShaPinsCLI::API_BASE, user_agent: "kettle-gha-pins")
      allow(client).to receive(:request_json).with("/repos/foo/bar/releases?per_page=100").and_return([
        {"tag_name" => "v7.0.0", "prerelease" => false},
        {"tag_name" => "v7.0.1", "prerelease" => false}
      ])
      allow(client).to receive(:request_json).with("/repos/foo/bar/git/matching-refs/tags/").and_return([
        {"ref" => "refs/tags/v7.0.0", "object" => {"type" => "commit", "sha" => "a" * 40}},
        {"ref" => "refs/tags/v7", "object" => {"type" => "commit", "sha" => "b" * 40}},
        {"ref" => "refs/tags/v7.0.1", "object" => {"type" => "commit", "sha" => "b" * 40}}
      ])

      versions = client.versions_for_repo("foo/bar")

      expect(versions).to match([
        include(tag: "v7.0.1", version: "7.0.1", sha: "b" * 40),
        include(tag: "v7.0.0", version: "7.0.0", sha: "a" * 40),
        include(tag: "v7", version: "7", sha: "b" * 40)
      ])
    end

    it "does not canonicalize equivalent version spellings when the tag SHA is unknown" do
      client = described_class.new(token: nil, api_base: Kettle::Dev::GhaShaPinsCLI::API_BASE, user_agent: "kettle-gha-pins")
      allow(client).to receive(:request_json).with("/repos/foo/bar/releases?per_page=100").and_return([
        {"tag_name" => "v7.0.0", "prerelease" => false}
      ])
      allow(client).to receive(:request_json).with("/repos/foo/bar/git/matching-refs/tags/").and_return([
        {"ref" => "refs/tags/v7", "object" => {"type" => "tag", "sha" => "a" * 40}},
        {"ref" => "refs/tags/v7.0.0", "object" => {"type" => "commit", "sha" => "b" * 40}}
      ])
      allow(client).to receive(:request_json).with("/repos/foo/bar/git/tags/#{"a" * 40}").and_return({})

      versions = client.versions_for_repo("foo/bar")

      expect(versions).to contain_exactly(
        include(tag: "v7", version: "7", sha: nil),
        include(tag: "v7.0.0", version: "7.0.0", sha: "b" * 40)
      )
    end

    it "resolves annotated tag commit targets while loading release versions" do
      client = described_class.new(token: nil, api_base: Kettle::Dev::GhaShaPinsCLI::API_BASE, user_agent: "kettle-gha-pins")
      allow(client).to receive(:request_json).with("/repos/foo/bar/releases?per_page=100").and_return([
        {"tag_name" => "v1.0.0", "prerelease" => false}
      ])
      allow(client).to receive(:request_json).with("/repos/foo/bar/git/matching-refs/tags/").and_return([
        {"ref" => "refs/tags/v1.0.0", "object" => {"type" => "tag", "sha" => "1" * 40}},
        {"ref" => "refs/tags/v1.0.1", "object" => {"type" => "tag", "sha" => "2" * 40}}
      ])
      allow(client).to receive(:request_json).with("/repos/foo/bar/git/tags/#{"1" * 40}").and_return(
        {"object" => {"type" => "commit", "sha" => "a" * 40}}
      )
      allow(client).to receive(:request_json).with("/repos/foo/bar/git/tags/#{"2" * 40}").and_return(
        {"object" => {"type" => "commit", "sha" => "b" * 40}}
      )

      versions = client.versions_for_repo("foo/bar")

      expect(versions.map { |entry| entry[:version] }).to eq(%w[1.0.1 1.0.0])
      expect(versions.map { |entry| entry[:sha] }).to eq(["b" * 40, "a" * 40])
    end

    it "does not dereference annotated tags that cannot be action release versions" do
      client = described_class.new(token: nil, api_base: Kettle::Dev::GhaShaPinsCLI::API_BASE, user_agent: "kettle-gha-pins")
      allow(client).to receive(:request_json).with("/repos/foo/bar/releases?per_page=100").and_return([
        {"tag_name" => "v1.0.0", "prerelease" => false}
      ])
      allow(client).to receive(:request_json).with("/repos/foo/bar/git/matching-refs/tags/").and_return([
        {"ref" => "refs/tags/v1.0.0", "object" => {"type" => "commit", "sha" => "a" * 40}},
        {"ref" => "refs/tags/codeql-bundle-v2.25.6", "object" => {"type" => "tag", "sha" => "1" * 40}}
      ])
      expect(client).not_to receive(:request_json).with("/repos/foo/bar/git/tags/#{"1" * 40}")

      versions = client.versions_for_repo("foo/bar")

      expect(versions.map { |entry| entry[:version] }).to eq(["1.0.0"])
      expect(versions.map { |entry| entry[:sha] }).to eq(["a" * 40])
    end

    it "includes prerelease tags so existing prerelease pins are not downgraded" do
      client = described_class.new(token: nil, api_base: Kettle::Dev::GhaShaPinsCLI::API_BASE, user_agent: "kettle-gha-pins")
      allow(client).to receive(:request_json).with("/repos/foo/bar/releases?per_page=100").and_return([
        {"tag_name" => "v2.3.7", "prerelease" => true},
        {"tag_name" => "v2.3.6", "prerelease" => false}
      ])
      allow(client).to receive(:request_json).with("/repos/foo/bar/git/matching-refs/tags/").and_return([
        {"ref" => "refs/tags/v2.3.7", "object" => {"type" => "commit", "sha" => "b" * 40}},
        {"ref" => "refs/tags/v2.3.6", "object" => {"type" => "commit", "sha" => "a" * 40}}
      ])

      versions = client.versions_for_repo("foo/bar")

      expect(versions.map { |entry| entry[:version] }).to eq(%w[2.3.7 2.3.6])
      expect(versions.map { |entry| entry[:sha] }).to eq(["b" * 40, "a" * 40])
    end

    it "uses fresh persistent cache entries after the latest-release probe", freeze: Time.utc(2026, 6, 8, 12, 0, 0) do
      cache = Kettle::Dev::GhaShaPinsCLI::PersistentActionCache.new(
        path: File.join(workflow_root, "gha-cache.json")
      )
      cache.write_versions(
        "foo/bar",
        [
          {tag: "v1.2.3", version_obj: Gem::Version.new("1.2.3"), version: "1.2.3", sha: "a" * 40},
          {tag: "v1.3.0", version_obj: Gem::Version.new("1.3.0"), version: "1.3.0", sha: "b" * 40},
          {tag: "v2.0.0", version_obj: Gem::Version.new("2.0.0"), version: "2.0.0", sha: "c" * 40}
        ]
      )
      client = described_class.new(
        token: nil,
        api_base: Kettle::Dev::GhaShaPinsCLI::API_BASE,
        user_agent: "kettle-gha-pins",
        persistent_cache: cache
      )
      allow(client).to receive(:request_json).with("/repos/foo/bar/releases/latest").and_return({})

      versions = client.versions_for_repo("foo/bar")

      expect(versions.map { |entry| entry[:version] }).to eq(%w[2.0.0 1.3.0 1.2.3])
    end

    it "bypasses fresh cache when refreshing and preserves unrelated cached actions", freeze: Time.utc(2026, 6, 8, 12, 5, 0) do
      cache_path = File.join(workflow_root, "gha-cache.json")
      cache = Kettle::Dev::GhaShaPinsCLI::PersistentActionCache.new(path: cache_path)
      cache.write_versions(
        "other/action",
        [{tag: "v9.0.0", version_obj: Gem::Version.new("9.0.0"), version: "9.0.0", sha: "9" * 40}]
      )
      cache.write_versions(
        "foo/bar",
        [{tag: "v1.2.0", version_obj: Gem::Version.new("1.2.0"), version: "1.2.0", sha: "a" * 40}]
      )
      client = described_class.new(
        token: nil,
        api_base: Kettle::Dev::GhaShaPinsCLI::API_BASE,
        user_agent: "kettle-gha-pins",
        persistent_cache: Kettle::Dev::GhaShaPinsCLI::PersistentActionCache.new(path: cache_path),
        refresh_cache: true
      )
      allow(client).to receive(:request_json).with("/repos/foo/bar/releases?per_page=100").and_return([
        {"tag_name" => "v1.2.3", "prerelease" => false},
        {"tag_name" => "v1.3.0", "prerelease" => false},
        {"tag_name" => "v2.0.0", "prerelease" => false}
      ])
      allow(client).to receive(:request_json).with("/repos/foo/bar/git/matching-refs/tags/").and_return([
        {"ref" => "refs/tags/v1.2.3", "object" => {"type" => "commit", "sha" => "b" * 40}},
        {"ref" => "refs/tags/v1.3.0", "object" => {"type" => "commit", "sha" => "c" * 40}},
        {"ref" => "refs/tags/v2.0.0", "object" => {"type" => "commit", "sha" => "d" * 40}}
      ])

      versions = client.versions_for_repo("foo/bar")
      cached = JSON.parse(File.read(cache_path))

      expect(versions.map { |entry| entry[:version] }).to eq(%w[2.0.0 1.3.0 1.2.3])
      expect(cached.fetch("actions")).to include("other/action")
      expect(cached.dig("actions", "foo/bar", "versions")).not_to include("1.2.0")
      expect(cached.dig("actions", "foo/bar", "versions")).to include("1.2.3", "1.3.0", "2.0.0")
      expect(cached.dig("actions", "foo/bar", "targets", "patch", "1.2", "version")).to eq("1.2.3")
      expect(cached.dig("actions", "foo/bar", "targets", "minor", "1", "version")).to eq("1.3.0")
      expect(cached.dig("actions", "foo/bar", "targets", "major", "*", "version")).to eq("2.0.0")
    end

    it "caches major-line tags as major-only targets", freeze: Time.utc(2026, 6, 8, 12, 5, 0) do
      cache_path = File.join(workflow_root, "gha-cache.json")
      client = described_class.new(
        token: nil,
        api_base: Kettle::Dev::GhaShaPinsCLI::API_BASE,
        user_agent: "kettle-gha-pins",
        persistent_cache: Kettle::Dev::GhaShaPinsCLI::PersistentActionCache.new(path: cache_path)
      )
      allow(client).to receive(:request_json).with("/repos/foo/bar/releases?per_page=100").and_return([
        {"tag_name" => "v2", "prerelease" => false}
      ])
      allow(client).to receive(:request_json).with("/repos/foo/bar/git/matching-refs/tags/").and_return([
        {"ref" => "refs/tags/v2", "object" => {"type" => "commit", "sha" => "b" * 40}}
      ])

      versions = client.versions_for_repo("foo/bar")
      cached = JSON.parse(File.read(cache_path))

      expect(versions.map { |entry| entry[:version] }).to eq(["2"])
      expect(cached.dig("actions", "foo/bar", "versions")).to include("2")
      expect(cached.dig("actions", "foo/bar", "targets", "patch")).to eq({})
      expect(cached.dig("actions", "foo/bar", "targets", "minor")).to eq({})
      expect(cached.dig("actions", "foo/bar", "targets", "major", "*", "version")).to eq("2")
    end

    it "ignores persistent cache entries from older schemas", freeze: Time.utc(2026, 6, 8, 12, 5, 0) do
      cache_path = File.join(workflow_root, "gha-cache.json")
      File.write(
        cache_path,
        JSON.pretty_generate(
          "version" => Kettle::Dev::GhaShaPinsCLI::PersistentActionCache::VERSION - 1,
          "actions" => {
            "foo/bar" => {
              "versions" => {
                "1.0.0" => {
                  "tag" => "v1.0.0",
                  "version" => "1.0.0",
                  "sha" => "a" * 40,
                  "cached_at" => "2026-06-08T12:00:00Z"
                }
              }
            }
          }
        )
      )
      client = described_class.new(
        token: nil,
        api_base: Kettle::Dev::GhaShaPinsCLI::API_BASE,
        user_agent: "kettle-gha-pins",
        persistent_cache: Kettle::Dev::GhaShaPinsCLI::PersistentActionCache.new(path: cache_path)
      )
      allow(client).to receive(:request_json).with("/repos/foo/bar/releases?per_page=100").and_return([
        {"tag_name" => "v1.0.1", "prerelease" => false}
      ])
      allow(client).to receive(:request_json).with("/repos/foo/bar/git/matching-refs/tags/").and_return([
        {"ref" => "refs/tags/v1.0.1", "object" => {"type" => "commit", "sha" => "b" * 40}}
      ])

      versions = client.versions_for_repo("foo/bar")

      expect(versions.map { |entry| entry[:version] }).to eq(["1.0.1"])
    end

    it "refreshes stale persistent cache entries after the TTL", freeze: Time.utc(2026, 6, 8, 12, 0, 1) do
      cache_path = File.join(workflow_root, "gha-cache.json")
      Timecop.freeze(Time.utc(2026, 6, 7, 11, 59, 0)) do
        Kettle::Dev::GhaShaPinsCLI::PersistentActionCache.new(path: cache_path).write_versions(
          "foo/bar",
          [{tag: "v1.2.0", version_obj: Gem::Version.new("1.2.0"), version: "1.2.0", sha: "a" * 40}]
        )
      end
      client = described_class.new(
        token: nil,
        api_base: Kettle::Dev::GhaShaPinsCLI::API_BASE,
        user_agent: "kettle-gha-pins",
        persistent_cache: Kettle::Dev::GhaShaPinsCLI::PersistentActionCache.new(path: cache_path)
      )
      allow(client).to receive(:request_json).with("/repos/foo/bar/releases?per_page=100").and_return([
        {"tag_name" => "v1.2.1", "prerelease" => false}
      ])
      allow(client).to receive(:request_json).with("/repos/foo/bar/git/matching-refs/tags/").and_return([
        {"ref" => "refs/tags/v1.2.1", "object" => {"type" => "commit", "sha" => "b" * 40}}
      ])

      versions = client.versions_for_repo("foo/bar")

      expect(versions.map { |entry| entry[:version] }).to eq(["1.2.1"])
    end

    it "persists live commit SHA lookups for reuse by the next client run", freeze: Time.utc(2026, 6, 8, 12, 0, 0) do
      cache_path = File.join(workflow_root, "gha-cache.json")
      cache = Kettle::Dev::GhaShaPinsCLI::PersistentActionCache.new(path: cache_path)
      first_client = described_class.new(
        token: nil,
        api_base: Kettle::Dev::GhaShaPinsCLI::API_BASE,
        user_agent: "kettle-gha-pins",
        persistent_cache: cache
      )
      allow(first_client).to receive(:request_json).with("/repos/foo/bar/commits/v1.2.3").and_return({"sha" => "a" * 40})

      expect(first_client.commit_sha("foo/bar", "v1.2.3")).to eq("a" * 40)

      second_client = described_class.new(
        token: nil,
        api_base: Kettle::Dev::GhaShaPinsCLI::API_BASE,
        user_agent: "kettle-gha-pins",
        persistent_cache: Kettle::Dev::GhaShaPinsCLI::PersistentActionCache.new(path: cache_path)
      )
      expect(second_client).not_to receive(:request_json)

      expect(second_client.commit_sha("foo/bar", "v1.2.3")).to eq("a" * 40)
      expect(JSON.parse(File.read(cache_path)).dig("actions", "foo/bar", "refs", "v1.2.3", "sha")).to eq("a" * 40)
    end
  end

  describe "run! output" do
    let(:client_versions) do
      [
        {
          tag: "v1.3.0",
          version_obj: Gem::Version.new("1.3.0"),
          version: "1.3.0",
          sha: "bbb"
        },
        {
          tag: "v2.0.0",
          version_obj: Gem::Version.new("2.0.0"),
          version: "2.0.0",
          sha: "ccc"
        },
        {
          tag: "v1.2.0",
          version_obj: Gem::Version.new("1.2.0"),
          version: "1.2.0",
          sha: "aaa"
        }
      ]
    end

    before do
      stub_github_client(
        versions: client_versions,
        commit_shas: {
          "v1.2.0" => "aaa",
          "v1.3.0" => "bbb",
          "v2.0.0" => "ccc"
        }
      )
    end

    it "emits JSON report with outdated_pins and version-equivalent values" do
      cli = described_class.new(["--root", workflow_root, "--upgrade", "minor", "--json"])

      payload = nil
      expect do
        cli.run!
      end.to output(satisfy { |stdout|
        payload = JSON.parse(stdout)
      }).to_stdout

      expect(payload.fetch("outdated_pins")).to contain_exactly(
        a_hash_including(
          "path" => File.realpath(workflow_path),
          "line" => 7,
          "action" => "foo/bar",
          "old_ref" => "v1.2.0",
          "old_version" => "1.2.0",
          "new_ref" => "ccc",
          "new_version" => "2.0.0",
          "upgrade_level" => "minor",
          "reason" => described_class::UPGRADE_REASON
        )
      )
      expect(payload.fetch("planned_changes").first["old_version"]).to eq("1.2.0")
      expect(payload.fetch("planned_changes").first["new_version"]).to eq("1.3.0")
    end

    it "emits human text report with version-equivalent outdated pins summary" do
      cli = described_class.new(["--root", workflow_root, "--upgrade", "minor"])

      expect do
        cli.run!
      end.to output(
        %r{Outdated actions \(1\):\nAction Current Latest Location Reason\nfoo/bar 1\.2\.0 1\.3\.0 #{Regexp.escape(File.realpath(workflow_path))}:\d+ #{Regexp.escape(described_class::UPGRADE_REASON)}}
      ).to_stdout
    end

    it "fails in check mode and recommends the write command when updates are needed" do
      cli = described_class.new(["--root", workflow_root, "--upgrade", "minor", "--check"])

      expect do
        expect(cli.run!).to eq(3)
      end.to output(/Outdated actions \(1\):.*Recommended fix: kettle-gha-pins --write --upgrade minor/m).to_stdout
    end

    it "does not fail check mode for broader outdated pins outside the selected upgrade level" do
      cli = described_class.new(["--root", workflow_root, "--upgrade", "patch", "--check"])

      expect do
        expect(cli.run!).to eq(0)
      end.to output(
        /Outdated pins \(1\):.*Outdated actions: none.*No change candidates found\./m
      ).to_stdout
    end

    it "rewrites unresolved version-equivalent refs to release SHAs instead of stripped tag names" do
      File.write(
        workflow_path,
        <<~YAML
          name: ci
          on: [push]
          jobs:
            test:
              runs-on: ubuntu-latest
              steps:
                - uses: foo/bar@1.2.0 # v1.2.0
        YAML
      )
      cli_client = instance_double(described_class::GitHubClient)
      allow(described_class::GitHubClient).to receive(:new).and_return(cli_client)
      allow(cli_client).to receive(:versions_for_repo).with("foo/bar").and_return(client_versions)
      allow(cli_client).to receive(:commit_sha).with("foo/bar", "1.2.0").and_return(nil)

      cli = described_class.new(["--root", workflow_root, "--upgrade", "patch", "--write"])
      cli.run!

      expect(File.read(workflow_path)).to include("uses: foo/bar@aaa # v1.2.0")
      expect(File.read(workflow_path)).not_to include("foo/bar@1.2.0")
    end

    it "updates adjacent version comments when upgrading to a newer release SHA" do
      File.write(
        workflow_path,
        <<~YAML
          name: ci
          on: [push]
          jobs:
            test:
              runs-on: ubuntu-latest
              steps:
                - uses: foo/bar@aaa # v1.2.0
        YAML
      )
      cli_client = instance_double(described_class::GitHubClient)
      allow(described_class::GitHubClient).to receive(:new).and_return(cli_client)
      allow(cli_client).to receive(:versions_for_repo).with("foo/bar").and_return(client_versions)
      allow(cli_client).to receive(:commit_sha).with("foo/bar", "aaa").and_return("aaa")

      cli = described_class.new(["--root", workflow_root, "--upgrade", "minor", "--write"])
      cli.run!

      expect(File.read(workflow_path)).to include("uses: foo/bar@bbb # v1.3.0")
      expect(File.read(workflow_path)).not_to include("# v1.2.0")
    end

    it "updates stale version comments even when the SHA is already current" do
      File.write(
        workflow_path,
        <<~YAML
          name: ci
          on: [push]
          jobs:
            test:
              runs-on: ubuntu-latest
              steps:
                - uses: foo/bar@bbb # v1.2.0
        YAML
      )
      cli_client = instance_double(described_class::GitHubClient)
      allow(described_class::GitHubClient).to receive(:new).and_return(cli_client)
      allow(cli_client).to receive(:versions_for_repo).with("foo/bar").and_return(client_versions)
      allow(cli_client).to receive(:commit_sha).with("foo/bar", "bbb").and_return("bbb")

      cli = described_class.new(["--root", workflow_root, "--upgrade", "minor", "--write"])
      cli.run!

      expect(File.read(workflow_path)).to include("uses: foo/bar@bbb # v1.3.0")
      expect(File.read(workflow_path)).not_to include("# v1.2.0")
    end

    it "updates major-line version comments to the canonical explicit equivalent once and stays clean" do
      File.write(
        workflow_path,
        <<~YAML
          name: ci
          on: [push]
          jobs:
            test:
              runs-on: ubuntu-latest
              steps:
                - uses: foo/bar@bbb # v7.0.0
        YAML
      )
      cli_client = instance_double(described_class::GitHubClient)
      allow(described_class::GitHubClient).to receive(:new).and_return(cli_client)
      allow(cli_client).to receive(:versions_for_repo).with("foo/bar").and_return([
        {tag: "v7.0.0", version_obj: Gem::Version.new("7.0.0"), version: "7.0.0", sha: "bbb"}
      ])
      allow(cli_client).to receive(:commit_sha).with("foo/bar", "bbb").and_return("bbb")

      first_run = described_class.new(["--root", workflow_root, "--upgrade", "major", "--write"])
      second_run = described_class.new(["--root", workflow_root, "--upgrade", "major", "--check"])

      expect(first_run.run!).to eq(0)
      expect(File.read(workflow_path)).to include("uses: foo/bar@bbb # v7.0.0")
      expect(second_run.run!).to eq(0)
    end

    it "updates shorthand major-line version comments to the canonical explicit equivalent" do
      File.write(
        workflow_path,
        <<~YAML
          name: ci
          on: [push]
          jobs:
            test:
              runs-on: ubuntu-latest
              steps:
                - uses: foo/bar@bbb # v7
        YAML
      )
      cli_client = instance_double(described_class::GitHubClient)
      allow(described_class::GitHubClient).to receive(:new).and_return(cli_client)
      allow(cli_client).to receive(:versions_for_repo).with("foo/bar").and_return([
        {tag: "v7.0.0", version_obj: Gem::Version.new("7.0.0"), version: "7.0.0", sha: "bbb"}
      ])
      allow(cli_client).to receive(:commit_sha).with("foo/bar", "bbb").and_return("bbb")

      cli = described_class.new(["--root", workflow_root, "--upgrade", "major", "--write"])

      expect(cli.run!).to eq(0)
      expect(File.read(workflow_path)).to include("uses: foo/bar@bbb # v7.0.0")
      expect(File.read(workflow_path)).not_to include("# v7\n")
    end

    it "calls GitHub release-version lookup for each workflow action when evaluating pins" do
      cli_client = instance_double(described_class::GitHubClient)
      allow(described_class::GitHubClient).to receive(:new).and_return(cli_client)
      allow(cli_client).to receive(:versions_for_repo).with("foo/bar").and_return(client_versions)
      allow(cli_client).to receive(:commit_sha).and_return("aaa")

      cli = described_class.new(["--root", workflow_root, "--upgrade", "minor"])
      cli.run!

      expect(cli_client).to have_received(:versions_for_repo).with("foo/bar")
    end

    it "reuses one resolution plan for duplicate action repos" do
      File.write(
        workflow_path,
        <<~YAML
          name: ci
          on: [push]
          jobs:
            test:
              runs-on: ubuntu-latest
              steps:
                - uses: foo/bar@v1.2.0
                - uses: foo/bar@v1.2.0
        YAML
      )
      cli_client = instance_double(described_class::GitHubClient)
      allow(described_class::GitHubClient).to receive(:new).and_return(cli_client)
      expect(cli_client).to receive(:versions_for_repo).with("foo/bar").once.and_return(client_versions)
      allow(cli_client).to receive(:commit_sha).and_return("aaa")

      cli = described_class.new(["--root", workflow_root, "--upgrade", "minor"])
      cli.run!
    end

    it "emits progress feedback to stderr for human output" do
      err = StringIO.new
      cli = described_class.new(["--root", workflow_root, "--upgrade", "minor", "--no-progress"], err: err)
      expect(cli.run!).to eq(0)
      expect(err.string).to eq("")

      err = StringIO.new
      cli = described_class.new(["--root", workflow_root, "--upgrade", "minor"], err: err)
      cli.run!

      expect(err.string).to include("Discovering workflow files")
      expect(err.string).to include("Discovered 1 workflow file")
      expect(err.string).to include("Resolving 1 GitHub action reference")
      expect(err.string).to include("Action resolution checks: 0 cached, 1 live.")
      expect(err.string).not_to include("Resolved foo/bar@v1.2.0 in")
    end

    it "keeps progress disabled by default for JSON output" do
      err = StringIO.new
      cli = described_class.new(["--root", workflow_root, "--upgrade", "minor", "--json"], err: err)

      cli.run!

      expect(err.string).to eq("")
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles, RSpec/MessageSpies, ThreadSafety/ClassInstanceVariable
