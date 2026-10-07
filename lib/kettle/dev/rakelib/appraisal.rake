# frozen_string_literal: true

# --- Appraisals (dev-only) ---
begin
  require "appraisal/task"
  require "kettle/dev/lockfile_reset"

  bundle = "bundle"
  # The exact Bundler running this rake, so `bundle update --bundler=VERSION`
  # records it instead of resolving to RubyGems' "latest" bundler, which can be
  # a prerelease. Falls back to the bare flag only if no version is
  # determinable, preserving prior behaviour rather than failing.
  bundler_version = if defined?(Bundler) && Bundler::VERSION
    Bundler::VERSION
  elsif (bundler_spec = Gem.loaded_specs["bundler"])
    bundler_spec.version.to_s
  end
  bundler_version_arg = bundler_version ? "--bundler=#{bundler_version}" : "--bundler"
  unbundled_env = Kettle::Dev::LockfileReset::UNBUNDLED_ENV_KEYS.each_with_object({}) do |key, env|
    env[key] = nil
  end
  quiet_env = {
    "KETTLE_JEM_QUIET" => "true",
    "KETTLE_JEM_DEBUG" => "false",
    "KETTLE_DEV_DEBUG" => "false",
    "STRUCTUREDMERGE_DEBUG" => "false",
    "DEBUG" => nil,
    "BUNDLE_QUIET" => "true",
    "BUNDLE_DEBUG" => "false",
    "BUNDLER_DEBUG" => "false",
    "BUNDLE_VERBOSE" => "false",
    "DEBUG_RESOLVER" => nil,
    "DEBUG_RESOLVER_TREE" => nil,
    "BUNDLER_DEBUG_RESOLVER" => nil,
    "BUNDLER_DEBUG_RESOLVER_TREE" => nil,
    "DEBUG_COMPACT_INDEX" => nil,
    "MOLINILLO_DEBUG" => nil,
    "BUNDLE_SILENCE_DEPRECATIONS" => "true",
    "BUNDLE_SILENCE_ROOT_WARNING" => "true",
    "BUNDLE_SUPPRESS_INSTALL_USING_MESSAGES" => "true"
  }
  appraisal_env = quiet_env.merge(
    Kettle::Dev::LockfileReset.new(root: Dir.pwd, command_runner: ->(_command) {}).appraisal_normalization_env
  ).merge(
    unbundled_env
  ).merge(
    "BUNDLE_GEMFILE" => "Appraisal.root.gemfile",
    "BUNDLE_LOCKFILE" => "Appraisal.root.gemfile.lock"
  )

  run_command = lambda do |failure_message, *args|
    ok = system(*args)
    raise(failure_message) unless ok
  end

  run_generate_steps = lambda do
    # 1) BUNDLE_GEMFILE=Appraisal.root.gemfile bundle install
    run_command.call(
      "appraisal:generate failed: BUNDLE_GEMFILE=Appraisal.root.gemfile bundle install",
      appraisal_env,
      bundle,
      "install",
      "--quiet"
    )

    # 2) BUNDLE_GEMFILE=Appraisal.root.gemfile bundle exec appraisal generate
    run_command.call(
      "appraisal:generate failed: BUNDLE_GEMFILE=Appraisal.root.gemfile bundle exec appraisal generate",
      appraisal_env,
      bundle,
      "exec",
      "appraisal",
      "generate"
    )
  end

  run_appraisal_task = lambda do |task_name, primary_steps = nil|
    begin
      if primary_steps
        begin
          primary_steps.call
        rescue RuntimeError => e
          warn("[kettle-dev][#{task_name}] #{e.message}; falling back to appraisal:generate")
          run_generate_steps.call
        end
      else
        run_generate_steps.call
      end
    rescue RuntimeError => e
      abort(e.message)
    end
  end

  desc("Install Appraisal gemfiles (initial setup for projects that didn't previously use Appraisal)")
  task("appraisal:install") do
    run_in_unbundled = proc do
      run_appraisal_task.call(
        "appraisal:install",
        lambda do
          # 1) BUNDLE_GEMFILE=Appraisal.root.gemfile bundle install
          run_command.call(
            "appraisal:install failed: BUNDLE_GEMFILE=Appraisal.root.gemfile bundle install",
            appraisal_env,
            bundle,
            "install",
            "--quiet"
          )

          # 2) BUNDLE_GEMFILE=Appraisal.root.gemfile bundle exec appraisal generate-install
          run_command.call(
            "appraisal:install failed: BUNDLE_GEMFILE=Appraisal.root.gemfile bundle exec appraisal generate-install",
            appraisal_env,
            bundle,
            "exec",
            "appraisal",
            "generate-install"
          )
        end
      )
    end

    if defined?(Bundler)
      Bundler.with_unbundled_env(&run_in_unbundled)
    else
      run_in_unbundled.call
    end
  end

  desc("Generate Appraisal gemfiles without resolving appraisal locks")
  task("appraisal:generate") do
    run_in_unbundled = proc do
      run_appraisal_task.call("appraisal:generate")
    end

    if defined?(Bundler)
      Bundler.with_unbundled_env(&run_in_unbundled)
    else
      run_in_unbundled.call
    end
  end

  desc("Generate and update Appraisal gemfiles")
  task("appraisal:update") do
    run_in_unbundled = proc do
      run_appraisal_task.call(
        "appraisal:update",
        lambda do
          # 1) BUNDLE_GEMFILE=Appraisal.root.gemfile bundle install
          run_command.call(
            "appraisal:update failed: BUNDLE_GEMFILE=Appraisal.root.gemfile bundle install",
            appraisal_env,
            bundle,
            "install",
            "--quiet"
          )

          # 2) BUNDLE_GEMFILE=Appraisal.root.gemfile bundle update --bundler=<version>
          #
          # Pinned to the executing Bundler. A bare `--bundler` resolves to
          # whatever RubyGems reports as bundler's "latest", which includes
          # prereleases, so it can install a beta and record it in BUNDLED WITH;
          # that beta's vendored URI then collides with rubygems' copy and
          # spams stderr. See ReleaseCLI#update_bundler_and_commit! and
          # LockfileReset#lockfile_command for the same hazard.
          run_command.call(
            "appraisal:update failed: BUNDLE_GEMFILE=Appraisal.root.gemfile bundle update --bundler",
            appraisal_env,
            bundle,
            "update",
            bundler_version_arg
          )

          # 3) BUNDLE_GEMFILE=Appraisal.root.gemfile bundle install
          run_command.call(
            "appraisal:update failed: BUNDLE_GEMFILE=Appraisal.root.gemfile bundle install",
            appraisal_env,
            bundle,
            "install",
            "--quiet"
          )

          # 4) BUNDLE_GEMFILE=Appraisal.root.gemfile bundle exec appraisal generate-update
          run_command.call(
            "appraisal:update failed: BUNDLE_GEMFILE=Appraisal.root.gemfile bundle exec appraisal generate-update",
            appraisal_env,
            bundle,
            "exec",
            "appraisal",
            "generate-update"
          )
        end
      )
    end

    if defined?(Bundler)
      Bundler.with_unbundled_env(&run_in_unbundled)
    else
      run_in_unbundled.call
    end
  end

  # Delete all Appraisal lockfiles in gemfiles/ (*.gemfile.lock)
  desc("Delete Appraisal lockfiles (gemfiles/*.gemfile.lock)")
  task("appraisal:reset") do
    run_in_unbundled = proc do
      lock_glob = File.join("gemfiles", "*.gemfile.lock")
      locks = Dir.glob(lock_glob)

      if locks.empty?
        puts("[kettle-dev][appraisal:reset] no files matching #{lock_glob}")
      else
        failures = []
        locks.each do |f|
          begin
            File.delete(f)
          rescue Errno::ENOENT
            # Ignore if already gone
          rescue => e
            failures << [f, e]
          end
        end

        unless failures.empty?
          failed_list = failures.map { |(f, e)| "#{f} (#{e.class}: #{e.message})" }.join(", ")
          abort("appraisal:reset failed: unable to delete #{failed_list}")
        end

        puts("[kettle-dev][appraisal:reset] deleted #{locks.size} file(s)")
      end
    end

    if defined?(Bundler)
      Bundler.with_unbundled_env(&run_in_unbundled)
    else
      run_in_unbundled.call
    end
  end
rescue LoadError
  # simplecov:disable -- Appraisal is an optional development dependency.
  warn("[kettle-dev][appraisal.rake] failed to load appraisal/tasks") if Kettle::Dev::DEBUGGING
  # simplecov:enable
end
