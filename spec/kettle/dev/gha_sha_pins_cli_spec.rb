# frozen_string_literal: true

require "open3"

# kettle-dev's GhaShaPinsCLI is a compatibility alias for the extracted
# kettle-gha-pins gem's CLI. Behavior coverage lives in that gem's suite;
# this file covers only the kettle-dev-owned surface: the alias itself and
# the LoadError fallback for installs missing the runtime dependency.
RSpec.describe Kettle::Dev::GhaShaPinsCLI do
  it "aliases the extracted kettle-gha-pins CLI" do
    expect(described_class).to be(Kettle::Gha::Pins::CLI)
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
end
