# frozen_string_literal: true

require "anonymous_loader"
require "kettle/dev/version_gem"
RSpec.describe Kettle::Dev::Version do
  it_behaves_like "a Version module", described_class

  it "executes the version file for coverage without redefining constants" do
    dir = File.expand_path("../../../lib/kettle/dev", __dir__)
    paths = %w[version.rb version_gem.rb].map { |file| File.join(dir, file) }.select { |path| File.file?(path) }
    anonymous_namespace = AnonymousLoader.load(files: paths)

    expect(anonymous_namespace::Kettle::Dev::Version::VERSION).to eq(described_class::VERSION)
  end
end
