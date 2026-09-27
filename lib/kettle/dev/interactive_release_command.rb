# frozen_string_literal: true

require "open3"
require "shellwords"

module Kettle
  module Dev
    class InteractiveReleaseCommand
      def initialize(secrets_provider:, input: $stdin, output: $stdout, error: $stderr, secret_event_handler: nil, forward_stdin: false)
        @secrets_provider = secrets_provider
        @input = input
        @output = output
        @error = error
        @secret_event_handler = secret_event_handler
        @forward_stdin = forward_stdin
        @gem_signing_passphrase = nil
      end

      def call(env, cmd)
        call_argv(env, Shellwords.split(cmd.to_s))
      end

      def call_argv(env, argv)
        return call_with_pty(env, argv) if pty_available?

        call_with_open3(env, argv)
      end

      private

      attr_reader :secrets_provider, :secret_event_handler

      def call_with_pty(env, argv)
        stdout_str = +""
        prompt_buffer = +""
        status = nil
        PTY.spawn(env, *argv) do |output, input, pid|
          begin
            loop do
              readers = [output]
              readers << @input if @forward_stdin && @input.tty?
              IO.select(readers).first.each do |reader|
                if reader.equal?(@input)
                  input.write(@input.readpartial(1024))
                else
                  chunk = output.readpartial(1024)
                  stdout_str << chunk
                  @output.print(chunk)
                  prompt_buffer = handle_prompt(input, chunk, prompt_buffer: prompt_buffer)
                end
              end
            end
          rescue Errno::EIO, EOFError
            # PTY platforms signal a closed child with EIO or EOFError.
          rescue Kettle::Dev::Error
            Process.kill("TERM", pid)
            raise
          ensure
            _, status = Process.wait2(pid)
          end
        end
        [stdout_str, "", status]
      end

      def call_with_open3(env, argv)
        stdout_str = +""
        stderr_str = +""
        prompt_buffer = +""
        status = nil
        Open3.popen3(env, *argv) do |input, output, error, wait_thread|
          readers = [output, error]
          readers << @input if @forward_stdin && @input.tty?
          until readers.empty?
            ready = IO.select(readers)
            ready.first.each do |reader|
              if reader.equal?(@input)
                input.write(@input.readpartial(1024))
              else
                begin
                  chunk = reader.readpartial(1024)
                  if reader.equal?(output)
                    stdout_str << chunk
                    @output.print(chunk)
                  else
                    stderr_str << chunk
                    @error.print(chunk)
                  end
                  prompt_buffer = handle_prompt(input, chunk, prompt_buffer: prompt_buffer)
                rescue EOFError
                  readers.delete(reader)
                end
              end
            end
          end
          status = wait_thread.value
        end
        [stdout_str, stderr_str, status]
      end

      def handle_prompt(input, chunk, prompt_buffer: nil)
        prompt_buffer = prompt_buffer.to_s.dup
        prompt_buffer << chunk.to_s
        prompt_buffer = prompt_buffer.byteslice([prompt_buffer.bytesize - 4096, 0].max, 4096).to_s

        if otp_prompt?(prompt_buffer)
          if otp_response_prompt?(prompt_buffer)
            write_secret(input, label: "RubyGems MFA code", source: "rubygems_otp") { secrets_provider.rubygems_otp }
            return +""
          end
          return prompt_buffer
        end

        write_secret(input, label: "gem signing passphrase", source: "gem_signing_passphrase") { gem_signing_passphrase } if signing_password_prompt?(prompt_buffer)
        prompt_buffer
      end

      def gem_signing_passphrase
        @gem_signing_passphrase ||= secrets_provider.gem_signing_passphrase.to_s
      end

      def write_secret(input, label:, source:)
        emit_secret_event(source: source, action: "prompt_response", status: "started", label: label)
        value = yield
        secret = value.to_s
        if secret.empty?
          raise Kettle::Dev::Error, "#{label} prompt reached, but the configured release secrets provider returned no value. Aborting because secret prompts are not allowed when a secrets provider is configured."
        end

        @output.puts("#{label} loaded from configured secrets provider.")
        input.write("#{secret}\n")
        input.flush
        emit_secret_event(source: source, action: "prompt_response", status: "ok", label: label)
      rescue Kettle::Dev::Error => error
        emit_secret_event(source: source, action: "prompt_response", status: "failed", label: label, reason: error.message)
        raise
      end

      def emit_secret_event(payload)
        secret_event_handler&.call(payload)
      end

      def otp_prompt?(chunk)
        chunk.match?(/(?:multi-factor authentication|OTP code|one-time password|\bCode:\s*)/i)
      end

      def otp_response_prompt?(chunk)
        chunk.match?(/(?:OTP code|one-time password|\bCode:\s*)/i)
      end

      def signing_password_prompt?(chunk)
        chunk.match?(/(?:enter\s+)?(?:PEM\s+)?pass(?:\s|-)?phrase\s*(?:for\s+[^:]+)?[:?]\s*\z/i) ||
          chunk.match?(/(?:PEM|private key) password\s*[:?]\s*\z/i)
      end

      def pty_available?
        return false unless RUBY_ENGINE == "ruby"

        require "pty"
        true
      rescue LoadError
        false
      end
    end
  end
end
