# frozen_string_literal: true

RSpec.describe Kettle::Dev::GemSpecReader do
  let(:tmp_root) { File.join(Dir.mktmpdir, "proj") }
  let(:gemspec_path) { File.join(tmp_root, "demo.gemspec") }

  before do
    described_class.clear_cache!
    stub_env("FORGE_ORG" => nil)
    FileUtils.mkdir_p(tmp_root)
  end

  def write_gemspec(body)
    File.write(gemspec_path, body)
  end

  def load_info
    described_class.load(tmp_root)
  end

  context "when no gemspec exists" do
    it "returns minimal defaults when missing gemspec", :real_git_adapter do
      info = load_info
      expect(info[:gemspec_path]).to be_nil
      expect(info[:gem_name]).to eq("")
      expect(info[:min_ruby]).to be_a(Gem::Version)
      expect(info[:homepage]).to eq("")
      expect(info[:forge_org]).to eq("kettle-dev") # fallback when no homepage and no git
    end

    it "normalizes the warning path for user-facing output", :check_output do
      allow(Kernel).to receive(:warn)
      allow(Dir).to receive(:glob).and_return(["/var/home/pboling/src/kettle-dev/demo/demo.gemspec"])
      allow(Gem::Specification).to receive(:load).and_return(double("spec", name: nil, required_ruby_version: nil, homepage: nil))

      described_class.load(tmp_root)

      expect(Kernel).to have_received(:warn).with(include("Path searched: /home/pboling/src/kettle-dev/demo/demo.gemspec"))
    end
  end

  context "with a valid gemspec" do
    before do
      write_gemspec <<~G
        Gem::Specification.new do |spec|
          spec.name          = "demo-gem"
          spec.version       = "0.1.0"
          spec.summary       = "Summary"
          spec.description   = "Description"
          spec.authors       = ["A", "A"]
          spec.email         = ["a@example.com", "a@example.com"]
          spec.homepage      = "https://github.com/acme/demo-gem"
          spec.licenses      = ["MIT"]
          spec.required_ruby_version = ">= 2.3"
          spec.require_paths = ["lib"]
          spec.bindir        = "exe"
          spec.executables   = ["demo"]
        end
      G
    end

    it "extracts expected fields" do
      info = load_info
      expect(File.identical?(info[:gemspec_path], gemspec_path)).to be(true)
      expect(info[:gem_name]).to eq("demo-gem")
      expect(info[:namespace]).to eq("Demo::Gem")
      expect(info[:namespace_shield]).to eq("Demo%3A%3AGem")
      expect(info[:entrypoint_require]).to eq("demo/gem")
      expect(info[:gem_shield]).to eq("demo--gem")
      expect(info[:authors]).to eq(["A"]) # uniq
      expect(info[:email]).to eq(["a@example.com"]) # uniq
      expect(info[:summary]).to eq("Summary")
      expect(info[:description]).to eq("Description")
      expect(info[:licenses]).to eq(["MIT"])
      expect(info[:required_ruby_version].to_s).to include(">=")
      expect(info[:require_paths]).to eq(["lib"])
      expect(info[:bindir]).to eq("exe")
      expect(info[:executables]).to eq(["demo"])
      expect(info[:forge_org]).to eq("acme")
      expect(info[:gh_repo]).to eq("demo-gem")
      expect(info[:homepage]).to eq("https://github.com/acme/demo-gem")
      expect(info[:min_ruby]).to be_a(Gem::Version)
      expect(info[:min_ruby]).to be >= Gem::Version.new("2.3")
    end
  end

  context "when the gem name differs from the library entrypoint path" do
    before do
      FileUtils.mkdir_p(File.join(tmp_root, "lib", "turbo_tests"))
      File.write(File.join(tmp_root, "lib", "turbo_tests", "version.rb"), <<~RUBY)
        module TurboTests
          VERSION = "2.2.5"
        end
      RUBY

      write_gemspec <<~G
        require_relative "lib/turbo_tests/version"

        Gem::Specification.new do |spec|
          spec.name = "turbo_tests2"
          spec.version = TurboTests::VERSION
          spec.homepage = "https://github.com/acme/turbo_tests2"
          spec.required_ruby_version = ">= 2.7"
        end
      G
    end

    it "prefers the actual version file require path for entrypoint and namespace derivation" do
      info = load_info

      expect(info[:gem_name]).to eq("turbo_tests2")
      expect(info[:version]).to eq("2.2.5")
      expect(info[:entrypoint_require]).to eq("turbo_tests")
      expect(info[:namespace]).to eq("TurboTests")
      expect(info[:namespace_shield]).to eq("TurboTests")
    end
  end

  context "when handling minimum ruby edge cases" do
    it "uses RubyGems default >= 0 when requirement missing" do
      write_gemspec <<~G
        Gem::Specification.new do |spec|
          spec.name    = "x"
          spec.version = "0.0.1"
        end
      G
      info = load_info
      expect(info[:min_ruby]).to eq(Gem::Version.new("0"))
    end

    it "rescues and falls back when parsing raises (warn path)" do
      write_gemspec <<~G
        Gem::Specification.new do |spec|
          spec.name    = "y"
          spec.version = "0.0.1"
          # Create a bogus object for required_ruby_version that will blow up Requirement.parse
          spec.required_ruby_version = Object.new
        end
      G
      allow(Kettle::Dev).to receive(:debug_error)
      allow(Gem::Requirement).to receive(:parse).and_raise(StandardError.new("boom"))
      info = load_info
      expect(info[:min_ruby]).to eq(Kettle::Dev::GemSpecReader::DEFAULT_MINIMUM_RUBY)
    end
  end

  context "when detecting funding org" do
    let(:oc_yaml) { File.join(tmp_root, ".opencollective.yml") }

    # Ensure a clean env for funding detection in each example; rely on rspec-stubbed_env.
    before do
      stub_env("FUNDING_ORG" => nil, "OPENCOLLECTIVE_HANDLE" => nil)
      FileUtils.rm_f(oc_yaml)
    end

    after do
      FileUtils.rm_f(oc_yaml)
    end

    it "honors FUNDING_ORG=false bypass" do
      stub_env("FUNDING_ORG" => "false")
      write_gemspec <<~G
        Gem::Specification.new do |spec|
          spec.name    = "x"
          spec.version = "0.0.1"
        end
      G
      info = load_info
      expect(info[:funding_org]).to be_nil
    end

    it "ignores FUNDING_ORG when it contains an unresolved token placeholder" do
      stub_env("FUNDING_ORG" => "{KJ|OPENCOLLECTIVE_ORG}")
      File.write(oc_yaml, "collective: oc-from-file\n")
      write_gemspec <<~G
        Gem::Specification.new do |spec|
          spec.name    = "x"
          spec.version = "0.0.1"
        end
      G
      # Should fall through to .opencollective.yml, not use the token placeholder
      expect(load_info[:funding_org]).to eq("oc-from-file")
    end

    it "ignores FUNDING_ORG when it contains a different unresolved token placeholder" do
      stub_env("FUNDING_ORG" => "{KJ|SOME_OTHER_TOKEN}")
      File.write(oc_yaml, "collective: oc-from-file\n")
      write_gemspec <<~G
        Gem::Specification.new do |spec|
          spec.name    = "x"
          spec.version = "0.0.1"
        end
      G
      expect(load_info[:funding_org]).to eq("oc-from-file")
    end

    it "uses OPENCOLLECTIVE_HANDLE when set" do
      stub_env("OPENCOLLECTIVE_HANDLE" => "oc-acme")
      write_gemspec <<~G
        Gem::Specification.new do |spec|
          spec.name    = "x"
          spec.version = "0.0.1"
        end
      G
      expect(load_info[:funding_org]).to eq("oc-acme")
    end

    it "reads from .opencollective.yml when present", :check_output do
      File.write(oc_yaml, "org: oc-file\n")
      write_gemspec <<~G
        Gem::Specification.new do |spec|
          spec.name    = "x"
          spec.version = "0.0.1"
        end
      G
      allow(Kernel).to receive(:warn).and_call_original
      load_info
      expect(Kernel).not_to have_received(:warn).with(/Could not determine funding org/)
      expect(load_info[:funding_org]).to eq("oc-file")
    end

    it "warns when cannot determine and leaves nil", :check_output do
      write_gemspec <<~G
        Gem::Specification.new do |spec|
          spec.name    = "x"
          spec.version = "0.0.1"
        end
      G
      allow(Kernel).to receive(:warn).and_call_original
      info = load_info
      expect(Kernel).to have_received(:warn).with(/Could not determine funding org/)
      expect(info[:funding_org]).to be_nil
    end

    it "warns only once per root when metadata is loaded repeatedly", :check_output do
      write_gemspec <<~G
        Gem::Specification.new do |spec|
          spec.name    = "x"
          spec.version = "0.0.1"
        end
      G
      allow(Gem::Specification).to receive(:load).and_call_original
      warnings = []
      allow(Kernel).to receive(:warn) do |message|
        warnings << message
      end

      3.times { load_info }

      expect(Gem::Specification).to have_received(:load).with(satisfy { |path| File.identical?(path, gemspec_path) }).once
      expect(warnings.grep(/Could not determine funding org/).size).to eq(1)
    end
  end

  context "when deriving forge org via git adapter" do
    it "honors FORGE_ORG when homepage and git origin are unavailable" do
      stub_env("FORGE_ORG" => "env-org")
      write_gemspec <<~G
        Gem::Specification.new do |spec|
          spec.name    = "z"
          spec.version = "0.0.1"
        end
      G

      allow(Kettle::Dev::GitAdapter).to receive(:new).and_raise(RuntimeError.new("boom"))
      allow(Kernel).to receive(:warn)

      info = load_info

      expect(info[:forge_org]).to eq("env-org")
      expect(Kernel).not_to have_received(:warn).with(/Could not determine forge org/)
    end

    it "uses git remote origin when homepage is missing" do
      write_gemspec <<~G
        Gem::Specification.new do |spec|
          spec.name    = "z"
          spec.version = "0.0.1"
        end
      G
      fake_ga = instance_double(Kettle::Dev::GitAdapter)
      allow(Kettle::Dev::GitAdapter).to receive(:new).and_return(fake_ga)
      allow(fake_ga).to receive(:remote_url).with("origin").and_return("git@github.com:orgy/repo.git")
      info = load_info
      expect(info[:forge_org]).to eq("orgy")
      expect(info[:gh_repo]).to eq("repo")
    end

    it "is lenient when adapter errors" do
      write_gemspec <<~G
        Gem::Specification.new do |spec|
          spec.name    = "z"
          spec.version = "0.0.1"
        end
      G
      allow(Kettle::Dev::GitAdapter).to receive(:new).and_raise(RuntimeError.new("boom"))
      allow(Kettle::Dev).to receive(:debug_error)
      info = load_info
      # default in caller will warn and fallback to kettle-dev for org
      expect(info[:forge_org]).to eq("kettle-dev")
    end
  end

  context "when gemspec load raises" do
    it "rescues, logs via debug_error, and proceeds with defaults" do
      write_gemspec <<~G
        Gem::Specification.new do |spec|
          spec.name    = "boom"
          spec.version = "0.0.1"
        end
      G
      # Make RubyGems loader blow up to exercise the lenient gemspec-load rescue.
      load_error = StandardError.new("load-fail")
      allow(Gem::Specification).to receive(:load).and_raise(load_error)
      allow(Kettle::Dev).to receive(:debug_error)
      allow(Kernel).to receive(:warn).and_call_original

      info = load_info

      expect(Kettle::Dev).to have_received(:debug_error).with(load_error, :load)
      expect(File.identical?(info[:gemspec_path], gemspec_path)).to be(true)
      expect(info[:gem_name]).to eq("") # falls back when spec could not be loaded
      expect(Kernel).to have_received(:warn).with(/Could not derive gem name/)
    end
  end

  context "when funding detection raises unexpectedly" do
    it "rescues, logs, and re-raises Kettle::Dev::Error" do
      # Ensure env does not short-circuit funding detection (deterministic on CI)
      stub_env("FUNDING_ORG" => nil, "OPENCOLLECTIVE_HANDLE" => nil)

      write_gemspec <<~G
        Gem::Specification.new do |spec|
          spec.name    = "x"
          spec.version = "0.0.1"
        end
      G
      # Force the file branch, then make File.read explode to hit rescue at 126-127
      oc_yaml = File.join(tmp_root, ".opencollective.yml")
      File.write(oc_yaml, "org: oc-file\n")
      allow(File).to receive(:read).and_raise(StandardError.new("bad read"))
      allow(Kettle::Dev).to receive(:debug_error)

      expect { load_info }.to raise_error(Kettle::Dev::Error, /Unable to determine funding org/)
      expect(Kettle::Dev).to have_received(:debug_error).at_least(:once)
    end
  end
end
