# frozen_string_literal: true

require "stringio"

RSpec.describe Kettle::Dev::PreReleaseCLI do
  let(:gha_sha_pins_cli) { instance_double(Kettle::Dev::GhaShaPinsCLI, run!: 0) }

  before do
    stub_env("KETTLE_IMAGE_URL_CACHE" => "false")
    allow(Kettle::Dev::GhaShaPinsCLI).to receive(:new).and_return(gha_sha_pins_cli)
  end

  it "emits pre-release events around checks", :check_output do
    io = StringIO.new
    event_recorder = Kettle::Ndjson.event_stream(io, types: "pre_release")
    allow(Kettle::Dev::PreReleaseCLI::Markdown).to receive_messages(
      project_markdown_files: [],
      extract_image_urls_from_files: []
    )

    described_class.new(check_num: 1, event_recorder: event_recorder).run

    events = io.string.lines.map { |line| JSON.parse(line) }
    expect(events).to include(
      include("type" => "pre_release", "action" => "check", "check" => "github_actions_sha_pins", "status" => "started", "index" => 1, "total" => 4, "mark" => ">"),
      include("type" => "pre_release", "action" => "check", "check" => "github_actions_sha_pins", "status" => "ok", "index" => 1, "total" => 4, "mark" => "."),
      include("type" => "pre_release", "action" => "markdown_urls", "status" => "ok", "candidates" => 0, "changed_files" => 0, "mark" => "."),
      include("type" => "pre_release", "action" => "markdown_references", "status" => "ok", "references" => 0, "local_targets" => 0, "failures" => 0, "mark" => "."),
      include("type" => "pre_release", "action" => "image_links", "status" => "ok", "urls" => 0, "failures" => 0, "mark" => ".")
    )
  end

  it "normalizes unicode URLs in markdown files (check 2)" do
    Dir.mktmpdir do |root|
      file = File.join(root, "README.md")
      url = "https://img.shields.io/badge/buy_me_a_coffee-\u2713-a51611.svg?style=flat"
      md = "![coffee](#{url})\n"
      File.write(file, md)

      # rubocop:disable ThreadSafety/DirChdir
      Dir.chdir(root) do
        cli = described_class.new(check_num: 2)
        # Avoid running actual HTTP in check 2 for this example; focus on check 1 behavior
        allow(Kettle::Dev::PreReleaseCLI::Markdown).to receive(:extract_image_urls_from_files).and_return([])
        # Wrap in VCR so any incidental HTTP is blocked deterministically
        VCR.use_cassette("head_image_ok") do
          expect { cli.run }.not_to raise_error
        end
        content = File.read(file)
        # After normalization, the URL should not be exactly equal to the raw unicode url string
        # (Addressable will percent-encode the checkmark in path)
        expect(content).not_to include(url)
        # And it should still be a shields URL
        expect(content).to include("https://img.shields.io/badge/")
      end
      # rubocop:enable ThreadSafety/DirChdir
    end
  end

  it "keeps encoded image query values stable while normalizing markdown URLs" do
    Dir.mktmpdir do |root|
      file = File.join(root, "README.md")
      url = "https://img.shields.io/discourse/topics?server=https%3A%2F%2Fwww.rubyforum.org&style=flat&label=Ruby%20Users%20Forum"
      File.write(file, "![forum](#{url})\n")

      # rubocop:disable ThreadSafety/DirChdir
      Dir.chdir(root) do
        cli = described_class.new(check_num: 2)
        allow(Kettle::Dev::PreReleaseCLI::Markdown).to receive(:extract_image_urls_from_files).and_return([])

        VCR.use_cassette("head_image_ok") do
          expect { cli.run }.not_to raise_error
        end
      end
      # rubocop:enable ThreadSafety/DirChdir

      expect(File.read(file)).to include(url)
    end
  end

  it "preserves Kettle-Jem template tokens while normalizing markdown URLs" do
    url = "https://img.shields.io/badge/name-{KJ|GEM_SHIELD}-3C2D2D.svg?style=square"

    expect(described_class.new.send(:normalized_markdown_image_url, url)).to eq(url)
  end

  describe Kettle::Dev::PreReleaseCLI::Markdown do
    it "extracts inline, reference, and html image urls" do
      md = <<~MD
        ![alt](https://example.com/a.png)
        ![alt][ref]
        [ref]: https://example.com/b.jpg
        <img src="https://example.com/c.gif" />
        <img src='https://example.com/d.webp'>
        ![alt](./local.png)
      MD
      urls = described_class.extract_image_urls_from_text(md)
      expect(urls).to contain_exactly(
        "https://example.com/a.png",
        "https://example.com/b.jpg",
        "https://example.com/c.gif",
        "https://example.com/d.webp"
      )
    end

    it "extracts from files matching glob and de-duplicates" do
      Dir.mktmpdir do |root|
        f1 = File.join(root, "a.md")
        f2 = File.join(root, "b.md")
        File.write(f1, "![x](https://e.com/a.png)\n")
        File.write(f2, "![x](https://e.com/a.png) ![y](https://e.com/b.png)\n")
        # Avoid Dir.chdir for thread safety; pass absolute glob
        urls = described_class.extract_image_urls_from_files(File.join(root, "*.md"))
        expect(urls.sort).to eq(["https://e.com/a.png", "https://e.com/b.png"])
      end
    end

    it "excludes scratch markdown artifacts from project file discovery" do
      Dir.mktmpdir do |root|
        readme = File.join(root, "README.md")
        scratch = File.join(root, "tmp", "template_test", "output", "README.md")
        FileUtils.mkdir_p(File.dirname(scratch))
        File.write(readme, "![current](https://example.com/current.svg)\n")
        File.write(scratch, "![stale](https://example.com/stale.svg)\n")

        allow(described_class).to receive(:tracked_markdown_files).and_return([])

        # rubocop:disable ThreadSafety/DirChdir
        Dir.chdir(root) do
          expect(described_class.project_markdown_files).to contain_exactly("README.md")
          expect(described_class.extract_image_urls_from_files).to contain_exactly("https://example.com/current.svg")
        end
        # rubocop:enable ThreadSafety/DirChdir
      end
    end

    it "excludes Markdown test fixtures from project file discovery" do
      Dir.mktmpdir do |root|
        readme = File.join(root, "README.md")
        fixture = File.join(root, "spec", "fixtures", "README.md")
        FileUtils.mkdir_p(File.dirname(fixture))
        File.write(readme, "![current](https://example.com/current.svg)\n")
        File.write(fixture, "![stale](https://example.com/stale.svg)\n")

        allow(described_class).to receive(:tracked_markdown_files).and_return([])

        # rubocop:disable ThreadSafety/DirChdir
        Dir.chdir(root) do
          expect(described_class.project_markdown_files).to contain_exactly("README.md")
          expect(described_class.extract_image_urls_from_files).to contain_exactly("https://example.com/current.svg")
        end
        # rubocop:enable ThreadSafety/DirChdir
      end
    end
  end

  describe Kettle::Dev::PreReleaseCLI::HTTP do
    it "returns false on unsupported scheme" do
      expect {
        described_class.head_ok?("ftp://example.com/a")
      }.to raise_error(ArgumentError)
    end

    # rubocop:disable RSpec/VerifiedDoubles
    it "falls back to GET when method not allowed and returns true on success" do
      method_not_allowed = double("MethodNotAllowed")
      allow(method_not_allowed).to receive(:is_a?).with(Net::HTTPMethodNotAllowed).and_return(true)

      success = double("Success")
      allow(success).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)

      http = double("HTTP")
      # Simulate Net::HTTP.start yielding http and returning the block value
      allow(http).to receive(:start).and_yield(http)
      # First request returns method not allowed; second (GET) returns success
      allow(http).to receive(:request).and_return(method_not_allowed, success)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:ssl_timeout=)
      allow(http).to receive(:verify_mode=)
      allow(http).to receive(:use_ssl?).and_return(true)

      allow(Net::HTTP).to receive(:new).and_return(http)

      expect(described_class.head_ok?("https://example.org/x")).to be(true)
    end
    # rubocop:enable RSpec/VerifiedDoubles

    it "performs a HEAD request for an image URL using VCR and replays it across specs", :vcr do
      # Use a stable endpoint that supports HEAD with 200 response
      url = "https://httpbin.org/image/png"
      VCR.use_cassette("head_image_ok") do
        expect(described_class.head_ok?(url)).to be(true)
      end
    end
  end

  describe "CLI run flow" do
    it "runs checks 1 through 4 and completes without abort when all links pass", :check_output do
      cli = described_class.new(check_num: 1)
      # Provide a deterministic URL and use VCR to avoid network
      allow(Kettle::Dev::PreReleaseCLI::Markdown).to receive_messages(
        project_markdown_files: [],
        extract_image_urls_from_files: ["https://httpbin.org/image/png"]
      )
      expect {
        VCR.use_cassette("head_image_ok") { cli.run }
      }.not_to raise_error
      expect(Kettle::Dev::GhaShaPinsCLI).to have_received(:new).with(["--root", Dir.pwd, "--check", "--upgrade", "major"])
    end

    it "aborts with the SHA pin recommendation when GitHub Actions pins are stale" do
      allow(gha_sha_pins_cli).to receive(:run!).and_return(3)
      cli = described_class.new(check_num: 1)

      expect { cli.run }.to raise_error(MockSystemExit, /GitHub Actions SHA pin validation failed/)
    end

    it "uses the persistent GitHub Actions pin cache when explicitly requested" do
      stub_env("KETTLE_PRE_RELEASE_GHA_SHA_PINS_OFFLINE" => "true")
      cli = described_class.new(check_num: 1)

      expect { cli.send(:check_github_actions_sha_pins!) }.not_to raise_error
      expect(Kettle::Dev::GhaShaPinsCLI).to have_received(:new).with(
        ["--root", Dir.pwd, "--check", "--upgrade", "major", "--offline"]
      )
    end

    it "aborts via ExitAdapter when HTTP failures occur in check 3" do
      cli = described_class.new(check_num: 4)
      allow(Kettle::Dev::PreReleaseCLI::Markdown).to receive(:extract_image_urls_from_files).and_return([
        "https://httpbin.org/image/png", "https://example.invalid/missing.png"
      ])
      # First will be OK via cassette; second will fail (no cassette and blocked net), so stub head_ok? only for failure path
      allow(Kettle::Dev::PreReleaseCLI::HTTP).to receive(:head_ok?).and_wrap_original do |m, url|
        if url.include?("httpbin.org")
          VCR.use_cassette("head_image_ok") { m.call(url) }
        else
          false
        end
      end
      expect { cli.run }.to raise_error(MockSystemExit)
    end

    it "uses fresh successful image URL cache entries instead of repeating HTTP checks", freeze: Time.utc(2026, 6, 16, 12, 0, 0) do
      Dir.mktmpdir do |root|
        cache_path = File.join(root, "image-url-cache.json")
        cache = Kettle::Dev::PreReleaseCLI::ImageUrlCache.new(path: cache_path)
        cache.write_success("https://example.com/logo.svg")

        stub_env("KETTLE_IMAGE_URL_CACHE" => cache_path, "KETTLE_IMAGE_URL_CACHE_REFRESH" => "false")
        allow(Kettle::Dev::PreReleaseCLI::Markdown).to receive(:extract_image_urls_from_files).and_return([
          "https://example.com/logo.svg"
        ])
        expect(Kettle::Dev::PreReleaseCLI::HTTP).not_to receive(:head_ok?)

        expect { described_class.new(check_num: 4).run }
          .to output(/Image URL checks: 1 cached, 0 live\./).to_stdout
      end
    end

    it "renders image cache, live, and skipped progress on separate TTY lines" do
      output = StringIO.new
      allow(output).to receive(:tty?).and_return(true)
      progress = Kettle::Dev::CacheProgress.new(
        total: 3,
        cached_title: "Images cached",
        live_title: "Images live",
        skipped_title: "Images skipped",
        output: output
      )

      progress.cached
      progress.live
      progress.skipped
      progress.stop

      expect(progress.cached_count).to eq(1)
      expect(progress.live_count).to eq(1)
      expect(progress.skipped_count).to eq(1)
      expect(output.string).to include("Images cached")
      expect(output.string).to include("Images live")
      expect(output.string).to include("Images skipped")
    end

    it "skips built-in volatile generated image URLs by default" do
      allow(Kettle::Dev::PreReleaseCLI::Markdown).to receive_messages(
        project_markdown_files: [],
        extract_image_urls_from_files: [
          "https://api.star-history.com/svg?repos=kettle-dev/kettle-test&type=Date",
          "https://star-history.dera.page/svg?repos=kettle-dev/kettle-test&type=date&legend=top-left",
          "https://contrib.rocks/image?repo=kettle-dev/kettle-test"
        ]
      )
      expect(Kettle::Dev::PreReleaseCLI::HTTP).not_to receive(:head_ok?)

      expect { described_class.new(check_num: 3).run }
        .to output(/Image URL checks: 0 cached, 0 live\.\n\[kettle-pre-release\] Skipped 3 image URL check\(s\)\./).to_stdout
    end

    it "skips unresolved Kettle-Jem template image URLs" do
      allow(Kettle::Dev::PreReleaseCLI::Markdown).to receive(:extract_image_urls_from_files).and_return([
        "https://contrib.rocks/image?repo={KJ|README:CONTRIBUTORS_IMAGE_REPO}"
      ])
      expect(Kettle::Dev::PreReleaseCLI::HTTP).not_to receive(:head_ok?)

      expect { described_class.new(check_num: 4).run }
        .to output(/Image URL checks: 0 cached, 0 live\.\n\[kettle-pre-release\] Skipped 1 image URL check\(s\)\./).to_stdout
    end

    it "skips a current-repository workflow badge until its local workflow is pushed" do
      Dir.mktmpdir do |root|
        workflow_path = File.join(root, ".github", "workflows", "new-workflow.yml")
        FileUtils.mkdir_p(File.dirname(workflow_path))
        File.write(workflow_path, "name: New workflow\n")
        allow(Open3).to receive(:capture2)
          .with("git", "config", "--get", "remote.origin.url")
          .and_return(["git@github.com:example/project.git", instance_double(Process::Status, success?: true)])

        # rubocop:disable ThreadSafety/DirChdir
        Dir.chdir(root) do
          allow(Kettle::Dev::PreReleaseCLI::Markdown).to receive(:extract_image_urls_from_files).and_return([
            "https://github.com/example/project/actions/workflows/new-workflow.yml/badge.svg"
          ])
          expect(Kettle::Dev::PreReleaseCLI::HTTP).not_to receive(:head_ok?)

          expect { described_class.new(check_num: 4).run }
            .to output(/Skipped 1 image URL check/).to_stdout
        end
        # rubocop:enable ThreadSafety/DirChdir
      end
    end

    it "skips image URLs matched by kettle-family config patterns" do
      Dir.mktmpdir do |root|
        File.write(File.join(root, ".kettle-family.yml"), <<~YAML)
          pre_release:
            image_url_skip_patterns:
              - https://assets.example.com/generated/*
        YAML

        # rubocop:disable ThreadSafety/DirChdir
        Dir.chdir(root) do
          allow(Kettle::Dev::PreReleaseCLI::Markdown).to receive(:extract_image_urls_from_files).and_return([
            "https://assets.example.com/generated/badge.svg",
            "https://assets.example.com/stable/logo.svg"
          ])
          allow(Kettle::Dev::PreReleaseCLI::HTTP).to receive(:head_ok?).and_return(true)

          expect { described_class.new(check_num: 4).run }.not_to raise_error

          expect(Kettle::Dev::PreReleaseCLI::HTTP).to have_received(:head_ok?).once.with("https://assets.example.com/stable/logo.svg")
        end
        # rubocop:enable ThreadSafety/DirChdir
      end
    end

    it "loads kettle-family skip patterns from KETTLE_FAMILY_CONFIG" do
      Dir.mktmpdir do |root|
        config_path = File.join(root, "family.yml")
        File.write(config_path, <<~YAML)
          pre_release:
            image_url_skip_patterns:
              - https://volatile.example.com/*
        YAML

        stub_env("KETTLE_FAMILY_CONFIG" => config_path)
        allow(Kettle::Dev::PreReleaseCLI::Markdown).to receive(:extract_image_urls_from_files).and_return([
          "https://volatile.example.com/badge.svg"
        ])
        expect(Kettle::Dev::PreReleaseCLI::HTTP).not_to receive(:head_ok?)

        expect { described_class.new(check_num: 4).run }.not_to raise_error
      end
    end

    it "refreshes stale image URL cache entries and records successful revalidation", freeze: Time.utc(2026, 6, 16, 12, 0, 0) do
      Dir.mktmpdir do |root|
        cache_path = File.join(root, "image-url-cache.json")
        Timecop.freeze(Time.utc(2026, 6, 1, 12, 0, 0)) do
          Kettle::Dev::PreReleaseCLI::ImageUrlCache.new(path: cache_path).write_success("https://example.com/logo.svg")
        end

        stub_env("KETTLE_IMAGE_URL_CACHE" => cache_path)
        allow(Kettle::Dev::PreReleaseCLI::Markdown).to receive(:extract_image_urls_from_files).and_return([
          "https://example.com/logo.svg"
        ])
        allow(Kettle::Dev::PreReleaseCLI::HTTP).to receive(:head_ok?).and_return(true)

        expect { described_class.new(check_num: 4).run }.not_to raise_error

        expect(Kettle::Dev::PreReleaseCLI::HTTP).to have_received(:head_ok?).with("https://example.com/logo.svg")
        cached_at = JSON.parse(File.read(cache_path)).dig("images", "https://example.com/logo.svg", "cached_at")
        expect(Time.iso8601(cached_at)).to be > Time.utc(2026, 6, 1, 12, 0, 0)
      end
    end

    it "does not cache failed image URL validations" do
      Dir.mktmpdir do |root|
        cache_path = File.join(root, "image-url-cache.json")
        stub_env("KETTLE_IMAGE_URL_CACHE" => cache_path)
        allow(Kettle::Dev::PreReleaseCLI::Markdown).to receive(:extract_image_urls_from_files).and_return([
          "https://example.com/missing.svg"
        ])
        allow(Kettle::Dev::PreReleaseCLI::HTTP).to receive(:head_ok?).and_return(false)

        expect { described_class.new(check_num: 4).run }.to raise_error(MockSystemExit)

        cached = File.file?(cache_path) ? JSON.parse(File.read(cache_path)) : {}
        expect(cached.fetch("images", {})).not_to include("https://example.com/missing.svg")
      end
    end

    it "bypasses fresh image URL cache entries when refresh is requested", freeze: Time.utc(2026, 6, 16, 12, 0, 0) do
      Dir.mktmpdir do |root|
        cache_path = File.join(root, "image-url-cache.json")
        cache = Kettle::Dev::PreReleaseCLI::ImageUrlCache.new(path: cache_path)
        cache.write_success("https://example.com/logo.svg")

        stub_env(
          "KETTLE_IMAGE_URL_CACHE" => cache_path,
          "KETTLE_IMAGE_URL_CACHE_REFRESH" => "true"
        )
        allow(Kettle::Dev::PreReleaseCLI::Markdown).to receive(:extract_image_urls_from_files).and_return([
          "https://example.com/logo.svg"
        ])
        allow(Kettle::Dev::PreReleaseCLI::HTTP).to receive(:head_ok?).and_return(true)

        expect { described_class.new(check_num: 4).run }.not_to raise_error

        expect(Kettle::Dev::PreReleaseCLI::HTTP).to have_received(:head_ok?).with("https://example.com/logo.svg")
      end
    end

    it "respects starting check index (no-op when > number of checks)" do
      cli = described_class.new(check_num: 5)
      expect { cli.run }.not_to raise_error
    end
  end

  describe "more edge cases for coverage" do
    describe Kettle::Dev::PreReleaseCLI::HTTP do
      it "falls back to URI.parse when Addressable::URI is not defined" do
        url = "http://example.com/x"
        # Temporarily hide Addressable::URI constant if present
        if defined?(Addressable::URI)
          hide_const("Addressable::URI")
        end
        uri = described_class.parse_http_uri(url)
        expect(uri).to be_a(URI::HTTP)
      end

      # rubocop:disable RSpec/VerifiedDoubles
      it "returns false when redirection has no location header" do
        redir = double("Redirection")
        allow(redir).to receive(:is_a?) { |k| k == Net::HTTPRedirection }
        allow(redir).to receive(:[]).with("location").and_return(nil)

        http = double("HTTP")
        allow(http).to receive(:use_ssl=)
        allow(http).to receive(:read_timeout=)
        allow(http).to receive(:open_timeout=)
        allow(http).to receive(:ssl_timeout=)
        allow(http).to receive(:verify_mode=)
        allow(http).to receive_messages(use_ssl?: true, request: redir)
        allow(http).to receive(:start).and_yield(http)

        allow(Net::HTTP).to receive(:new).and_return(http)

        expect(described_class.head_ok?("https://example.com/start")).to be(false)
      end

      it "returns false for non-success, non-redirection, non-method-not-allowed responses" do
        failure = double("Failure")
        allow(failure).to receive(:is_a?).with(Net::HTTPMethodNotAllowed).and_return(false)

        http = double("HTTP")
        allow(http).to receive(:use_ssl=)
        allow(http).to receive(:read_timeout=)
        allow(http).to receive(:open_timeout=)
        allow(http).to receive(:ssl_timeout=)
        allow(http).to receive(:verify_mode=)
        allow(http).to receive_messages(use_ssl?: true, request: failure)
        allow(http).to receive(:start).and_yield(http)

        allow(Net::HTTP).to receive(:new).and_return(http)

        expect(described_class.head_ok?("https://example.org/x")).to be(false)
      end

      it "rescues network errors and returns false" do
        http = double("HTTP")
        allow(http).to receive(:use_ssl=)
        allow(http).to receive(:read_timeout=)
        allow(http).to receive(:open_timeout=)
        allow(http).to receive(:ssl_timeout=)
        allow(http).to receive(:verify_mode=)
        allow(http).to receive(:use_ssl?).and_return(true)
        allow(http).to receive(:start).and_raise(Timeout::Error)

        allow(Net::HTTP).to receive(:new).and_return(http)

        expect(described_class.head_ok?("https://example.org/x")).to be(false)
      end
      # rubocop:enable RSpec/VerifiedDoubles

      it "raises on too many redirects (limit <= 0)" do
        # No Net::HTTP stubbing needed; the error is raised before any network
        expect {
          described_class.head_ok?("https://example.org/x", limit: 0)
        }.to raise_error(ArgumentError, /too many redirects/)
      end
    end

    describe Kettle::Dev::PreReleaseCLI::Markdown do
      it "handles file read errors gracefully and still returns unique urls" do
        Dir.mktmpdir do |root|
          bad = File.join(root, "bad.md")
          File.write(bad, "![x](https://e.com/a.png)\n")
          glob = File.join(root, "*.md")
          allow(File).to receive(:read).and_wrap_original do |original, path, *args|
            raise Errno::EACCES, path if File.basename(path) == "bad.md"

            original.call(path, *args)
          end

          urls = described_class.extract_image_urls_from_files(glob)
          expect(urls).to be_empty
        end
      end
    end

    describe "check 1 error handling" do
      it "skips files that cannot be read" do
        Dir.mktmpdir do |root|
          good = File.join(root, "good.md")
          bad = File.join(root, "bad.md")
          File.write(good, "# Title\n")
          File.write(bad, "# Bad\n")
          # rubocop:disable ThreadSafety/DirChdir
          Dir.chdir(root) do
            cli = described_class.new(check_num: 1)
            allow(File).to receive(:read).and_call_original
            allow(File).to receive(:read).with(bad).and_raise(Errno::EACCES)
            expect { cli.run }.not_to raise_error
          end
          # rubocop:enable ThreadSafety/DirChdir
        end
      end

      it "warns but continues when write fails for a modified file" do
        Dir.mktmpdir do |root|
          file = File.join(root, "README.md")
          url = "https://img.shields.io/badge/buy_me_a_coffee-\u2713-a51611.svg?style=flat"
          File.write(file, "![x](#{url})\n")
          # rubocop:disable ThreadSafety/DirChdir
          Dir.chdir(root) do
            cli = described_class.new(check_num: 1)
            allow(File).to receive(:write).and_call_original
            allow(File).to receive(:write).with(file, kind_of(String)).and_raise(Errno::EACCES)
            # Avoid running check 2 by stubbing out URLs discovery
            allow(Kettle::Dev::PreReleaseCLI::Markdown).to receive(:extract_image_urls_from_files).and_return([])
            expect { cli.run }.not_to raise_error
          end
          # rubocop:enable ThreadSafety/DirChdir
        end
      end
    end
  end
end
