# frozen_string_literal: true

RSpec.describe Kettle::Dev::RebaseCLI do
  around do |example|
    Dir.mktmpdir("kettle-rebase-cli-spec") do |dir|
      @tmpdir = dir
      example.run
    end
  end

  it "prints the result message and returns 0 for an ok result" do
    stub_rebase(status: :ok, message: "main is up to date with origin/main")

    status = nil
    expect { status = described_class.new([], root: @tmpdir).run! }.to output("main is up to date with origin/main\n").to_stdout
    expect(status).to eq(0)
  end

  it "returns 1 for a conflict result" do
    stub_rebase(status: :conflict, message: "rebase of main onto origin/main failed")

    status = nil
    expect { status = described_class.new([], root: @tmpdir).run! }.to output(/rebase of main/).to_stdout
    expect(status).to eq(1)
  end

  it "accepts a PATH argument" do
    target = File.join(@tmpdir, "elsewhere")
    FileUtils.mkdir_p(target)
    stub_rebase(status: :ok, message: "ok")

    expect { described_class.new([target], root: @tmpdir).run! }.to output("ok\n").to_stdout
    expect(Kettle::Dev::Rebase).to have_received(:call).with(root: target)
  end

  it "raises on unexpected arguments" do
    stub_rebase(status: :ok, message: "ok")

    expect { described_class.new(["a", "b"], root: @tmpdir).run! }.to raise_error(Kettle::Dev::Error, /unexpected argument/)
  end

  it "raises on unknown options" do
    stub_rebase(status: :ok, message: "ok")

    expect { described_class.new(["--bogus"], root: @tmpdir).run! }.to raise_error(Kettle::Dev::Error, /--bogus/)
  end

  def stub_rebase(status:, message:)
    result = Kettle::Dev::Rebase::Result.new(status: status, message: message)
    allow(Kettle::Dev::Rebase).to receive(:call).and_return(result)
  end
end
