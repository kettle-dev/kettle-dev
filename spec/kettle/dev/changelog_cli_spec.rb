# frozen_string_literal: true

require "json"

RSpec.describe Kettle::Dev::ChangelogCLI, :check_output do
  include_context "with mocked git adapter"
  include_context "with mocked exit adapter"

  before do
    allow(Kettle::Dev::InputAdapter).to receive(:gets).and_return("y\n")
    allow(described_class).to receive(:new).and_wrap_original do |original, *args, **kwargs, &block|
      cli = original.call(*args, **kwargs, &block)
      allow(cli).to receive_messages(
        detect_gem_name: "demo",
        latest_released_versions: [nil, nil]
      )
      cli
    end
  end

  def mkproj
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, "lib", "my", "gem"))
      File.write(File.join(root, "demo.gemspec"), <<~RB)
        Gem::Specification.new do |spec|
          spec.name = "demo"
          spec.version = "1.2.3"
        end
      RB
      yield root
    end
  end

  def write_version(root, version = "1.2.3")
    File.write(File.join(root, "lib", "my", "gem", "version.rb"), <<~RB)
      module My; module Gem; VERSION = "#{version}"; end; end
    RB
  end

  def git!(root, *args)
    system("git", *args, chdir: root, out: File::NULL, err: File::NULL) || raise("git #{args.join(" ")} failed")
  end

  describe "#release_state" do
    it "reports latest release data even when the Unreleased section has entries" do
      mkproj do |root|
        write_version(root)
        File.write(File.join(root, "CHANGELOG.md"), <<~MD)
          # Changelog

          ## [Unreleased]

          ### Fixed

          - Fixed a bug.

          ## [1.2.3] - 2025-08-30
        MD
        allow(Kettle::Dev::CIHelpers).to receive(:project_root).and_return(root)

        cli = described_class.new(strict: false)
        allow(cli).to receive(:latest_released_versions).and_return(["1.2.3", "1.2.3"])
        status = cli.pending_release_status

        expect(status).to include(
          gem_name: "demo",
          version: "1.2.3",
          pending: true,
          pending_release: true,
          unreleased_entries: true,
          prepared_release_pending: false,
          latest_released: "1.2.3",
          latest_changelog_version: "1.2.3"
        )
      end
    end

    it "reports commits ahead of the latest release tag on the default branch", :real_git_adapter do
      mkproj do |root|
        write_version(root)
        File.write(File.join(root, "CHANGELOG.md"), <<~MD)
          # Changelog

          ## [Unreleased]

          ### Fixed

          - Fixed a bug.

          ## [1.2.3] - 2025-08-30
        MD
        git!(root, "init", "-q")
        git!(root, "checkout", "-q", "-b", "main")
        git!(root, "config", "user.email", "test@example.com")
        git!(root, "config", "user.name", "Test User")
        git!(root, "config", "commit.gpgSign", "false")
        git!(root, "config", "tag.gpgSign", "false")
        git!(root, "add", ".")
        git!(root, "commit", "-q", "-m", "release")
        git!(root, "tag", "v1.2.3")
        File.write(File.join(root, "one.txt"), "one\n")
        git!(root, "add", ".")
        git!(root, "commit", "-q", "-m", "one")
        File.write(File.join(root, "two.txt"), "two\n")
        git!(root, "add", ".")
        git!(root, "commit", "-q", "-m", "two")
        allow(Kettle::Dev::CIHelpers).to receive(:project_root).and_return(root)

        cli = described_class.new(strict: false)
        allow(cli).to receive(:latest_released_versions).and_return(["1.2.3", "1.2.3"])
        status = cli.release_state

        expect(status).to include(ahead: 2)
      end
    end

    it "aborts with a family-root hint when CHANGELOG.md is missing from a family root" do
      mkproj do |root|
        FileUtils.rm_rf(File.join(root, "lib"))
        FileUtils.rm_f(File.join(root, "demo.gemspec"))
        File.write(File.join(root, "Gemfile"), %(gem "kettle-family"\n))
        FileUtils.mkdir_p(File.join(root, "demo"))
        File.write(File.join(root, "demo", "demo.gemspec"), "Gem::Specification.new { |spec| spec.name = \"demo\"; spec.version = \"1.0.0\" }\n")
        allow(Kettle::Dev::CIHelpers).to receive(:project_root).and_return(root)

        cli = described_class.new(strict: false)

        expect { cli.release_state }.to raise_error(MockSystemExit, /kettle-family release-state/)
      end
    end

    it "reports no pending changelog work when an individual gem has no changelog" do
      mkproj do |root|
        write_version(root)
        FileUtils.rm_f(File.join(root, "CHANGELOG.md"))
        allow(Kettle::Dev::CIHelpers).to receive(:project_root).and_return(root)

        cli = described_class.new(strict: false)
        allow(cli).to receive(:latest_released_versions).and_return(["1.2.3", "1.2.3"])
        status = cli.release_state

        expect(status).to include(
          gem_name: "demo",
          version: "1.2.3",
          changelog_present: false,
          pending: false,
          pending_release: false,
          unreleased_entries: false,
          prepared_release_pending: false,
          latest_changelog_version: nil,
          latest_released: "1.2.3",
          latest_release_target: "1.2.3"
        )
      end
    end

    it "reports pending when the latest changelog release section has not been published" do
      mkproj do |root|
        write_version(root)
        File.write(File.join(root, "CHANGELOG.md"), <<~MD)
          # Changelog

          ## [Unreleased]

          ### Added
          ### Changed
          ### Deprecated
          ### Removed
          ### Fixed
          ### Security

          ## [1.2.4] - 2025-08-31

          ### Fixed

          - Prepared release notes.

          ## [1.2.3] - 2025-08-30
        MD
        allow(Kettle::Dev::CIHelpers).to receive(:project_root).and_return(root)

        cli = described_class.new(strict: false)
        allow(cli).to receive(:latest_released_versions).and_return(["1.2.3", "1.2.3"])
        status = cli.pending_release_status

        expect(status).to include(
          pending: true,
          unreleased_entries: false,
          prepared_release_pending: true,
          latest_changelog_version: "1.2.4",
          latest_release_target: "1.2.3"
        )
      end
    end

    it "reports the latest released version for the current major on branch-stacked gems" do
      mkproj do |root|
        write_version(root, "0.3.0")
        File.write(File.join(root, "CHANGELOG.md"), <<~MD)
          # Changelog

          ## [Unreleased]

          ### Fixed

          - Fixed a bug.

          ## [0.3.0] - 2026-06-24
        MD
        allow(Kettle::Dev::CIHelpers).to receive(:project_root).and_return(root)

        cli = described_class.new(strict: false)
        allow(cli).to receive(:latest_released_versions).and_return(["24.2.0", "0.3.0", "0.3.0"])
        status = cli.pending_release_status

        expect(status).to include(
          latest_released: "0.3.0",
          latest_released_overall: "24.2.0",
          latest_released_for_current_major: "0.3.0",
          latest_release_target: "0.3.0"
        )
      end
    end

    it "treats prerelease sections as the latest changelog release section" do
      mkproj do |root|
        write_version(root, "3.0.0.rc3")
        File.write(File.join(root, "CHANGELOG.md"), <<~MD)
          # Changelog

          ## [Unreleased]

          ### Added
          ### Changed
          ### Deprecated
          ### Removed
          ### Fixed
          ### Security

          ## [3.0.0.rc3] - 2026-06-21

          ### Fixed

          - Prepared prerelease notes.

          ## [2.0.2] - 2026-06-20
        MD
        allow(Kettle::Dev::CIHelpers).to receive(:project_root).and_return(root)

        cli = described_class.new(strict: false)
        allow(cli).to receive(:latest_released_versions).and_return(["2.0.2", "2.0.2"])
        status = cli.pending_release_status

        expect(status).to include(
          pending: true,
          unreleased_entries: false,
          prepared_release_pending: true,
          latest_changelog_version: "3.0.0.rc3",
          latest_release_target: "2.0.2"
        )
      end
    end

    it "reports not pending when Unreleased is empty and the latest changelog release is published" do
      mkproj do |root|
        write_version(root)
        File.write(File.join(root, "CHANGELOG.md"), <<~MD)
          # Changelog

          ## [Unreleased]

          ### Added
          ### Changed
          ### Deprecated
          ### Removed
          ### Fixed
          ### Security

          ## [1.2.3] - 2025-08-30
        MD
        allow(Kettle::Dev::CIHelpers).to receive(:project_root).and_return(root)

        cli = described_class.new(strict: false)
        allow(cli).to receive(:latest_released_versions).and_return(["1.2.3", "1.2.3"])
        status = cli.pending_release_status

        expect(status).to include(
          pending: false,
          unreleased_entries: false,
          prepared_release_pending: false,
          latest_changelog_version: "1.2.3",
          latest_release_target: "1.2.3"
        )
      end
    end

    it "passes refresh-cache through to RubyGems.org version lookup" do
      allow(described_class).to receive(:new).and_call_original
      cli = described_class.new(strict: false, refresh_cache: true)
      allow(Kettle::Dev::RubyGemsVersions).to receive(:fetch).with("demo", version_hint: "1.2.3", refresh: true).and_return([{"number" => "1.2.3"}])

      latest_overall, latest_series, latest_major = cli.send(:latest_released_versions, "demo", "1.2.3")

      expect([latest_overall, latest_series, latest_major]).to eq(["1.2.3", "1.2.3", "1.2.3"])
    end

    it "formats release state as a single-gem table" do
      cli = described_class.new(strict: false)
      table = cli.release_state_table(
        gem_name: "demo",
        version: "1.2.4",
        latest_released: "1.2.3",
        latest_changelog_version: "1.2.4",
        unreleased_entries: false,
        prepared_release_pending: true,
        pending_release: true,
        ahead: 4
      )

      expect(table).to include("gem")
      expect(table).to include("ahead")
      expect(table).to include("latest released")
      expect(table).to include("demo")
      expect(table).to include("1.2.3")
      expect(table).to include("4")
      expect(table).to include("yes")
    end
  end

  describe "#pending_release_status" do
    it "delegates to release_state for backward-compatible pending queries" do
      cli = described_class.new(strict: false)
      state = {pending_release: true, pending: true}

      allow(cli).to receive(:release_state).and_return(state)

      expect(cli.pending_release_status).to eq(state)
    end
  end

  describe "K_CHANGELOG_PATH" do
    it "reads changelog state from an explicit shared changelog path" do
      mkproj do |root|
        write_version(root)
        shared_root = File.join(root, "family")
        FileUtils.mkdir_p(shared_root)
        shared_changelog = File.join(shared_root, "CHANGELOG.md")
        File.write(shared_changelog, <<~MD)
          # Changelog

          ## [Unreleased]

          ### Fixed

          - Fixed a shared release bug.

          ## [1.2.3] - 2025-08-30
        MD
        FileUtils.mkdir_p(File.join(root, "coverage"))
        File.write(File.join(root, "coverage", "coverage.json"), {"coverage" => {}}.to_json)
        allow(Kettle::Dev::CIHelpers).to receive(:project_root).and_return(root)
        stub_env("K_CHANGELOG_PATH" => shared_changelog)

        cli = described_class.new(strict: false)
        allow(cli).to receive(:latest_released_versions).and_return(["1.2.3", "1.2.3"])

        expect(cli.release_state).to include(
          pending_release: true,
          latest_changelog_version: "1.2.3"
        )
      end
    end

    it "resolves relative shared changelog paths from the execution root" do
      mkproj do |root|
        write_version(root)
        shared_changelog = File.join(root, "family", "CHANGELOG.md")
        FileUtils.mkdir_p(File.dirname(shared_changelog))
        File.write(shared_changelog, <<~MD)
          # Changelog

          ## [Unreleased]

          ## [1.2.3] - 2025-08-30
        MD
        allow(Kettle::Dev::CIHelpers).to receive(:project_root).and_return(root)
        stub_env("K_CHANGELOG_PATH" => "family/CHANGELOG.md")

        cli = described_class.new(strict: false)
        allow(cli).to receive(:latest_released_versions).and_return(["1.2.3", "1.2.3"])

        expect(cli.release_state).to include(latest_changelog_version: "1.2.3")
      end
    end
  end

  describe "#detect_gem_name" do
    it "uses K_CHANGELOG_GEM_NAME before root gemspec discovery" do
      mkproj do |root|
        FileUtils.rm_f(File.join(root, "demo.gemspec"))
        allow(Kettle::Dev::CIHelpers).to receive(:project_root).and_return(root)
        stub_env("K_CHANGELOG_GEM_NAME" => "structuredmerge-ruby")

        cli = described_class.new(strict: false)
        allow(cli).to receive(:detect_gem_name).and_call_original

        expect(cli.send(:detect_gem_name)).to eq("structuredmerge-ruby")
      end
    end
  end

  describe "#run warnings and aborts" do
    it "warns when owner/repo cannot be determined and Unreleased is empty", freeze: Time.new(2025, 8, 31) do
      mkproj do |root|
        # version.rb
        File.write(File.join(root, "lib", "my", "gem", "version.rb"), <<~RB)
          module My; module Gem; VERSION = "1.2.3"; end; end
        RB
        # coverage present but empty content acceptable
        FileUtils.mkdir_p(File.join(root, "coverage"))
        File.write(File.join(root, "coverage", "coverage.json"), {"coverage" => {}}.to_json)
        # Minimal changelog with empty Unreleased
        File.write(File.join(root, "CHANGELOG.md"), <<~MD)
          # Changelog
          ## [Unreleased]
          ### Added
          ### Changed
          ### Deprecated
          ### Removed
          ### Fixed
          ### Security

          ## [0.9.9] - 2020-01-01
        MD
        allow(Kettle::Dev::CIHelpers).to receive_messages(project_root: root, repo_info: [nil, nil])
        cli = described_class.new(strict: false)
        expect { cli.run }.not_to raise_error
        updated = File.read(File.join(root, "CHANGELOG.md"))
        expect(updated).to include("## [1.2.3] - 2025-08-31")
      end
    end

    it "prompts and aborts when the selected plan is declined" do
      mkproj do |root|
        File.write(File.join(root, "lib", "my", "gem", "version.rb"), <<~RB)
          module My; module Gem; VERSION = "1.2.3"; end; end
        RB
        FileUtils.mkdir_p(File.join(root, "coverage"))
        File.write(File.join(root, "coverage", "coverage.json"), {"coverage" => {}}.to_json)
        # Duplicate section already exists
        File.write(File.join(root, "CHANGELOG.md"), <<~MD)
          # Changelog
          ## [Unreleased]

          ## [1.2.3] - 2025-08-30
        MD
        allow(Kettle::Dev::CIHelpers).to receive_messages(project_root: root, repo_info: ["o", "r"])
        allow(Kettle::Dev::InputAdapter).to receive(:gets).and_return("n\n")
        cli = described_class.new(strict: false)
        allow(cli).to receive(:latest_released_versions).and_return(["1.2.3", "1.2.3"])
        expect { cli.run }.to raise_error(MockSystemExit, /changelog plan was not confirmed/)
      end
    end

    it "auto-approves the selected plan when yes mode is enabled" do
      mkproj do |root|
        File.write(File.join(root, "lib", "my", "gem", "version.rb"), <<~RB)
          module My; module Gem; VERSION = "1.2.3"; end; end
        RB
        FileUtils.mkdir_p(File.join(root, "coverage"))
        File.write(File.join(root, "coverage", "coverage.json"), {"coverage" => {}}.to_json)
        File.write(File.join(root, "CHANGELOG.md"), <<~MD)
          # Changelog
          ## [Unreleased]

          ## [1.2.3] - 2025-08-30
        MD
        allow(Kettle::Dev::CIHelpers).to receive_messages(project_root: root, repo_info: ["o", "r"])
        expect(Kettle::Dev::InputAdapter).not_to receive(:gets)
        cli = described_class.new(strict: false, yes: true)
        allow(cli).to receive(:latest_released_versions).and_return(["1.2.3", "1.2.3"])

        expect { cli.run }.not_to raise_error
      end
    end

    it "emits changelog plan events" do
      io = StringIO.new
      event_stream = Kettle::Ndjson.event_stream(io, types: "changelog")
      cli = described_class.new(strict: false, yes: true, event_stream: event_stream)
      plan = {
        action: :create_release,
        version: "1.2.3",
        gem_name: "demo",
        latest_overall: "1.2.2",
        latest_for_series: "1.2.2",
        latest_changelog_version: "1.2.2"
      }

      cli.send(:confirm_plan!, plan)

      events = io.string.lines.map { |line| JSON.parse(line) }
      expect(events).to contain_exactly(
        include("type" => "changelog", "action" => "plan", "status" => "ok", "plan" => "create_release", "version" => "1.2.3", "gem_name" => "demo", "mark" => ".")
      )
    end

    it "reformats only when duplicate version exists and user agrees" do
      mkproj do |root|
        File.write(File.join(root, "lib", "my", "gem", "version.rb"), <<~RB)
          module My; module Gem; VERSION = "1.2.3"; end; end
        RB
        FileUtils.mkdir_p(File.join(root, "coverage"))
        File.write(File.join(root, "coverage", "coverage.json"), {"coverage" => {}}.to_json)
        # Changelog with minimal missing blank lines to demonstrate reformat
        File.write(File.join(root, "CHANGELOG.md"), <<~MD)
          # Changelog
          ## [Unreleased]
          ### Added
          ### Changed
          ### Deprecated
          ### Removed
          ### Fixed
          ### Security
          ## [1.2.3] - 2025-08-30
          - TAG: [v1.2.3][1.2.3t]
          - COVERAGE: 95.00% -- 95/100 lines in 2 files
          - BRANCH COVERAGE: 80.00% -- 8/10 branches in 2 files
          - 20.00% documented

          ### Fixed

          - prev
        MD
        allow(Kettle::Dev::CIHelpers).to receive_messages(project_root: root, repo_info: ["o", "r"])
        allow(Kettle::Dev::InputAdapter).to receive(:gets).and_return("y\n")
        cli = described_class.new(strict: false)
        allow(cli).to receive(:latest_released_versions).and_return(["1.2.3", "1.2.3"])
        expect { cli.run }.not_to raise_error
        updated = File.read(File.join(root, "CHANGELOG.md"))
        # Should not add another 1.2.3 section
        expect(updated.scan(/^## \[1\.2\.3\]/).size).to eq(1)
        # Headings should have blank lines around
        expect(updated).to match(/# Changelog\n\n## \[Unreleased\]/)
        expect(updated).to match(/## \[Unreleased\]\n\n### Added/)
      end
    end

    it "aborts when the current released version has pending unreleased entries", freeze: Time.new(2025, 8, 31) do
      mkproj do |root|
        File.write(File.join(root, "lib", "my", "gem", "version.rb"), <<~RB)
          module My; module Gem; VERSION = "1.2.3"; end; end
        RB
        FileUtils.mkdir_p(File.join(root, "coverage"))
        File.write(File.join(root, "coverage", "coverage.json"), {"coverage" => {}}.to_json)
        File.write(File.join(root, "CHANGELOG.md"), <<~MD)
          # Changelog

          ## [Unreleased]

          ### Fixed

          - Fixed a follow-up before release.

          ## [1.2.3] - 2025-08-30

          - TAG: [v1.2.3][1.2.3t]

          ### Fixed

          - Prepared the release.

          ## [1.2.2] - 2025-08-01

          [Unreleased]: https://github.com/o/r/compare/v1.2.3...HEAD
          [1.2.3]: https://github.com/o/r/compare/v1.2.2...v1.2.3
          [1.2.3t]: https://github.com/o/r/releases/tag/v1.2.3
          [1.2.2]: https://github.com/o/r/compare/v1.2.1...v1.2.2
          [1.2.2t]: https://github.com/o/r/releases/tag/v1.2.2
        MD
        allow(Kettle::Dev::CIHelpers).to receive_messages(project_root: root, repo_info: ["o", "r"])
        cli = described_class.new(strict: false)
        allow(cli).to receive(:latest_released_versions).and_return(["1.2.3", "1.2.3"])
        expect { cli.run }.to raise_error(MockSystemExit, /matches the latest released version.*bump version\.rb/m)
        updated = File.read(File.join(root, "CHANGELOG.md"))

        expect(updated.scan(/^## \[1\.2\.3\]/).size).to eq(1)
        expect(updated).to include("## [1.2.3] - 2025-08-30")
        expect(updated).to include("- Fixed a follow-up before release.")
        expect(updated).not_to include("## [1.2.3] - 2025-08-31")
      end
    end

    it "reformats only when the current released version is missing generated metadata and Unreleased is empty", freeze: Time.new(2025, 8, 31) do
      mkproj do |root|
        File.write(File.join(root, "lib", "my", "gem", "version.rb"), <<~RB)
          module My; module Gem; VERSION = "1.2.3"; end; end
        RB
        FileUtils.mkdir_p(File.join(root, "coverage"))
        File.write(File.join(root, "coverage", "coverage.json"), {"coverage" => {}}.to_json)
        File.write(File.join(root, "CHANGELOG.md"), <<~MD)
          # Changelog

          ## [Unreleased]

          ### Added
          ### Changed
          ### Deprecated
          ### Removed
          ### Fixed
          ### Security

          ## [1.2.3] - 2025-08-30

          - TAG: [v1.2.3][1.2.3t]

          ### Fixed

          - Prepared the release.

          ## [1.2.2] - 2025-08-01

          [Unreleased]: https://github.com/o/r/compare/v1.2.3...HEAD
          [1.2.3]: https://github.com/o/r/compare/v1.2.2...v1.2.3
          [1.2.3t]: https://github.com/o/r/releases/tag/v1.2.3
          [1.2.2]: https://github.com/o/r/compare/v1.2.1...v1.2.2
          [1.2.2t]: https://github.com/o/r/releases/tag/v1.2.2
        MD
        allow(Kettle::Dev::CIHelpers).to receive_messages(project_root: root, repo_info: ["o", "r"])
        cli = described_class.new(strict: false)
        allow(cli).to receive(:latest_released_versions).and_return(["1.2.3", "1.2.3"])
        expect { cli.run }.not_to raise_error
        updated = File.read(File.join(root, "CHANGELOG.md"))

        expect(updated.scan(/^## \[1\.2\.3\]/).size).to eq(1)
        expect(updated).to include("## [1.2.3] - 2025-08-30")
        expect(updated).not_to include("- COVERAGE:")
        expect(updated).not_to include("- BRANCH COVERAGE:")
        expect(updated).not_to include("- 20.00% documented")
        expect(updated).to include("- Prepared the release.")
      end
    end

    it "reformats historical changelogs without requiring a section for the current released version" do
      mkproj do |root|
        File.write(File.join(root, "CHANGELOG.md"), <<~MD)
          # Changelog
          ## [Unreleased]
          ### Added
          ## [1.0.0] - 2020-01-01
          - TAG: [v1.0.0][1.0.0t]
        MD

        cli = described_class.new(root: root, strict: false, reformat_only: true)

        expect { cli.run }.not_to raise_error
        expect(File.read(File.join(root, "CHANGELOG.md"))).to include("# Changelog\n\n## [Unreleased]\n\n### Added")
      end
    end

    it "updates the most recent prepared release in place", freeze: Time.new(2025, 8, 31) do
      mkproj do |root|
        File.write(File.join(root, "lib", "my", "gem", "version.rb"), <<~RB)
          module My; module Gem; VERSION = "1.2.4"; end; end
        RB
        FileUtils.mkdir_p(File.join(root, "coverage"))
        File.write(File.join(root, "coverage", "coverage.json"), {"coverage" => {}}.to_json)
        File.write(File.join(root, "CHANGELOG.md"), <<~MD)
          # Changelog

          ## [Unreleased]

          ### Fixed

          - Fixed a release-prep follow-up.

          ## [1.2.4] - 2025-08-30

          - TAG: [v1.2.4][1.2.4t]
          - COVERAGE: 90.00% -- 90/100 lines in 2 files
          - BRANCH COVERAGE: 70.00% -- 7/10 branches in 2 files
          - 10.00% documented

          ### Fixed

          - Prepared the release.

          ## [1.2.3] - 2025-08-01

          ### Fixed

          - Previous release.

          [Unreleased]: https://github.com/o/r/compare/v1.2.4...HEAD
          [1.2.4]: https://github.com/o/r/compare/v1.2.3...v1.2.4
          [1.2.4t]: https://github.com/o/r/releases/tag/v1.2.4
          [1.2.3]: https://github.com/o/r/compare/v1.2.2...v1.2.3
          [1.2.3t]: https://github.com/o/r/releases/tag/v1.2.3
        MD
        allow(Kettle::Dev::CIHelpers).to receive_messages(project_root: root, repo_info: ["o", "r"])
        cli = described_class.new(strict: false, update_prep: true)
        allow(cli).to receive_messages(
          coverage_lines: [
            "COVERAGE: 95.00% -- 95/100 lines in 2 files",
            "BRANCH COVERAGE: 80.00% -- 8/10 branches in 2 files"
          ],
          yard_percent_documented: "20.00% documented"
        )

        expect { cli.run }.not_to raise_error
        updated = File.read(File.join(root, "CHANGELOG.md"))

        expect(updated.scan(/^## \[1\.2\.4\]/).size).to eq(1)
        expect(updated).to include("## [1.2.4] - 2025-08-31")
        expect(updated).to include("- COVERAGE: 95.00% -- 95/100 lines in 2 files")
        expect(updated).to include("- BRANCH COVERAGE: 80.00% -- 8/10 branches in 2 files")
        expect(updated).to include("- 20.00% documented")
        expect(updated).to match(/### Fixed\n\n- Prepared the release\.\n\n- Fixed a release-prep follow-up\./)
        expect(updated).to match(/## \[Unreleased\]\n\n### Added\n\n### Changed\n\n### Deprecated\n\n### Removed\n\n### Fixed\n\n### Security/)
        expect(updated).to include("[Unreleased]: https://github.com/o/r/compare/v1.2.4...HEAD")
      end
    end

    it "updates a prerelease prepared release in place", freeze: Time.new(2026, 6, 21) do
      mkproj do |root|
        File.write(File.join(root, "lib", "my", "gem", "version.rb"), <<~RB)
          module My; module Gem; VERSION = "3.0.0.rc3"; end; end
        RB
        FileUtils.mkdir_p(File.join(root, "coverage"))
        File.write(File.join(root, "coverage", "coverage.json"), {"coverage" => {}}.to_json)
        File.write(File.join(root, "CHANGELOG.md"), <<~MD)
          # Changelog

          ## [Unreleased]

          ### Fixed

          - Fixed a prerelease follow-up.

          ## [3.0.0.rc3] - 2026-06-20

          - TAG: [v3.0.0.rc3][3.0.0.rc3t]
          - COVERAGE: 90.00% -- 90/100 lines in 2 files
          - BRANCH COVERAGE: 70.00% -- 7/10 branches in 2 files
          - 10.00% documented

          ### Fixed

          - Prepared the prerelease.

          ## [2.0.2] - 2026-06-01

          ### Fixed

          - Previous stable release.

          [Unreleased]: https://github.com/o/r/compare/v3.0.0.rc3...HEAD
          [3.0.0.rc3]: https://github.com/o/r/compare/v3.0.0.rc2...v3.0.0.rc3
          [3.0.0.rc3t]: https://github.com/o/r/releases/tag/v3.0.0.rc3
          [2.0.2]: https://github.com/o/r/compare/v2.0.1...v2.0.2
          [2.0.2t]: https://github.com/o/r/releases/tag/v2.0.2
        MD
        allow(Kettle::Dev::CIHelpers).to receive_messages(project_root: root, repo_info: ["o", "r"])
        cli = described_class.new(strict: false, update_prep: true)
        allow(cli).to receive_messages(
          coverage_lines: [
            "COVERAGE: 95.00% -- 95/100 lines in 2 files",
            "BRANCH COVERAGE: 80.00% -- 8/10 branches in 2 files"
          ],
          yard_percent_documented: "20.00% documented"
        )

        expect { cli.run }.not_to raise_error
        updated = File.read(File.join(root, "CHANGELOG.md"))

        expect(updated.scan(/^## \[3\.0\.0\.rc3\]/).size).to eq(1)
        expect(updated).to include("## [3.0.0.rc3] - 2026-06-21")
        expect(updated).to include("- TAG: [v3.0.0.rc3][3.0.0.rc3t]")
        expect(updated).to include("- COVERAGE: 95.00% -- 95/100 lines in 2 files")
        expect(updated).to include("- BRANCH COVERAGE: 80.00% -- 8/10 branches in 2 files")
        expect(updated).to include("- 20.00% documented")
        expect(updated).to match(/### Fixed\n\n- Prepared the prerelease\.\n\n- Fixed a prerelease follow-up\./)
        expect(updated).to include("[Unreleased]: https://github.com/o/r/compare/v3.0.0.rc3...HEAD")
      end
    end

    it "auto-selects update-prep when version.rb matches the most recent changelog release but is newer than live", freeze: Time.new(2025, 8, 31) do
      mkproj do |root|
        File.write(File.join(root, "lib", "my", "gem", "version.rb"), <<~RB)
          module My; module Gem; VERSION = "1.2.4"; end; end
        RB
        FileUtils.mkdir_p(File.join(root, "coverage"))
        File.write(File.join(root, "coverage", "coverage.json"), {"coverage" => {}}.to_json)
        File.write(File.join(root, "CHANGELOG.md"), <<~MD)
          # Changelog

          ## [Unreleased]

          ### Fixed

          - Fixed a release-prep follow-up.

          ## [1.2.4] - 2025-08-30

          - TAG: [v1.2.4][1.2.4t]

          ### Fixed

          - Prepared the release.

          ## [1.2.3] - 2025-08-01

          [Unreleased]: https://github.com/o/r/compare/v1.2.4...HEAD
          [1.2.4]: https://github.com/o/r/compare/v1.2.3...v1.2.4
          [1.2.4t]: https://github.com/o/r/releases/tag/v1.2.4
          [1.2.3]: https://github.com/o/r/compare/v1.2.2...v1.2.3
          [1.2.3t]: https://github.com/o/r/releases/tag/v1.2.3
        MD
        allow(Kettle::Dev::CIHelpers).to receive_messages(project_root: root, repo_info: ["o", "r"])
        cli = described_class.new(strict: false)
        allow(cli).to receive(:latest_released_versions).and_return(["1.2.3", "1.2.3"])
        allow(cli).to receive_messages(
          coverage_lines: ["COVERAGE: 95.00% -- 95/100 lines in 2 files", nil],
          yard_percent_documented: nil
        )

        expect { cli.run }.not_to raise_error
        updated = File.read(File.join(root, "CHANGELOG.md"))
        expect(updated.scan(/^## \[1\.2\.4\]/).size).to eq(1)
        expect(updated).to include("## [1.2.4] - 2025-08-31")
        expect(updated).to match(/### Fixed\n\n- Prepared the release\.\n\n- Fixed a release-prep follow-up\./)
      end
    end

    it "auto-selects a new release when version.rb is newer than live and not yet in changelog", freeze: Time.new(2025, 8, 31) do
      mkproj do |root|
        File.write(File.join(root, "lib", "my", "gem", "version.rb"), <<~RB)
          module My; module Gem; VERSION = "1.2.4"; end; end
        RB
        FileUtils.mkdir_p(File.join(root, "coverage"))
        File.write(File.join(root, "coverage", "coverage.json"), {"coverage" => {}}.to_json)
        File.write(File.join(root, "CHANGELOG.md"), <<~MD)
          # Changelog

          ## [Unreleased]

          ### Fixed

          - Fixed a new release.

          ## [1.2.3] - 2025-08-01

          [Unreleased]: https://github.com/o/r/compare/v1.2.3...HEAD
          [1.2.3]: https://github.com/o/r/compare/v1.2.2...v1.2.3
          [1.2.3t]: https://github.com/o/r/releases/tag/v1.2.3
        MD
        allow(Kettle::Dev::CIHelpers).to receive_messages(project_root: root, repo_info: ["o", "r"])
        cli = described_class.new(strict: false)
        allow(cli).to receive(:latest_released_versions).and_return(["1.2.3", "1.2.3"])

        expect { cli.run }.not_to raise_error
        updated = File.read(File.join(root, "CHANGELOG.md"))
        expect(updated).to include("## [1.2.4] - 2025-08-31")
        expect(updated).to include("- Fixed a new release.")
      end
    end

    it "aborts when Unreleased section is missing" do
      mkproj do |root|
        File.write(File.join(root, "lib", "my", "gem", "version.rb"), <<~RB)
          module My; module Gem; VERSION = "1.2.3"; end; end
        RB
        FileUtils.mkdir_p(File.join(root, "coverage"))
        File.write(File.join(root, "coverage", "coverage.json"), {"coverage" => {}}.to_json)
        File.write(File.join(root, "CHANGELOG.md"), "# no unreleased here\n")
        allow(Kettle::Dev::CIHelpers).to receive_messages(project_root: root, repo_info: ["o", "r"])
        cli = described_class.new(strict: false)
        expect { cli.run }.to raise_error(MockSystemExit, /Could not find '## \[Unreleased\]'/)
      end
    end
  end

  describe "#detect_initial_compare_base (private)" do
    it "returns KETTLE_CHANGELOG_INITIAL_SHA env var when set (highest priority)" do
      cli = described_class.new(strict: false)
      stub_env("KETTLE_CHANGELOG_INITIAL_SHA" => "upstream-sha-abc123")
      expect(cli.send(:detect_initial_compare_base)).to eq("upstream-sha-abc123")
    end

    it "returns the root commit SHA from git when env var is absent" do
      cli = described_class.new(strict: false)
      # The mocked git adapter returns deadbeefcafe1234deadbeefcafe1234deadbeef
      expect(cli.send(:detect_initial_compare_base)).to eq("deadbeefcafe1234deadbeefcafe1234deadbeef")
    end

    it "falls back to HEAD^ when git command fails" do
      cli = described_class.new(strict: false)
      adapter = instance_double(Kettle::Dev::GitAdapter)
      allow(adapter).to receive(:capture).and_return(["", false])
      allow(Kettle::Dev::GitAdapter).to receive(:new).and_return(adapter)
      expect(cli.send(:detect_initial_compare_base)).to eq("HEAD^")
    end
  end

  describe "#detect_version" do
    it "uses an explicit version override when no version.rb is present" do
      mkproj do |root|
        allow(Kettle::Dev::CIHelpers).to receive(:project_root).and_return(root)
        cli = described_class.new(strict: false, version: "4.5.6")
        expect(cli.send(:detect_version)).to eq("4.5.6")
        expect(cli.send(:version_source_label, {explicit: false})).to eq("version override")
      end
    end

    it "errors when no version.rb present" do
      mkproj do |root|
        allow(Kettle::Dev::CIHelpers).to receive(:project_root).and_return(root)
        cli = described_class.new(strict: false)
        expect { cli.send(:detect_version) }.to raise_error(MockSystemExit, /Could not find version.rb/)
      end
    end

    it "errors when VERSION constant not found" do
      mkproj do |root|
        FileUtils.mkdir_p(File.join(root, "lib", "x"))
        File.write(File.join(root, "lib", "x", "version.rb"), "module X; end\n")
        allow(Kettle::Dev::CIHelpers).to receive(:project_root).and_return(root)
        cli = described_class.new(strict: false)
        expect { cli.send(:detect_version) }.to raise_error(MockSystemExit, /VERSION constant not found/)
      end
    end

    it "errors when multiple VERSION values differ" do
      mkproj do |root|
        FileUtils.mkdir_p(File.join(root, "lib", "a"))
        FileUtils.mkdir_p(File.join(root, "lib", "b"))
        File.write(File.join(root, "lib", "a", "version.rb"), "module A; VERSION='1.0.0'; end\n")
        File.write(File.join(root, "lib", "b", "version.rb"), "module B; VERSION='2.0.0'; end\n")
        allow(Kettle::Dev::CIHelpers).to receive(:project_root).and_return(root)
        cli = described_class.new(strict: false)
        expect { cli.send(:detect_version) }.to raise_error(MockSystemExit, /Multiple VERSION constants/)
      end
    end

    it "returns the single VERSION value when consistent" do
      mkproj do |root|
        FileUtils.mkdir_p(File.join(root, "lib", "a"))
        File.write(File.join(root, "lib", "a", "version.rb"), "module A; VERSION='3.2.1'; end\n")
        allow(Kettle::Dev::CIHelpers).to receive(:project_root).and_return(root)
        cli = described_class.new(strict: false)
        expect(cli.send(:detect_version)).to eq("3.2.1")
      end
    end
  end

  describe "#extract_unreleased and #detect_previous_version" do
    it "returns nils when Unreleased heading missing and previous_version nil when not matched" do
      cli = described_class.new(strict: false)
      unreleased, before, after = cli.send(:extract_unreleased, "# Changelog\n")
      expect(unreleased).to be_nil
      expect(before).to be_nil
      expect(after).to be_nil
      expect(cli.send(:detect_previous_version, "random\ntext")).to be_nil
    end
  end

  describe "#filter_unreleased_sections" do
    it "keeps only sections with content and trims trailing blanks" do
      cli = described_class.new(strict: false)
      block = <<~BLK
        noise outside
        ### Added
        - one

        ### Changed
        
        ### Fixed
        - fx
        
      BLK
      out = cli.send(:filter_unreleased_sections, block)
      expect(out).to include("### Added\n- one\n")
      expect(out).to include("### Fixed\n- fx\n")
      expect(out).not_to include("### Changed")
      expect(out).not_to include("noise outside")
    end
  end

  describe "#coverage_lines" do
    it "warns and returns nils when coverage.json missing" do
      mkproj do |root|
        allow(Kettle::Dev::CIHelpers).to receive(:project_root).and_return(root)
        cli = described_class.new(strict: false)
        line_cov, branch_cov = cli.send(:coverage_lines)
        expect(line_cov).to be_nil
        expect(branch_cov).to be_nil
      end
    end

    it "rescues JSON parsing errors and returns nils" do
      mkproj do |root|
        FileUtils.mkdir_p(File.join(root, "coverage"))
        File.write(File.join(root, "coverage", "coverage.json"), "not json")
        allow(Kettle::Dev::CIHelpers).to receive(:project_root).and_return(root)
        cli = described_class.new(strict: false)
        line_cov = branch_cov = nil
        expect {
          line_cov, branch_cov = cli.send(:coverage_lines)
        }.to output(/Failed to parse coverage: JSON::ParserError:/).to_stderr
        expect(line_cov).to be_nil
        expect(branch_cov).to be_nil
      end
    end

    context "when success aggregation" do
      it "computes line and branch coverage across files" do
        mkproj do |root|
          allow(Kettle::Dev::CIHelpers).to receive(:project_root).and_return(root)
          FileUtils.mkdir_p(File.join(root, "coverage"))
          data = {
            "coverage" => {
              "lib/a.rb" => {
                "lines" => [1, 0, nil, "x"],
                "branches" => [
                  {"coverage" => 1},
                  {"coverage" => 0},
                  {"coverage" => "n/a"}
                ]
              },
              "lib/b.rb" => {
                "lines" => [0, 0, 2],
                "branches" => [
                  {"coverage" => 0},
                  {"coverage" => 0}
                ]
              },
              "lib/c.rb" => {
                "lines" => [nil, nil],
                "branches" => []
              }
            }
          }
          File.write(File.join(root, "coverage", "coverage.json"), JSON.pretty_generate(data))
          cli = described_class.new(strict: false)
          line_cov, branch_cov = cli.send(:coverage_lines)
          expect(line_cov).to eq("COVERAGE: 40.00% -- 2/5 lines in 2 files")
          expect(branch_cov).to eq("BRANCH COVERAGE: 25.00% -- 1/4 branches in 2 files")
        end
      end
    end

    context "when branch filtering" do
      it "counts only Hash entries with Numeric coverage and increments covered only for > 0" do
        Dir.mktmpdir do |root|
          allow(Kettle::Dev::CIHelpers).to receive(:project_root).and_return(root)
          FileUtils.mkdir_p(File.join(root, "coverage"))
          data = {
            "coverage" => {
              "lib/a.rb" => {
                "lines" => [1],
                "branches" => [
                  "string",             # skipped: not a Hash (line 202)
                  123,                   # skipped: not a Hash (line 202)
                  {"coverage" => "n/a"}, # skipped: non-Numeric (line 204)
                  {"coverage" => 0},     # counts in total, not covered (205-206)
                  {"coverage" => 2}      # counts in total and covered (205-206)
                ]
              }
            }
          }
          File.write(File.join(root, "coverage", "coverage.json"), JSON.pretty_generate(data))
          cli = described_class.new(strict: false)
          line_cov, branch_cov = cli.send(:coverage_lines)
          # lines: 1 relevant, 1 covered, 1 file
          expect(line_cov).to eq("COVERAGE: 100.00% -- 1/1 lines in 1 files")
          # branches considered: only the two Hash+Numeric ones => total 2, covered 1
          expect(branch_cov).to eq("BRANCH COVERAGE: 50.00% -- 1/2 branches in 1 files")
        end
      end
    end

    it "runs kettle-test with coverage JSON and hard thresholds enabled in strict mode" do
      mkproj do |root|
        allow(Kettle::Dev::CIHelpers).to receive(:project_root).and_return(root)
        coverage_payload = JSON.generate(
          "coverage" => {
            "lib/a.rb" => {
              "lines" => [1],
              "branches" => [{"coverage" => 1}]
            }
          }
        )

        expect(cli = described_class.new(strict: true)).to receive(:system).with(
          hash_including(
            "K_SOUP_COV_DO" => "true",
            "K_SOUP_COV_FORMATTERS" => "json",
            "K_SOUP_COV_MIN_HARD" => "true",
            "K_SOUP_COV_MULTI_FORMATTERS" => "false",
            "K_SOUP_COV_OPEN_BIN" => ""
          ),
          "bundle",
          "exec",
          "kettle-test",
          chdir: root
        ) do
          FileUtils.mkdir_p(File.join(root, "coverage"))
          File.write(File.join(root, "coverage", "coverage.json"), coverage_payload)
          true
        end

        line_cov, branch_cov = cli.send(:coverage_lines)
        expect(line_cov).to eq("COVERAGE: 100.00% -- 1/1 lines in 1 files")
        expect(branch_cov).to eq("BRANCH COVERAGE: 100.00% -- 1/1 branches in 1 files")
      end
    end

    it "uses the checked-in coverage workflow thresholds for the changelog test run", :modern_tooling_only do
      mkproj do |root|
        allow(Kettle::Dev::CIHelpers).to receive(:project_root).and_return(root)
        workflow_dir = File.join(root, ".github", "workflows")
        FileUtils.mkdir_p(workflow_dir)
        File.write(File.join(workflow_dir, "coverage.yml"), <<~YAML)
          env:
            K_SOUP_COV_MIN_LINE: 91
            K_SOUP_COV_MIN_BRANCH: 72
            K_SOUP_COV_MIN_HARD: true
        YAML
        coverage_payload = JSON.generate("coverage" => {"lib/a.rb" => {"lines" => [1], "branches" => [{"coverage" => 1}]}})

        expect(cli = described_class.new(strict: true)).to receive(:system).with(
          hash_including(
            "K_SOUP_COV_MIN_LINE" => "91",
            "K_SOUP_COV_MIN_BRANCH" => "72",
            "K_SOUP_COV_MIN_HARD" => "true"
          ),
          "bundle",
          "exec",
          "kettle-test",
          chdir: root
        ) do
          FileUtils.mkdir_p(File.join(root, "coverage"))
          File.write(File.join(root, "coverage", "coverage.json"), coverage_payload)
          true
        end

        cli.send(:coverage_lines)
      end
    end

    it "runs strict coverage from K_CHANGELOG_COVERAGE_ROOT when configured" do
      mkproj do |root|
        coverage_root = File.join(root, "family")
        FileUtils.mkdir_p(coverage_root)
        File.write(File.join(coverage_root, "Gemfile"), "source \"https://rubygems.org\"\n")
        allow(Kettle::Dev::CIHelpers).to receive(:project_root).and_return(root)
        stub_env("K_CHANGELOG_COVERAGE_ROOT" => coverage_root)
        coverage_payload = JSON.generate(
          "coverage" => {
            "gems/alpha/lib/alpha.rb" => {
              "lines" => [1, 1],
              "branches" => [{"coverage" => 1}]
            }
          }
        )

        expect(cli = described_class.new(strict: true)).to receive(:system).with(
          hash_including(
            "BUNDLE_GEMFILE" => File.join(coverage_root, "Gemfile"),
            "K_SOUP_COV_DO" => "true",
            "K_SOUP_COV_FORMATTERS" => "json",
            "K_SOUP_COV_MIN_HARD" => "true"
          ),
          "bundle",
          "exec",
          "kettle-test",
          chdir: coverage_root
        ) do
          FileUtils.mkdir_p(File.join(coverage_root, "coverage"))
          File.write(File.join(coverage_root, "coverage", "coverage.json"), coverage_payload)
          true
        end

        line_cov, branch_cov = cli.send(:coverage_lines)
        expect(line_cov).to eq("COVERAGE: 100.00% -- 2/2 lines in 1 files")
        expect(branch_cov).to eq("BRANCH COVERAGE: 100.00% -- 1/1 branches in 1 files")
      end
    end

    it "runs strict coverage in a subprocess using the coverage root bundle instead of inherited member bundler state" do
      mkproj do |member_root|
        coverage_root = File.join(member_root, "family")
        fake_bin = File.join(member_root, "fake-bin")
        snapshot_path = File.join(member_root, "coverage-subprocess-env.json")
        FileUtils.mkdir_p(fake_bin)
        FileUtils.mkdir_p(coverage_root)
        File.write(File.join(member_root, "Gemfile"), "source \"https://rubygems.org\"\n")
        File.write(File.join(coverage_root, "Gemfile"), "source \"https://rubygems.org\"\n")
        File.write(File.join(fake_bin, "bundle"), <<~RUBY)
          #!/usr/bin/env ruby
          require "fileutils"
          require "json"

          snapshot = {
            "argv" => ARGV,
            "cwd" => Dir.pwd,
            "bundle_gemfile" => ENV["BUNDLE_GEMFILE"],
            "bundle_bin_path" => ENV["BUNDLE_BIN_PATH"],
            "bundler_setup" => ENV["BUNDLER_SETUP"],
            "rubyopt" => ENV["RUBYOPT"]
          }
          File.write(#{snapshot_path.dump}, JSON.generate(snapshot))
          exit(12) unless ARGV == ["exec", "kettle-test"]

          FileUtils.mkdir_p(File.join(Dir.pwd, "coverage"))
          File.write(
            File.join(Dir.pwd, "coverage", "coverage.json"),
            JSON.generate(
              "coverage" => {
                "gems/alpha/lib/alpha.rb" => {
                  "lines" => [1, 0],
                  "branches" => [{"coverage" => 1}, {"coverage" => 0}]
                }
              }
            )
          )
        RUBY
        FileUtils.chmod(0o755, File.join(fake_bin, "bundle"))

        allow(Kettle::Dev::CIHelpers).to receive(:project_root).and_return(member_root)
        stub_env(
          "BUNDLE_BIN_PATH" => File.join(member_root, "member-bundle-bin"),
          "BUNDLE_GEMFILE" => File.join(member_root, "Gemfile"),
          "BUNDLER_SETUP" => File.join(member_root, "member-setup"),
          "K_CHANGELOG_COVERAGE_ROOT" => coverage_root,
          "PATH" => "#{fake_bin}#{File::PATH_SEPARATOR}#{ENV.fetch("PATH", "")}",
          "RUBYOPT" => "-rbundler/setup"
        )

        line_cov, branch_cov = described_class.new(strict: true).send(:coverage_lines)
        snapshot = JSON.parse(File.read(snapshot_path))

        expect(snapshot).to include(
          "argv" => %w[exec kettle-test],
          "cwd" => File.realpath(coverage_root),
          "bundle_gemfile" => File.join(coverage_root, "Gemfile")
        )
        expect(snapshot.fetch("bundle_bin_path")).to be_nil.or eq("")
        expect(snapshot.fetch("bundler_setup")).to be_nil.or eq("")
        expect(snapshot.fetch("rubyopt")).to be_nil.or eq("")
        expect(line_cov).to eq("COVERAGE: 50.00% -- 1/2 lines in 1 files")
        expect(branch_cov).to eq("BRANCH COVERAGE: 50.00% -- 1/2 branches in 1 files")
      end
    end

    it "fails closed when kettle-test does not collate parallel coverage JSON" do
      mkproj do |root|
        allow(Kettle::Dev::CIHelpers).to receive(:project_root).and_return(root)

        expect(cli = described_class.new(strict: true)).to receive(:system) do
          worker_one = File.join(root, "coverage", "turbo_tests", "1")
          worker_two = File.join(root, "coverage", "turbo_tests", "2")
          FileUtils.mkdir_p(worker_one)
          FileUtils.mkdir_p(worker_two)
          File.write(
            File.join(worker_one, "coverage.json"),
            JSON.generate(
              "coverage" => {
                "lib/a.rb" => {
                  "lines" => [1, 0, nil],
                  "branches" => [{"type" => "then", "start_line" => 1, "end_line" => 1, "coverage" => 0}]
                }
              }
            )
          )
          File.write(
            File.join(worker_two, "coverage.json"),
            JSON.generate(
              "coverage" => {
                "lib/a.rb" => {
                  "lines" => [0, 1, nil],
                  "branches" => [{"type" => "then", "start_line" => 1, "end_line" => 1, "coverage" => 1}]
                }
              }
            )
          )
          true
        end

        expect do
          cli.send(:coverage_lines)
        end.to raise_error(
          RuntimeError,
          /kettle-test runs specs in parallel and is expected to collate parallel SimpleCov results/
        )
        expect(File.file?(File.join(root, "coverage", "coverage.json"))).to be(false)
      end
    end

    it "allows strict coverage generation without hard threshold enforcement" do
      mkproj do |root|
        allow(Kettle::Dev::CIHelpers).to receive(:project_root).and_return(root)
        coverage_payload = JSON.generate(
          "coverage" => {
            "lib/a.rb" => {
              "lines" => [1],
              "branches" => [{"coverage" => 1}]
            }
          }
        )

        expect(cli = described_class.new(strict: true, enforce_coverage_thresholds: false)).to receive(:system).with(
          hash_including(
            "K_SOUP_COV_DO" => "true",
            "K_SOUP_COV_FORMATTERS" => "json",
            "K_SOUP_COV_MIN_HARD" => "false",
            "K_SOUP_COV_MULTI_FORMATTERS" => "false",
            "K_SOUP_COV_OPEN_BIN" => ""
          ),
          "bundle",
          "exec",
          "kettle-test",
          chdir: root
        ) do
          FileUtils.mkdir_p(File.join(root, "coverage"))
          File.write(File.join(root, "coverage", "coverage.json"), coverage_payload)
          true
        end

        line_cov, branch_cov = cli.send(:coverage_lines)
        expect(line_cov).to eq("COVERAGE: 100.00% -- 1/1 lines in 1 files")
        expect(branch_cov).to eq("BRANCH COVERAGE: 100.00% -- 1/1 branches in 1 files")
      end
    end
  end

  describe "#yard_percent_documented" do
    it "warns and returns nil when bin/rake not executable" do
      mkproj do |root|
        allow(Kettle::Dev::CIHelpers).to receive(:project_root).and_return(root)
        cli = described_class.new(strict: false)
        expect(cli.send(:yard_percent_documented)).to be_nil
      end
    end

    it "returns nil and warns when percent not found in output" do
      mkproj do |root|
        # fake bin/rake
        path = File.join(root, "bin")
        FileUtils.mkdir_p(path)
        cmd = File.join(path, "rake")
        File.write(cmd, "#!/usr/bin/env ruby\nputs 'no percent here'\n")
        FileUtils.chmod(0o755, cmd)
        allow(Kettle::Dev::CIHelpers).to receive(:project_root).and_return(root)
        # Don't actually execute file; just stub capture2 to return our text
        allow(File).to receive(:executable?).and_call_original
        allow(File).to receive(:executable?).with(cmd).and_return(true)
        allow(Open3).to receive(:capture2e).and_return(["nothing documented line\n", double("ps")])
        cli = described_class.new(strict: false)
        expect(cli.send(:yard_percent_documented)).to be_nil
      end
    end

    it "rescues failures running yard" do
      mkproj do |root|
        path = File.join(root, "bin")
        FileUtils.mkdir_p(path)
        cmd = File.join(path, "rake")
        File.write(cmd, "#!/usr/bin/env ruby\nputs 'hi'\n")
        FileUtils.chmod(0o755, cmd)
        allow(Kettle::Dev::CIHelpers).to receive(:project_root).and_return(root)
        allow(Open3).to receive(:capture2e).and_raise(StandardError.new("boom"))
        cli = described_class.new(strict: false)
        expect(cli.send(:yard_percent_documented)).to be_nil
      end
    end

    it "falls back to bin/yard when the rake task has no documented percentage" do
      mkproj do |root|
        allow(Kettle::Dev::CIHelpers).to receive(:project_root).and_return(root)
        path = File.join(root, "bin")
        FileUtils.mkdir_p(path)
        rake = File.join(path, "rake")
        yard = File.join(path, "yard")
        File.write(rake, "#!/usr/bin/env ruby\n")
        File.write(yard, "#!/usr/bin/env ruby\n")
        FileUtils.chmod(0o755, rake)
        FileUtils.chmod(0o755, yard)
        allow(Open3).to receive(:capture2e).with(rake, "yard", {chdir: root}).and_return(["no task here\n", double("rake status")])
        allow(Open3).to receive(:capture2e).with(yard, {chdir: root}).and_return(["95.35% documented\n", double("yard status")])

        cli = described_class.new(strict: true)
        expect(cli.send(:yard_percent_documented)).to eq("95.35% documented")
      end
    end

    it "raises the rake yard failure output when yard lint fails" do
      mkproj do |root|
        allow(Kettle::Dev::CIHelpers).to receive(:project_root).and_return(root)
        path = File.join(root, "bin")
        FileUtils.mkdir_p(path)
        rake = File.join(path, "rake")
        File.write(rake, "#!/usr/bin/env ruby\n")
        FileUtils.chmod(0o755, rake)
        status = instance_double(Process::Status, success?: false, exitstatus: 1)
        output = "bundle exec yard-lint lib\nrake aborted!\nCommand failed with status (1): [bundle exec yard-lint lib]\n"
        allow(Open3).to receive(:capture2e).with(rake, "yard", {chdir: root}).and_return([output, status])

        cli = described_class.new(strict: true)

        expect { cli.send(:yard_percent_documented) }.to raise_error(RuntimeError, include("Failed to run bin/rake yard (exit 1): bundle exec yard-lint lib"))
      end
    end
  end

  describe "#update_link_refs GitLab conversion and owner/repo behavior" do
    it "converts GitLab compare and tag links to GitHub using captured owner/repo when nil provided" do
      cli = described_class.new(strict: false)
      input = <<~TXT
        ## [Unreleased]
        Something

        [Unreleased]: https://gitlab.com/foo/bar/-/compare/abc...HEAD
        [1.0.0]: https://gitlab.com/foo/bar/-/compare/abc...v1.0.0
        [1.0.0t]: https://gitlab.com/foo/bar/-/tags/v1.0.0
      TXT
      out = cli.send(:update_link_refs, input, nil, nil, "0.9.0", "1.0.1")
      expect(out).to include("https://github.com/foo/bar/compare/abc...v1.0.0")
      expect(out).to include("https://github.com/foo/bar/releases/tag/v1.0.0")
    end

    it "appends new compare and tag refs only when owner/repo present and handles missing Unreleased ref" do
      cli = described_class.new(strict: false)
      input = <<~TXT
        ## [Unreleased]
        Notes

        [1.0.0]: https://github.com/acme/x/compare/v0.9.0...v1.0.0
        [1.0.0t]: https://github.com/acme/x/releases/tag/v1.0.0
      TXT
      out = cli.send(:update_link_refs, input, "acme", "x", "1.0.0", "1.1.0")
      expect(out).to include("[Unreleased]: https://github.com/acme/x/compare/v1.1.0...HEAD")
      expect(out).to include("[1.1.0]: https://github.com/acme/x/compare/v1.0.0...v1.1.0")
      expect(out).to include("[1.1.0t]: https://github.com/acme/x/releases/tag/v1.1.0")
    end
  end

  describe "#update_link_refs GitLab compare owner override and multiple entries" do
    it "uses provided owner/repo instead of captured ones when present (compare links)" do
      cli = described_class.new(strict: false)
      input = <<~TXT
        [1.2.3]: https://gitlab.com/foo/bar/-/compare/deadbeef...v1.2.3
      TXT
      out = cli.send(:update_link_refs, input, "acme", "widget", "1.2.2", "1.2.3")
      expect(out).to include("https://github.com/acme/widget/compare/deadbeef...v1.2.3")
      # Ensure old GitLab URL no longer present
      expect(out).not_to include("gitlab.com/foo/bar/-/compare/deadbeef...v1.2.3")
    end

    it "converts multiple GitLab compare links using captured groups when owner/repo are nil" do
      cli = described_class.new(strict: false)
      input = <<~TXT
        [0.9.0]: https://gitlab.com/one/repo/-/compare/abc123...v0.9.0
        [1.0.0]: https://gitlab.com/two/other/-/compare/def456...v1.0.0
      TXT
      out = cli.send(:update_link_refs, input, nil, nil, "0.9.0", "1.0.1")
      expect(out).to include("https://github.com/one/repo/compare/abc123...v0.9.0")
      expect(out).to include("https://github.com/two/other/compare/def456...v1.0.0")
    end
  end

  describe "#detect_initial_compare_base" do
    it "returns KETTLE_CHANGELOG_INITIAL_SHA env var when set" do
      cli = described_class.new(strict: false)
      stub_env("KETTLE_CHANGELOG_INITIAL_SHA" => "forked-sha-xyz")
      expect(cli.send(:detect_initial_compare_base)).to eq("forked-sha-xyz")
    end

    it "returns the git root commit SHA when env var absent and git succeeds" do
      cli = described_class.new(strict: false)
      expect(cli.send(:detect_initial_compare_base)).to eq("deadbeefcafe1234deadbeefcafe1234deadbeef")
    end

    it "defaults to HEAD^ when git fails and env var is absent" do
      cli = described_class.new(strict: false)
      adapter = instance_double(Kettle::Dev::GitAdapter)
      allow(adapter).to receive(:capture).and_return(["", false])
      allow(Kettle::Dev::GitAdapter).to receive(:new).and_return(adapter)
      expect(cli.send(:detect_initial_compare_base)).to eq("HEAD^")
    end
  end

  it "lists Unreleased first, then newest to oldest versions in footer", freeze: Time.new(2025, 8, 30) do
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, "lib", "my", "gem"))
      File.write(File.join(root, "lib", "my", "gem", "version.rb"), <<~RB)
        module My
          module Gem
            VERSION = "2.0.14"
          end
        end
      RB
      FileUtils.mkdir_p(File.join(root, "coverage"))
      File.write(File.join(root, "coverage", "coverage.json"), {result: {covered_lines: 100, total_lines: 100, covered_branches: 10, total_branches: 10}}.to_json)

      fixture_path = File.expand_path("../../support/fixtures/CHANGELOG.md", __dir__)
      content = File.read(fixture_path)
      File.write(File.join(root, "CHANGELOG.md"), content)

      ci_helpers = Kettle::Dev::CIHelpers
      allow(ci_helpers).to receive_messages(project_root: root, repo_info: ["acme", "my-gem"]) # owner, repo

      cli = described_class.new(strict: false)
      expect { cli.run }.not_to raise_error

      updated = File.read(File.join(root, "CHANGELOG.md"))

      # Extract footer lines only
      footer = updated.lines.drop_while { |l| !l.start_with?("[Unreleased]:") }
      keys = footer.grep(/^\[[^\]]+\]:/).map { |l| l[/^\[([^\]]+)\]:/, 1] }

      # Ensure Unreleased is first
      expect(keys.first).to eq("Unreleased")

      # Find versions order that follows Unreleased
      versions = keys.drop(1).map { |k| k.sub(/t\z/, "") }
      # Remove duplicates for compare/tag pairs
      versions_uniq = []
      versions.each { |v| versions_uniq << v unless versions_uniq.include?(v) }

      # Expect strictly descending order (newest to oldest)
      parsed = versions_uniq.map { |s| Gem::Version.new(s) }
      expect(parsed).to eq(parsed.sort.reverse)
    end
  end

  it "preserves older release blocks and interspersed link refs when adding new version", freeze: Time.new(2025, 8, 30) do
    Dir.mktmpdir do |root|
      # Prepare minimal gem fixture
      FileUtils.mkdir_p(File.join(root, "lib", "my", "gem"))
      # version.rb
      File.write(File.join(root, "lib", "my", "gem", "version.rb"), <<~RB)
        module My
          module Gem
            VERSION = "9.9.9"
          end
        end
      RB
      # coverage json minimal to satisfy CLI coverage parsing
      FileUtils.mkdir_p(File.join(root, "coverage"))
      File.write(File.join(root, "coverage", "coverage.json"), {result: {covered_lines: 100, total_lines: 100, covered_branches: 10, total_branches: 10}}.to_json)

      # Copy the complex CHANGELOG fixture into this temp gem
      fixture_path = File.expand_path("../../support/fixtures/CHANGELOG.md", __dir__)
      content = File.read(fixture_path)
      File.write(File.join(root, "CHANGELOG.md"), content)

      # Stub project_root and repo_info for deterministic link updates
      ci_helpers = Kettle::Dev::CIHelpers
      allow(ci_helpers).to receive_messages(project_root: root, repo_info: ["acme", "my-gem"])

      # Run the CLI
      cli = described_class.new(strict: false)
      expect { cli.run }.not_to raise_error

      updated = File.read(File.join(root, "CHANGELOG.md"))

      # It should add the new section header with date and TAG
      expect(updated).to include("## [9.9.9] - 2025-08-30")
      expect(updated).to include("- TAG: [v9.9.9][9.9.9t]")

      # Crucially, it should preserve at least one older section header
      expect(updated).to include("## [2.0.12] - 2025-05-31").or include("## [2.0.11] - 2025-05-23")

      # And preserve interspersed link refs that appear near 2.0.13 in the fixture
      expect(updated).to include("[gh660]: https://github.com/ruby-oauth/oauth2/pull/660")
      expect(updated).to include("[gh657]: https://github.com/ruby-oauth/oauth2/pull/657")
      expect(updated).to include("[gh656]: https://github.com/ruby-oauth/oauth2/pull/656")

      # Unreleased section should be reset with headings intact and spaced by blank lines
      expect(updated).to match(/## \[Unreleased\]\n\n### Added\n\n### Changed\n\n### Deprecated\n\n### Removed\n\n### Fixed\n\n### Security/)
    end
  end

  it "works with a vanilla keep-a-changelog fixture", freeze: Time.new(2025, 8, 30) do
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, "lib", "my", "gem"))
      File.write(File.join(root, "lib", "my", "gem", "version.rb"), <<~RB)
        module My
          module Gem
            VERSION = "9.9.9"
          end
        end
      RB
      FileUtils.mkdir_p(File.join(root, "coverage"))
      File.write(File.join(root, "coverage", "coverage.json"), {result: {covered_lines: 100, total_lines: 100, covered_branches: 10, total_branches: 10}}.to_json)

      # Copy the vanilla Keep a Changelog fixture
      fixture_path = File.expand_path("../../support/fixtures/KEEP_A_CHANGELOG.md", __dir__)
      content = File.read(fixture_path)
      File.write(File.join(root, "CHANGELOG.md"), content)

      # Stub project_root and repo_info for deterministic link updates
      ci_helpers = Kettle::Dev::CIHelpers
      allow(ci_helpers).to receive_messages(project_root: root, repo_info: ["acme", "my-gem"])

      cli = described_class.new(strict: false)
      expect { cli.run }.not_to raise_error

      updated = File.read(File.join(root, "CHANGELOG.md"))

      # New section and TAG
      expect(updated).to include("## [9.9.9] - 2025-08-30")
      expect(updated).to include("- TAG: [v9.9.9][9.9.9t]")

      # Preserve at least one older release section from the vanilla fixture
      expect(updated).to include("## [1.3.3] - 2024-11-08").or include("## [1.3.2] - 2024-11-05")

      # Unreleased section reset with headings intact and spaced by blank lines
      expect(updated).to match(/## \[Unreleased\]\n\n### Added\n\n### Changed\n\n### Deprecated\n\n### Removed\n\n### Fixed\n\n### Security/)

      # Footer should still contain the Unreleased link-ref and include new compare/tag refs for 9.9.9
      expect(updated).to include("[Unreleased]: ")
      expect(updated).to include("[9.9.9]: https://github.com/acme/my-gem/compare/")
      expect(updated).to include("[9.9.9t]: https://github.com/acme/my-gem/releases/tag/v9.9.9")
    end
  end

  it "works with a partial-unreleased changelog fixture", freeze: Time.new(2025, 8, 30) do
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, "lib", "my", "gem"))
      File.write(File.join(root, "lib", "my", "gem", "version.rb"), <<~RB)
        module My
          module Gem
            VERSION = "9.9.9"
          end
        end
      RB
      FileUtils.mkdir_p(File.join(root, "coverage"))
      File.write(File.join(root, "coverage", "coverage.json"), {"coverage" => {}}.to_json)

      # Copy the new partial Unreleased fixture
      fixture_path = File.expand_path("../../support/fixtures/CHANGELOG_PARTIAL_UNRELEASED.md", __dir__)
      content = File.read(fixture_path)
      File.write(File.join(root, "CHANGELOG.md"), content)

      # Stub project_root and repo_info for deterministic link updates
      allow(Kettle::Dev::CIHelpers).to receive_messages(project_root: root, repo_info: ["acme", "x"]) # owner, repo

      cli = described_class.new(strict: false)
      expect { cli.run }.not_to raise_error

      updated = File.read(File.join(root, "CHANGELOG.md"))

      # New section and TAG
      expect(updated).to include("## [9.9.9] - 2025-08-30")
      expect(updated).to include("- TAG: [v9.9.9][9.9.9t]")

      # Unreleased section should be fully reset to all standard subheadings without duplication
      expect(updated).to match(/## \[Unreleased\]\n\n### Added\n\n### Changed\n\n### Deprecated\n\n### Removed\n\n### Fixed\n\n### Security\n\n## \[9\.9\.9\] - 2025-08-30/)

      # Ensure footer [Unreleased] link-ref is preserved (fixture uses ...main)
      expect(updated).to include("[Unreleased]: ")
      expect(updated).to include("...main").or include("...HEAD")
    end
  end

  # ── Bug regression specs ────────────────────────────────────────────────────

  # Bug: link-ref definition lines (e.g. `[key]: https://...`) were treated as
  # real content when deciding whether an H3 section was non-empty.  A section
  # that contains ONLY link-ref defs (no list items / paragraphs) must be
  # dropped from the released block.
  describe "bug: link-ref definitions must not count as section content", freeze: Time.new(2025, 8, 30) do
    def run_with_fixture(fixture_name, version: "9.9.9", owner: "acme", repo: "x")
      Dir.mktmpdir do |root|
        FileUtils.mkdir_p(File.join(root, "lib", "my", "gem"))
        File.write(File.join(root, "lib", "my", "gem", "version.rb"), <<~RB)
          module My; module Gem; VERSION = "#{version}"; end; end
        RB
        FileUtils.mkdir_p(File.join(root, "coverage"))
        File.write(File.join(root, "coverage", "coverage.json"), {"coverage" => {}}.to_json)

        fixture_path = File.expand_path("../../support/fixtures/#{fixture_name}", __dir__)
        File.write(File.join(root, "CHANGELOG.md"), File.read(fixture_path))

        allow(Kettle::Dev::CIHelpers).to receive_messages(project_root: root, repo_info: [owner, repo])
        cli = described_class.new(strict: false)
        expect { cli.run }.not_to raise_error
        yield File.read(File.join(root, "CHANGELOG.md"))
      end
    end

    it "drops H3 section whose body contains only link-ref definitions" do
      run_with_fixture("CHANGELOG_BUG_LINK_REFS_AS_CONTENT.md") do |updated|
        # ### Changed body had only a link-ref def — must be omitted
        released = updated[/## \[9\.9\.9\].*?(?=## \[|\z)/m]
        expect(released).not_to include("### Changed")
        # ### Added and ### Fixed had real list items — must be kept
        expect(released).to include("### Added")
        expect(released).to include("### Fixed")
        # ### Deprecated, ### Removed, ### Security were all empty — must be omitted
        expect(released).not_to include("### Deprecated")
        expect(released).not_to include("### Removed")
        expect(released).not_to include("### Security")
      end
    end

    it "keeps inline link-ref defs that accompany real content, drops refs from dropped sections" do
      run_with_fixture("CHANGELOG_BUG_LINK_REFS_AS_CONTENT.md") do |updated|
        released = updated[/## \[9\.9\.9\].*?(?=## \[|\z)/m]
        # [🔀ref1] lives in ### Added (kept) → must be preserved in the released body
        expect(released).to include("[🔀ref1]: https://example.com/one")
        # [🔀ref2] lives in ### Changed (dropped, link-ref only) → must be absent
        expect(released).not_to include("[🔀ref2]:")
        # [🔀ref3] lives in ### Security (dropped, link-ref only) → must be absent
        expect(released).not_to include("[🔀ref3]:")
      end
    end
  end

  # Bug: when the CHANGELOG has no previous `## [...]` release (i.e. this is the
  # very first release), the footer link-refs (`[Unreleased]: ...` etc.) live
  # directly inside the Unreleased block with no `## [` boundary to stop
  # `extract_unreleased`.  They bleed into the last H3 section (typically
  # ### Security), making it appear non-empty and causing it to be retained with
  # the footer refs as its body.
  describe "bug: footer link-refs must not bleed into unreleased body on first release" do
    it "drops ### Security and places footer link-refs only in the footer", freeze: Time.new(2025, 8, 30) do
      Dir.mktmpdir do |root|
        FileUtils.mkdir_p(File.join(root, "lib", "my", "gem"))
        File.write(File.join(root, "lib", "my", "gem", "version.rb"), <<~RB)
          module My; module Gem; VERSION = "1.0.0"; end; end
        RB
        FileUtils.mkdir_p(File.join(root, "coverage"))
        File.write(File.join(root, "coverage", "coverage.json"), {"coverage" => {}}.to_json)

        fixture_path = File.expand_path("../../support/fixtures/CHANGELOG_BUG_FOOTER_BLEEDING.md", __dir__)
        File.write(File.join(root, "CHANGELOG.md"), File.read(fixture_path))

        allow(Kettle::Dev::CIHelpers).to receive_messages(project_root: root, repo_info: ["acme", "new-gem"])
        cli = described_class.new(strict: false)
        expect { cli.run }.not_to raise_error

        updated = File.read(File.join(root, "CHANGELOG.md"))
        # Extract just the released section: from ## [1.0.0] until the footer block or next ## [
        released_start = updated.index("## [1.0.0]")
        footer_start = updated.index("\n[Unreleased]:")
        released = (released_start && footer_start) ? updated[released_start...footer_start] : ""

        # Empty sections must be absent from the released block
        expect(released).not_to include("### Security")
        expect(released).not_to include("### Deprecated")
        expect(released).not_to include("### Removed")
        # ### Fixed has real content → must be present
        expect(released).to include("### Fixed")
        expect(released).to include("### Added")
        expect(released).to include("### Changed")

        # Footer link-refs must NOT appear inside the released section body
        expect(released).not_to match(/^\[Unreleased\]:/)
        expect(released).not_to match(/^\[1\.0\.0\]:/)
        expect(released).not_to match(/^\[1\.0\.0t\]:/)

        # But the footer itself must still exist at the end of the file
        footer = updated.lines.drop_while { |l| !l.start_with?("[Unreleased]:") }.join
        expect(footer).to include("[Unreleased]:")
        expect(footer).to include("[1.0.0]:")
        expect(footer).to include("[1.0.0t]:")
        # Compare link must use the git root commit SHA (mocked as deadbeef...)
        expect(footer).to include("deadbeefcafe1234deadbeefcafe1234deadbeef...v1.0.0")
      end
    end
  end

  # Bug: an H4 subsection heading (####) with no list items under it — but
  # appearing under an H3 section that does have real content elsewhere —
  # should not count as real content for a section that is otherwise empty.
  describe "bug: H4 subsection headings alone must not count as section content" do
    it "drops H3 section whose body has only an H4 heading and no list items", freeze: Time.new(2025, 8, 30) do
      Dir.mktmpdir do |root|
        FileUtils.mkdir_p(File.join(root, "lib", "my", "gem"))
        File.write(File.join(root, "lib", "my", "gem", "version.rb"), <<~RB)
          module My; module Gem; VERSION = "2.0.0"; end; end
        RB
        FileUtils.mkdir_p(File.join(root, "coverage"))
        File.write(File.join(root, "coverage", "coverage.json"), {"coverage" => {}}.to_json)

        fixture_path = File.expand_path("../../support/fixtures/CHANGELOG_BUG_H4_ONLY_CONTENT.md", __dir__)
        File.write(File.join(root, "CHANGELOG.md"), File.read(fixture_path))

        allow(Kettle::Dev::CIHelpers).to receive_messages(project_root: root, repo_info: ["acme", "x"])
        cli = described_class.new(strict: false)
        expect { cli.run }.not_to raise_error

        updated = File.read(File.join(root, "CHANGELOG.md"))
        released = updated[/## \[2\.0\.0\] - 2025-08-30.*?(?=## \[|\z)/m]

        # ### Added has ONLY an H4 heading (no list items) → must be dropped
        expect(released).not_to include("### Added")
        expect(released).not_to include("#### From upstream project")
        # Other empty H3 sections must also be absent
        expect(released).not_to include("### Deprecated")
        expect(released).not_to include("### Removed")
        expect(released).not_to include("### Fixed")
        expect(released).not_to include("### Security")
        # ### Changed had a real list item → kept
        expect(released).to include("### Changed")
      end
    end
  end

  # Full integration regression: the real turbo_tests2 CHANGELOG exercising all
  # three bugs simultaneously.
  describe "bug integration: turbo_tests2 CHANGELOG with H4 subsections, inline link-refs, and footer bleeding" do
    it "produces a correct released section from the turbo_tests2 fixture", freeze: Time.new(2026, 4, 7) do
      Dir.mktmpdir do |root|
        FileUtils.mkdir_p(File.join(root, "lib", "turbo_tests2"))
        File.write(File.join(root, "lib", "turbo_tests2", "version.rb"), <<~RB)
          module TurboTests2; VERSION = "3.0.0"; end
        RB
        FileUtils.mkdir_p(File.join(root, "coverage"))
        File.write(File.join(root, "coverage", "coverage.json"), {"coverage" => {}}.to_json)

        fixture_path = File.expand_path("../../support/fixtures/CHANGELOG_TURBO_TESTS2.md", __dir__)
        File.write(File.join(root, "CHANGELOG.md"), File.read(fixture_path))

        allow(Kettle::Dev::CIHelpers).to receive_messages(
          project_root: root,
          repo_info: ["galtzo-floss", "turbo_tests2"]
        )
        cli = described_class.new(strict: false)
        expect { cli.run }.not_to raise_error

        updated = File.read(File.join(root, "CHANGELOG.md"))
        # Extract just the released section: stop before the footer block
        released_start = updated.index("## [3.0.0]")
        footer_start = updated.index("\n[Unreleased]:")
        released = (released_start && footer_start) ? updated[released_start...footer_start] : ""

        # --- Sections that have real content must be present ---
        expect(released).to include("### Added")
        expect(released).to include("### Changed")
        expect(released).to include("### Fixed")

        # --- H4 subsections with content must be preserved ---
        expect(released).to include("#### From `VitalConnectInc/turbo_tests`, now part of `turbo_tests2`")
        expect(released).to include("#### New in `turbo_tests2`")

        # --- Empty sections must be absent ---
        expect(released).not_to include("### Deprecated")
        expect(released).not_to include("### Removed")
        expect(released).not_to include("### Security")

        # --- Footer link-refs must NOT appear in the released section body ---
        expect(released).not_to match(/^\[Unreleased\]:/)
        expect(released).not_to match(/^\[3\.0\.0\]:/)
        expect(released).not_to match(/^\[3\.0\.0t\]:/)

        # --- The footer must be present and correct at end of file ---
        footer = updated.lines.drop_while { |l| !l.start_with?("[Unreleased]:") }.join
        expect(footer).to include("[Unreleased]: https://github.com/galtzo-floss/turbo_tests2")
        expect(footer).to include("[3.0.0]:")
        expect(footer).to include("[3.0.0t]:")
        # The hard-fork compare SHA must be preserved (not overwritten by the git root SHA)
        expect(footer).to include("7d4064e5b8acc2f53929fccf7be3eb63f8a9f140...v3.0.0")

        # --- Unreleased section reset to empty headings ---
        expect(updated).to match(/## \[Unreleased\]\n\n### Added\n\n### Changed\n\n### Deprecated\n\n### Removed\n\n### Fixed\n\n### Security/)
      end
    end
  end

  describe "#yard_percent_documented success" do
    it "parses the documented percentage from yard output" do
      mkproj do |root|
        allow(Kettle::Dev::CIHelpers).to receive(:project_root).and_return(root)
        path = File.join(root, "bin")
        FileUtils.mkdir_p(path)
        cmd = File.join(path, "rake")
        File.write(cmd, "#!/usr/bin/env ruby\nputs 'ok'\n")
        FileUtils.chmod(0o755, cmd)
        allow(File).to receive(:executable?).and_call_original
        allow(File).to receive(:executable?).with(cmd).and_return(true)
        allow(Open3).to receive(:capture2e).and_return(["Some header\n95.5% documented\nMore lines\n", double("ps")])
        cli = described_class.new(strict: false)
        expect(cli.send(:yard_percent_documented)).to eq("95.5% documented")
      end
    end
  end

  describe "#detect_previous_version positive" do
    it "extracts the next released version heading after Unreleased" do
      cli = described_class.new(strict: false)
      after_text = <<~TXT
        ## [2.1.0] - 2025-07-07
        notes
      TXT
      expect(cli.send(:detect_previous_version, after_text)).to eq("2.1.0")
    end
  end

  describe "#update_link_refs without owner/repo" do
    it "does not append new refs when owner and repo are nil" do
      cli = described_class.new(strict: false)
      input = <<~TXT
        # Changelog
        ## [Unreleased]
        Things

        [1.0.0]: https://github.com/acme/x/compare/v0.9.0...v1.0.0
        [1.0.0t]: https://github.com/acme/x/releases/tag/v1.0.0
      TXT
      out = cli.send(:update_link_refs, input, nil, nil, "1.0.0", "1.1.0")
      expect(out).not_to include("[1.1.0]: https://github.com")
      expect(out).not_to include("[1.1.0t]: https://github.com")
      # And Unreleased ref is not added because we don't know owner/repo
      expect(out).not_to include("[Unreleased]: https://github.com/")
    end
  end

  describe "#update_link_refs spacing around footer" do
    it "ensures a blank line before the link-ref block and retains a trailing blank line" do
      cli = described_class.new(strict: false)
      input = <<~TXT
        ## [Unreleased]
        Changelog body
        [Unreleased]: https://github.com/acme/demo/compare/v1.0.0...HEAD
        [1.0.0]: https://github.com/acme/demo/compare/v0.9.0...v1.0.0
      TXT
      out = cli.send(:update_link_refs, input, "acme", "demo", "1.0.0", "1.1.0")
      # There should be exactly one blank line between body and the first ref line
      expect(out).to match(/Changelog body\n\n\[Unreleased\]:/)
      # And the output should end with a blank line (double newline at EOF)
      expect(out).to match(/\n\n\z/)
    end
  end

  describe "tag suffix transformation" do
    it "moves ([tag][Xt]) from heading suffix into first list item under heading using fixtures" do
      cli = described_class.new(strict: false)
      heading_style = File.read(File.join(__dir__, "..", "..", "support", "fixtures", "CHANGELOG_HEADING_TAGS.md"))
      list_style = File.read(File.join(__dir__, "..", "..", "support", "fixtures", "CHANGELOG_LIST_TAGS.md"))
      transformed = cli.send(:convert_heading_tag_suffix_to_list, heading_style)
      expect(transformed).to eq(list_style)
    end
  end

  describe "#backfill_historical_release!" do
    it "adds a tagged release section without moving Unreleased entries" do
      mkproj do |root|
        File.write(File.join(root, "CHANGELOG.md"), <<~MD)
          # Changelog

          ## [Unreleased]

          ### Fixed

          - Keep this pending change.

          [Unreleased]: https://github.com/acme/demo/compare/HEAD
        MD
        cli = described_class.new(strict: false, root: root)
        allow(cli).to receive(:tagged_release_date).with("1.2.3").and_return("2024-09-24")
        allow(Kettle::Dev::CIHelpers).to receive(:repo_info).and_return(["acme", "demo"])

        cli.send(:backfill_historical_release!, "1.2.3")

        changelog = File.read(File.join(root, "CHANGELOG.md"))
        expect(changelog).to include("- Keep this pending change.")
        expect(changelog).to include("## [1.2.3] - 2024-09-24")
        expect(changelog).to include("Historical release notes are unavailable in this changelog.")
      end
    end
  end

  describe "#reformat_changelog!" do
    it "canonicalizes legacy headings and removes only a redundant historical placeholder" do
      mkproj do |root|
        path = File.join(root, "CHANGELOG.md")
        File.write(path, <<~MD)
          # Changelog

          ## [Unreleased]

          ### Fixed

          - Pending fix.

          ## 1.2.3 - 2024-09-24

          - Original release notes.

          ## [1.2.3] - 2024-09-24

          ### Changed

          - Historical release notes are unavailable in this changelog.

          [Unreleased]: https://github.com/acme/demo/compare/v1.2.3...HEAD
        MD
        cli = described_class.new(strict: false, root: root)

        cli.send(:reformat_changelog!, File.read(path))

        changelog = File.read(path)
        expect(changelog).to include("## [1.2.3] - 2024-09-24")
        expect(changelog.scan("## [1.2.3]").size).to eq(1)
        expect(changelog).to include("- Original release notes.")
        expect(changelog).not_to include("Historical release notes are unavailable")
        expect(changelog).to include("[Unreleased]: https://github.com/acme/demo/compare/v1.2.3...HEAD")
      end
    end
  end

  describe "prepared release rollback" do
    it "returns a higher unpublished prepared section to Unreleased when version.rb was rolled back" do
      mkproj do |root|
        write_version(root, "3.1.0")
        path = File.join(root, "CHANGELOG.md")
        File.write(path, <<~MD)
          # Changelog

          ## [Unreleased]

          ### Fixed

          - Existing pending fix.

          ## [3.1.1] - 2024-09-25

          - TAG: [v3.1.1][3.1.1t]

          ### Added

          - Prepared feature.

          ## [3.1.0] - 2024-09-24

          - Published release notes.

          [Unreleased]: https://github.com/acme/demo/compare/v3.1.1...HEAD
          [3.1.1]: https://github.com/acme/demo/compare/v3.1.0...v3.1.1
          [3.1.1t]: https://github.com/acme/demo/releases/tag/v3.1.1
        MD
        cli = described_class.new(strict: false, root: root, yes: true)
        allow(cli).to receive_messages(
          detect_gem_name: "demo",
          latest_released_versions: ["3.1.0", "3.1.0"]
        )
        allow(Kettle::Dev::CIHelpers).to receive(:repo_info).and_return(["acme", "demo"])

        cli.run

        changelog = File.read(path)
        expect(changelog).to include("- Existing pending fix.")
        expect(changelog).to include("- Prepared feature.")
        expect(changelog).to include("## [3.1.0] - 2024-09-24")
        expect(changelog).not_to include("## [3.1.1]")
        expect(changelog).not_to include("[3.1.1]:")
      end
    end
  end
end
