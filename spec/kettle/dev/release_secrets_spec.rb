# frozen_string_literal: true

RSpec.describe Kettle::Dev::ReleaseSecrets, :real_release_secrets do
  before do
    allow(Kettle::Dev::ReleaseNotifier).to receive(:alert)
  end

  it "builds an interactive provider by default" do
    provider = described_class::Factory.build

    expect(provider.gem_signing_passphrase).to be_nil
    expect(provider.rubygems_otp).to be_nil
  end

  it "loads the gem signing passphrase from 1Password defaults" do
    allow(Open3).to receive(:capture3)
      .with("op", "item", "get", "Rubygems", "--fields", "label=GEM-SIGN-PASSPHRASE", "--reveal")
      .and_return(["secret\n", "", status(success: true)])

    provider = described_class::Factory.build(provider_name: "1password")

    expect(provider.gem_signing_passphrase).to eq("secret")
  end

  it "loads the provider name from explicit config" do
    allow(Open3).to receive(:capture3)
      .with("op", "item", "get", "Rubygems", "--fields", "label=GEM-SIGN-PASSPHRASE", "--reveal")
      .and_return(["secret\n", "", status(success: true)])

    provider = described_class::Factory.build(config: {"provider" => "1password"})

    expect(provider.gem_signing_passphrase).to eq("secret")
  end

  it "memoizes the gem signing passphrase after the first 1Password lookup" do
    allow(Open3).to receive(:capture3)
      .with("op", "item", "get", "Rubygems", "--fields", "label=GEM-SIGN-PASSPHRASE", "--reveal")
      .once
      .and_return(["secret\n", "", status(success: true)])

    provider = described_class::Factory.build(provider_name: "1password")

    expect(provider.gem_signing_passphrase).to eq("secret")
    expect(provider.gem_signing_passphrase).to eq("secret")
  end

  it "loads RubyGems OTP values close to prompt time" do
    allow(Open3).to receive(:capture3)
      .with("op", "item", "get", "Rubygems", "--otp")
      .and_return(["123456\n", "", status(success: true)])

    provider = described_class::Factory.build(provider_name: "op")

    expect(provider.rubygems_otp).to eq("123456")
  end

  it "does not poll 1Password during release keepalive callbacks" do
    provider = described_class::Factory.build(provider_name: "op")

    expect(provider.keepalive!(elapsed: "03:21")).to be(true)
    expect(Open3).not_to receive(:capture3)
    expect(Kettle::Dev::InteractiveReleaseCommand).not_to receive(:new)
  end

  it "uses a family broker for OTP requests" do
    socket = instance_double(UNIXSocket)
    allow(UNIXSocket).to receive(:new).with("/run/kettle-secrets.sock").and_return(socket)
    allow(socket).to receive(:gets).and_return("{\"ok\":true,\"value\":\"123456\"}\n")
    allow(socket).to receive(:write)
    allow(socket).to receive(:close)

    provider = described_class::Factory.build(
      provider_name: "family",
      config: {"endpoint" => "/run/kettle-secrets.sock"}
    )

    expect(provider.rubygems_otp).to eq("123456")
    expect(socket).to have_received(:write).with(/"operation":"rubygems_otp"/)
  end

  it "requires a broker endpoint for family release secrets" do
    expect { described_class::Factory.build(provider_name: "family") }
      .to raise_error(Kettle::Dev::Error, /broker endpoint is required/)
  end

  it "alerts before 1Password lookups" do
    allow(Kettle::Dev::ReleaseNotifier).to receive(:alert).and_call_original
    stub_env(
      "KETTLE_RELEASE_SECRET_BELL" => "false",
      "KETTLE_RELEASE_SECRET_ALERT" => "true"
    )
    stream = StringIO.new

    Kettle::Dev::ReleaseNotifier.alert("watch now", stream: stream)

    expect(stream.string).to eq("watch now\n")
  end

  it "supports explicit 1Password references and accounts" do
    allow(Open3).to receive(:capture3)
      .with("op", "read", "op://Private/Rubygems/GEM-SIGN-PASSPHRASE", "--account", "work")
      .and_return(["secret\n", "", status(success: true)])

    provider = described_class::Factory.build(
      provider_name: "onepassword",
      config: {
        "account" => "work",
        "gem_signing_passphrase_reference" => "op://Private/Rubygems/GEM-SIGN-PASSPHRASE"
      }
    )

    expect(provider.gem_signing_passphrase).to eq("secret")
  end

  it "supports an explicit 1Password CLI path" do
    allow(Open3).to receive(:capture3)
      .with("/opt/1Password/op", "item", "get", "Rubygems", "--fields", "label=GEM-SIGN-PASSPHRASE", "--reveal")
      .and_return(["secret\n", "", status(success: true)])

    provider = described_class::Factory.build(
      provider_name: "1password",
      config: {"cli" => "/opt/1Password/op"}
    )

    expect(provider.gem_signing_passphrase).to eq("secret")
  end

  it "loads the explicit 1Password CLI path from the environment" do
    stub_env("KETTLE_RELEASE_1PASSWORD_CLI" => "/opt/1Password/op")
    allow(Open3).to receive(:capture3)
      .with("/opt/1Password/op", "item", "get", "Rubygems", "--fields", "label=GEM-SIGN-PASSPHRASE", "--reveal")
      .and_return(["secret\n", "", status(success: true)])

    provider = described_class::Factory.build(provider_name: "1password")

    expect(provider.gem_signing_passphrase).to eq("secret")
  end

  it "uses a cached family passphrase without querying 1Password for it" do
    stub_env(
      "KETTLE_RELEASE_GEM_SIGNING_PASSPHRASE_SOURCE" => "cached",
      "KETTLE_RELEASE_GEM_SIGNING_PASSPHRASE" => "cached-secret"
    )

    provider = described_class::Factory.build(provider_name: "1password")

    expect(Open3).not_to receive(:capture3)
    expect(provider.gem_signing_passphrase).to eq("cached-secret")
  end

  it "redacts lookup failures" do
    allow(Open3).to receive(:capture3)
      .and_return(["", "item not found\n", status(success: false, exitstatus: 1)])

    provider = described_class::Factory.build(provider_name: "1password")

    expect { provider.gem_signing_passphrase }
      .to raise_error(Kettle::Dev::Error, /1Password gem signing passphrase field lookup failed: item not found/)
  end

  it "raises Kettle::Dev::Error for direct provider lookup failures" do
    allow(Open3).to receive(:capture3)
      .and_return(["", "item not found\n", status(success: false, exitstatus: 1)])

    provider = described_class::OnePassword.new("item" => "Rubygems")

    expect { provider.gem_signing_passphrase }
      .to raise_error(Kettle::Dev::Error, /1Password gem signing passphrase field lookup failed: item not found/)
  end

  def status(success:, exitstatus: success ? 0 : 1)
    instance_double(Process::Status, success?: success, exitstatus: exitstatus)
  end
end
