# frozen_string_literal: true

RSpec.describe Kettle::Dev::BundlerPinning do
  def gem_spec_double(version)
    instance_double(Gem::Specification, version: Gem::Version.new(version))
  end

  def stub_installed_bundlers(loaded: nil, installed: [])
    allow(Gem).to receive(:loaded_specs).and_call_original
    loaded_specs = Gem.loaded_specs.dup
    if loaded
      loaded_specs["bundler"] = gem_spec_double(loaded)
    else
      loaded_specs.delete("bundler")
    end
    allow(Gem).to receive(:loaded_specs).and_return(loaded_specs)
    allow(Gem::Specification).to receive(:find_all_by_name).and_call_original
    allow(Gem::Specification).to receive(:find_all_by_name).with("bundler").and_return(installed.map { |v| gem_spec_double(v) })
  end

  describe ".installed_stable" do
    it "returns the newest stable across the activated and installed specs" do
      stub_installed_bundlers(loaded: "4.0.21", installed: ["4.0.21", "4.0.23", "4.1.0.beta1"])

      expect(described_class.installed_stable).to eq(Gem::Version.new("4.0.23"))
    end

    it "considers the activated spec when the installed list is older" do
      stub_installed_bundlers(loaded: "4.0.23", installed: ["4.0.21"])

      expect(described_class.installed_stable).to eq(Gem::Version.new("4.0.23"))
    end

    it "returns nil when no stable bundler is installed" do
      stub_installed_bundlers(loaded: nil, installed: ["4.1.0.beta1"])

      expect(described_class.installed_stable).to be_nil
    end
  end

  describe ".published_stable" do
    it "returns the newest stable version the registry serves" do
      allow(Kettle::Dev::RubyGemsVersions).to receive(:published_version_numbers)
        .with("bundler")
        .and_return(["4.0.22", "4.0.23", "4.1.0.beta1"])

      expect(described_class.published_stable).to eq(Gem::Version.new("4.0.23"))
    end

    it "skips unparseable version numbers" do
      allow(Kettle::Dev::RubyGemsVersions).to receive(:published_version_numbers)
        .with("bundler")
        .and_return(["not-a-version", "4.0.23"])

      expect(described_class.published_stable).to eq(Gem::Version.new("4.0.23"))
    end

    it "returns nil when the registry cannot be consulted" do
      allow(Kettle::Dev::RubyGemsVersions).to receive(:published_version_numbers).with("bundler").and_return(nil)

      expect(described_class.published_stable).to be_nil
    end
  end

  describe ".install_stable" do
    let(:installer) { instance_double(Gem::DependencyInstaller, install: [gem_spec_double("4.0.23")]) }

    before do
      allow(Gem::DependencyInstaller).to receive(:new)
        .with(domain: :remote, prerelease: false, document: [])
        .and_return(installer)
      allow(Gem::Specification).to receive(:reset)
    end

    it "installs the exact version given and resets the specification index" do
      described_class.install_stable("4.0.23")

      expect(installer).to have_received(:install).with("bundler", "= 4.0.23")
      expect(Gem::Specification).to have_received(:reset)
    end

    it "installs the latest stable when no version is given" do
      described_class.install_stable

      expect(installer).to have_received(:install).with("bundler")
    end

    it "scopes the install to rubygems.org and restores the original sources" do
      original = Gem.sources.to_a

      described_class.install_stable("4.0.23")

      expect(Gem.sources.to_a).to eq(original)
    end
  end

  describe ".ensure_latest_stable" do
    it "installs and returns the registry version when it is newer than the executing one" do
      allow(described_class).to receive(:published_stable).and_return(Gem::Version.new("4.0.23"))
      allow(described_class).to receive(:install_stable)

      expect(described_class.ensure_latest_stable(executing: "4.0.22")).to eq("4.0.23")
      expect(described_class).to have_received(:install_stable).with(Gem::Version.new("4.0.23"))
    end

    it "returns the executing version when the registry is not newer" do
      allow(described_class).to receive(:published_stable).and_return(Gem::Version.new("4.0.22"))
      allow(described_class).to receive(:install_stable)

      expect(described_class.ensure_latest_stable(executing: "4.0.22")).to eq("4.0.22")
      expect(described_class).not_to have_received(:install_stable)
    end

    it "fails open to the executing version when the registry cannot be consulted" do
      allow(described_class).to receive(:published_stable).and_return(nil)
      allow(described_class).to receive(:install_stable)

      expect(described_class.ensure_latest_stable(executing: "4.0.22")).to eq("4.0.22")
      expect(described_class).not_to have_received(:install_stable)
    end
  end

  describe ".update_argv" do
    it "pins both the executable selector and the --bundler flag" do
      expect(described_class.update_argv("4.0.23")).to eq(["bundle", "_4.0.23_", "update", "--bundler=4.0.23"])
    end

    it "places extra gems between update and the pin" do
      expect(described_class.update_argv("4.0.23", extra_gems: ["nomono"]))
        .to eq(["bundle", "_4.0.23_", "update", "nomono", "--bundler=4.0.23"])
    end
  end
end
