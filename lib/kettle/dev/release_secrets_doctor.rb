# frozen_string_literal: true

require "rbconfig"
require "shellwords"
require "time"

module Kettle
  module Dev
    class ReleaseSecretsDoctor
      DEFAULT_SLEEP_SECONDS = 30.0
      DEFAULT_KEEPALIVE_SECONDS = 0.0
      DEFAULT_PROVIDER = "op"
      DEFAULT_SHAPE = "same-process"
      CHILD_SHAPE = "same-process"
      SHAPES = %w[same-process child-process parent-child thread bundler-child env-reset-child].freeze
      BUNDLER_ENV_UNSETS = %w[
        BUNDLE_BIN_PATH
        BUNDLE_FROZEN
        BUNDLE_GEMFILE
        BUNDLE_LOCKFILE
        BUNDLER_SETUP
        BUNDLER_VERSION
        RUBYLIB
        RUBYOPT
      ].freeze

      def self.options_from_env(env = ENV)
        {
          provider: env.fetch("KETTLE_RELEASE_SECRETS_PROVIDER", DEFAULT_PROVIDER),
          sleep_seconds: Float(env.fetch("KETTLE_RELEASE_SECRETS_DOCTOR_SLEEP", DEFAULT_SLEEP_SECONDS.to_s)),
          keepalive_seconds: Float(env.fetch("KETTLE_RELEASE_SECRETS_DOCTOR_KEEPALIVE", DEFAULT_KEEPALIVE_SECONDS.to_s)),
          shape: env.fetch("KETTLE_RELEASE_SECRETS_DOCTOR_SHAPE", DEFAULT_SHAPE),
          otp: false
        }
      end

      def initialize(options:, program_name:, output: $stdout, system_runner: Kernel, provider_factory: Kettle::Dev::ReleaseSecrets::Factory)
        @options = normalize_options(options)
        @program_name = program_name
        @output = output
        @system_runner = system_runner
        @provider_factory = provider_factory
      end

      def run
        case options.fetch(:shape)
        when "same-process"
          run_same_process(options)
        when "child-process"
          run_child_process(options)
        when "parent-child"
          run_parent_child(options)
        when "thread"
          run_thread(options)
        when "bundler-child"
          run_bundler_child(options)
        when "env-reset-child"
          run_env_reset_child(options)
        else
          raise Kettle::Dev::Error, "unknown shape #{options.fetch(:shape).inspect}; expected #{SHAPES.join(", ")}"
        end
      end

      def child_env(shape:, options: self.options)
        env = {
          "KETTLE_RELEASE_SECRETS_PROVIDER" => options.fetch(:provider),
          "KETTLE_RELEASE_SECRETS_DOCTOR_SHAPE" => shape,
          "KETTLE_RELEASE_SECRETS_DOCTOR_SLEEP" => options.fetch(:sleep_seconds).to_s,
          "KETTLE_RELEASE_SECRETS_DOCTOR_KEEPALIVE" => options.fetch(:keepalive_seconds).to_s
        }
        env["KETTLE_RELEASE_SECRETS_DOCTOR_CHILD"] = "true"
        env
      end

      def child_args(otp: options.fetch(:otp))
        args = [RbConfig.ruby, program_name]
        args << "--otp" if otp
        args
      end

      def bundler_child_args(otp: options.fetch(:otp))
        args = ["bundle", "exec", RbConfig.ruby, program_name]
        args << "--otp" if otp
        args
      end

      private

      attr_reader :options, :program_name, :output, :system_runner, :provider_factory

      def normalize_options(raw_options)
        {
          provider: raw_options.fetch(:provider, DEFAULT_PROVIDER).to_s,
          sleep_seconds: Float(raw_options.fetch(:sleep_seconds, DEFAULT_SLEEP_SECONDS)),
          keepalive_seconds: Float(raw_options.fetch(:keepalive_seconds, DEFAULT_KEEPALIVE_SECONDS)),
          shape: raw_options.fetch(:shape, DEFAULT_SHAPE).to_s,
          otp: !!raw_options.fetch(:otp, false)
        }
      end

      def provider_for(current_options)
        provider_factory.build(provider_name: current_options.fetch(:provider))
      end

      def run_same_process(current_options)
        provider = provider_for(current_options)
        output.puts("[#{timestamp}] initial keepalive")
        provider.keepalive!
        wait_with_keepalive(provider, current_options)
        output.puts("[#{timestamp}] final keepalive")
        provider.keepalive!
        run_otp_lookup(provider) if current_options.fetch(:otp)
        true
      end

      def run_parent_child(current_options)
        provider = provider_for(current_options)
        output.puts("[#{timestamp}] parent initial keepalive")
        provider.keepalive!
        wait_with_keepalive(provider, current_options)
        output.puts("[#{timestamp}] parent spawning child after keepalive")
        run_child_process(current_options)
      end

      def run_child_process(current_options)
        env = child_env(shape: CHILD_SHAPE, options: current_options)
        args = child_args(otp: current_options.fetch(:otp))
        output.puts("[#{timestamp}] spawning child: #{args.shelljoin}")
        run_system(env, args)
      end

      def run_bundler_child(current_options)
        env = child_env(shape: CHILD_SHAPE, options: current_options)
        args = bundler_child_args(otp: current_options.fetch(:otp))
        output.puts("[#{timestamp}] spawning bundler child: #{args.shelljoin}")
        run_system(env, args)
      end

      def run_env_reset_child(current_options)
        env = child_env(shape: CHILD_SHAPE, options: current_options)
        BUNDLER_ENV_UNSETS.each { |key| env[key] = nil }
        args = child_args(otp: current_options.fetch(:otp))
        output.puts("[#{timestamp}] spawning env-reset child: #{args.shelljoin}")
        run_system(env, args)
      end

      def run_thread(current_options)
        error = nil
        # rubocop:disable ThreadSafety/NewThread -- this doctor intentionally probes threaded secret-provider behavior.
        thread = Thread.new do
          begin
            run_same_process(current_options)
          rescue => e
            error = e
          end
        end
        # rubocop:enable ThreadSafety/NewThread
        thread.join
        raise error if error

        true
      end

      def run_system(env, args)
        success = system_runner.system(env, *args)
        raise Kettle::Dev::Error, "child shape failed: #{args.shelljoin}" unless success

        true
      end

      def wait_with_keepalive(provider, current_options)
        sleep_seconds = current_options.fetch(:sleep_seconds)
        keepalive_seconds = current_options.fetch(:keepalive_seconds)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + sleep_seconds
        if keepalive_seconds <= 0
          output.puts("[#{timestamp}] sleeping #{sleep_seconds}s without keepalive")
          sleep(sleep_seconds)
          return
        end

        output.puts("[#{timestamp}] sleeping #{sleep_seconds}s with #{keepalive_seconds}s keepalive")
        loop do
          remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          break if remaining <= 0

          sleep([remaining, keepalive_seconds].min)
          break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

          output.puts("[#{timestamp}] keepalive")
          provider.keepalive!
        end
      end

      def run_otp_lookup(provider)
        output.puts("[#{timestamp}] OTP lookup")
        otp = provider.rubygems_otp
        output.puts("[#{timestamp}] OTP lookup returned #{otp.to_s.empty? ? "empty" : "#{otp.length} chars"}")
      end

      def timestamp
        Time.now.iso8601
      end
    end
  end
end
