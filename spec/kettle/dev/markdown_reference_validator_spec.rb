# frozen_string_literal: true

RSpec.describe Kettle::Dev::MarkdownReferenceValidator do
  def write_markdown(root, path, content)
    full_path = File.join(root, path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, content)
  end

  it "accepts defined references and local heading anchors" do
    Dir.mktmpdir do |root|
      write_markdown(root, "README.md", <<~MD)
        # Project Guide

        [guide][docs]
        [docs]: docs/guide.md#installation
        [inline](docs/guide.md#usage)
      MD
      write_markdown(root, "docs/guide.md", <<~MD)
        # Installation

        Usage
        -----
      MD

      report = described_class.new(root: root, files: ["README.md", "docs/guide.md"]).validate!

      expect(report.file_count).to eq(2)
      expect(report.reference_count).to eq(1)
      expect(report.local_target_count).to eq(2)
      expect(report.issues).to be_empty
    end
  end

  it "reports undefined references, missing files, and missing headings" do
    Dir.mktmpdir do |root|
      write_markdown(root, "README.md", <<~MD)
        [missing][not-defined]
        [bad-file](docs/nope.md#section)
        [bad-heading](docs/guide.md#unknown)
      MD
      write_markdown(root, "docs/guide.md", "# Existing Section\n")

      expect {
        described_class.new(root: root, files: ["README.md", "docs/guide.md"]).validate!
      }.to raise_error(Kettle::Dev::Error, /3 issue\(s\)/)
    end
  end

  it "ignores references and headings inside fenced code" do
    Dir.mktmpdir do |root|
      write_markdown(root, "README.md", <<~MD)
        ```markdown
        [not-a-link][missing]
        [missing]: nowhere.md
        # Not a heading
        ```
      MD

      report = described_class.new(root: root, files: ["README.md"]).validate!

      expect(report.reference_count).to eq(0)
      expect(report.issues).to be_empty
    end
  end

  it "continues parsing after an indented list-item fence closes" do
    Dir.mktmpdir do |root|
      write_markdown(root, "CHANGELOG.md", <<~MD)
        - ```rake

            task :release
            ```

        [release][3.0.9t]

        [3.0.9t]: https://github.com/kettle-dev/kettle-soup-cover/releases/tag/v3.0.9
      MD

      report = described_class.new(root: root, files: ["CHANGELOG.md"]).validate!

      expect(report.reference_count).to eq(1)
      expect(report.issues).to be_empty
    end
  end

  it "ignores bracket expressions embedded in prose" do
    Dir.mktmpdir do |root|
      write_markdown(root, "CHANGELOG.md", <<~MD)
        - `options[column][:value]` is a hash lookup.
        - options[column][:value] is also a hash lookup.
      MD

      report = described_class.new(root: root, files: ["CHANGELOG.md"]).validate!

      expect(report.reference_count).to eq(0)
      expect(report.issues).to be_empty
    end
  end

  it "keeps the leading hyphen GitHub generates for emoji-led headings" do
    Dir.mktmpdir do |root|
      write_markdown(root, "README.md", <<~MD)
        ## 🔧 Basic Usage

        Following [Basic Usage](#-basic-usage) above.
      MD

      report = described_class.new(root: root, files: ["README.md"]).validate!

      expect(report.issues).to be_empty
    end
  end

  it "uses GitHub-style suffixes for duplicate headings" do
    Dir.mktmpdir do |root|
      write_markdown(root, "README.md", <<~MD)
        # Setup
        # Setup

        [first](README.md#setup)
        [second](README.md#setup-1)
      MD

      report = described_class.new(root: root, files: ["README.md"]).validate!

      expect(report.issues).to be_empty
    end
  end

  it "ignores external and non-Markdown links while accepting shorthand references" do
    Dir.mktmpdir do |root|
      write_markdown(root, "README.md", <<~MD)
        # Introduction

        [docs][]
        [docs]: docs.txt#ignored
        [anchor](#introduction)
        [plain](docs.txt)
        [external](https://example.test/guide#remote)
        [protocol-relative](//example.test/guide#remote)
        [malformed](%zz#remote)
        [not-a-heading](README.md)
      MD

      report = described_class.new(root: root, files: ["README.md"]).validate!

      expect(report.reference_count).to eq(1)
      expect(report.local_target_count).to eq(1)
      expect(report.issues).to be_empty
    end
  end

  it "reports duplicate reference definitions" do
    Dir.mktmpdir do |root|
      write_markdown(root, "README.md", <<~MD)
        [docs][guide]
        [guide]: https://example.test/one
        [guide]: https://example.test/two
      MD

      expect {
        described_class.new(root: root, files: ["README.md"]).validate!
      }.to raise_error(Kettle::Dev::Error, /1 issue\(s\)/)
    end
  end

  it "discovers Markdown files while ignoring generated and test paths" do
    Dir.mktmpdir do |root|
      write_markdown(root, "README.md", "# Readme\n")
      write_markdown(root, "docs/example.md.example", "# Example\n")
      write_markdown(root, "tmp/generated.md", "# Generated\n")

      Dir.chdir(root) do # rubocop:disable ThreadSafety/DirChdir
        report = described_class.new.validate!

        expect(report.file_count).to eq(2)
      end
    end
  end

  it "reports files that cannot be read" do
    Dir.mktmpdir do |root|
      path = File.join(root, "README.md")
      write_markdown(root, "README.md", "# Readme\n")
      allow(File).to receive(:readlines).with(path, chomp: true).and_raise(Errno::EACCES, path)

      expect {
        described_class.new(root: root, files: ["README.md"]).validate!
      }.to raise_error(Kettle::Dev::Error, /Markdown reference validation failed \(1 issue\(s\)/)
    end
  end
end
