# frozen_string_literal: true

RSpec.describe Kettle::Dev::VersionBump, :check_output, :prism_only do
  around do |example|
    begin
      Dir.mktmpdir do |root|
        @root = root
        example.run
      end
    ensure
      Kettle::Dev::GemSpecReader.clear_cache!
    end
  end

  it "resolves relative bump targets from a supplied current version" do
    expect(described_class.resolve_target_version("patch", "1.2.3")).to eq("1.2.4")
    expect(described_class.resolve_target_version("minor", "1.2.3")).to eq("1.3.0")
    expect(described_class.resolve_target_version("major", "1.2.3")).to eq("2.0.0")
    expect(described_class.resolve_target_version("pre", "1.2.3.rc9")).to eq("1.2.3.rd0")
  end

  it "resolves patch bumps from prerelease versions to the matching full release" do
    expect(described_class.resolve_target_version("patch", "3.0.pre")).to eq("3.0.0")
    expect(described_class.resolve_target_version("patch", "3.0.0.rc6")).to eq("3.0.0")
    expect(described_class.resolve_target_version("patch", "3.0.5.pre")).to eq("3.0.5")
  end

  it "collects version file and literal gemspec version edits without writing" do
    version_file, gemspec_path = write_project(version: "1.2.3")

    bump = described_class.new(root: @root, target_version: "patch")
    edits = bump.edits

    expect(bump.current_version).to eq("1.2.3")
    expect(bump.target_version).to eq("1.2.4")
    expect(edits.map { |edit| File.basename(edit.fetch(:path)) }).to contain_exactly("version.rb", "demo.gemspec")
    expect(edits.any? { |edit| Kettle::Dev::Paths.same?(edit[:path], version_file) }).to be(true)
    expect(edits.any? { |edit| Kettle::Dev::Paths.same?(edit[:path], gemspec_path) }).to be(true)
    expect(File.read(version_file)).to include('VERSION = "1.2.3"')
    expect(File.read(gemspec_path)).to include('spec.version = "1.2.3"')
  end

  it "writes collected edits through the shared writer" do
    version_file, gemspec_path = write_project(version: "1.2.3")
    bump = described_class.new(root: @root, target_version: "1.2.4")

    described_class.write_edits(bump.edits)

    expect(File.read(version_file)).to include('VERSION = "1.2.4"')
    expect(File.read(gemspec_path)).to include('spec.version = "1.2.4"')
  end

  it "writes Prism byte-offset edits after non-ASCII content" do
    _version_file, gemspec_path = write_project(version: "1.2.3", pre_version_content: 'spec.summary = "🔖 release metadata"')
    bump = described_class.new(root: @root, target_version: "1.2.4")

    described_class.write_edits(bump.edits)

    content = File.read(gemspec_path)
    expect(content).to include('spec.summary = "🔖 release metadata"')
    expect(content).to include('spec.version = "1.2.4"')
    expect(RubyVM::InstructionSequence.compile(content)).to be_a(RubyVM::InstructionSequence) if defined?(RubyVM::InstructionSequence)
  end

  it "updates literal versions inside conditional gemspec loaders" do
    version_file, gemspec_path = write_project(version: "1.2.3")
    File.write(gemspec_path, <<~RUBY)
      gem_version =
        if Gem.ruby_version >= Gem::Version.new("3.1")
          "modern"
        elsif Gem.ruby_version >= Gem::Version.new("2.2")
          "anonymous"
        else
          "1.2.3"
        end

      Gem::Specification.new do |spec|
        spec.name = "demo"
        spec.version = gem_version
      end
    RUBY

    bump = described_class.new(root: @root, target_version: "1.2.4")
    described_class.write_edits(bump.edits)

    expect(File.read(version_file)).to include('VERSION = "1.2.4"')
    expect(File.read(gemspec_path)).to include('"1.2.4"')
    expect(File.read(gemspec_path)).not_to include('else\n    "1.2.3"')
  end

  def write_project(version:, pre_version_content: nil)
    FileUtils.mkdir_p(File.join(@root, "lib", "demo"))
    version_file = File.join(@root, "lib", "demo", "version.rb")
    File.write(version_file, <<~RUBY)
      module Demo
        VERSION = "#{version}"
      end
    RUBY
    gemspec_path = File.join(@root, "demo.gemspec")
    File.write(gemspec_path, <<~RUBY)
      Gem::Specification.new do |spec|
        spec.name = "demo"
        #{pre_version_content}
        spec.version = "#{version}"
      end
    RUBY
    Kettle::Dev::GemSpecReader.clear_cache!
    [version_file, gemspec_path]
  end
end
