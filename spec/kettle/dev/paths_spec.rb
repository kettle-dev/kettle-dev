# frozen_string_literal: true

RSpec.describe Kettle::Dev::Paths do
  around do |example|
    Dir.mktmpdir("kettle-dev-paths") do |root|
      @root = root
      example.run
    end
  end

  describe ".canonical" do
    it "resolves existing ancestors for paths that do not exist yet" do
      expect(described_class.canonical(File.join(@root, "new", "child"))).to eq(File.join(File.realpath(@root), "new", "child"))
    end
  end

  describe ".same?" do
    it "uses filesystem identity for existing path aliases" do
      target = File.join(@root, "target")
      alias_path = File.join(@root, "alias")
      Dir.mkdir(target)
      File.symlink(target, alias_path)

      expect(described_class.same?(target, alias_path)).to be(true)
    end
  end

  describe ".within?" do
    it "accepts a descendant that does not exist yet" do
      expect(described_class.within?(File.join(@root, "new", "child"), @root)).to be(true)
    end

    it "rejects a sibling whose name shares the root prefix" do
      expect(described_class.within?("#{@root}-other/file", @root)).to be(false)
    end

    it "accepts the root itself" do
      expect(described_class.within?(@root, @root)).to be(true)
    end
  end
end
