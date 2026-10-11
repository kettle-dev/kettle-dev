# frozen_string_literal: true

require "shellwords"

RSpec.describe Kettle::Dev::InteractiveReleaseCommand do
  it "uses a PTY to write the configured passphrase to prompt-bearing commands" do
    provider = instance_double(Kettle::Dev::ReleaseSecrets::OnePassword, gem_signing_passphrase: "secret")
    output = StringIO.new
    command = described_class.new(secrets_provider: provider, output: output)
    skip "PTY is unavailable on this Ruby engine" unless command.send(:pty_available?)

    script = "print 'Enter PEM pass phrase:'; $stdout.flush; exit(STDIN.gets&.chomp == 'secret' ? 0 : 1)"
    _stdout, _stderr, status = command.call({}, [RbConfig.ruby, "-e", script].shelljoin)

    expect(status).to be_success
    expect(output.string).to include("Enter PEM pass phrase:")
    expect(output.string).to include("gem signing passphrase loaded from configured secrets provider.")
  end

  it "falls back to Open3 when PTY is unavailable" do
    provider = instance_double(Kettle::Dev::ReleaseSecrets::OnePassword, gem_signing_passphrase: "secret")
    output = StringIO.new
    command = described_class.new(secrets_provider: provider, output: output)
    allow(command).to receive(:pty_available?).and_return(false)
    script = "print 'Enter PEM pass phrase:'; $stdout.flush; exit(STDIN.gets&.chomp == 'secret' ? 0 : 1)"

    _stdout, _stderr, status = command.call({}, [RbConfig.ruby, "-e", script].shelljoin)

    expect(status).to be_success
    expect(output.string).to include("gem signing passphrase loaded from configured secrets provider.")
  end

  it "waits for the MFA response prompt before writing an OTP" do
    provider = instance_double(Kettle::Dev::ReleaseSecrets::OnePassword, rubygems_otp: "123456")
    output = StringIO.new
    command = described_class.new(secrets_provider: provider, output: output)
    input = StringIO.new

    command.send(:handle_prompt, input, "You have enabled multi-factor authentication.\n")
    expect(input.string).to eq("")

    command.send(:handle_prompt, input, "Code: ")
    expect(input.string).to eq("123456\n")
    expect(output.string).to include("RubyGems MFA code loaded from configured secrets provider.")
  end

  it "buffers prompt text split across output chunks" do
    provider = instance_double(Kettle::Dev::ReleaseSecrets::OnePassword, rubygems_otp: "123456")
    command = described_class.new(secrets_provider: provider, output: StringIO.new)
    input = StringIO.new

    prompt_buffer = command.send(:handle_prompt, input, "You have enabled multi-factor authenti")
    prompt_buffer = command.send(:handle_prompt, input, "cation.\nCode: ", prompt_buffer: prompt_buffer)

    expect(prompt_buffer).to eq("")
    expect(input.string).to eq("123456\n")
  end

  it "emits secret provider events around an MFA prompt response" do
    provider = instance_double(Kettle::Dev::ReleaseSecrets::OnePassword, rubygems_otp: "123456")
    events = []
    command = described_class.new(
      secrets_provider: provider,
      output: StringIO.new,
      secret_event_handler: ->(payload) { events << payload }
    )
    input = StringIO.new

    command.send(:handle_prompt, input, "Code: ")

    expect(input.string).to eq("123456\n")
    expect(events).to contain_exactly(
      include(source: "rubygems_otp", action: "prompt_response", status: "started", label: "RubyGems MFA code"),
      include(source: "rubygems_otp", action: "prompt_response", status: "ok", label: "RubyGems MFA code")
    )
  end

  it "memoizes the gem signing passphrase for repeated PEM prompts" do
    provider = instance_double(Kettle::Dev::ReleaseSecrets::OnePassword, gem_signing_passphrase: "secret")
    command = described_class.new(secrets_provider: provider, output: StringIO.new)
    input = StringIO.new

    command.send(:handle_prompt, input, "Enter PEM pass phrase: ")
    command.send(:handle_prompt, input, "Enter PEM pass phrase: ")

    expect(input.string).to eq("secret\nsecret\n")
    expect(provider).to have_received(:gem_signing_passphrase).once
  end

  it "never leaks the passphrase through PTY echo back into captured output" do
    provider = instance_double(Kettle::Dev::ReleaseSecrets::OnePassword, gem_signing_passphrase: "supersekrit-phrase")
    output = StringIO.new
    command = described_class.new(secrets_provider: provider, output: output)
    skip "PTY is unavailable on this Ruby engine" unless command.send(:pty_available?)

    # The child mirrors RubyGems' signing prompt: it asks with terminal echo
    # still on (Gem::StreamUI#ask_for_password only wraps gets in noecho), so
    # the bytes written by the automation are echoed back through the PTY.
    child = [
      RbConfig.ruby,
      "-rrubygems",
      "-rrubygems/user_interaction",
      "-e",
      'ui = Gem::StreamUI.new($stdin, $stdout, $stderr, true); ' \
        'pw = ui.ask_for_password("Enter PEM pass phrase:  "); ' \
        '$stdout.puts("LEN=#{pw.nil? ? "nil" : pw.length}")'
    ]

    _stdout, _stderr, status = command.call({}, child.shelljoin)

    expect(status).to be_success
    expect(output.string).not_to include("supersekrit-phrase")
    expect(output.string).to include("LEN=18")
    expect(output.string).to include("[SECRET REMOVED]")
  end

  it "scrubs a passphrase echoed across chunk boundaries" do
    provider = instance_double(Kettle::Dev::ReleaseSecrets::OnePassword, gem_signing_passphrase: "supersekrit-phrase")
    command = described_class.new(secrets_provider: provider, output: StringIO.new)
    command.send(:register_secret!, "supersekrit-phrase")

    first = command.send(:scrub_secrets_from_chunk, "partial-supersekrit-ph")
    second = command.send(:scrub_secrets_from_chunk, "rase\r\n\r\n")
    flushed = command.send(:flush_secret_scrub_carryover)

    expect(first + second + flushed).not_to include("supersekrit-phrase")
    expect(first + second + flushed).to include("partial-")
  end

  it "leaves output untouched when no secret has been written" do
    provider = instance_double(Kettle::Dev::ReleaseSecrets::OnePassword, gem_signing_passphrase: "secret")
    command = described_class.new(secrets_provider: provider, output: StringIO.new)

    expect(command.send(:scrub_secrets_from_chunk, "ordinary output")).to eq("ordinary output")
  end

  it "fails closed when a configured provider returns no secret for a prompt" do
    provider = instance_double(Kettle::Dev::ReleaseSecrets::OnePassword, gem_signing_passphrase: nil)
    command = described_class.new(secrets_provider: provider, output: StringIO.new)

    expect {
      command.send(:handle_prompt, StringIO.new, "Enter PEM pass phrase: ")
    }.to raise_error(Kettle::Dev::Error, /configured release secrets provider returned no value/)
  end
end
