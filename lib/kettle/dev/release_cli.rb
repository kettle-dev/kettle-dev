# frozen_string_literal: true

# External stdlib
require "digest"
require "open3"
require "shellwords"
require "time"
require "fileutils"
require "tmpdir"
require "net/http"
require "openssl"
require "json"
require "uri"
require "yaml"
require "set"

# External gems
require "kettle/ndjson"
require "kettle/rb/compat_matrix"
require "ruby-progressbar"

require_relative "interactive_release_command"
require_relative "exit_adapter"
require_relative "lockfile_reset"
require_relative "release_secrets"

module Kettle
  module Dev
    class ReleaseCLI
      RUBYGEMS_INVALID_OTP = /Your OTP code is incorrect\. Please check it and retry\./.freeze
      OTP_RETRY_DELAY_SECONDS = 2
      GITHUB_RELEASE_ASSET_UPLOAD_ATTEMPTS = 3
      GITHUB_RELEASE_ASSET_UPLOAD_RETRY_DELAY_SECONDS = 1
      QUIET_ENV = {
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
      }.freeze
      RELEASE_CHILD_ENV_KEYS = %w[
        K_RELEASE_CI_CONTINUE
        K_RELEASE_REQUIRED_REMOTES
        KETTLE_FAMILY_CONFIG
        KETTLE_PRE_RELEASE_GHA_SHA_PINS_OFFLINE
        KETTLE_RELEASE_SECRETS_PROVIDER
        KETTLE_RELEASE_SECRETS_BROKER
        KETTLE_RELEASE_GEM_SIGNING_PASSPHRASE
        KETTLE_RELEASE_GEM_SIGNING_PASSPHRASE_SOURCE
        KETTLE_RELEASE_1PASSWORD_ACCOUNT
        KETTLE_RELEASE_1PASSWORD_CLI
        KETTLE_RELEASE_1PASSWORD_ITEM
        KETTLE_RELEASE_1PASSWORD_GEM_SIGNING_PASSPHRASE_FIELD
        KETTLE_RELEASE_1PASSWORD_RUBYGEMS_OTP_FIELD
        KETTLE_RELEASE_1PASSWORD_GEM_SIGNING_PASSPHRASE_REFERENCE
        KETTLE_RELEASE_1PASSWORD_RUBYGEMS_OTP_REFERENCE
      ].freeze
      DEBUG_TRUE_VALUES = %w[1 true yes on].freeze
      RELEASE_VALIDATION_SOURCE = "https://gem.coop"
      FAMILY_MEMBER_PUBLISH_MODE_ENV = "KETTLE_RELEASE_FAMILY_MEMBER_PUBLISH"
      FAMILY_MEMBER_FINALIZE_MODE_ENV = "KETTLE_RELEASE_FAMILY_MEMBER_FINALIZE"

      class << self
        def run_cmd!(cmd)
          # For Bundler-invoked build/release, explicitly prefix SKIP_GEM_SIGNING so
          # the signing step is skipped even when Bundler scrubs ENV.
          # Always do this on CI to avoid interactive prompts; locally only when explicitly requested.
          if ENV["SKIP_GEM_SIGNING"] && /\Abundle(\s+exec)?\s+rake\s+(build|release)\b/.match?(cmd)
            cmd = "SKIP_GEM_SIGNING=true #{cmd}"
          end
          puts "$ #{cmd}"
          # Pass a plain Hash for the environment to satisfy tests and avoid ENV object oddities
          env_hash = command_env_for(cmd)

          # Some commands are interactive (e.g., `bundle exec rake release` prompting for RubyGems MFA).
          # Using capture3 detaches STDIN, preventing prompts from working. For such commands, use system
          # so they inherit the current TTY and can read the user's input.
          interactive_words = effective_command_words(cmd)
          interactive = interactive_words.first(4) == ["bundle", "exec", "rake", "release"] ||
            interactive_words.first(2) == ["gem", "push"] ||
            interactive_words.first(2) == ["bundle", "exec"] && interactive_words[2] == "kettle-changelog"
          if interactive
            ok = system(env_hash, cmd)
            unless ok
              exit_code = $?.respond_to?(:exitstatus) ? $?.exitstatus : 1
              Kettle::Dev::ExitAdapter.abort("Command failed: #{cmd} (exit #{exit_code})")
            end
            return
          end

          # Non-interactive: capture output so we can surface clear diagnostics on failure
          stdout_str, stderr_str, status = Open3.capture3(env_hash, cmd)

          # Echo command output to match prior behavior
          $stdout.print(stdout_str) unless stdout_str.nil? || stdout_str.empty?
          $stderr.print(stderr_str) unless stderr_str.nil? || stderr_str.empty?

          unless status.success?
            exit_code = status.exitstatus
            # Keep the original prefix to avoid breaking any tooling/tests that grep for it,
            # but add the exit status and a brief diagnostic tail from stderr.
            diag = ""
            unless stderr_str.to_s.empty?
              tail = stderr_str.lines.last(20).join
              diag = "\n--- STDERR (last 20 lines) ---\n#{tail}".rstrip
            end
            Kettle::Dev::ExitAdapter.abort("Command failed: #{cmd} (exit #{exit_code})#{diag}")
          end
        end

        private

        def command_env
          env_hash = ENV.respond_to?(:to_hash) ? ENV.to_hash : ENV.to_h
          return env_hash if debug_env_enabled?

          env_hash.merge(QUIET_ENV)
        end

        def command_env_for(cmd)
          env_hash = command_env
          if gem_push_command?(cmd)
            # RubyGems publication is an unbundled operation. In particular, an
            # OTP retry can run after the parent release task has selected a
            # different Gemfile; carrying that bundle into `gem push` can make
            # RubyGems load stale local dependency state before it publishes.
            return env_hash.merge(BundlerEnvGuard.unbundled_env)
          end

          return env_hash unless project_bundle_command?(cmd)

          env_hash.merge(BundlerEnvGuard.unbundled_env).merge(
            RELEASE_CHILD_ENV_KEYS.each_with_object({}) { |key, env| env[key] = nil }
          )
        end

        def project_bundle_command?(cmd)
          words = effective_command_words(cmd)
          words == ["bin/setup"] ||
            words.first(1) == ["bin/rake"] ||
            words.first(2) == ["bundle", "update"] ||
            words.first(3) == ["bundle", "exec", "rake"] ||
            words.first(3) == ["bundle", "exec", "kettle-changelog"]
        rescue ArgumentError
          false
        end

        def gem_push_command?(cmd)
          effective_command_words(cmd).first(2) == ["gem", "push"]
        rescue ArgumentError
          false
        end

        def effective_command_words(cmd)
          words = Shellwords.split(cmd.to_s)
          words.shift while words.first&.match?(/\A[A-Za-z_][A-Za-z0-9_]*=/)

          if words.first == "env"
            words.shift
            while words.any?
              if words.first == "-u"
                words.shift(2)
              elsif words.first&.include?("=")
                words.shift
              else
                break
              end
            end
          end

          words
        end

        def debug_env_enabled?
          DEBUG_TRUE_VALUES.include?(ENV.fetch("KETTLE_DEV_DEBUG", "").downcase)
        end
      end

      private

      def abort(msg)
        Kettle::Dev::ExitAdapter.abort(msg)
      end

      public

      def initialize(start_step: 0, local_ci: false, version: nil, appraisal_task: nil, skip_steps: nil, skip_changelog: nil, skip_appraisals: nil, skip_bundle_audit: nil, ci_workflows: nil, skip_remotes: nil, required_remotes: nil, secrets_provider_name: nil, yes: false, **options)
        @root = Kettle::Dev::CIHelpers.project_root
        @git = Kettle::Dev::GitAdapter.new(@root)
        @start_step = (start_step || 0).to_i
        @start_step = 0 if @start_step < 0
        @skip_steps = normalize_skip_steps(skip_steps)
        @skip_changelog = truthy_value?(skip_changelog) || truthy_value?(ENV["KETTLE_DEV_SKIP_CHANGELOG"])
        @skip_appraisals = truthy_value?(skip_appraisals) || truthy_value?(ENV["KETTLE_DEV_SKIP_APPRAISALS"])
        @ci_workflows = normalize_ci_workflows(ci_workflows || ENV["K_RELEASE_CI_WORKFLOWS"])
        @skip_remotes = normalize_remote_names(skip_remotes || ENV["K_RELEASE_SKIP_REMOTES"], "skip remotes")
        @required_remotes = normalize_required_remotes(required_remotes)
        @local_ci = !!local_ci
        @skip_bundle_audit = truthy_value?(skip_bundle_audit) || truthy_value?(ENV["KETTLE_DEV_SKIP_BUNDLE_AUDIT"])
        @yes = !!yes
        @version_override = Kettle::Dev::Versioning.normalize_explicit_version(version)
        @appraisal_task = normalize_appraisal_task(appraisal_task || ENV["KETTLE_RELEASE_APPRAISAL_TASK"])
        @release_candidate = nil
        @event_stream = options[:event_stream]
        @event_recorder = Kettle::Ndjson.event_recorder(@event_stream, phase_timings: [])
        @secrets_provider = options[:secrets_provider] || Kettle::Dev::ReleaseSecrets::Factory.build(provider_name: secrets_provider_name)
        @report_path = options[:report_path]
        @json_output = !!options[:json_output]
        @json_io = options[:json_io] || $stdout
        @command_events = []
        @diagnostics = []
        @started_at = nil
        @finished_report = nil
        @changelog_generated_coverage = false
        @release_task_lockfile_paths = {}
        @family_member_publish = truthy_value?(ENV[FAMILY_MEMBER_PUBLISH_MODE_ENV])
        @family_member_finalize = truthy_value?(ENV[FAMILY_MEMBER_FINALIZE_MODE_ENV])
      end

      def run
        @started_at = monotonic_time
        emit_run_start
        status = "ok"
        error = nil
        with_bundle_audit_skip_env do
          with_skip_changelog_env do
            with_machine_stdout_redirect do
              run_with_release_environment
            end
          end
        end
      rescue SystemExit => e
        status = e.status.to_i.zero? ? "ok" : "failed"
        error = e
        record_diagnostic("release_exit", e.message, severity: (status == "ok") ? "info" : "error", blocking: status != "ok")
        raise
      rescue => e
        status = "failed"
        error = e
        record_diagnostic("release_error", "#{e.class}: #{e.message}", severity: "error", blocking: true)
        raise
      ensure
        cleanup_release_task_lockfile!
        finish_release_report(status: status, error: error)
      end

      attr_reader :finished_report

      def run_with_release_environment
        return run_family_member_publish if family_member_publish?
        return run_family_member_finalize if family_member_finalize?

        # Changelog generation at step 0 runs the target project's test bundle
        # to collect coverage. Normalize its canonical release lockfile before
        # that subprocess starts; otherwise a local development PATH lock can
        # force Bundler to resolve an invalid mixed local/released graph.
        if release_lockfile_preflight_needed?
          prepare_release_lockfiles_for_release_tasks!
          materialize_release_lockfiles_for_release_tasks!
        end
        run_pre_release_checks! if run_step?(0)

        # 1. Ensure Bundler version and record its current release in the
        # development lockfiles before any release-preparation commit.
        if run_step?(1)
          ensure_bundler_2_7_plus!
          update_bundler_and_commit!
        end

        version = nil
        committed = nil
        trunk = nil
        feature = nil
        branch_stack_release = false

        # 2. Version detection and sanity checks + prompt
        if run_step?(2)
          version = detect_version
          puts "Detected version: #{version.inspect}"

          latest_overall = nil
          latest_for_series = nil
          begin
            gem_name = detect_gem_name
            latest_overall, latest_for_series = latest_released_versions(gem_name, version)
          rescue => e
            warn("[kettle-release] RubyGems.org release check failed: #{e.class}: #{e.message}")
            warn(e.backtrace.first(3).map { |l| "  " + l }.join("\n")) if ENV["KETTLE_DEV_DEBUG"]
            warn("Proceeding without RubyGems.org latest version info.")
          end

          if latest_overall
            msg = "Latest released: #{latest_overall}"
            if latest_for_series && latest_for_series != latest_overall
              msg += " | Latest for series #{Gem::Version.new(version).segments[0, 2].join(".")}.x: #{latest_for_series}"
            elsif latest_for_series
              msg += " (matches current series)"
            end
            puts msg

            cur = Gem::Version.new(version)
            overall = Gem::Version.new(latest_overall)
            cur_series = cur.segments[0, 2]
            overall_series = overall.segments[0, 2]
            # Ensure latest_for_series actually matches our current series; ignore otherwise.
            if latest_for_series
              lfs_series = Gem::Version.new(latest_for_series).segments[0, 2]
              latest_for_series = nil unless lfs_series == cur_series
            end
            # Determine the sanity-check target correctly for the current series.
            # If RubyGems.org has a newer overall series than our current series, only compare
            # against the latest published in our current series. If that cannot be determined
            # (e.g., offline), skip the sanity check rather than treating the overall as target.
            target = if (cur_series <=> overall_series) == -1
              latest_for_series
            else
              latest_overall
            end
            # IMPORTANT: Never treat a higher different-series "latest_overall" as a downgrade target.
            # If our current series is behind overall and RubyGems.org does not report a latest_for_series,
            # then we cannot determine the correct target for this series and should skip the check.
            if (cur_series <=> overall_series) == -1 && target.nil?
              puts "Could not determine latest released version from RubyGems.org (offline?). Proceeding without sanity check."
            elsif target
              bump = Kettle::Dev::Versioning.classify_bump(target, version)
              case bump
              when :same
                series = cur_series.join(".")
                warn("version.rb (#{version}) matches the latest released version for series #{series} (#{target}).")
                abort("Aborting: version bump required. Bump PATCH/MINOR/MAJOR/EPIC.")
              when :downgrade
                series = cur_series.join(".")
                warn("version.rb (#{version}) is lower than the latest released version for series #{series} (#{target}).")
                abort("Aborting: version must be bumped above #{target}.")
              else
                label = {epic: "EPIC", major: "MAJOR", minor: "MINOR", patch: "PATCH"}[bump] || bump.to_s.upcase
                puts "Proposed bump type: #{label} (from #{target} -> #{version})"
              end
            else
              puts "Could not determine latest released version from RubyGems.org (offline?). Proceeding without sanity check."
            end
          else
            puts "Could not determine latest released version from RubyGems.org (offline?). Proceeding without sanity check."
          end

          confirm_yes!("Have you updated lib/**/version.rb and CHANGELOG.md for v#{version}? [y/N]", "> ", "Aborted: please update version.rb and CHANGELOG.md, then re-run.")

          # Initial validation: Ensure README.md and LICENSE.txt have identical sets of copyright years; also ensure current year present when matched
          validate_copyright_years!

          # Ensure README KLOC badge reflects current CHANGELOG coverage denominator
          begin
            update_readme_kloc_badge!
          rescue => e
            warn("Failed to update KLOC badge in README: #{e.class}: #{e.message}")
          end

          # Update Rakefile.example header banner with current version and date
          begin
            update_rakefile_example_header!(version)
          rescue => e
            warn("Failed to update Rakefile.example header: #{e.class}: #{e.message}")
          end
        end

        prepare_rubocop_lts_local_branch! if rubocop_lts_release_preflight_needed?

        # 3. bin/setup
        with_release_resume_step(3) { run_cmd!(release_setup_command) } if run_step?(3)
        # 4. bin/rake
        with_release_resume_step(4) { run_cmd!(release_default_task_command) } if run_step?(4)

        # 5. appraisal:generate (optional) + canonical docs build
        with_release_resume_step(5) do
          if run_step?(5)
            appraisals_path = File.join(@root, "Appraisals")
            if skip_appraisals?
              puts "Skipping #{@appraisal_task} because --skip-appraisals was provided."
            elsif File.file?(appraisals_path)
              puts "Appraisals detected at #{Kettle::Dev.display_path(appraisals_path)}. Running: bin/rake #{@appraisal_task}"
              run_cmd!(release_project_command("bin/rake #{@appraisal_task}"))
            else
              puts "No Appraisals file found; skipping #{@appraisal_task}"
            end

            puts "Generating docs site via canonical task: bin/rake yard"
            run_cmd!(release_project_command("bin/rake yard"))
          end
        end

        # 6. git user + commit release prep
        if run_step?(6)
          prepare_release_lockfiles_for_commit!
          ensure_git_user!
          version ||= detect_version
          committed = commit_release_prep!(version)
        end

        # 7. optional local CI via act
        maybe_run_local_ci_before_push!(committed, force: local_ci?) if run_step?(7)

        # 8. ensure trunk synced
        if run_step?(8) && !local_ci?
          trunk = detect_trunk_branch
          feature = current_branch
          branch_stack_release = branch_stack_release_branch?(feature, trunk)
          if branch_stack_release
            puts "Kettle-family branch stack release branch detected: #{feature}; skipping trunk sync/rebase."
          end
          puts "Trunk branch detected: #{trunk}"
          ensure_trunk_synced_before_push!(trunk, feature) unless branch_stack_release
        elsif run_step?(8)
          puts "Local CI release mode: skipping remote trunk sync before publishing."
        end

        # 9. push branches
        if run_step?(9) && !local_ci?
          validate_release_lockfiles!(stage: "before push")
          push!
        end

        # 10. monitor CI after push
        if run_step?(10) && !local_ci?
          validate_release_lockfiles!(stage: "before CI monitoring")
          monitor_workflows_after_push!
        end

        # 11. merge feature into trunk and push
        if run_step?(11) && !local_ci?
          trunk ||= detect_trunk_branch
          feature ||= current_branch
          branch_stack_release ||= branch_stack_release_branch?(feature, trunk)
          if branch_stack_release
            puts "Kettle-family branch stack release branch detected: #{feature}; skipping merge into #{trunk}."
          else
            merge_feature_into_trunk_and_push!(trunk, feature)
          end
        end

        # 12. checkout trunk and pull
        if run_step?(12) && !local_ci?
          trunk ||= detect_trunk_branch
          feature ||= current_branch
          branch_stack_release ||= branch_stack_release_branch?(feature, trunk)
          if branch_stack_release
            puts "Kettle-family branch stack release branch detected: #{feature}; staying on release branch."
          else
            checkout!(trunk)
            pull!(trunk)
          end
        end

        # 13. signing guidance and checks
        if run_step?(13)
          if signing_enabled?
            puts "TIP: For local dry-runs or testing the release workflow, set SKIP_GEM_SIGNING=true to avoid PEM password prompts."
            if @yes
              puts "Proceeding with signing enabled because --yes was provided."
            elsif Kettle::Dev::InputAdapter.tty?
              # In CI, avoid interactive prompts when no TTY is present (e.g., act or GitHub Actions "CI validation").
              # Non-interactive CI runs should not abort here; later signing checks are either stubbed in tests
              # or will be handled explicitly by ensure_signing_setup_or_skip!.
              print("Proceed with signing enabled? This may hang waiting for a PEM password. [y/N]: ")
              ans = Kettle::Dev::InputAdapter.gets&.strip
              unless ans&.downcase&.start_with?("y")
                abort("Aborted. Re-run with SKIP_GEM_SIGNING=true bundle exec kettle-release (or set it in your environment).")
              end
            else
              warn("Non-interactive shell detected (non-TTY); skipping interactive signing confirmation.")
            end
          end

          ensure_signing_setup_or_skip!
          ensure_release_secrets_ready_for_signing! if signing_enabled? && release_secrets_configured?
        end

        # 14. build
        with_release_resume_step(14) do
          if run_step?(14)
            ensure_release_secrets_ready_for_signing! if signing_enabled? && release_secrets_configured?
            if signing_enabled? && release_secrets_configured?
              puts "Running build with gem signing passphrase from configured secrets provider (#{release_secrets_provider_label})..."
            else
              puts "Running build (you may be prompted for the signing key password)..."
            end
            run_cmd!(release_project_command("bundle exec rake build"))
          end
        end

        # 15. release and tag
        with_release_resume_step(15) do
          if run_step?(15)
            version ||= detect_version
            gem_name = detect_gem_name
            @release_candidate = build_release_candidate(gem_name, version)
            if local_ci?
              with_unpublished_candidate_cleanup { release_gem_and_tag_locally!(version) }
            else
              ensure_release_secrets_ready_for_signing! if signing_enabled? && release_secrets_configured?
              if release_secrets_configured?
                puts "Running release with configured secrets provider (#{release_secrets_provider_label}) for signing and RubyGems MFA prompts..."
              else
                puts "Running release (you may be prompted for signing key password and RubyGems MFA OTP)..."
              end
              with_unpublished_candidate_cleanup do
                run_cmd!(release_project_command("bundle exec rake release"))
                @release_candidate.published = true
                confirm_release_candidate_available!(@release_candidate)
              end
              mark_rubygems_release_cache_bust(version)
            end
          end
        end

        # 16. generate checksums
        #    Checksums are generated after release to avoid including checksums/ in gem package
        #    Rationale: Running gem_checksums before release may commit checksums/ and cause Bundler's
        #    release build to include them in the gem, thus altering the artifact, and invalidating the checksums.
        with_release_resume_step(16) do
          if run_step?(16)
            # Generate checksums for the just-built artifact, commit them, then validate
            version ||= detect_version
            gem_path = checksum_gem_path_for_version!(version)
            run_cmd!(release_child_command("bin/gem_checksums #{Shellwords.escape(gem_path)}"))
            validate_checksums!(version, stage: "after release")
          end
        end

        # 17. push checksum commit (gem_checksums already commits)
        if run_step?(17)
          push!
          push_tags! if local_ci?
        end

        # 18. create GitHub release (optional)
        if run_step?(18)
          version ||= detect_version
          created, message = maybe_create_github_release!(version)
          abort("GitHub release creation failed: #{message}") if github_release_required? && !created
        end

        # 19. push tags to remotes (final step)
        push_tags! if run_step?(19) && !local_ci?

        # Final success message
        begin
          version ||= detect_version
          gem_name = detect_gem_name
          human_output.puts "\n🚀 Release #{gem_name} v#{version} Complete 🚀"
        rescue => e
          Kettle::Dev.debug_error(e, __method__)
          # Fallback if detection fails for any reason
          human_output.puts "\n🚀 Release v#{version || "unknown"} Complete 🚀"
        end
      end

      def normalize_appraisal_task(value)
        task = value.to_s.strip
        return "appraisal:generate" if task.empty?
        return "appraisal:generate" if task == "generate" || task == "appraisal:generate"
        return "appraisal:update" if task == "update" || task == "appraisal:update"

        abort("Unsupported appraisal task #{value.inspect}; use appraisal:generate or appraisal:update.")
      end

      def normalize_skip_steps(value)
        raw_steps = Array(value).flat_map { |part| part.to_s.split(",") }.map(&:strip).reject(&:empty?)
        raw_steps.map do |raw|
          abort("Invalid skip_steps value #{raw.inspect}; use comma-separated release step numbers from 0 to 19.") unless raw.match?(/\A\d+\z/)

          step = raw.to_i
          abort("Invalid skip_steps value #{raw.inspect}; release steps are numbered 0 to 19.") unless step.between?(0, 19)

          step
        end.uniq
      end

      def normalize_ci_workflows(value)
        workflows = Array(value).flat_map { |part| part.to_s.split(",") }.map(&:strip).reject(&:empty?)
        workflows.map { |workflow| workflow.match?(/\.ya?ml\z/) ? workflow : "#{workflow}.yml" }.uniq
      end

      def normalize_remote_names(value, label)
        remotes = Array(value).flat_map { |part| part.to_s.split(",") }.map(&:strip).reject(&:empty?)
        invalid = remotes.find { |remote| !remote.match?(/\A[A-Za-z0-9_.-]+\z/) }
        abort("Invalid #{label} value #{invalid.inspect}; use comma-separated git remote names.") if invalid

        remotes.uniq
      end

      def normalize_required_remotes(value)
        remotes = normalize_remote_names(value.nil? ? ENV["K_RELEASE_REQUIRED_REMOTES"] : value, "required remotes")
        remotes.empty? ? ["origin"] : remotes
      end

      private

      def local_ci?
        @local_ci
      end

      def skip_bundle_audit?
        @skip_bundle_audit
      end

      # Kettle Family uses this mode only after it has prepared and validated
      # the shared monorepo release commit. A member may build and publish its
      # gem, but it must never alter the shared Git repository or release it.
      def family_member_publish?
        @family_member_publish
      end

      def family_member_finalize?
        @family_member_finalize
      end

      def run_family_member_publish
        version = detect_version
        prepare_release_lockfiles_for_release_tasks!
        ensure_signing_setup_or_skip!
        ensure_release_secrets_ready_for_signing! if signing_enabled? && release_secrets_configured?
        run_cmd!(release_project_command("bundle exec rake build"))

        gem_name = detect_gem_name
        @release_candidate = build_release_candidate(gem_name, version)
        with_unpublished_candidate_cleanup { publish_built_gem!(version) }
        human_output.puts "\n🚀 Published #{gem_name} v#{version} from family member mode 🚀"
      end

      # Kettle Family invokes this serially in the primary checkout after
      # concurrent member publication. bin/gem_checksums owns its checksum
      # commit; the family owns the one shared tag, pushes, and GitHub Release.
      def run_family_member_finalize
        version = detect_version
        gem_path = checksum_gem_path_for_version!(version)
        run_cmd!(release_child_command("bin/gem_checksums #{Shellwords.escape(gem_path)}"))
        validate_checksums!(version, stage: "after family member publish")
        human_output.puts "\n🔒 Finalized checksums for #{detect_gem_name} v#{version} from family member mode 🔒"
      end

      def truthy_value?(value)
        return true if value == true

        DEBUG_TRUE_VALUES.include?(value.to_s.downcase)
      end

      def run_step?(step)
        @start_step <= step && !@skip_steps.include?(step)
      end

      def rubocop_lts_release_preflight_needed?
        (3..5).any? { |step| run_step?(step) }
      end

      def release_lockfile_preflight_needed?
        # Step 0 invokes kettle-changelog, which runs `bundle exec kettle-test`
        # for fresh coverage. It therefore needs the same registry-backed
        # release lockfile as later setup, task, and documentation steps.
        run_step?(0) || (3..5).any? { |step| run_step?(step) }
      end

      def prepare_rubocop_lts_local_branch!
        local_root = rubocop_lts_local_root
        return unless local_root

        ruby_gem = selected_rubocop_lts_ruby_gem
        return unless ruby_gem

        branch = Kettle::Rb::CompatMatrix.rubocop_lts_branch_for_gem(ruby_gem)
        abort("Cannot select RUBOCOP_LTS_LOCAL branch for #{ruby_gem.inspect}.") unless branch

        checkout = File.join(local_root, "rubocop-lts")
        return if active_local_branch_stack_release_checkout?(checkout)

        current, ok = git_output(["-C", checkout, "branch", "--show-current"])
        abort("Cannot inspect RUBOCOP_LTS_LOCAL checkout at #{checkout}.") unless ok
        return if current == branch

        puts "Switching RUBOCOP_LTS_LOCAL checkout #{checkout} to #{branch} for #{ruby_gem}."
        _stdout, switched = git_output(["-C", checkout, "switch", branch])
        abort("Cannot switch RUBOCOP_LTS_LOCAL checkout at #{checkout} to #{branch}. Commit or stash local changes, then retry.") unless switched
      end

      def active_local_branch_stack_release_checkout?(checkout)
        return false if local_kettle_family_release_target_branches.empty?

        same_path?(@root, checkout)
      end

      def same_path?(left, right)
        File.realpath(left) == File.realpath(right)
      rescue Errno::ENOENT
        false
      end

      def rubocop_lts_local_root
        value = ENV["RUBOCOP_LTS_LOCAL"].to_s.strip
        return nil if value.empty? || %w[false 0 no off].include?(value.downcase)
        return File.join(Dir.home, "src", "rubocop-lts") if %w[true 1 yes on].include?(value.downcase)
        return value if value.start_with?("/")

        File.join(Dir.home, value)
      end

      def selected_rubocop_lts_ruby_gem
        path = File.join(@root, "gemfiles", "modular", "style_local.gemfile")
        return nil unless File.file?(path)

        content = File.read(path)
        # This reads the generated kettle-jem style_local.gemfile declaration
        # without evaluating the Gemfile during release preflight.
        local_gems = content[/\blocal_gems\s*=\s*%w\[(.*?)\]/m, 1].to_s.split
        local_gems.find { |gem_name| Kettle::Rb::CompatMatrix.rubocop_ruby_gem?(gem_name) }
      end

      def run_pre_release_checks!
        puts "Running pre-release checks via kettle-pre-release..."
        Kettle::Dev::PreReleaseCLI.new(check_num: 1, event_recorder: @event_recorder).run
        if skip_changelog?
          puts "Skipping kettle-changelog because --skip-changelog was provided."
        else
          run_changelog!
        end
      end

      def skip_changelog?
        @skip_changelog
      end

      def skip_appraisals?
        @skip_appraisals
      end

      def prepare_release_lockfiles_for_commit!
        # Release setup and documentation tasks can re-materialize local PATH
        # sources in the parent development bundle after the preflight reset.
        # Always normalize again at the commit boundary.
        reset_release_lockfiles!(stage: "before release prep commit")
        validate_release_lockfiles!(stage: "before release prep commit")
      end

      def prepare_release_lockfiles_for_release_tasks!
        reset_release_lockfiles!(stage: "before release task bundle installs")
      end

      # Resetting can select a platform-specific artifact that is not installed
      # in the invoking development bundle. Materialize every canonical release
      # bundle before a release gate runs `bundle exec`. Use a disposable copy:
      # Bundler may reconcile the active host platform during installation, and
      # that must never alter the canonical release-preparation lockfile.
      def materialize_release_lockfiles_for_release_tasks!
        release_lockfile_paths.each do |lockfile|
          gemfile = release_gemfile_for_lockfile(lockfile)
          next unless gemfile && File.file?(gemfile)

          begin
            stage = "before release task bundle installs"
            task_lockfile = release_task_lockfile_path(gemfile: gemfile)
            emit_release_lockfile_event(action: "install", status: "started", stage: stage, reason: File.basename(gemfile))
            puts "Installing normalized release bundle for #{File.basename(gemfile)}..."
            run_cmd!(release_child_command(
              "bundle install",
              environment: {
                "BUNDLE_GEMFILE" => gemfile,
                "BUNDLE_LOCKFILE" => task_lockfile || lockfile
              }
            ))
            emit_release_lockfile_event(action: "install", status: "ok", stage: stage, reason: File.basename(gemfile))
          rescue => error
            emit_release_lockfile_event(action: "install", status: "failed", stage: stage, reason: error.message)
            raise
          end
        end
      end

      def reset_release_lockfiles!(stage:)
        return if @release_lockfiles_reset_for_release_tasks && stage == "before release task bundle installs"

        attempts = release_lockfile_reset_attempts(stage)
        attempts.times do |index|
          attempt = index + 1
          emit_release_lockfile_event(action: "reset", status: "started", stage: stage, attempt: attempt, attempts: attempts)
          puts "Resetting release lockfiles with local path dependencies disabled #{stage} (attempt #{attempt}/#{attempts})..."
          begin
            lockfile_reset.reset(
              Kettle::Dev::LockfileReset::RELEASE_LOCKFILES_TARGET
            )
            emit_release_lockfile_event(action: "reset", status: "ok", stage: stage, attempt: attempt, attempts: attempts)
            break
          rescue Kettle::Dev::Error => error
            raise unless error.message.start_with?("Reset #{Kettle::Dev::LockfileReset::RELEASE_LOCKFILES_TARGET} failed validation:")

            retryable = retryable_release_lockfile_reset_error?(error) && attempt < attempts
            emit_release_lockfile_event(
              action: "reset",
              status: retryable ? "retrying" : "blocked",
              stage: stage,
              attempt: attempt,
              attempts: attempts,
              reason: error.message
            )
            if retryable
              puts "Release lockfile reset could not resolve a newly published workspace gem from #{RELEASE_VALIDATION_SOURCE}; waiting before retry #{attempt + 1}/#{attempts}."
              sleep(release_availability_probe_interval)
              next
            end

            # Keep non-transient release-facing failures shaped like the
            # lockfile validation guard, even when the shared reset helper
            # detects the unrepaired lockfile.
            break
          rescue => error
            retryable = retryable_release_lockfile_reset_error?(error) && attempt < attempts
            emit_release_lockfile_event(
              action: "reset",
              status: retryable ? "retrying" : "failed",
              stage: stage,
              attempt: attempt,
              attempts: attempts,
              reason: error.message
            )
            raise unless retryable

            puts "Release lockfile reset could not resolve a gem from #{RELEASE_VALIDATION_SOURCE}; waiting before retry #{attempt + 1}/#{attempts}."
            sleep(release_availability_probe_interval)
          end
        end

        diagnostics = release_lockfile_paths.flat_map { |path| release_lockfile_diagnostics(path) }
        if diagnostics.empty?
          emit_release_lockfile_event(action: "validate", status: "ok", stage: stage, count: release_lockfile_paths.length)
          puts "Release lockfile reset complete: #{release_lockfile_paths.length} lockfile(s) checked, no diagnostics remain."
        else
          emit_release_lockfile_event(
            action: "validate",
            status: "failed",
            stage: stage,
            count: diagnostics.length,
            reason: "#{diagnostics.length} diagnostic(s)"
          )
        end
        @release_lockfiles_reset_for_release_tasks = true if stage == "before release task bundle installs"
      end

      def release_lockfile_reset_attempts(stage)
        (stage == "before release task bundle installs") ? release_availability_probe_attempts : 1
      end

      def retryable_release_lockfile_reset_error?(error)
        message = error.message.to_s
        message.include?("Bundler::GemNotFound") ||
          message.include?("Could not find gem") ||
          message.include?("can no longer be found in that source") ||
          message.include?("locks local workspace gem") &&
            message.include?("not resolvable from the configured gem source")
      end

      def validate_release_lockfiles!(stage:)
        diagnostics = release_lockfile_paths.flat_map { |path| release_lockfile_diagnostics(path) }
        return if diagnostics.empty?
        if stage == "before push"
          diagnostics = reset_release_lockfiles_before_push(diagnostics)
          return if diagnostics.empty?
        end

        abort(<<~MSG)
          Release lockfile validation failed #{stage}:
          #{diagnostics.map { |diagnostic| "  - #{diagnostic}" }.join("\n")}
          Re-run bundle lock/update with local path development env disabled before releasing.
        MSG
      end

      def release_lockfile_paths
        lockfile_reset.lockfile_paths
      end

      def release_lockfile_normalization_needed?(path)
        lockfile_reset.normalization_needed?(path, strict: true)
      end

      def normalize_release_lockfile!(path)
        lockfile_reset.reset_lockfile!(path, strict: true)
      end

      def release_gemfile_for_lockfile(path)
        lockfile_reset.gemfile_for_lockfile(path)
      end

      def release_lockfile_normalization_env
        lockfile_reset.release_normalization_env
      end

      # The release process has three distinct lockfile roles:
      #
      # - canonical: tracked project lockfiles, always registry-backed;
      # - task: a disposable Gemfile.lock copy for build and publication; and
      # - tool: a tool-owned Gemfile, such as kettle-changelog's release bundle.
      #
      # A family may use local sibling gems to launch this process, but no
      # release child may inherit that graph. Git hooks are release children
      # too: they commonly load project tooling and otherwise can silently
      # rewrite the canonical lockfile with local PATH sources.
      def release_git_hook_environment
        release_child_environment
      end

      def release_lockfile_diagnostics(path)
        lockfile_reset.diagnostics(path, strict: true)
      end

      def release_lockfile_has_local_path_remote?(path)
        lockfile_reset.has_local_path_remote?(path, strict: true)
      end

      def release_lockfile_local_path_remote_lines(path)
        lockfile_reset.local_path_remote_lines(path)
      end

      def release_lockfile_empty_registry_checksums(path)
        lockfile_reset.empty_registry_checksums(path)
      end

      def release_lockfile_has_any_sha_checksum?(path)
        lockfile_reset.has_any_sha_checksum?(path)
      end

      def release_lockfile_path_source_gems(path)
        lockfile_reset.path_source_gems(path)
      end

      def release_lockfile_path_dependency_gems(path)
        lockfile_reset.path_dependency_gems(path)
      end

      def release_lockfile_label(path)
        Kettle::Dev.display_path(path)
      end

      def reset_release_lockfiles_before_push(diagnostics)
        puts "Release lockfile validation found #{diagnostics.length} issue(s) before push:"
        diagnostics.each { |diagnostic| puts "  - #{diagnostic}" }
        puts "Running one fallback release lockfile reset before push; tracked lockfile changes will amend the release prep commit."
        changed_before_reset = changed_release_lockfile_paths
        begin
          lockfile_reset.reset(Kettle::Dev::LockfileReset::RELEASE_LOCKFILES_TARGET)
        rescue Kettle::Dev::Error => error
          puts error.message
        end

        remaining = release_lockfile_paths.flat_map { |path| release_lockfile_diagnostics(path) }
        if remaining.empty?
          amend_release_lockfile_reset_commit(changed_before_reset)
          return []
        end

        puts "Release lockfile reset did not repair all before-push issues:"
        remaining.each { |diagnostic| puts "  - #{diagnostic}" }
        remaining
      end

      def amend_release_lockfile_reset_commit(changed_before_reset = [])
        paths = changed_release_lockfile_paths
        if paths.empty?
          if changed_before_reset.empty?
            puts "Fallback release lockfile reset result: diagnostics cleared, but tracked lockfiles matched the release prep commit before and after reset; no amend is possible."
          else
            puts "Fallback release lockfile reset result: diagnostics cleared by restoring tracked lockfiles to the release prep commit; no amend is needed."
          end
          return
        end

        puts "Fallback release lockfile reset result: diagnostics cleared; amending release prep commit with #{paths.length} lockfile(s)."
        abort("Failed to stage reset release lockfiles.") unless @git.add_paths(paths)
        abort("Failed to amend release prep commit with reset lockfiles.") unless @git.commit_amend_no_edit(env: release_git_hook_environment)
      end

      def changed_release_lockfile_paths
        release_lockfile_paths.select { |path| git_path_changed?(path) }
      end

      def git_path_changed?(path)
        if @git.respond_to?(:diff_head_quiet?)
          !@git.diff_head_quiet?(path)
        else
          !@git.diff_quiet?(path)
        end
      end

      def lockfile_reset
        @lockfile_reset ||= Kettle::Dev::LockfileReset.new(root: @root, command_runner: method(:run_lockfile_reset_command!))
      end

      def run_lockfile_reset_command!(command)
        Kettle::Dev::ExitAdapter.abort_as_error do
          run_cmd!(command)
        end
      end

      def run_changelog!
        cmd = release_changelog_command
        cmd = "#{cmd} --version #{Shellwords.escape(@version_override)}" if @version_override
        cmd = "#{cmd} --yes" if @yes
        cmd = "#{cmd} --events=changelog" if @event_stream
        with_project_changelog_coverage_policy { run_cmd!(cmd) }
        @changelog_generated_coverage = true
      end

      # The changelog executable is owned by kettle-changelog, not kettle-dev.
      # During the bootstrap release of kettle-dev it is therefore intentionally
      # absent from kettle-dev's bundle. When a local kettle-dev workspace is
      # supplied, run the standalone tool through that project's bundle instead
      # of relying on an ambient installed executable.
      def release_changelog_command
        gemfile = release_changelog_gemfile
        return release_child_command("bundle exec kettle-changelog") unless gemfile

        environment = {"BUNDLE_GEMFILE" => gemfile}
        coverage_gemfile = changelog_coverage_gemfile
        environment["K_CHANGELOG_COVERAGE_GEMFILE"] = coverage_gemfile if coverage_gemfile
        # Changelog coverage runs the target project's bundle. Give that nested
        # invocation a disposable lockfile for its selected coverage Gemfile so
        # Bundler's host-platform reconciliation cannot dirty the prep commit.
        if (lockfile = release_task_lockfile_path(gemfile: coverage_gemfile || File.join(@root, "Gemfile")))
          environment["KETTLE_CHANGELOG_COVERAGE_LOCKFILE"] = lockfile
        end
        if (local_root = release_changelog_local_root)
          environment["KETTLE_CHANGELOG_DEV_ROOT"] = local_root
        end
        release_child_command("bundle exec kettle-changelog", environment: environment)
      end

      def release_changelog_gemfile
        configured = ENV["K_RELEASE_CHANGELOG_GEMFILE"].to_s.strip
        unless configured.empty?
          path = File.expand_path(configured)
          return path if File.file?(path)

          abort("Configured K_RELEASE_CHANGELOG_GEMFILE does not exist: #{path}")
        end

        local_root = release_changelog_local_root
        return nil unless local_root

        changelog_root = File.join(File.expand_path(local_root), "kettle-changelog")
        candidates = [
          File.join(changelog_root, "gemfiles", "release.gemfile"),
          File.join(changelog_root, "Gemfile")
        ]
        candidates.find { |path| File.file?(path) }
      end

      def release_changelog_local_root
        local_root = ENV["KETTLE_DEV_DEV"].to_s.strip
        return nil if local_root.empty? || %w[false 0 no off].include?(local_root.downcase)

        File.expand_path(local_root)
      end

      # A generated coverage appraisal is intentionally smaller than the root
      # development bundle and therefore avoids release-only tool dependency
      # conflicts. Let kettle-changelog retain the root-Gemfile fallback when
      # a project has not generated this optional bundle.
      def changelog_coverage_gemfile
        configured = ENV["K_CHANGELOG_COVERAGE_GEMFILE"].to_s.strip
        return File.expand_path(configured, @root) unless configured.empty?

        generated = File.join(@root, "gemfiles", "coverage.gemfile")
        generated if File.file?(generated)
      end

      # Monorepo subprojects commonly disable their local hard coverage gate
      # because their narrow test suite cannot satisfy the aggregate root
      # thresholds. Preserve an explicit changelog policy, otherwise derive
      # the changelog coverage policy from the project's coverage setting.
      def with_project_changelog_coverage_policy
        original = ENV["K_CHANGELOG_COVERAGE_HARD"]
        changed = original.nil? && ENV["K_SOUP_COV_MIN_HARD"].to_s.casecmp?("false")
        return yield unless changed

        ENV["K_CHANGELOG_COVERAGE_HARD"] = "false"
        yield
      ensure
        ENV["K_CHANGELOG_COVERAGE_HARD"] = original if changed
      end

      def release_default_task_command
        # `kettle-changelog` generates strict coverage by running `bundle exec kettle-test`.
        # When that happened during this same release invocation, the default task can skip
        # its test/coverage prerequisites and still run lint, audit, documentation, and any
        # other non-test release checks. Resumed releases do not set this flag, so they keep
        # the full default task behavior.
        return release_project_command("KETTLE_DEV_SKIP_TESTS=true bin/rake") if @changelog_generated_coverage

        release_project_command("bin/rake")
      end

      def release_setup_command
        release_project_command("bin/setup")
      end

      # Canonical release commands use the tracked project lockfiles. These
      # lockfiles are shared state and are normalized/committed before release
      # prep; they must never contain sibling PATH sources.
      def release_project_command(command)
        release_child_command(command, lockfile: release_task_command?(command) ? release_task_lockfile_path : nil)
      end

      def release_task_command?(command)
        ["bundle exec rake build", "bundle exec rake release"].include?(command.to_s.strip)
      end

      # Every release child runs outside the release tool's Bundler context and
      # with local sibling switches disabled. The optional lockfile identifies
      # a disposable task lockfile; omitting it deliberately selects the
      # canonical tracked lockfile for setup, checks, docs, and checksums.
      def release_child_command(command, environment: {}, lockfile: nil)
        command_body = command
        command = +"env"
        release_child_environment.each do |key, value|
          command << " -u #{Shellwords.escape(key)}" if value.nil?
        end
        release_child_environment.each do |key, value|
          command << " #{key}=#{Shellwords.escape(value)}" unless value.nil?
        end
        environment.each do |key, value|
          command << " #{key}=#{Shellwords.escape(value)}"
        end
        command << " BUNDLE_LOCKFILE=#{Shellwords.escape(lockfile)}" if lockfile
        command << " #{command_body}"
        command
      end

      def release_child_environment
        @release_child_environment ||= begin
          release_lockfile_normalization_env
            .merge(BundlerEnvGuard.unbundled_env)
            .merge("RUBYLIB" => nil, "RUBYOPT" => nil)
        end
      end

      # Bundler may reconcile the current machine's platform while loading a
      # project bundle. That is useful during development, but it can dirty the
      # release-preparation commit between the final lockfile reset and
      # bundler/gem_tasks' release:guard_clean check. Keep that reconciliation
      # in a disposable lockfile so the committed, normalized lockfile remains
      # unchanged throughout build and publication.
      def release_task_lockfile_path(gemfile: File.join(@root, "Gemfile"))
        return @release_task_lockfile_paths[gemfile] if @release_task_lockfile_paths.key?(gemfile)

        source = "#{gemfile}.lock"
        return unless File.file?(source)

        directory = File.join(@root, "tmp", "kettle-release", "lockfiles")
        FileUtils.mkdir_p(directory)
        path = File.join(directory, "#{File.basename(gemfile)}-#{$$}.lock")
        FileUtils.cp(source, path)
        @release_task_lockfile_paths[gemfile] = path
      rescue SystemCallError => error
        abort("Unable to isolate the release task lockfile: #{error.message}")
      end

      def cleanup_release_task_lockfile!
        return if @release_task_lockfile_paths.empty?

        @release_task_lockfile_paths.each_value { |path| FileUtils.rm_f(path) }
        @release_task_lockfile_paths.clear
      end

      def confirm_yes!(message, prompt, abort_message)
        puts(message)
        if @yes
          puts("#{prompt}y")
          return
        end

        print(prompt)
        ans = Kettle::Dev::InputAdapter.gets&.strip
        abort(abort_message) unless ans&.downcase&.start_with?("y")
      end

      def changelog_strict?
        ENV.fetch("K_CHANGELOG_STRICT", "true").downcase != "false"
      end

      def changelog_coverage_hard?
        ENV.fetch("K_CHANGELOG_COVERAGE_HARD", "true").downcase != "false"
      end

      # Update the README KLOC badge number based on the denominator in the current version's COVERAGE line in CHANGELOG.md.
      # - Parses the current version section of CHANGELOG.md
      # - Finds a line matching: "- COVERAGE: ... -- <tested>/<total> lines ..."
      # - Computes KLOC = total / 1000.0
      # - Formats with three decimals (e.g., 0.076, 2.175, 10.123)
      # - Rewrites the [🧮kloc-img] badge line in README.md (and README.md.example when present)
      #   replacing only the numeric portion after "KLOC-" while preserving other URL params.
      def update_readme_kloc_badge!
        version = detect_version
        # Extract only the current version's section
        section, _compare_ref, _tag_ref = extract_changelog_for_version(version)
        return unless section

        # Example match: "- COVERAGE: 97.70% -- 2125/2175 lines in 20 files"
        m = section.lines.find { |l| /-\s*COVERAGE:\s*.+--\s*\d+\/(\d+)\s+lines/i.match?(l) }
        return unless m

        denom = m.match(/-\s*COVERAGE:\s*.+--\s*\d+\/(\d+)\s+lines/i)[1].to_i
        kloc = denom.to_f / 1000.0
        kloc_str = format("%.3f", kloc)

        update_badge_number_in_file(File.join(@root, "README.md"), kloc_str)
        example_path = File.join(@root, "README.md.example")
        update_badge_number_in_file(example_path, kloc_str) if File.file?(example_path)
      end

      # Helper to update the [🧮kloc-img] badge in the given file path.
      # Replaces only the numeric portion after "KLOC-" keeping other URL parts intact.
      def update_badge_number_in_file(path, kloc_str)
        return unless File.file?(path)

        content = File.read(path)
        # Match the specific reference line, capture groups around the number
        # Example: [🧮kloc-img]: https://img.shields.io/badge/KLOC-2.175-FFDD67.svg?style=...
        new_content = content.gsub(/(\[🧮kloc-img\]:\s*https?:\/\/img\.shields\.io\/badge\/KLOC-)(\d+(?:\.\d+)?)(-[^\s]*)/, "\\1#{kloc_str}\\3")
        if new_content != content
          File.write(path, new_content)
        end
      end

      # Update Rakefile.example banner to include current gem version and current date.
      # Looks for a line starting with "# kettle-dev Rakefile v" and replaces version/date.
      def update_rakefile_example_header!(version)
        path = File.join(@root, "Rakefile.example")
        return unless File.file?(path)

        content = File.read(path)
        today = Time.now.strftime("%Y-%m-%d")
        new_line = "# kettle-dev Rakefile v#{version} - #{today}"
        new_content = content.gsub(/^# kettle-dev Rakefile v.*$/, new_line)
        if new_content != content
          File.write(path, new_content)
        end
      end

      # Validate that README.md and CHANGELOG.md contain identical sets of copyright years.
      # This helps ensure docs are kept in sync when bumping the years.
      # Aborts with a helpful message when they differ.
      def validate_copyright_years!
        readme = File.join(@root, "README.md")
        license = File.join(@root, "LICENSE.txt")
        unless File.file?(readme) && File.file?(license)
          # If either file is missing, skip this check silently (some projects might not have both initially)
          return
        end

        # Normalize year formatting in both files before comparing
        reformat_copyright_year_lines!(readme)
        reformat_copyright_year_lines!(license)

        r_years = extract_years_from_file(readme)
        l_years = extract_years_from_file(license)
        if r_years == l_years
          # If they match, ensure the current year is present; if not, inject it into both files.
          current_year = Time.now.year
          unless r_years.include?(current_year)
            # Update both files by appending current year to the set and rewriting the lines canonically
            updated_years = r_years.dup
            updated_years << current_year
            # Write back to both files using canonical collapse formatting
            inject_years_into_file!(readme, updated_years)
            inject_years_into_file!(license, updated_years)
          end
          return
        end

        abort(<<~MSG)
          Mismatched copyright years between README.md and LICENSE.txt.
            README.md:   #{r_years.to_a.sort.join(", ")}
            LICENSE.txt: #{l_years.to_a.sort.join(", ")}
          Please update both files so they contain the identical set of years.
        MSG
      end

      # Extract a Set of Integer years from the given file.
      # It searches for lines containing the word "Copyright" (case-insensitive),
      # then parses four-digit years and year ranges like "2012-2015" (hyphen or en dash).
      # Returns Set[Integer].
      def extract_years_from_file(path)
        years = Set.new
        content = File.read(path)
        # Only consider lines that look like copyright notices to reduce false positives
        content.each_line do |line|
          next unless /copyright/i.match?(line)

          # Expand ranges first (supports hyphen-minus and en dash)
          line.scan(/\b(19\d{2}|20\d{2})\s*[-–]\s*(19\d{2}|20\d{2})\b/).each do |a, b|
            s = a.to_i
            e = b.to_i
            if e < s
              s, e = e, s
            end
            (s..e).each { |y| years << y }
          end

          # Then single standalone years
          line.scan(/\b(19\d{2}|20\d{2})\b/).each do |y|
            years << y[0].to_i
          end
        end
        years
      end

      # Collapse a set/array of years into a canonical, comma-separated string, combining
      # consecutive runs into ranges with a hyphen (YYYY-YYYY) and leaving gaps as commas.
      def collapse_years(enum)
        arr = enum.to_a.map(&:to_i).uniq.sort
        return "" if arr.empty?

        segments = []
        start = arr.first
        prev = start
        arr[1..-1].to_a.each do |y|
          if y == prev + 1
            prev = y
            next
          else
            segments << ((start == prev) ? start.to_s : "#{start}-#{prev}")
            start = prev = y
          end
        end
        segments << ((start == prev) ? start.to_s : "#{start}-#{prev}")
        segments.join(", ")
      end

      # Inject the provided set of years into copyright lines, rewriting them in canonical form.
      # - Finds lines containing 'copyright' (case-insensitive) and a years blob.
      # - Replaces that blob with the canonical collapsed form of the union of existing years and given years.
      # - If multiple copyright lines, updates each consistently.
      def inject_years_into_file!(path, years_set)
        content = File.read(path)
        changed = false
        canonical_all = collapse_years(years_set)
        new_lines = content.each_line.map do |line|
          unless /copyright/i.match?(line)
            next line
          end

          m = line.match(/\A(?<pre>.*?copyright[^0-9]*)(?<years>(?:\b(?:19|20)\d{2}\b(?:\s*[-–]\s*\b(?:19|20)\d{2}\b)?)(?:\s*,\s*\b(?:19|20)\d{2}\b(?:\s*[-–]\s*\b(?:19|20)\d{2}\b)?)*)(?<post>.*)\z/i)
          unless m
            next line
          end

          new_line = "#{m[:pre]}#{canonical_all}#{m[:post]}"
          changed ||= (new_line != line)
          new_line
        end
        if changed
          File.write(path, new_lines.join)
        end
      end

      # Rewrite copyright lines in-place to collapse years into canonical ranges.
      # Only modifies lines that contain the word "copyright" (case-insensitive).
      def reformat_copyright_year_lines!(path)
        content = File.read(path)
        changed = false
        new_lines = content.each_line.map do |line|
          unless /copyright/i.match?(line)
            next line
          end

          # Capture three parts: prefix up to first year, the year blob, and the rest
          m = line.match(/\A(?<pre>.*?copyright[^0-9]*)(?<years>(?:\b(?:19|20)\d{2}\b(?:\s*[-–]\s*\b(?:19|20)\d{2}\b)?)(?:\s*,\s*\b(?:19|20)\d{2}\b(?:\s*[-–]\s*\b(?:19|20)\d{2}\b)?)*)(?<post>.*)\z/i)
          unless m
            # No parsable year sequence on this line; leave as-is
            next line
          end

          years_blob = m[:years]
          # Reuse extraction logic on just the years blob
          years = []
          years_blob.scan(/\b(19\d{2}|20\d{2})\s*[-–]\s*(19\d{2}|20\d{2})\b/).each do |a, b|
            s = a.to_i
            e = b.to_i
            s, e = e, s if e < s
            (s..e).each { |y| years << y }
          end
          years_blob.scan(/\b(19\d{2}|20\d{2})\b/).each { |y| years << y[0].to_i }
          canonical = collapse_years(years)
          new_line = "#{m[:pre]}#{canonical}#{m[:post]}"
          changed ||= (new_line != line)
          new_line
        end
        if changed
          File.write(path, new_lines.join)
        end
      end

      def monitor_workflows_after_push!
        ensure_github_pull_request_for_ci!
        keep_release_secrets_alive!("CI monitoring")
        restart_hint = "bundle exec kettle-release --start-step 10"
        emit_ci_monitor_event(action: "start", status: "started", workflows: @ci_workflows, restart_hint: restart_hint)
        # The monitor preserves fail-fast behavior by default and returns false
        # when K_RELEASE_CI_CONTINUE explicitly allows failed CI checks.
        begin
          ci_ok = Kettle::Dev::CIMonitor.monitor_all!(
            restart_hint: restart_hint,
            workflows: @ci_workflows,
            keepalive: release_secrets_keepalive_required? ? -> { keep_release_secrets_alive!("CI monitoring") } : nil,
            event_recorder: @event_recorder
          )
          if ci_ok
            emit_ci_monitor_event(action: "finish", status: "ok", workflows: @ci_workflows, restart_hint: restart_hint)
          else
            emit_ci_monitor_event(
              action: "finish",
              status: "continued",
              workflows: @ci_workflows,
              restart_hint: restart_hint,
              reason: "CI checks failed; continuing because K_RELEASE_CI_CONTINUE=true"
            )
          end
        rescue SystemExit => error
          emit_ci_monitor_event(action: "finish", status: "failed", workflows: @ci_workflows, restart_hint: restart_hint, reason: error.message)
          raise
        rescue => error
          emit_ci_monitor_event(action: "finish", status: "failed", workflows: @ci_workflows, restart_hint: restart_hint, reason: "#{error.class}: #{error.message}")
          raise
        end
      end

      def ensure_github_pull_request_for_ci!
        branch = current_branch
        return if branch.to_s.empty?

        trunk = detect_trunk_branch
        return if branch == trunk

        gh_remote = preferred_github_remote
        return unless gh_remote

        owner, repo = parse_github_owner_repo(remote_url(gh_remote))
        return unless owner && repo

        pull_request = github_pull_request_for_branch(owner: owner, repo: repo, branch: branch, base: trunk)
        if pull_request
          puts "GitHub pull request ##{pull_request.fetch("number")} already open for #{branch} -> #{trunk}: #{pull_request.fetch("url")}"
          return
        end

        create_github_pull_request!(owner: owner, repo: repo, branch: branch, base: trunk)
      end

      def github_pull_request_for_branch(owner:, repo:, branch:, base:)
        output = gh_output!(
          "pr",
          "list",
          "--repo",
          "#{owner}/#{repo}",
          "--head",
          branch,
          "--base",
          base,
          "--state",
          "open",
          "--json",
          "number,url",
          "--limit",
          "1"
        )
        Array(JSON.parse(output)).first
      rescue JSON::ParserError => e
        Kettle::Dev.debug_error(e, __method__)
        abort("Could not parse GitHub pull request list from gh CLI.")
      end

      def create_github_pull_request!(owner:, repo:, branch:, base:)
        output = gh_output!(
          "pr",
          "create",
          "--repo",
          "#{owner}/#{repo}",
          "--head",
          branch,
          "--base",
          base,
          "--title",
          "Release #{branch}",
          "--body",
          "Automated release validation PR for `#{branch}`.\n\nThis PR lets GitHub Actions run before kettle-release merges the branch into `#{base}`."
        )
        puts "Created GitHub pull request for #{branch} -> #{base}: #{output.strip}"
      end

      def gh_output!(*args)
        stdout_str, stderr_str, status = Open3.capture3(self.class.send(:command_env), "gh", *args)
        return stdout_str if status.success?

        exit_code = status.respond_to?(:exitstatus) ? status.exitstatus : 1
        diag = stderr_str.to_s.empty? ? "" : "\n--- STDERR ---\n#{stderr_str}".rstrip
        abort("GitHub pull request setup failed: gh #{args.join(" ")} (exit #{exit_code})#{diag}")
      rescue Errno::ENOENT
        abort("GitHub pull request setup failed: gh CLI is required to create or find the release PR.")
      end

      def run_cmd!(cmd, resume_step: @release_resume_step)
        cmd = bundle_audit_skip_command(cmd)
        emit_command_event(cmd, "started", resume_step: resume_step)
        with_bundle_audit_skip_env do
          with_machine_stdout_redirect do
            run_command_with_release_secrets!(cmd)
          end
        end
        emit_command_event(cmd, "ok", resume_step: resume_step)
      rescue SystemExit => e
        emit_command_event(cmd, "failed", reason: e.message, resume_step: resume_step)
        raise
      rescue => e
        emit_command_event(cmd, "failed", reason: "#{e.class}: #{e.message}", resume_step: resume_step)
        raise
      end

      def bundle_audit_skip_command(cmd)
        return cmd unless skip_bundle_audit?
        return cmd unless /(?:\A|\s)bin\/rake\b/.match?(cmd)
        return cmd if cmd.start_with?("KETTLE_DEV_SKIP_BUNDLE_AUDIT=")

        "KETTLE_DEV_SKIP_BUNDLE_AUDIT=true #{cmd}"
      end

      def with_release_resume_step(step)
        previous_step = @release_resume_step
        @release_resume_step = step
        yield
      ensure
        @release_resume_step = previous_step
      end

      def run_command_with_release_secrets!(cmd)
        return self.class.run_cmd!(cmd) unless release_secret_command?(cmd) && release_secrets_configured?

        keep_release_secrets_alive!("prompt-bearing command")
        puts "$ #{cmd}"
        stdout_str, stderr_str, status = Kettle::Dev::InteractiveReleaseCommand.new(
          secrets_provider: @secrets_provider,
          secret_event_handler: ->(payload) { emit_secret_event(payload) }
        ).call(
          self.class.send(:command_env_for, cmd),
          cmd
        )
        return if status.success?

        if gem_release_command?(cmd) && rubygems_invalid_otp?(stdout_str, stderr_str)
          retry_gem_push_after_invalid_otp!
          return
        end

        exit_code = status.respond_to?(:exitstatus) ? status.exitstatus : 1
        diag = stderr_str.to_s.empty? ? "" : "\n--- STDERR (last 20 lines) ---\n#{stderr_str.lines.last(20).join}".rstrip
        abort("Command failed: #{cmd} (exit #{exit_code})#{diag}")
      rescue Kettle::Dev::Error => error
        abort(error.message)
      end

      def release_secrets_configured?
        !@secrets_provider.instance_of?(Kettle::Dev::ReleaseSecrets::Provider)
      end

      def release_secrets_provider_label
        release_secrets_configured? ? @secrets_provider.class.name.to_s.split("::").last : "interactive"
      end

      def gem_release_command?(cmd)
        effective_command_words(cmd).first(4) == ["bundle", "exec", "rake", "release"]
      end

      def rubygems_invalid_otp?(*output)
        output.any? { |chunk| chunk.to_s.match?(RUBYGEMS_INVALID_OTP) }
      end

      def retry_gem_push_after_invalid_otp!
        version = @release_candidate&.version || detect_version
        gem_path = gem_file_for_version(version)
        unless gem_path && File.file?(gem_path)
          abort("RubyGems rejected the OTP, but the built gem for version #{version} could not be found in pkg/.")
        end

        puts "RubyGems rejected the OTP after the release task completed; retrying the existing gem publication with a fresh OTP..."
        emit_secret_event(
          source: release_secrets_provider_label,
          action: "otp_retry",
          status: "started",
          reason: "RubyGems rejected the first OTP"
        )
        # A rejection at the TOTP boundary can leave the provider returning the
        # same code for a moment. Wait briefly before starting the retry so the
        # next prompt can obtain a refreshed code.
        sleep(OTP_RETRY_DELAY_SECONDS)
        run_cmd!("gem push #{Shellwords.escape(gem_path)}")
        emit_secret_event(
          source: release_secrets_provider_label,
          action: "otp_retry",
          status: "ok",
          reason: "existing gem artifact published after OTP retry"
        )
      rescue SystemExit, Kettle::Dev::Error
        emit_secret_event(
          source: release_secrets_provider_label,
          action: "otp_retry",
          status: "failed",
          reason: "fresh OTP retry failed"
        )
        raise
      end

      def signing_enabled?
        ENV.fetch("SKIP_GEM_SIGNING", "false").casecmp("false").zero?
      end

      def ensure_release_secrets_ready_for_signing!
        keep_release_secrets_alive!("signing preflight")
        value = @secrets_provider.gem_signing_passphrase.to_s
        abort(release_secrets_configuration_message("gem signing passphrase was empty")) if value.empty?
      rescue Kettle::Dev::Error => error
        abort(release_secrets_configuration_message(error.message))
      end

      def keep_release_secrets_alive!(purpose)
        return unless release_secrets_keepalive_required?
        return unless @secrets_provider.respond_to?(:keepalive!)

        emit_secret_event(action: "keepalive", status: "started", purpose: purpose, source: release_secrets_provider_label, elapsed: release_elapsed_label)
        @secrets_provider.keepalive!(elapsed: release_elapsed_label)
        emit_secret_event(action: "keepalive", status: "ok", purpose: purpose, source: release_secrets_provider_label, elapsed: release_elapsed_label)
      rescue Kettle::Dev::Error => error
        emit_secret_event(action: "keepalive", status: "failed", purpose: purpose, source: release_secrets_provider_label, elapsed: release_elapsed_label, reason: error.message)
        abort("Release secrets provider keepalive failed before #{purpose}: #{error.message}")
      end

      def release_secrets_keepalive_required?
        return false unless release_secrets_configured?
        if @secrets_provider.respond_to?(:keepalive_required?)
          configured = @secrets_provider.keepalive_required?
          return configured unless configured.nil?
        end

        true
      end

      def release_elapsed_label
        return nil unless @started_at

        format_elapsed_seconds(monotonic_time - @started_at)
      end

      def format_elapsed_seconds(seconds)
        total = seconds.to_f.round
        hours = total / 3600
        minutes = (total % 3600) / 60
        remaining_seconds = total % 60
        return format("%d:%02d:%02d", hours, minutes, remaining_seconds) if hours.positive?

        format("%02d:%02d", minutes, remaining_seconds)
      end

      def release_secrets_configuration_message(reason)
        <<~MSG.strip
          Release secrets provider was requested, but #{reason}.
          Configure the 1Password CLI before release:
            KETTLE_RELEASE_1PASSWORD_ITEM=Rubygems
            KETTLE_RELEASE_1PASSWORD_GEM_SIGNING_PASSPHRASE_FIELD=GEM-SIGN-PASSPHRASE
          Or provide an explicit reference:
            KETTLE_RELEASE_1PASSWORD_GEM_SIGNING_PASSPHRASE_REFERENCE=op://<vault>/<item>/<field>
          If `op` is installed outside PATH:
            KETTLE_RELEASE_1PASSWORD_CLI=/absolute/path/to/op
          Ensure `op` is installed and signed in. Secret prompts are not allowed when --secrets-provider is set.
        MSG
      end

      def release_secret_command?(cmd)
        words = effective_command_words(cmd)
        (words.first(3) == ["bundle", "exec", "rake"] && %w[build release].include?(words[3])) ||
          words.first(2) == ["gem", "push"]
      rescue ArgumentError
        false
      end

      def effective_command_words(cmd)
        words = Shellwords.split(cmd.to_s)
        words.shift while words.first&.match?(/\A[A-Za-z_][A-Za-z0-9_]*=/)

        if words.first == "env"
          words.shift
          while words.any?
            if words.first == "-u"
              words.shift(2)
            elsif words.first&.include?("=")
              words.shift
            else
              break
            end
          end
        end

        words
      end

      def with_bundle_audit_skip_env
        return yield unless skip_bundle_audit?

        previous = ENV["KETTLE_DEV_SKIP_BUNDLE_AUDIT"]
        ENV["KETTLE_DEV_SKIP_BUNDLE_AUDIT"] = "true"
        yield
      ensure
        if skip_bundle_audit?
          previous.nil? ? ENV.delete("KETTLE_DEV_SKIP_BUNDLE_AUDIT") : ENV["KETTLE_DEV_SKIP_BUNDLE_AUDIT"] = previous
        end
      end

      def with_skip_changelog_env
        return yield unless skip_changelog?

        previous = ENV["KETTLE_DEV_SKIP_CHANGELOG"]
        ENV["KETTLE_DEV_SKIP_CHANGELOG"] = "true"
        yield
      ensure
        if skip_changelog?
          previous.nil? ? ENV.delete("KETTLE_DEV_SKIP_CHANGELOG") : ENV["KETTLE_DEV_SKIP_CHANGELOG"] = previous
        end
      end

      def git_output(args)
        # Route all git interactions through the GitAdapter so tests can safely mock them
        out, ok = @git.capture(args)
        [out.to_s.strip, !!ok]
      end

      def ensure_git_user!
        name, ok1 = git_output(%w[config user.name])
        email, ok2 = git_output(%w[config user.email])
        abort("Git user.name or user.email not configured.") unless ok1 && ok2 && !name.empty? && !email.empty?
      end

      def ensure_bundler_2_7_plus!
        begin
          require "bundler"
        rescue LoadError => e
          Kettle::Dev.debug_error(e, __method__)
          abort("Bundler is required. Please install bundler >= 2.7.0 and try again.")
        end
        ver = Gem::Version.new(Bundler::VERSION)
        min = Gem::Version.new("2.7.0")
        if ver < min
          abort("kettle-release requires Bundler >= 2.7.0 for reproducible builds by default. Current: #{Bundler::VERSION}. Please upgrade bundler.")
        end
      end

      # Keep Bundler maintenance separate from the release metadata commit.
      # The project lockfiles are shared development state, so the update must
      # be real and committed rather than hidden behind a temporary lockfile.
      def update_bundler_and_commit!
        run_cmd!(release_project_command("bundle update --bundler"))

        appraisal_gemfile = File.join(@root, "Appraisal.root.gemfile")
        if File.file?(appraisal_gemfile)
          appraisal_lockfile = File.join(@root, "Appraisal.root.gemfile.lock")
          appraisal_command = "BUNDLE_GEMFILE=#{Shellwords.escape(appraisal_gemfile)} " \
            "BUNDLE_LOCKFILE=#{Shellwords.escape(appraisal_lockfile)} bundle update --bundler"
          run_cmd!(release_project_command(appraisal_command))
          run_cmd!(release_project_command("bundle exec rake appraisal:reset"))
        end

        commit_bundle_update!
      end

      def commit_bundle_update!
        paths = changed_bundle_lockfile_paths
        return false if paths.empty?

        unexpected = staged_paths - paths
        unless unexpected.empty?
          abort(<<~MSG)
            Cannot commit Bundler updates atomically because unrelated files are already staged:
            #{unexpected.map { |path| "  - #{path}" }.join("\n")}
            Commit or unstage those files, then retry the release.
          MSG
        end

        puts "Committing Bundler update in #{paths.length} lockfile(s)."
        abort("Failed to stage Bundler update lockfiles.") unless @git.add_repository_paths(paths)
        abort("Failed to commit Bundler update lockfiles.") unless @git.commit_staged("🔒️ Update bundle", env: release_git_hook_environment)
        reconcile_bundle_update_commit!
        true
      end

      def changed_bundle_lockfile_paths
        tracked, tracked_ok = git_output(["diff", "--name-only", "HEAD", "--"])
        untracked, untracked_ok = git_output(["ls-files", "--others", "--exclude-standard"])
        return [] unless tracked_ok && untracked_ok

        (tracked.lines + untracked.lines).map(&:strip).reject(&:empty?).select { |path| bundle_lockfile_path?(path) }.uniq
      end

      def staged_paths
        output, ok = git_output(["diff", "--cached", "--name-only"])
        return [] unless ok

        output.lines.map(&:strip).reject(&:empty?).uniq
      end

      def bundle_lockfile_path?(path)
        path == "Gemfile.lock" || File.basename(path).end_with?(".lock")
      end

      def reconcile_bundle_update_commit!
        3.times do
          paths = changed_bundle_lockfile_paths
          return if paths.empty?

          puts "Bundler changed lockfiles while committing; amending the bundle update commit."
          abort("Failed to stage post-commit Bundler lockfile changes.") unless @git.add_repository_paths(paths)
          abort("Failed to amend the bundle update commit.") unless @git.commit_amend_no_edit(env: release_git_hook_environment)
        end

        abort("Bundler continued changing lockfiles after the bundle update commit.") unless changed_bundle_lockfile_paths.empty?
      end

      def reconcile_release_prep_commit!
        3.times do
          output, = git_output(["status", "--porcelain"])
          return if output.empty?

          puts "Release commit hooks changed tracked files; amending the release preparation commit."
          abort("Failed to stage post-commit release changes.") unless @git.add_all
          abort("Failed to amend the release preparation commit.") unless @git.commit_amend_no_edit(env: release_git_hook_environment)
        end

        output, = git_output(["status", "--porcelain"])
        abort("Release commit hooks continued changing files after the release preparation commit.") unless output.empty?
      end

      def maybe_run_local_ci_before_push!(committed, force: false)
        mode = (ENV["K_RELEASE_LOCAL_CI"] || "").strip.downcase
        run_it =
          if force
            true
          else
            case mode
            when "true", "1", "yes", "y" then true
            when "ask"
              print("Run local CI with 'act' before pushing? [Y/n] ")
              ans = Kettle::Dev::InputAdapter.gets&.strip
              ans.nil? || ans.empty? || /\Ay(es)?\z/i.match?(ans)
            else
              false
            end
          end
        return unless run_it

        act_ok = begin
          system("act", "--version", out: File::NULL, err: File::NULL)
        rescue => e
          Kettle::Dev.debug_error(e, __method__)
          false
        end
        unless act_ok
          msg = "Local CI requires 'act'. Install https://github.com/nektos/act to enable."
          abort(msg) if force
          puts "Skipping local CI: 'act' command not found. Install https://github.com/nektos/act to enable."
          return
        end

        root = Kettle::Dev::CIHelpers.project_root
        workflows_dir = File.join(root, ".github", "workflows")
        candidates = Kettle::Dev::CIHelpers.workflows_list(root)

        chosen = (ENV["K_RELEASE_LOCAL_CI_WORKFLOW"] || "").strip
        if !chosen.empty?
          chosen = "#{chosen}.yml" unless /\.ya?ml\z/.match?(chosen)
        else
          chosen = if candidates.include?("locked_deps.yml")
            "locked_deps.yml"
          elsif candidates.include?("locked_deps.yaml")
            "locked_deps.yaml"
          else
            candidates.first
          end
        end

        unless chosen
          msg = "Local CI requires at least one workflow under .github/workflows."
          abort(msg) if force
          puts "Skipping local CI: no workflows found under .github/workflows."
          return
        end

        file_path = File.join(workflows_dir, chosen)
        unless File.file?(file_path)
          msg = "Local CI selected workflow not found: #{Kettle::Dev.display_path(file_path)}"
          abort(msg) if force
          puts "Skipping local CI: selected workflow not found: #{Kettle::Dev.display_path(file_path)}"
          return
        end

        puts "== Running local CI with act on #{chosen} =="
        ok = system("act", "-W", file_path)
        if ok
          puts "Local CI succeeded for #{chosen}."
        else
          puts "Local CI failed for #{chosen}."
          if committed
            puts "Rolling back release prep commit (soft reset)..."
            @git.reset_soft("HEAD^")
          end
          abort("Aborting due to local CI failure.")
        end
      end

      def release_gem_and_tag_locally!(version)
        tag = "v#{version}"
        gem_path = gem_file_for_version(version)
        unless gem_path && File.file?(gem_path)
          abort("Unable to locate built gem for version #{version} in pkg/. Did the build succeed?")
        end

        _out, tag_exists = git_output(["rev-parse", "-q", "--verify", "refs/tags/#{tag}"])
        if tag_exists
          puts "Local tag #{tag} already exists."
        else
          puts "Creating local git tag #{tag} without pushing it."
          abort("Failed to create local tag #{tag}.") unless @git.tag_annotated(tag, tag)
        end

        publish_built_gem!(version)
      end

      def publish_built_gem!(version)
        gem_path = gem_file_for_version(version)
        unless gem_path && File.file?(gem_path)
          abort("Unable to locate built gem for version #{version} in pkg/. Did the build succeed?")
        end

        puts "Publishing #{File.basename(gem_path)} to RubyGems without pushing git refs..."
        run_cmd!("gem push #{Shellwords.escape(gem_path)}")
        gem_name = gem_name_from_gem_path(gem_path, version)
        @release_candidate ||= build_release_candidate(gem_name, version)
        @release_candidate.published = true
        confirm_release_candidate_available!(@release_candidate)
        mark_rubygems_release_cache_bust(version, gem_name: gem_name)
      end

      def build_release_candidate(gem_name, version)
        ReleaseCandidate.new(
          gem_name: gem_name.to_s,
          version: version.to_s,
          installed_before: gem_version_installed?(gem_name, version),
          published: false
        )
      end

      def with_unpublished_candidate_cleanup
        yield
      rescue SystemExit, StandardError
        cleanup_unpublished_release_candidate(@release_candidate)
        raise
      end

      def cleanup_unpublished_release_candidate(candidate)
        return unless candidate
        return if candidate.published
        return if candidate.installed_before
        return unless gem_version_installed?(candidate.gem_name, candidate.version)

        warn(
          "Release of #{candidate.gem_name} #{candidate.version} was not validated; " \
          "uninstalling the local candidate gem so future bundle updates cannot resolve an unreleased version."
        )
        uninstall_release_candidate(candidate)
      end

      def uninstall_release_candidate(candidate)
        run_cmd!(
          "gem uninstall #{Shellwords.escape(candidate.gem_name)} " \
          "-v #{Shellwords.escape(candidate.version)} -x -I --ignore-dependencies"
        )
      rescue SystemExit, StandardError => error
        warn("Could not uninstall local candidate #{candidate.gem_name} #{candidate.version}: #{error.message}")
        warn("Manual cleanup: gem uninstall #{candidate.gem_name} -v #{candidate.version} -x -I --ignore-dependencies")
      end

      def gem_version_installed?(gem_name, version)
        Gem::Specification.reset
        Gem::Specification.find_all_by_name(gem_name.to_s, "= #{version}").any?
      rescue Gem::LoadError
        false
      end

      def confirm_release_candidate_available!(candidate)
        run_release_availability_probe(candidate)
        candidate.published = true
        true
      rescue SystemExit
        raise
      rescue => error
        abort(<<~MSG)
          Published gem availability could not be validated for #{candidate.gem_name} #{candidate.version}: #{error.class}: #{error.message}
          kettle-release will clean up any local candidate install that was introduced by this failed release attempt.
          If the push actually succeeded, resolve the registry/checksum state manually before resuming.
        MSG
      end

      def run_release_availability_probe(candidate)
        script_path = write_release_availability_probe(candidate)
        attempts = release_availability_probe_attempts
        last_stderr = nil
        last_status = nil
        sleep(release_availability_probe_initial_delay)
        attempts.times do |index|
          attempt = index + 1
          emit_release_probe_event(action: "availability", status: "started", candidate: candidate, attempt: attempt, attempts: attempts)
          puts("Validating #{candidate.gem_name} #{candidate.version} from #{RELEASE_VALIDATION_SOURCE} (attempt #{attempt}/#{attempts})")
          stdout_str = nil
          stderr_str = nil
          status = nil
          with_unbundled_release_probe_env do
            with_release_availability_probe_gem_home do |gem_home|
              stdout_str, stderr_str, status = Open3.capture3(
                self.class.send(:command_env).merge("GEM_HOME" => gem_home, "GEM_PATH" => gem_home),
                Gem.ruby,
                script_path
              )
            end
          end
          $stdout.print(stdout_str) unless stdout_str.to_s.empty?
          if status.success?
            emit_release_probe_event(action: "availability", status: "ok", candidate: candidate, attempt: attempt, attempts: attempts)
            return true
          end

          last_stderr = stderr_str
          last_status = status
          emit_release_probe_event(
            action: "availability",
            status: (attempt < attempts) ? "retrying" : "failed",
            candidate: candidate,
            attempt: attempt,
            attempts: attempts,
            reason: "exit #{status.exitstatus}"
          )
          sleep(release_availability_probe_interval) if attempt < attempts
        end

        diag = last_stderr.to_s.empty? ? "" : "\n--- STDERR ---\n#{last_stderr}".rstrip
        abort("Published gem availability probe failed for #{candidate.gem_name} #{candidate.version} after #{attempts} attempt(s) (exit #{last_status.exitstatus})#{diag}")
      ensure
        FileUtils.rm_f(script_path) if script_path
      end

      def release_availability_probe_attempts
        15
      end

      def release_availability_probe_initial_delay
        5
      end

      def release_availability_probe_interval
        10
      end

      def with_release_availability_probe_gem_home
        dir = File.join(@root, "tmp", "kettle-release")
        FileUtils.mkdir_p(dir)
        Dir.mktmpdir("probe-gem-home-", dir) { |gem_home| yield gem_home }
      end

      def with_unbundled_release_probe_env(&block)
        if defined?(Bundler)
          Bundler.with_unbundled_env(&block)
        else
          yield
        end
      end

      def write_release_availability_probe(candidate)
        dir = File.join(@root, "tmp", "kettle-release")
        FileUtils.mkdir_p(dir)
        path = File.join(dir, "validate-#{candidate.gem_name}-#{candidate.version}-#{$$}.rb")
        File.write(path, release_availability_probe_script(candidate))
        path
      end

      def release_availability_probe_script(candidate)
        GemSourceProbe.bundler_inline_script(
          name: candidate.gem_name,
          version: candidate.version,
          source_url: RELEASE_VALIDATION_SOURCE
        )
      end

      def detect_version
        Kettle::Dev::Versioning.detect_version(@root, override: @version_override)
      end

      def detect_gem_name
        env_gem_name = ENV.fetch("K_CHANGELOG_GEM_NAME", "").to_s.strip
        return env_gem_name unless env_gem_name.empty?

        gemspecs = Dir[File.join(@root, "*.gemspec")]
        abort("Could not find a .gemspec in project root.") if gemspecs.empty?
        path = gemspecs.min
        content = File.read(path)
        m = content.match(/spec\.name\s*=\s*(["'])([^"']+)\1/)
        abort("Could not determine gem name from #{Kettle::Dev.display_path(path)}.") unless m
        m[2]
      end

      def latest_released_versions(gem_name, current_version)
        data = Kettle::Dev::RubyGemsVersions.fetch(gem_name, version_hint: current_version)
        return [nil, nil] unless data.is_a?(Array)

        versions = data.map { |h| h["number"] }.compact
        versions.reject! { |v| v.to_s.include?("-pre") || v.to_s.include?(".pre") || /[a-zA-Z]/.match?(v.to_s) }
        gversions = versions.map { |s| Gem::Version.new(s) }.sort
        latest_overall = gversions.last&.to_s

        cur = Gem::Version.new(current_version)
        series = cur.segments[0, 2]
        series_versions = gversions.select { |gv| gv.segments[0, 2] == series }
        latest_series = series_versions.last&.to_s
        [latest_overall, latest_series]
      rescue => e
        Kettle::Dev.debug_error(e, __method__)
        [nil, nil]
      end

      def mark_rubygems_release_cache_bust(version, gem_name: nil)
        gem_name ||= detect_gem_name
        Kettle::Dev::RubyGemsVersions.mark_released(gem_name, version)
      rescue => error
        warn("[kettle-release] could not mark RubyGems.org cache-bust for release-state: #{error.class}: #{error.message}") if Kettle::Dev::DEBUGGING
      end

      def gem_name_from_gem_path(gem_path, version)
        basename = File.basename(gem_path, ".gem")
        basename.delete_suffix("-#{version}")
      end

      def commit_release_prep!(version)
        msg = "🔖 Prepare release v#{version}#{release_prep_ci_marker}"
        # Stage all changes (including new/untracked files) prior to committing
        abort("Failed to stage release prep changes.") unless @git.add_all
        out, _ = git_output(["status", "--porcelain"])
        if out.empty?
          puts "No changes to commit for release prep (continuing)."
          false
        else
          abort("Failed to commit release prep changes.") unless @git.commit_all(msg, env: release_git_hook_environment)
          reconcile_release_prep_commit!
          true
        end
      end

      def release_prep_ci_marker
        case ENV.fetch("KETTLE_RELEASE_FAMILY_CI_MODE", "").to_s.strip
        when "validation"
          " [kettle-family:aggregate-ci]"
        when "member"
          " [kettle-family:aggregate-member]"
        else
          ""
        end
      end

      def push!
        branch = current_branch
        abort("Could not determine current branch to push.") unless branch

        if use_all_remote?
          puts "$ git push all #{branch}"
          success = @git.push("all", branch)
          unless success
            warn("Normal push to 'all' failed; retrying with force push...")
            @git.push("all", branch, force: true)
          end
          return
        end

        remotes = []
        remotes << "origin" if has_remote?("origin") && !skipped_remote?("origin")
        remotes |= github_remote_candidates
        remotes |= gitlab_remote_candidates
        remotes |= codeberg_remote_candidates
        remotes.uniq!

        if remotes.empty?
          puts "$ git push #{branch}"
          success = @git.push(nil, branch)
          unless success
            warn("Normal push failed; retrying with force push...")
            @git.push(nil, branch, force: true)
          end
          return
        end

        remotes.each do |remote|
          puts "$ git push #{remote} #{branch}"
          success = @git.push(remote, branch)
          unless success
            warn("Push to #{remote} failed; retrying with force push...")
            @git.push(remote, branch, force: true)
          end
        end
      end

      def emit_run_start
        Kettle::Ndjson.emit_event(
          @event_recorder,
          "run_start",
          command: "release",
          root: @root,
          start_step: @start_step,
          skipped_steps: @skip_steps,
          local_ci: @local_ci,
          ci_workflows: @ci_workflows,
          skipped_remotes: @skip_remotes
        )
      end

      def emit_command_event(command, status, reason: nil, resume_step: nil)
        event = {
          phase: "release",
          index: @command_events.length + 1,
          name: command_event_name(command),
          status: status,
          reason: reason,
          summary: command_event_summary(command),
          command: command,
          changed_files: []
        }
        event[:resume_step] = resume_step if resume_step
        @command_events << event unless status == "started"
        Kettle::Ndjson.emit_step_event(@event_recorder, "command_step", event, phase: "release", index: event[:index])
      end

      def command_event_name(command)
        words = Shellwords.split(command.to_s)
        effective_words = command_event_effective_words(words)
        joined = effective_words.join(" ")

        return "kettle_changelog" if joined.start_with?("bundle exec kettle-changelog")
        return "gem_build" if joined == "bundle exec rake build"
        return "gem_release" if joined == "bundle exec rake release"
        return "gem_push" if effective_words.first(2) == ["gem", "push"]
        return "gem_checksums" if effective_words.first == "bin/gem_checksums"
        return "bundle_update" if effective_words.first(2) == ["bundle", "update"]
        return "bundle_lock" if effective_words.first(2) == ["bundle", "lock"]
        return "bin_setup" if effective_words == ["bin/setup"]
        return "default_task" if effective_words == ["bin/rake"]
        return "appraisal_generate" if effective_words == ["bin/rake", "appraisal:generate"]
        return "appraisal_update" if effective_words == ["bin/rake", "appraisal:update"]
        return "yard" if effective_words == ["bin/rake", "yard"]
        return "git_fetch" if effective_words.first(2) == ["git", "fetch"]
        return "git_pull" if effective_words.first(2) == ["git", "pull"]
        return "git_rebase" if effective_words.first(2) == ["git", "rebase"]
        return "git_merge" if effective_words.first(2) == ["git", "merge"]
        return "git_push" if effective_words.first(2) == ["git", "push"]

        effective_words.first(2).join("_").gsub(/[^A-Za-z0-9_]+/, "_").sub(/_+\z/, "")
      end

      def command_event_effective_words(words)
        words = words.dup
        words.shift while words.first&.match?(/\A[A-Za-z_][A-Za-z0-9_]*=/)

        if words.first == "env"
          words.shift
          while words.any?
            if words.first == "-u"
              words.shift(2)
            elsif words.first&.include?("=")
              words.shift
            else
              break
            end
          end
        end

        words
      end

      def command_event_summary(command)
        words = Shellwords.split(command.to_s)
        effective_words = command_event_effective_words(words)
        joined = effective_words.join(" ")

        return "changelog" if joined.start_with?("bundle exec kettle-changelog")
        return "bundle update" if effective_words.first(2) == ["bundle", "update"]
        return command_event_bundle_lock_summary(words) if effective_words.first(2) == ["bundle", "lock"]
        return "setup" if effective_words == ["bin/setup"]
        return "default task" if effective_words == ["bin/rake"]
        return "appraisals" if effective_words == ["bin/rake", "appraisal:generate"]
        return "appraisals" if effective_words == ["bin/rake", "appraisal:update"]
        return "documentation" if effective_words == ["bin/rake", "yard"]
        return "build gem" if joined == "bundle exec rake build"
        return "publish gem" if joined == "bundle exec rake release"
        return "push gem" if effective_words.first(2) == ["gem", "push"]
        return "checksums" if effective_words.first == "bin/gem_checksums"
        return effective_words[2] if effective_words.first(2) == ["git", "fetch"] && effective_words[2]
        return effective_words[2] if effective_words.first(2) == ["git", "push"] && effective_words[2]
        return effective_words[2] if effective_words.first(2) == ["git", "pull"] && effective_words[2]
        return effective_words[2] if effective_words.first(2) == ["git", "rebase"] && effective_words[2]
        return effective_words[2] if effective_words.first(2) == ["git", "merge"] && effective_words[2]

        nil
      end

      def command_event_bundle_lock_summary(words)
        gemfile = words.find { |word| word.start_with?("BUNDLE_GEMFILE=") }&.split("=", 2)&.last
        return "lockfile" unless gemfile

        File.basename(gemfile)
      end

      def record_diagnostic(kind, message, severity:, blocking:)
        diagnostic = {
          kind: kind,
          severity: severity,
          message: message.to_s,
          blocking: blocking
        }
        @diagnostics << diagnostic
        Kettle::Ndjson.emit_diagnostic_event(@event_recorder, diagnostic, index: @diagnostics.length)
      end

      def emit_secret_event(payload)
        status = payload.fetch(:status).to_s
        mark = case status
        when "started"
          ">"
        when "ok"
          "."
        when "failed"
          "!"
        else
          "?"
        end
        Kettle::Ndjson.emit_event(
          @event_recorder,
          "secret_provider",
          payload.merge(
            phase: "release",
            provider: release_secrets_provider_label,
            mark: mark
          )
        )
      end

      def emit_remote_parity_event(action:, remote: nil, status: nil, trunk: nil, attempt: nil, attempts: nil, required: nil, reason: nil, remotes: nil)
        mark = release_progress_mark(status)
        Kettle::Ndjson.emit_event(
          @event_recorder,
          "remote_parity",
          action: action,
          phase: "release",
          remote: remote,
          status: status,
          trunk: trunk,
          attempt: attempt,
          attempts: attempts,
          required: required,
          reason: reason,
          remotes: remotes,
          mark: mark
        )
      end

      def emit_release_lockfile_event(action:, status:, stage:, attempt: nil, attempts: nil, count: nil, reason: nil)
        Kettle::Ndjson.emit_event(
          @event_recorder,
          "release_lockfile",
          action: action,
          phase: "release",
          status: status,
          stage: stage,
          attempt: attempt,
          attempts: attempts,
          count: count,
          reason: reason,
          mark: release_progress_mark(status)
        )
      end

      def emit_release_probe_event(action:, status:, candidate:, attempt:, attempts:, reason: nil)
        Kettle::Ndjson.emit_event(
          @event_recorder,
          "release_probe",
          action: action,
          phase: "release",
          status: status,
          gem: candidate.gem_name,
          version: candidate.version,
          source: RELEASE_VALIDATION_SOURCE,
          attempt: attempt,
          attempts: attempts,
          reason: reason,
          mark: release_progress_mark(status)
        )
      end

      def release_progress_mark(status)
        case status.to_s
        when "started"
          ">"
        when "ok", "skipped"
          "."
        when "failed", "blocked"
          "!"
        when "retrying"
          ">"
        else
          ">"
        end
      end

      def emit_ci_monitor_event(action:, status:, workflows:, restart_hint:, reason: nil)
        mark = case status.to_s
        when "started"
          ">"
        when "ok"
          "."
        when "failed"
          "!"
        else
          "?"
        end
        Kettle::Ndjson.emit_event(
          @event_recorder,
          "ci_monitor",
          action: action,
          phase: "release",
          status: status,
          workflows: workflows,
          restart_hint: restart_hint,
          reason: reason,
          mark: mark
        )
      end

      def finish_release_report(status:, error:)
        return if @finished_report

        duration_ms = @started_at ? duration_ms_since(@started_at) : nil
        @finished_report = {
          command: "release",
          root: @root,
          version: safe_detect_version,
          gem_name: safe_detect_gem_name,
          start_step: @start_step,
          skipped_steps: @skip_steps,
          local_ci: @local_ci,
          ci_workflows: @ci_workflows,
          skipped_remotes: @skip_remotes,
          status: status,
          error_class: error&.class&.name,
          error_message: error&.message,
          duration_ms: duration_ms,
          command_events: @command_events,
          diagnostics: @diagnostics,
          diagnostics_count: @diagnostics.length,
          phase_timings: @event_recorder.phase_timings
        }.compact
        Kettle::Ndjson.emit_summary_event(@event_recorder, @finished_report)
        write_release_report(@finished_report)
        @json_io.puts(JSON.pretty_generate(@finished_report)) if @json_output
      end

      def write_release_report(report)
        return unless @report_path

        FileUtils.mkdir_p(File.dirname(@report_path))
        File.write(@report_path, "#{JSON.pretty_generate(report)}\n")
      end

      def with_machine_stdout_redirect
        return yield unless @json_output || @event_stream

        previous_stdout = $stdout
        $stdout = $stderr
        yield
      ensure
        $stdout = previous_stdout if previous_stdout
      end

      def human_output
        (@json_output || @event_stream) ? $stderr : $stdout
      end

      def safe_detect_version
        detect_version
      rescue
        nil
      end

      def safe_detect_gem_name
        detect_gem_name
      rescue
        nil
      end

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def duration_ms_since(started_at)
        ((monotonic_time - started_at) * 1000).round(3)
      end

      def push_tags!
        # After release, push tags to remotes according to policy:
        # 1) If a remote named "all" exists, push tags only to it.
        # 2) Otherwise, if other remotes exist, push tags to each of them.
        # 3) If no remotes are configured, push tags using default remote.
        if use_all_remote?
          ok = @git.push_tags("all")
          warn("Push tags to 'all' reported failure.") unless ok
          return
        end

        remotes = active_remotes
        remotes -= ["all"] if remotes
        if remotes.nil? || remotes.empty?
          ok = @git.push_tags(nil)
          warn("Push tags (default remote) reported failure.") unless ok
        else
          remotes.each do |remote|
            ok = @git.push_tags(remote)
            warn("Push tags to #{remote} reported failure.") unless ok
          end
        end
      end

      def detect_trunk_branch
        out, ok = git_output(["remote", "show", "origin"])
        abort("Failed to get origin remote info.") unless ok
        m = out.lines.find { |l| l.include?("HEAD branch") }
        abort("Unable to detect trunk branch from origin.") unless m
        m.split.last
      end

      def checkout!(branch)
        ok = @git.checkout(branch)
        abort("Failed to checkout #{branch}") unless ok
      end

      def pull!(branch)
        ok = @git.pull("origin", branch)
        abort("Failed to pull origin #{branch}") unless ok
      end

      def current_branch
        @git.current_branch
      end

      def list_remotes
        @git.remotes
      end

      def remotes_with_urls
        @git.remotes_with_urls
      end

      def remote_url(name)
        @git.remote_url(name)
      end

      def github_remote_candidates
        active_remote_candidates(remotes_with_urls.select { |n, u| u.include?("github.com") }.keys)
      end

      def gitlab_remote_candidates
        active_remote_candidates(remotes_with_urls.select { |n, u| u.include?("gitlab.com") }.keys)
      end

      def codeberg_remote_candidates
        active_remote_candidates(remotes_with_urls.select { |n, u| u.include?("codeberg.org") }.keys)
      end

      def preferred_github_remote
        cands = github_remote_candidates
        return if cands.empty?

        # Prefer explicitly named GitHub remotes first, then origin (only if it points to GitHub), else the first candidate
        explicit = cands.find { |n| n == "github" } || cands.find { |n| n == "gh" }
        return explicit if explicit
        return "origin" if cands.include?("origin")

        cands.first
      end

      def parse_github_owner_repo(url)
        Kettle::Dev::CIHelpers.parse_hosted_repo(url, "github.com") || [nil, nil]
      end

      def has_remote?(name)
        list_remotes.include?(name)
      end

      def skipped_remote?(name)
        @skip_remotes.include?(name)
      end

      def required_remote?(name)
        @required_remotes.include?(name)
      end

      def active_remotes
        list_remotes.reject { |remote| skipped_remote?(remote) }
      end

      def active_remote_candidates(candidates)
        candidates.reject { |remote| skipped_remote?(remote) }
      end

      def use_all_remote?
        has_remote?("all") && @skip_remotes.empty?
      end

      def remote_branch_exists?(remote, branch)
        _out, ok = git_output(["show-ref", "--verify", "--quiet", "refs/remotes/#{remote}/#{branch}"])
        ok
      end

      def ahead_behind_counts(local_ref, remote_ref)
        out, ok = git_output(["rev-list", "--left-right", "--count", "#{local_ref}...#{remote_ref}"])
        return [0, 0] unless ok && !out.empty?

        parts = out.split
        left = parts[0].to_i
        right = parts[1].to_i
        [left, right]
      end

      def trunk_behind_remote?(trunk, remote)
        return false unless remote_branch_exists?(remote, trunk)

        _ahead, behind = ahead_behind_counts(trunk, "#{remote}/#{trunk}")
        behind.positive?
      end

      def ensure_trunk_synced_before_push!(trunk, feature)
        if has_remote?("all")
          remotes = active_remotes
          skipped = list_remotes.select { |remote| skipped_remote?(remote) }
          required = remotes.select { |remote| required_remote?(remote) }
          puts "Remote 'all' detected. Fetching from active remotes and enforcing strict trunk parity..."
          puts "Skipping configured remotes: #{skipped.join(", ")}" unless skipped.empty?
          puts "Required release parity remotes: #{required.join(", ")}" unless required.empty?
          fetched_remotes = []
          emit_remote_parity_event(action: "start", status: "started", trunk: trunk, remotes: remotes - ["all"])
          remotes.each do |remote|
            next if remote == "all"

            fetched_remotes << remote if fetch_remote_for_parity!(remote)
          end
          missing_from = []
          fetched_remotes.each do |r|
            if remote_branch_exists?(r, trunk)
              _ahead, behind = ahead_behind_counts(trunk, "#{r}/#{trunk}")
              missing_from << r if behind.positive?
            end
          end
          unless missing_from.empty?
            emit_remote_parity_event(action: "missing", status: "failed", trunk: trunk, remotes: missing_from, reason: "missing commits")
            abort("Local #{trunk} is missing commits present on: #{missing_from.join(", ")}. Please sync trunk first.")
          end
          puts "Local #{trunk} has all commits from remotes: #{fetched_remotes.join(", ")}"
          emit_remote_parity_event(action: "ok", status: "ok", trunk: trunk, remotes: fetched_remotes)
          return
        end

        run_cmd!("git fetch origin #{Shellwords.escape(trunk)}")
        if trunk_behind_remote?(trunk, "origin")
          puts "Local #{trunk} is behind origin/#{trunk}. Rebasing..."
          cur = current_branch
          checkout!(trunk) unless cur == trunk
          run_cmd!("git pull --rebase origin #{Shellwords.escape(trunk)}")
          checkout!(feature) unless feature.nil? || feature == trunk
          run_cmd!("git rebase #{Shellwords.escape(trunk)}")
          puts "Rebase complete. Will push updated branch next."
        else
          puts "Local #{trunk} is up to date with origin/#{trunk}."
        end

        gh_remote = preferred_github_remote
        if gh_remote && gh_remote != "origin"
          puts "GitHub remote detected: #{gh_remote}. Fetching #{trunk}..."
          run_cmd!("git fetch #{gh_remote} #{Shellwords.escape(trunk)}")

          left, right = ahead_behind_counts("origin/#{trunk}", "#{gh_remote}/#{trunk}")
          if left.zero? && right.zero?
            puts "origin/#{trunk} and #{gh_remote}/#{trunk} are already in sync."
            return
          end

          checkout!(trunk)
          run_cmd!("git pull --rebase origin #{Shellwords.escape(trunk)}")

          if left.positive? && right.positive?
            puts "origin/#{trunk} and #{gh_remote}/#{trunk} have diverged (#{left} ahead of GH, #{right} behind GH)."
            puts "Choose how to reconcile:"
            puts "  [r] Rebase local/#{trunk} on top of #{gh_remote}/#{trunk} (push to origin)"
            puts "  [m] Merge --no-ff #{gh_remote}/#{trunk} into #{trunk} (push to origin and #{gh_remote})"
            puts "  [a] Abort"
            print("> ")
            choice = Kettle::Dev::InputAdapter.gets&.strip&.downcase
            case choice
            when "r"
              run_cmd!("git rebase #{Shellwords.escape("#{gh_remote}/#{trunk}")}")
              run_cmd!("git push origin #{Shellwords.escape(trunk)}")
              puts "Rebased #{trunk} onto #{gh_remote}/#{trunk} and pushed to origin."
            when "m"
              run_cmd!("git merge --no-ff #{Shellwords.escape("#{gh_remote}/#{trunk}")}")
              run_cmd!("git push origin #{Shellwords.escape(trunk)}")
              run_cmd!("git push #{Shellwords.escape(gh_remote)} #{Shellwords.escape(trunk)}")
              puts "Merged #{gh_remote}/#{trunk} into #{trunk} and pushed to origin and #{gh_remote}."
            else
              abort("Aborted by user. Please reconcile trunks and re-run.")
            end
          elsif right.positive? && left.zero?
            puts "Fast-forwarding #{trunk} to include #{gh_remote}/#{trunk}..."
            run_cmd!("git merge --ff-only #{Shellwords.escape("#{gh_remote}/#{trunk}")}")
            run_cmd!("git push origin #{Shellwords.escape(trunk)}")
          elsif left.positive? && right.zero?
            puts "origin/#{trunk} is ahead of #{gh_remote}/#{trunk}; no action required before push."
          end
        end
      end

      def fetch_remote_for_parity!(remote)
        command = "git fetch #{Shellwords.escape(remote)}"
        attempts = remote_fetch_parity_attempts
        last_error = nil
        attempts.times do |index|
          attempt = index + 1
          puts "Fetching remote '#{remote}' for release parity (attempt #{attempt}/#{attempts})"
          emit_remote_parity_event(action: "fetch", remote: remote, status: "started", attempt: attempt, attempts: attempts, required: required_remote?(remote))
          begin
            run_cmd!(command)
            emit_remote_parity_event(action: "fetch", remote: remote, status: "ok", attempt: attempt, attempts: attempts, required: required_remote?(remote))
            return true
          rescue SystemExit => error
            last_error = error
          rescue => error
            last_error = error
          end
          sleep(remote_fetch_parity_interval) if attempt < attempts
        end

        detail = last_error&.message.to_s
        if required_remote?(remote)
          emit_remote_parity_event(action: "fetch", remote: remote, status: "failed", attempts: attempts, required: true, reason: detail)
          abort(remote_fetch_failure_message(remote, detail))
        end

        message = optional_remote_fetch_failure_message(remote, detail)
        warn(message)
        emit_remote_parity_event(action: "skip", remote: remote, status: "skipped", attempts: attempts, required: false, reason: detail)
        record_diagnostic("release_remote_skipped", message, severity: "warning", blocking: false)
        false
      end

      def remote_fetch_parity_attempts
        3
      end

      def remote_fetch_parity_interval
        5
      end

      def remote_fetch_failure_message(remote, detail)
        <<~MSG
          Unable to fetch required git remote '#{remote}' during release parity checks.
          kettle-release enforces trunk parity across active remotes before publishing.

          If this remote is temporarily unavailable or intentionally not part of this release,
          rerun with one of:
            kettle-release --skip-remotes #{remote}
            K_RELEASE_SKIP_REMOTES=#{remote} kettle-release

          Original failure:
          #{detail}
        MSG
      end

      def optional_remote_fetch_failure_message(remote, detail)
        <<~MSG
          Unable to fetch optional git remote '#{remote}' during release parity checks; skipping this remote for this release.
          Required remotes still block release parity checks.

          To make this remote block releases, configure:
            kettle-release --required-remotes #{remote}
            K_RELEASE_REQUIRED_REMOTES=#{remote} kettle-release

          Original failure:
          #{detail}
        MSG
      end

      def merge_feature_into_trunk_and_push!(trunk, feature)
        return if feature.nil? || feature == trunk

        puts "Merging #{feature} into #{trunk} (after CI success)..."
        checkout!(trunk)
        run_cmd!("git pull --rebase origin #{Shellwords.escape(trunk)}")
        run_cmd!("git merge #{Shellwords.escape(feature)}")
        run_cmd!("git push origin #{Shellwords.escape(trunk)}")
        puts "Merged #{feature} into #{trunk} and pushed. The PR (if any) should auto-close."
      end

      def branch_stack_release_branch?(branch, trunk = nil)
        return false if branch.to_s.empty?
        return false if trunk && branch == trunk

        local_kettle_family_release_target_branches.include?(branch)
      end

      def local_kettle_family_release_target_branches
        local_kettle_family_config_paths.each do |path|
          next unless File.file?(path)

          begin
            data = Kettle::Dev.safe_load_yaml_file(path) || {}
            branches = Array(dig_string_keys(data, "release", "target_branches")) +
              Array(dig_string_keys(data, "branches", "release_targets"))
            return branches.map(&:to_s).reject(&:empty?) unless branches.empty?
          rescue Psych::Exception => e
            warn("Ignoring invalid kettle-family config #{Kettle::Dev.display_path(path)}: #{e.message}")
          end
        end
        []
      end

      def local_kettle_family_config_paths
        [
          File.join(@root, ".kettle-family.yml"),
          File.join(@root, ".structuredmerge", "kettle-family.yml")
        ]
      end

      def dig_string_keys(data, *keys)
        keys.reduce(data) do |memo, key|
          break nil unless memo.is_a?(Hash)

          memo[key] || memo[key.to_sym]
        end
      end

      def ensure_signing_setup_or_skip!
        # Treat any non-/true/i value as an explicit skip signal
        return if ENV.fetch("SKIP_GEM_SIGNING", "").casecmp("true").zero?

        user = ENV.fetch("GEM_CERT_USER", ENV["USER"])
        cert_path = File.join(@root, "certs", "#{user}.pem")
        unless File.exist?(cert_path)
          abort(<<~MSG)
            Gem signing appears enabled but no public cert found at:
              #{Kettle::Dev.display_path(cert_path)}
            Add your public key to certs/<USER>.pem (or set GEM_CERT_USER), or set SKIP_GEM_SIGNING to build unsigned.
          MSG
        end
        puts "Found signing cert: #{Kettle::Dev.display_path(cert_path)}"
        puts "When prompted during build/release, enter the PEM password for ~/.ssh/gem-private_key.pem"
      end

      def validate_checksums!(version, stage: "")
        gem_path = checksum_gem_path_for_version!(version)
        actual = compute_sha256(gem_path)
        checks_path = File.join(@root, "checksums", "#{File.basename(gem_path)}.sha256")
        unless File.file?(checks_path)
          abort("Expected checksum file not found: #{checks_path}. Did bin/gem_checksums run?")
        end
        expected = File.read(checks_path).strip
        if actual != expected
          abort(<<~MSG)
            SHA256 mismatch #{stage}:
              gem:   #{gem_path}
              sha256sum: #{actual}
              file: #{checks_path}
              file: #{expected}
            The artifact being released must match the checksummed artifact exactly.
            Retry locally: bundle exec rake build && bin/gem_checksums && bundle exec rake release
          MSG
        else
          puts "Checksum OK #{stage}: #{File.basename(gem_path)}"
        end
      end

      def checksum_gem_path_for_version!(version)
        gem_path = gem_file_for_version(version)
        unless gem_path && File.file?(gem_path)
          abort("Unable to locate built gem for version #{version} in pkg/. Did the build succeed?")
        end
        gem_path
      end

      def gem_file_for_version(version)
        pkg = File.join(@root, "pkg")
        pattern = File.join(pkg, "*.gem")
        gems = Dir[pattern].select { |p| File.basename(p).include?("-#{version}.gem") }
        gems.max
      end

      def compute_sha256(path)
        if system("which sha256sum > /dev/null 2>&1")
          out, _ = Open3.capture2e("sha256sum", path)
          out.split.first
        elsif system("which shasum > /dev/null 2>&1")
          out, _ = Open3.capture2e("shasum", "-a", "256", path)
          out.split.first
        else
          require "digest"
          Digest::SHA256.file(path).hexdigest
        end
      end

      # If GITHUB_TOKEN is present, create a GitHub release for the given version tag.
      # Title: v<version>
      # Body: the CHANGELOG section for this version, followed by the two link references for this version.
      def maybe_create_github_release!(version, assets: [])
        if truthy_value?(ENV["KETTLE_RELEASE_SKIP_GITHUB_RELEASE"])
          message = "GitHub release creation disabled for this release context"
          puts "Skipping GitHub release creation: #{message}."
          return [true, message]
        end
        token = github_token
        if token.empty?
          message = "GITHUB_TOKEN or GH_TOKEN is not set; skipping GitHub release creation. Set a token with repo:public_repo (classic) or contents:write scope."
          warn(message)
          return [false, message]
        end

        gh_remote = preferred_github_remote
        url = remote_url(gh_remote || "origin")
        owner, repo = parse_github_owner_repo(url)
        unless owner && repo
          message = "GitHub token present but could not determine GitHub owner/repo from remotes. Skipping release creation."
          warn(message)
          return [false, message]
        end

        section, compare_ref, tag_ref = extract_changelog_for_version(version)
        unless section
          message = "CHANGELOG.md does not contain a section for #{version}. Skipping GitHub release creation."
          warn(message)
          return [false, message]
        end

        body = +""
        body << section.rstrip
        body << "\n\n"
        body << compare_ref if compare_ref
        body << tag_ref if tag_ref
        # Append funding footer from FUNDING.md if present
        footer = extract_release_notes_footer
        body << "\n" << footer if footer && !footer.strip.empty?

        tag = "v#{version}"
        puts "Creating GitHub release #{owner}/#{repo} #{tag}..."
        emit_github_release_event(action: "create", status: "started", tag: tag, assets: Array(assets).length)
        ok, msg = github_create_release(owner: owner, repo: repo, token: token, tag: tag, title: tag, body: body, assets: assets)
        emit_github_release_event(action: "create", status: ok ? "ok" : "failed", tag: tag, assets: Array(assets).length, reason: msg)
        if ok
          puts "GitHub release created for #{tag}."
        else
          warn("GitHub release creation skipped/failed: #{msg}")
        end
        [ok, msg]
      end

      def maybe_update_github_release!(version)
        token = github_token
        return [false, "GITHUB_TOKEN or GH_TOKEN is not set"] if token.empty?

        owner, repo = parse_github_owner_repo(remote_url(preferred_github_remote || "origin"))
        return [false, "could not determine GitHub owner/repo from remotes"] unless owner && repo

        body = github_release_body(version)
        return [false, "CHANGELOG.md does not contain a section for #{version}"] unless body

        github_update_release(owner: owner, repo: repo, token: token, tag: "v#{version}", title: "v#{version}", body: body)
      end

      def github_release_body(version)
        section, compare_ref, tag_ref = extract_changelog_for_version(version)
        return unless section

        body = +section.rstrip
        body << "\n\n" << compare_ref if compare_ref
        body << tag_ref if tag_ref
        footer = extract_release_notes_footer
        body << "\n" << footer if footer && !footer.strip.empty?
        body
      end

      # Validate the immutable inputs required to backfill a GitHub Release.
      # This must never create a tag or publish a gem as a side effect.
      def github_release_backfill_check(version, require_rubygems: true)
        normalized_version = version.to_s.delete_prefix("v")
        tag = "v#{normalized_version}"
        diagnostics = []
        token = github_token
        diagnostics << "GITHUB_TOKEN is not set" if token.empty?

        gem_name = detect_gem_name
        if require_rubygems && !rubygems_version_published?(gem_name, normalized_version)
          diagnostics << "RubyGems.org does not list #{gem_name} #{normalized_version}"
        end

        remote = preferred_github_remote
        if remote.nil?
          diagnostics << "no GitHub remote is configured"
        elsif !remote_tag_exists?(remote, tag)
          diagnostics << "remote #{remote.inspect} does not contain tag #{tag}"
        end

        section, = extract_changelog_for_version(normalized_version)
        diagnostics << "CHANGELOG.md does not contain a section for #{normalized_version}" unless section

        {
          "ok" => diagnostics.empty?,
          "version" => normalized_version,
          "tag" => tag,
          "gem_name" => gem_name,
          "remote" => remote,
          "diagnostics" => diagnostics
        }
      end

      def github_release_token_configured?
        !github_token.empty?
      end

      def github_release_required?
        github_release_token_configured? && truthy_value?(ENV["KETTLE_RELEASE_REQUIRE_GITHUB_RELEASE"])
      end

      def github_token
        token = ENV.fetch("GITHUB_TOKEN", "").strip
        return token unless token.empty?

        ENV.fetch("GH_TOKEN", "").strip
      end

      def rubygems_version_published?(gem_name, version)
        versions = Kettle::Dev::RubyGemsVersions.fetch(gem_name, version_hint: version, refresh: true)
        Array(versions).any? { |entry| entry.is_a?(Hash) && entry["number"].to_s == version.to_s }
      rescue => error
        warn("Could not verify RubyGems.org publication for #{gem_name} #{version}: #{error.class}: #{error.message}")
        false
      end

      def remote_tag_exists?(remote, tag)
        _stdout, _stderr, status = Open3.capture3("git", "ls-remote", "--exit-code", "--tags", remote, "refs/tags/#{tag}", chdir: @root)
        status.success?
      rescue SystemCallError => error
        warn("Could not verify remote tag #{tag}: #{error.class}: #{error.message}")
        false
      end

      # Returns [section_text, compare_ref_line, tag_ref_line]
      def extract_changelog_for_version(version)
        path = resolved_changelog_path
        return [nil, nil, nil] unless File.file?(path)

        content = File.read(path)
        lines = content.lines

        # Find section start
        start_idx = lines.index { |l| l.start_with?("## [#{version}]") }
        return [nil, nil, nil] unless start_idx

        i = start_idx + 1
        # Find next section heading or EOF
        while i < lines.length && !lines[i].start_with?("## [")
          i += 1
        end
        section = lines[start_idx...(i)].join

        # Find link refs (anywhere after Unreleased or at end; simple global scan acceptable)
        compare_ref = lines.find { |l| l.start_with?("[#{version}]: ") }
        tag_ref = lines.find { |l| l.start_with?("[#{version}t]: ") }
        # Ensure newline termination
        compare_ref = compare_ref&.end_with?("\n") ? compare_ref : (compare_ref && compare_ref + "\n")
        tag_ref = tag_ref&.end_with?("\n") ? tag_ref : (tag_ref && tag_ref + "\n")
        [section, compare_ref, tag_ref]
      rescue => e
        warn("Failed to parse CHANGELOG.md: #{e.class}: #{e.message}")
        [nil, nil, nil]
      end

      def resolved_changelog_path
        path = ENV.fetch("K_CHANGELOG_PATH", "").to_s.strip
        path = "CHANGELOG.md" if path.empty?
        File.expand_path(path, @root)
      end

      def extract_release_notes_footer
        path = File.join(@root, "FUNDING.md")
        return unless File.file?(path)

        content = File.read(path)
        start_tag = "<!-- RELEASE-NOTES-FOOTER-START -->"
        end_tag = "<!-- RELEASE-NOTES-FOOTER-END -->"
        s = content.index(start_tag)
        e = content.index(end_tag)
        return unless s && e && e > s

        # Extract between tags, excluding the tags themselves
        block = content[(s + start_tag.length)...e]
        # Normalize: trim trailing whitespace but keep internal formatting
        block = block.lstrip # drop leading newline/space
        block.rstrip
      rescue => e
        warn("[kettle-release] Failed to extract release notes footer from FUNDING.md: #{e.class}: #{e.message}")
        nil
      end

      # POST to GitHub Releases API
      # Returns [ok(Boolean), message(String)]
      def github_create_release(owner:, repo:, token:, tag:, title:, body:, assets: [])
        uri = URI("https://api.github.com/repos/#{owner}/#{repo}/releases")
        req = Net::HTTP::Post.new(uri)
        req["Accept"] = "application/vnd.github+json"
        req["Authorization"] = "token #{token}"
        req["User-Agent"] = "kettle-dev-release-cli"
        req.body = JSON.dump({
          tag_name: tag,
          name: title,
          body: body,
          draft: false,
          prerelease: false
        })

        res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
          http.request(req)
        end

        case res
        when Net::HTTPSuccess, Net::HTTPCreated
          return [true, "created"] if Array(assets).empty?

          release = JSON.parse(res.body)
          asset_messages = Array(assets).map { |asset| github_upload_release_asset(release.fetch("id"), owner: owner, repo: repo, token: token, path: asset) }
          github_release_asset_result(asset_messages, "created")
        else
          if res.code.to_s == "422" && res.body.to_s.include?("already_exists")
            return [true, "already exists"] if Array(assets).empty?

            update_existing_github_release_with_assets(
              owner: owner,
              repo: repo,
              token: token,
              tag: tag,
              title: title,
              body: body,
              assets: assets
            )
          else
            [false, "HTTP #{res.code}: #{res.body}"]
          end
        end
      rescue => e
        [false, "#{e.class}: #{e.message}"]
      end

      def update_existing_github_release_with_assets(owner:, repo:, token:, tag:, title:, body:, assets:)
        release, error = github_release_for_tag(owner: owner, repo: repo, token: token, tag: tag)
        return [false, error] unless release

        updated, error = github_update_release_by_id(
          release.fetch("id"),
          owner: owner,
          repo: repo,
          token: token,
          title: title,
          body: body
        )
        return [false, error] unless updated

        existing_names = Array(release["assets"]).filter_map { |asset| asset["name"] }.to_set
        missing_assets = Array(assets).reject { |asset| existing_names.include?(File.basename(asset)) }
        return [true, "updated existing release with all assets present"] if missing_assets.empty?

        asset_messages = missing_assets.map do |asset|
          github_upload_release_asset(release.fetch("id"), owner: owner, repo: repo, token: token, path: asset)
        end
        github_release_asset_result(asset_messages, "updated existing release")
      end

      def github_release_asset_result(asset_messages, success_prefix)
        failures = asset_messages.reject(&:first).map(&:last)
        return [false, failures.join("; ")] unless failures.empty?

        asset_noun = asset_messages.one? ? "asset" : "assets"
        [true, "#{success_prefix} with #{asset_messages.length} #{asset_noun} uploaded"]
      end

      def github_release_for_tag(owner:, repo:, token:, tag:)
        uri = URI("https://api.github.com/repos/#{owner}/#{repo}/releases/tags/#{tag}")
        request = Net::HTTP::Get.new(uri)
        request["Accept"] = "application/vnd.github+json"
        request["Authorization"] = "token #{token}"
        request["User-Agent"] = "kettle-dev-release-cli"
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
        return [JSON.parse(response.body), nil] if response.is_a?(Net::HTTPSuccess)

        [nil, "release #{tag} was not found (HTTP #{response.code})"]
      rescue => e
        [nil, "#{e.class}: #{e.message}"]
      end

      def github_upload_release_asset(release_id, owner:, repo:, token:, path:)
        path = File.expand_path(path)
        return [false, "asset does not exist: #{path}"] unless File.file?(path)

        attempts = GITHUB_RELEASE_ASSET_UPLOAD_ATTEMPTS
        attempts.times do |attempt|
          emit_github_release_event(
            action: "asset_upload",
            status: "started",
            asset: File.basename(path),
            attempt: attempt + 1,
            attempts: attempts
          )
          result = github_upload_release_asset_once(release_id, owner: owner, repo: repo, token: token, path: path)
          retrying = !result.first && retryable_github_release_asset_upload_result?(result.last) && attempt < attempts - 1
          status = if result.first
            "ok"
          elsif retrying
            "retrying"
          else
            "failed"
          end
          emit_github_release_event(
            action: "asset_upload",
            status: status,
            asset: File.basename(path),
            attempt: attempt + 1,
            attempts: attempts,
            reason: result.first ? nil : result.last
          )
          return result unless retrying

          warn("GitHub release asset upload failed for #{File.basename(path)}; retrying #{attempt + 2}/#{attempts}.")
          sleep(GITHUB_RELEASE_ASSET_UPLOAD_RETRY_DELAY_SECONDS)
        end
      rescue => e
        [false, "asset #{File.basename(path)}: #{e.class}: #{e.message}"]
      end

      def github_upload_release_asset_once(release_id, owner:, repo:, token:, path:)
        uri = URI("https://uploads.github.com/repos/#{owner}/#{repo}/releases/#{release_id}/assets")
        uri.query = URI.encode_www_form(name: File.basename(path))
        req = Net::HTTP::Post.new(uri)
        req["Accept"] = "application/vnd.github+json"
        req["Authorization"] = "token #{token}"
        req["Content-Type"] = "application/octet-stream"
        req["User-Agent"] = "kettle-dev-release-cli"
        req.body = File.binread(path)
        res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(req) }
        return [true, File.basename(path)] if res.is_a?(Net::HTTPSuccess) || res.is_a?(Net::HTTPCreated)

        [false, "asset #{File.basename(path)}: HTTP #{res.code}: #{res.body}"]
      rescue OpenSSL::SSL::SSLError, IOError, SystemCallError, Timeout::Error => e
        [false, "asset #{File.basename(path)}: #{e.class}: #{e.message}"]
      end

      def retryable_github_release_asset_upload_result?(message)
        message.match?(/(?:OpenSSL::SSL::SSLError|IOError|Errno::|(?:Net::)?(?:Open|Read)Timeout|HTTP (?:429|5\d\d))/)
      end

      def emit_github_release_event(action:, status:, tag: nil, asset: nil, assets: nil, attempt: nil, attempts: nil, reason: nil)
        Kettle::Ndjson.emit_event(
          @event_recorder,
          "github_release",
          action: action,
          phase: "release",
          status: status,
          tag: tag,
          asset: asset,
          assets: assets,
          attempt: attempt,
          attempts: attempts,
          reason: reason,
          mark: release_progress_mark(status)
        )
      end

      def github_update_release(owner:, repo:, token:, tag:, title:, body:)
        release, error = github_release_for_tag(owner: owner, repo: repo, token: token, tag: tag)
        return [false, error] unless release

        github_update_release_by_id(release.fetch("id"), owner: owner, repo: repo, token: token, title: title, body: body)
      end

      def github_update_release_by_id(id, owner:, repo:, token:, title:, body:)
        uri = URI("https://api.github.com/repos/#{owner}/#{repo}/releases/#{id}")
        request = Net::HTTP::Patch.new(uri)
        request["Accept"] = "application/vnd.github+json"
        request["Authorization"] = "token #{token}"
        request["User-Agent"] = "kettle-dev-release-cli"
        request.body = JSON.dump(name: title, body: body)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
        response.is_a?(Net::HTTPSuccess) ? [true, "updated"] : [false, "HTTP #{response.code}: #{response.body}"]
      rescue => e
        [false, "#{e.class}: #{e.message}"]
      end
    end
  end
end

class Kettle::Dev::ReleaseCLI::ReleaseCandidate
  attr_accessor :gem_name, :version, :installed_before, :published

  def initialize(gem_name:, version:, installed_before:, published:)
    @gem_name = gem_name
    @version = version
    @installed_before = installed_before
    @published = published
  end
end
