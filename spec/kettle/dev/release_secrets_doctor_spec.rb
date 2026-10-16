# frozen_string_literal: true

RSpec.describe Kettle::Dev::ReleaseSecretsDoctor do
  let(:output) { StringIO.new }
  let(:system_runner) { class_double(Kernel, system: true) }
  let(:options) do
    {
      provider: "op",
      sleep_seconds: 0.0,
      keepalive_seconds: 0.0,
      shape: "child-process",
      otp: false
    }
  end

  it "builds options from the environment" do
    env = {
      "KETTLE_RELEASE_SECRETS_PROVIDER" => "1password",
      "KETTLE_RELEASE_SECRETS_DOCTOR_SLEEP" => "12.5",
      "KETTLE_RELEASE_SECRETS_DOCTOR_KEEPALIVE" => "2.5",
      "KETTLE_RELEASE_SECRETS_DOCTOR_SHAPE" => "parent-child"
    }

    expect(described_class.options_from_env(env)).to include(
      provider: "1password",
      sleep_seconds: 12.5,
      keepalive_seconds: 2.5,
      shape: "parent-child",
      otp: false
    )
  end

  it "spawns a plain child process with doctor env" do
    doctor = described_class.new(options: options, program_name: "/repo/exe/kettle-release-secrets-doctor", output: output, system_runner: system_runner)

    doctor.run

    expect(system_runner).to have_received(:system).with(
      hash_including(
        "KETTLE_RELEASE_SECRETS_PROVIDER" => "op",
        "KETTLE_RELEASE_SECRETS_DOCTOR_SHAPE" => "same-process",
        "KETTLE_RELEASE_SECRETS_DOCTOR_CHILD" => "true"
      ),
      RbConfig.ruby,
      "/repo/exe/kettle-release-secrets-doctor"
    )
  end

  it "spawns a Bundler child process for bundle boundary probes" do
    doctor = described_class.new(options: options.merge(shape: "bundler-child", otp: true), program_name: "/repo/exe/kettle-release-secrets-doctor", output: output, system_runner: system_runner)

    doctor.run

    expect(system_runner).to have_received(:system).with(
      hash_including("KETTLE_RELEASE_SECRETS_DOCTOR_SHAPE" => "same-process"),
      "bundle",
      "exec",
      RbConfig.ruby,
      "/repo/exe/kettle-release-secrets-doctor",
      "--otp"
    )
  end

  it "spawns an env-reset child process with Bundler variables unset" do
    doctor = described_class.new(options: options.merge(shape: "env-reset-child"), program_name: "/repo/exe/kettle-release-secrets-doctor", output: output, system_runner: system_runner)

    doctor.run

    expect(system_runner).to have_received(:system).with(
      hash_including(
        "BUNDLE_BIN_PATH" => nil,
        "BUNDLE_GEMFILE" => nil,
        "BUNDLER_SETUP" => nil,
        "RUBYOPT" => nil
      ),
      RbConfig.ruby,
      "/repo/exe/kettle-release-secrets-doctor"
    )
  end

  it "runs a parent keepalive before spawning a parent-child probe" do
    provider = instance_double(Kettle::Dev::ReleaseSecrets::OnePassword, keepalive!: true)
    allow(Kettle::Dev::ReleaseSecrets::Factory).to receive(:build).with(provider_name: "op").and_return(provider)
    doctor = described_class.new(options: options.merge(shape: "parent-child"), program_name: "/repo/exe/kettle-release-secrets-doctor", output: output, system_runner: system_runner)

    doctor.run

    expect(provider).to have_received(:keepalive!).once
    expect(system_runner).to have_received(:system)
    expect(output.string).to include("parent initial keepalive")
    expect(output.string).to include("parent spawning child after keepalive")
  end

  it "rejects unknown shapes" do
    doctor = described_class.new(options: options.merge(shape: "unknown"), program_name: "/repo/exe/kettle-release-secrets-doctor", output: output, system_runner: system_runner)

    expect { doctor.run }.to raise_error(Kettle::Dev::Error, /unknown shape/)
  end

  # A plain, thread-safe provider fake. RSpec mocks do not cross the Thread
  # boundary the doctor's thread shape creates, so provider behavior must be
  # faked with a real object and injected via provider_factory.
  let(:recording_provider_class) do
    Class.new(Kettle::Dev::ReleaseSecrets::Provider) do
      def initialize(otp: "123456", error: nil)
        @otp = otp
        @error = error
        @keepalives = Queue.new
        @otps = Queue.new
      end

      def keepalive!(elapsed: nil)
        raise @error if @error

        @keepalives << true
        nil
      end

      def rubygems_otp
        @otps << true
        @otp
      end

      def keepalive_count
        @keepalives.size
      end

      def otp_count
        @otps.size
      end
    end
  end

  def fake_provider_factory(provider)
    Class.new do
      def initialize(fake)
        @fake = fake
      end

      def build(provider_name:)
        @fake
      end
    end.new(provider)
  end

  it "runs same-process keepalives with an OTP lookup" do
    provider = recording_provider_class.new(otp: "123456")
    doctor = described_class.new(
      options: options.merge(shape: "same-process", otp: true),
      program_name: "/repo/exe/kettle-release-secrets-doctor",
      output: output,
      system_runner: system_runner,
      provider_factory: fake_provider_factory(provider)
    )

    expect(doctor.run).to be(true)

    expect(provider.keepalive_count).to eq(2)
    expect(provider.otp_count).to eq(1)
    expect(output.string).to include("initial keepalive")
    expect(output.string).to include("final keepalive")
    expect(output.string).to include("OTP lookup returned 6 chars")
  end

  it "pulses keepalives while sleeping when a keepalive interval is configured" do
    provider = recording_provider_class.new
    doctor = described_class.new(
      options: options.merge(shape: "same-process", sleep_seconds: 0.02, keepalive_seconds: 0.005),
      program_name: "/repo/exe/kettle-release-secrets-doctor",
      output: output,
      system_runner: system_runner,
      provider_factory: fake_provider_factory(provider)
    )

    expect(doctor.run).to be(true)

    expect(provider.keepalive_count).to be >= 3
    expect(output.string).to include("with 0.005s keepalive")
    expect(output.string).to include("] keepalive\n")
  end

  it "runs the thread shape and reports OTP inside the thread" do
    provider = recording_provider_class.new(otp: "654321")
    doctor = described_class.new(
      options: options.merge(shape: "thread", otp: true),
      program_name: "/repo/exe/kettle-release-secrets-doctor",
      output: output,
      system_runner: system_runner,
      provider_factory: fake_provider_factory(provider)
    )

    expect(doctor.run).to be(true)
    expect(provider.otp_count).to eq(1)
  end

  it "propagates provider errors from the thread shape" do
    provider = recording_provider_class.new(error: Kettle::Dev::Error.new("session expired"))
    doctor = described_class.new(
      options: options.merge(shape: "thread"),
      program_name: "/repo/exe/kettle-release-secrets-doctor",
      output: output,
      system_runner: system_runner,
      provider_factory: fake_provider_factory(provider)
    )

    expect { doctor.run }.to raise_error(Kettle::Dev::Error, "session expired")
  end
end
