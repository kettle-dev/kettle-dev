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
        # Secrets are written to the PTY master to answer child prompts. A PTY
        # slave still echoes what is typed while the child has not yet disabled
        # terminal echo (RubyGems' ask_for_password only wraps gets in noecho),
        # so the secret bytes can bounce back into the PTY output stream and —
        # without filtering — land in release logs. Track every secret written
        # and scrub it from all child output before it is printed or captured.
        @written_secrets = []
        @secret_scrub_carryover = +""
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
                  # Two views of the same bytes, with independent state.
                  #
                  # Emitted view: holds back a trailing window so a secret
                  # split across chunks can never reach the log; the window
                  # is released by flush_secret_scrub_carryover at stream end.
                  #
                  # Prompt view: scrubbed but never held back. A child that
                  # prints its prompt and then blocks on stdin (Gem's OTP
                  # `Code: ` ask) produces no further output; if the prompt
                  # tail sat in the emitted view's holdback, detection would
                  # never fire and the child would deadlock. The prompt view
                  # therefore scrubs the raw chunk directly (plus the emitted
                  # view's carryover, read-only, so bytes spanning the
                  # boundary are still masked) instead of consuming it.
                  chunk = scrub_secrets_from_chunk(chunk)
                  prompt_text = scrub_secrets_for_prompt_detection(chunk)
                  stdout_str << chunk
                  @output.print(chunk)
                  prompt_buffer = handle_prompt(input, prompt_text, prompt_buffer: prompt_buffer)
                end
              end
            end
          rescue Errno::EIO, EOFError
            # PTY platforms signal a closed child with EIO or EOFError.
            chunk = flush_secret_scrub_carryover
            unless chunk.empty?
              stdout_str << chunk
              @output.print(chunk)
            end
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
                  chunk = scrub_secrets_from_chunk(chunk)
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
          chunk = flush_secret_scrub_carryover
          unless chunk.empty?
            stdout_str << chunk
            @output.print(chunk)
          end
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

        if signing_password_prompt?(prompt_buffer)
          write_secret(input, label: "gem signing passphrase", source: "gem_signing_passphrase") { gem_signing_passphrase }
          # Clear the buffer after answering: otherwise the stale prompt text
          # re-matches on every subsequent chunk and writes the secret again.
          # The duplicate write happens after the child has restored terminal
          # echo (RubyGems' noecho wraps only the gets call), so its bytes echo
          # back through the PTY and land in the captured output and logs.
          return +""
        end
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
        # Register AFTER writing: a chunk currently in flight may contain a
        # legitimately echoed prompt line, but anything the child echoes from
        # this point on that contains the secret bytes is PTY echo of the write
        # and must never reach @output, captured output, or release logs.
        register_secret!(secret)
        emit_secret_event(source: source, action: "prompt_response", status: "ok", label: label)
      rescue Kettle::Dev::Error => error
        emit_secret_event(source: source, action: "prompt_response", status: "failed", label: label, reason: error.message)
        raise
      end

      def emit_secret_event(payload)
        secret_event_handler&.call(payload)
      end

      # Never persist secret values. Register the exact byte string so the
      # scrubber can recognize it in child output without logging it.
      def register_secret!(secret)
        secret = secret.to_s
        return if secret.empty?

        @written_secrets << secret unless @written_secrets.include?(secret)
        @written_secrets.shift if @written_secrets.length > 8
      end

      # Secrets typed into a PTY can be echoed back when the child's terminal
      # echo is momentarily on (e.g. before Gem's noecho gets runs). Remove
      # registered secret byte sequences from every chunk before printing or
      # capturing. A chunk boundary can split a secret, so carry a trailing
      # window of the longest secret forward to the next chunk.
      def scrub_secrets_from_chunk(chunk)
        return chunk if @written_secrets.empty? || chunk.empty?

        window = @written_secrets.map(&:bytesize).max || 0
        buffer = @secret_scrub_carryover + chunk
        buffer = buffer.gsub(Regexp.union(@written_secrets), "[SECRET REMOVED]")
        if buffer.bytesize >= window && window > 0
          @secret_scrub_carryover = buffer.byteslice(-window, window).to_s
          buffer.byteslice(0, buffer.bytesize - window).to_s
        else
          @secret_scrub_carryover = buffer
          +""
        end
      end

      # At stream end nothing else can reveal a secret split across chunks, so
      # release the held trailing window (already scrubbed once).
      def flush_secret_scrub_carryover
        chunk = @secret_scrub_carryover
        @secret_scrub_carryover = +""
        chunk
      end

      # Prompt-detection view: scrubbed, but never holds back a trailing
      # window. Reads (never consumes) the emitted view's carryover so bytes
      # spanning a chunk boundary are still masked here. Without this view, a
      # prompt whose tail falls inside the holdback — a child that blocks on
      # stdin and produces no further output — would never be answered, and
      # the release would deadlock.
      def scrub_secrets_for_prompt_detection(chunk)
        return chunk if @written_secrets.empty?

        buffer = @secret_scrub_carryover + chunk
        buffer.gsub(Regexp.union(@written_secrets), "[SECRET REMOVED]")
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
