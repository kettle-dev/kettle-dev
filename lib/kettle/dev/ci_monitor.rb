# frozen_string_literal: true

# External stdlib
require "uri"
require "json"
require "net/http"
require "kettle/ndjson"

module Kettle
  module Dev
    # CIMonitor centralizes CI monitoring logic (GitHub Actions and GitLab pipelines)
    # so it can be reused by both kettle-release and Rake tasks (e.g., ci:act).
    #
    # Public API is intentionally small and based on environment/project introspection
    # via CIHelpers, matching the behavior historically implemented in ReleaseCLI.
    module CIMonitor
      module_function

      # Abort helper (delegates through ExitAdapter so specs can trap exits)
      def abort(msg)
        Kettle::Dev::ExitAdapter.abort(msg)
      end
      module_function :abort

      # Small helper to map CI run status/conclusion to an emoji.
      # Reused by ci:act and release summary.
      # @param status [String, nil]
      # @param conclusion [String, nil]
      # @return [String]
      def status_emoji(status, conclusion)
        case status.to_s
        when "queued" then "⏳️"
        when "in_progress", "running" then "👟"
        when "completed"
          (conclusion.to_s == "success") ? "✅" : "🍅"
        else
          # Some APIs report only a final state string like "success"/"failed"
          return "✅" if conclusion.to_s == "success" || status.to_s == "success"
          return "🍅" if conclusion.to_s == "failure" || status.to_s == "failed"

          "⏳️"
        end
      end
      module_function :status_emoji

      # Monitor both GitHub and GitLab CI for the current project/branch.
      # This mirrors ReleaseCLI behavior and returns false when failures are
      # tolerated through K_RELEASE_CI_CONTINUE.
      #
      # @param restart_hint [String] guidance command shown on failure
      # @return [Boolean] whether all configured CI providers passed
      def monitor_all!(restart_hint: "bundle exec kettle-release --start-step 10", workflows: nil, keepalive: nil, event_recorder: nil, **options)
        results = [
          monitor_github_internal!(restart_hint: restart_hint, workflows: workflows, keepalive: keepalive, event_recorder: event_recorder),
          monitor_gitlab_internal!(restart_hint: restart_hint, keepalive: keepalive, event_recorder: event_recorder)
        ]
        abort("CI configuration not detected (GitHub or GitLab). Ensure CI is configured and remotes point to the correct hosts.") if results.all?(&:nil?)

        results.all? { |result| result != false }
      end

      def continue_ci_failures?
        !!(Kettle::Dev::ENV_TRUE_RE =~ ENV.fetch("K_RELEASE_CI_CONTINUE", "false"))
      end
      module_function :continue_ci_failures?

      # Public wrapper to monitor GitLab pipeline with abort-on-failure semantics.
      # Matches RBS and call sites expecting ::monitor_gitlab!
      # Returns false when GitLab is not configured for this repo/branch.
      # @param restart_hint [String]
      # @return [Boolean]
      def monitor_gitlab!(restart_hint: "bundle exec kettle-release --start-step 10")
        result = monitor_gitlab_internal!(restart_hint: restart_hint)
        result.nil? ? false : result
      end
      module_function :monitor_gitlab!

      # Non-aborting collection across GH and GL, returning a compact results hash.
      # Results format:
      # ```ruby
      #   {
      #     github: [ {workflow: "file.yml", status: "completed", conclusion: "success"|"failure"|nil, url: String} ],
      #     gitlab: { status: "success"|"failed"|"blocked"|"unknown"|nil, url: String }
      #   }
      # ```
      # @return [Hash]
      def collect_all
        results = {github: [], gitlab: nil}
        begin
          gh = collect_github
          results[:github] = gh if gh
        rescue => e
          Kettle::Dev.debug_error(e, __method__)
        end
        begin
          gl = collect_gitlab
          results[:gitlab] = gl if gl
        rescue => e
          Kettle::Dev.debug_error(e, __method__)
        end
        results
      end
      module_function :collect_all

      # Print a concise summary like ci:act and return whether everything is green.
      # @param results [Hash]
      # @return [Boolean] true when all checks passed or were unknown, false when any failed
      def summarize_results(results)
        all_ok = true
        gh_items = results[:github] || []
        unless gh_items.empty?
          puts "GitHub Actions:"
          gh_items.each do |item|
            emoji = status_emoji(item[:status], item[:conclusion])
            details = [item[:status], item[:conclusion]].compact.join("/")
            wf = item[:workflow]
            puts "  - #{wf}: #{emoji} (#{details}) #{"-> #{item[:url]}" if item[:url]}"
            all_ok &&= (item[:conclusion] == "success")
          end
        end
        gl = results[:gitlab]
        if gl
          status = if gl[:status] == "success"
            "success"
          else
            ((gl[:status] == "failed") ? "failure" : nil)
          end
          emoji = status_emoji(gl[:status], status)
          details = gl[:status].to_s
          puts "GitLab Pipeline: #{emoji} (#{details}) #{"-> #{gl[:url]}" if gl[:url]}"
          all_ok &&= (gl[:status] != "failed")
        end
        all_ok
      end
      module_function :summarize_results

      # Prompt user to continue or quit when failures are present; otherwise return.
      # Designed for kettle-release.
      # @param restart_hint [String]
      # @return [void]
      def monitor_and_prompt_for_release!(restart_hint: "bundle exec kettle-release --start-step 10")
        results = collect_all
        any_checks = !(results[:github].nil? || results[:github].empty?) || !!results[:gitlab]
        abort("CI configuration not detected (GitHub or GitLab). Ensure CI is configured and remotes point to the correct hosts.") unless any_checks

        ok = summarize_results(results)
        return if ok

        # Non-interactive environments default to quitting unless explicitly allowed
        env_val = ENV.fetch("K_RELEASE_CI_CONTINUE", "false")
        non_interactive_continue = !!(Kettle::Dev::ENV_TRUE_RE =~ env_val)
        if !$stdin.tty?
          abort("CI checks reported failures. Fix and restart from CI validation (#{restart_hint}).") unless non_interactive_continue
          puts "CI checks reported failures, but continuing due to K_RELEASE_CI_CONTINUE=true."
          return
        end

        # Prompt exactly once; avoid repeated printing in case of unexpected input buffering.
        # Accept c/continue to proceed or q/quit to abort. Any other input defaults to quit with a message.
        print("One or more CI checks failed. (c)ontinue or (q)uit? ")
        ans = Kettle::Dev::InputAdapter.gets
        if ans.nil?
          abort("Aborting (no input available). Fix CI, then restart with: #{restart_hint}")
        end
        ans = ans.strip.downcase
        if ans == "c" || ans == "continue"
          puts "Continuing release despite CI failures."
        elsif ans == "q" || ans == "quit"
          abort("Aborting per user choice. Fix CI, then restart with: #{restart_hint}")
        else
          abort("Unrecognized input '#{ans}'. Aborting. Fix CI, then restart with: #{restart_hint}")
        end
      end
      module_function :monitor_and_prompt_for_release!

      # --- Collectors ---
      def collect_github
        root = Kettle::Dev::CIHelpers.ci_project_root
        workflows = Kettle::Dev::CIHelpers.workflows_list(root)
        gh_remote = preferred_github_remote
        return unless gh_remote && !workflows.empty?

        branch = Kettle::Dev::CIHelpers.current_branch
        abort("Could not determine current branch for CI checks.") unless branch

        url = remote_url(gh_remote)
        owner, repo = parse_github_owner_repo(url)
        return unless owner && repo

        total = workflows.size
        return [] if total.zero?

        puts "Checking GitHub Actions workflows on #{branch} (#{owner}/#{repo}) via remote '#{gh_remote}'"
        pbar = if defined?(ProgressBar)
          ProgressBar.create(title: "GHA", total: total, format: "%t %b %c/%C", length: 30)
        end
        # Initial sleep same as aborting path
        begin
          initial_sleep = Integer(ENV["K_RELEASE_CI_INITIAL_SLEEP"])
        rescue
          initial_sleep = nil
        end
        sleep((initial_sleep && initial_sleep >= 0) ? initial_sleep : 3)

        results = {}
        idx = 0
        loop do
          wf = workflows[idx]
          run = Kettle::Dev::CIHelpers.latest_run(owner: owner, repo: repo, workflow_file: wf, branch: branch)
          if run
            if Kettle::Dev::CIHelpers.success?(run)
              unless results[wf]
                status = run["status"] || "completed"
                conclusion = run["conclusion"] || "success"
                results[wf] = {workflow: wf, status: status, conclusion: conclusion, url: run["html_url"]}
                pbar&.increment
              end
            elsif Kettle::Dev::CIHelpers.failed?(run)
              unless results[wf]
                results[wf] = {workflow: wf, status: run["status"], conclusion: run["conclusion"] || "failure", url: run["html_url"] || "https://github.com/#{owner}/#{repo}/actions/workflows/#{wf}"}
                pbar&.increment
              end
            end
          end
          break if results.size == total

          idx = (idx + 1) % total
          sleep(1)
        end
        pbar&.finish unless pbar&.finished?
        results.values
      end
      module_function :collect_github

      def collect_gitlab
        root = Kettle::Dev::CIHelpers.ci_project_root
        gitlab_ci = File.exist?(File.join(root, ".gitlab-ci.yml"))
        gl_remote = gitlab_remote_candidates.first
        return unless gitlab_ci && gl_remote

        branch = Kettle::Dev::CIHelpers.current_branch
        abort("Could not determine current branch for CI checks.") unless branch

        owner, repo = Kettle::Dev::CIHelpers.repo_info_gitlab
        return unless owner && repo

        puts "Checking GitLab pipeline on #{branch} (#{owner}/#{repo}) via remote '#{gl_remote}'"
        pbar = if defined?(ProgressBar)
          ProgressBar.create(title: "GL", total: 1, format: "%t %b %c/%C", length: 30)
        end
        result = {status: "unknown", url: nil}
        loop do
          pipe = Kettle::Dev::CIHelpers.gitlab_latest_pipeline(owner: owner, repo: repo, branch: branch)
          if pipe
            result[:url] ||= pipe["web_url"] || "https://gitlab.com/#{owner}/#{repo}/-/pipelines"
            if Kettle::Dev::CIHelpers.gitlab_success?(pipe)
              result[:status] = "success"
              pbar&.increment unless pbar&.finished?
            elsif Kettle::Dev::CIHelpers.gitlab_failed?(pipe)
              reason = (pipe["failure_reason"] || "").to_s
              if /insufficient|quota|minute/i.match?(reason)
                result[:status] = "unknown"
                pbar&.finish unless pbar&.finished?
              else
                result[:status] = "failed"
                pbar&.increment unless pbar&.finished?
              end
            elsif pipe["status"] == "blocked"
              result[:status] = "blocked"
              pbar&.finish unless pbar&.finished?
            end
            break
          end
          sleep(1)
        end
        pbar&.finish unless pbar&.finished?
        result
      end
      module_function :collect_gitlab

      def monitor_github_internal!(restart_hint:, workflows: nil, keepalive: nil, event_recorder: nil)
        root = Kettle::Dev::CIHelpers.ci_project_root
        workflows = Array(workflows).empty? ? Kettle::Dev::CIHelpers.workflows_list(root) : Array(workflows)
        gh_remote = preferred_github_remote
        return unless gh_remote && !workflows.empty?

        branch = Kettle::Dev::CIHelpers.current_branch
        abort("Could not determine current branch for CI checks.") unless branch

        url = remote_url(gh_remote)
        owner, repo = parse_github_owner_repo(url)
        return unless owner && repo

        total = workflows.size
        abort("No GitHub workflows found under .github/workflows; aborting.") if total.zero?

        head_sha = Kettle::Dev::CIHelpers.current_head_sha
        abort("Could not determine local HEAD SHA for GitHub Actions checks.") unless head_sha && !head_sha.empty?

        passed = {}
        failed = {}
        started = {}
        emit_ci_monitor_event(
          event_recorder,
          action: "github_discover",
          status: "started",
          provider: "github",
          remote: gh_remote,
          owner: owner,
          repo: repo,
          branch: branch,
          head_sha: head_sha,
          workflows: workflows,
          total: total
        )
        puts "Ensuring GitHub Actions workflows pass on #{branch} (#{owner}/#{repo}) via remote '#{gh_remote}'"
        puts "Waiting for GitHub Actions runs to start for HEAD #{head_sha[0, 12]}."
        emit_ci_monitor_event(
          event_recorder,
          action: "github_wait",
          status: "started",
          provider: "github",
          branch: branch,
          head_sha: head_sha,
          completed: 0,
          total: total
        )
        pbar = if defined?(ProgressBar)
          ProgressBar.create(title: "CI", total: total, format: "%t %b %c/%C", length: 30)
        end
        # Small initial delay to allow GitHub to register the newly pushed commit and enqueue workflows.
        # Configurable via K_RELEASE_CI_INITIAL_SLEEP (seconds); defaults to 3s.

        initial_sleep = begin
          Integer(ENV["K_RELEASE_CI_INITIAL_SLEEP"])
        rescue
          nil
        end

        sleep((initial_sleep && initial_sleep >= 0) ? initial_sleep : 3)
        start_timeout = github_start_timeout
        poll_interval = github_poll_interval
        start_deadline = monotonic_time + start_timeout
        keepalive_timer = keepalive_timer(keepalive)
        all_started_emitted = false
        loop do
          keepalive_timer.call

          # Poll each unfinished workflow once per cycle. Polling one workflow
          # per sleep made the global start timeout dependent on workflow order:
          # late-dispatched workflows could be checked only once before timing
          # out, while completed workflows consumed the remaining polls.
          pending_workflows = workflows.reject { |candidate| passed[candidate] || failed[candidate] }
          break if pending_workflows.empty?

          completed = passed.size + failed.size
          pending_workflows.each do |wf|
            keepalive_timer.call
            run = Kettle::Dev::CIHelpers.latest_run(owner: owner, repo: repo, workflow_file: wf, branch: branch, require_head: true, head_sha: head_sha)
            completed_workflow = nil
            if run
              unless started[wf]
                started[wf] = true
                emit_ci_monitor_event(
                  event_recorder,
                  action: "github_workflow",
                  status: "started",
                  provider: "github",
                  workflow: wf,
                  url: run["html_url"],
                  run_status: run["status"],
                  conclusion: run["conclusion"],
                  completed: passed.size,
                  total: total
                )
              end
              if started.size == total && !all_started_emitted
                all_started_emitted = true
                emit_ci_monitor_event(
                  event_recorder,
                  action: "github_started",
                  status: "ok",
                  provider: "github",
                  completed: passed.size,
                  total: total,
                  started: started.size
                )
              end
              if Kettle::Dev::CIHelpers.success?(run)
                unless passed[wf] || failed[wf]
                  passed[wf] = true
                  completed_workflow = wf
                  pbar&.increment
                  emit_ci_monitor_event(
                    event_recorder,
                    action: "github_workflow",
                    status: "ok",
                    provider: "github",
                    workflow: wf,
                    url: run["html_url"],
                    run_status: run["status"],
                    conclusion: run["conclusion"],
                    completed: passed.size,
                    total: total
                  )
                end
              elsif !failed[wf]
                # Detect a failure at the JOB level while the run is still
                # in_progress: a large matrix keeps the run-level status
                # pending for many minutes after its first job has already
                # concluded failure, but an operator watching the Actions UI
                # sees the red job immediately. Abort as soon as any job is
                # definitively red so the release stops burning minutes that
                # a re-run will have to spend anyway.
                run_failed = Kettle::Dev::CIHelpers.failed?(run)
                failed_job = nil
                if !passed[wf] && !run_failed && run["status"] != "completed"
                  # Run still in flight: poll its jobs so a single red job in
                  # a large matrix aborts immediately instead of waiting for
                  # the whole workflow to conclude.
                  jobs = Kettle::Dev::CIHelpers.run_jobs(owner: owner, repo: repo, run_id: run["id"])
                  failed_job = jobs.find do |job|
                    job["status"] == "completed" && job["conclusion"] && job["conclusion"] != "success" && job["conclusion"] != "skipped"
                  end
                end
                next unless run_failed || failed_job

                puts
                wf_url = run["html_url"] || "https://github.com/#{owner}/#{repo}/actions/workflows/#{wf}"
                failed_job_note = failed_job ? " (job: #{failed_job["name"]})" : ""
                wf_url = failed_job["html_url"] if failed_job && failed_job["html_url"]
                emit_ci_monitor_event(
                  event_recorder,
                  action: "github_workflow",
                  status: "failed",
                  provider: "github",
                  workflow: wf,
                  url: wf_url,
                  run_status: run["status"],
                  conclusion: run["conclusion"],
                  failed_job: failed_job && failed_job["name"],
                  completed: passed.size,
                  total: total,
                  reason: "Workflow failed#{failed_job_note}"
                )
                unless continue_ci_failures?
                  abort("Workflow failed#{failed_job_note}: #{wf} -> #{wf_url} Fix the workflow, then restart this tool from CI validation with: #{restart_hint}")
                end

                failed[wf] = true
                pbar&.increment
                puts "Continuing CI monitoring despite #{wf} failure because K_RELEASE_CI_CONTINUE=true."
              end
            end
            completed = passed.size + failed.size
            emit_ci_monitor_event(
              event_recorder,
              action: "github_tick",
              status: "started",
              provider: "github",
              workflow: wf,
              run_status: run && run["status"],
              conclusion: run && run["conclusion"],
              completed_workflow: completed_workflow,
              completed: completed,
              total: total,
              started: started.size
            )
          end
          break if completed == total
          if started.size < total && monotonic_time >= start_deadline
            missing = (workflows - started.keys).join(", ")
            puts
            emit_ci_monitor_event(
              event_recorder,
              action: "github_timeout",
              status: "failed",
              provider: "github",
              missing: workflows - started.keys,
              head_sha: head_sha,
              total: total,
              completed: passed.size,
              reason: "Timed out waiting for workflows to start"
            )
            abort("Timed out after #{start_timeout}s waiting for GitHub Actions workflows to start for HEAD #{head_sha[0, 12]}: #{missing}. Confirm GitHub Actions started, then restart this tool from CI validation with: #{restart_hint}")
          end

          sleep(poll_interval)
        end
        pbar&.finish unless pbar&.finished?
        emit_ci_monitor_event(
          event_recorder,
          action: "github_complete",
          status: failed.empty? ? "ok" : "failed",
          provider: "github",
          workflows: workflows,
          completed: passed.size + failed.size,
          total: total,
          failed: failed.keys
        )
        if failed.empty?
          puts "\nAll GitHub workflows passing (#{passed.size}/#{total})."
        else
          puts "\nGitHub workflows completed with failures (#{passed.size}/#{total} passed); continuing because K_RELEASE_CI_CONTINUE=true."
        end
        failed.empty?
      end
      module_function :monitor_github_internal!

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
      module_function :monotonic_time

      def github_start_timeout
        seconds = begin
          Integer(ENV["K_RELEASE_CI_START_TIMEOUT"])
        rescue
          nil
        end
        (seconds && seconds >= 0) ? seconds : 300
      end
      module_function :github_start_timeout

      def github_poll_interval
        seconds = begin
          Float(ENV["K_RELEASE_CI_POLL_INTERVAL"])
        rescue
          nil
        end
        (seconds && seconds >= 0) ? seconds : 1
      end
      module_function :github_poll_interval

      def keepalive_timer(keepalive)
        interval = keepalive_interval
        last_run = nil
        lambda do
          if keepalive
            now = monotonic_time
            if !last_run || (now - last_run) >= interval
              keepalive.call
              last_run = now
            end
          end
        end
      end
      module_function :keepalive_timer

      def keepalive_interval
        seconds = begin
          Float(ENV["KETTLE_RELEASE_SECRET_KEEPALIVE_INTERVAL"])
        rescue
          nil
        end
        (seconds && seconds >= 0) ? seconds : 240.0
      end
      module_function :keepalive_interval

      def monitor_gitlab_internal!(restart_hint:, keepalive: nil, event_recorder: nil)
        root = Kettle::Dev::CIHelpers.ci_project_root
        gitlab_ci = File.exist?(File.join(root, ".gitlab-ci.yml"))
        gl_remote = gitlab_remote_candidates.first
        return unless gitlab_ci && gl_remote

        branch = Kettle::Dev::CIHelpers.current_branch
        abort("Could not determine current branch for CI checks.") unless branch

        owner, repo = Kettle::Dev::CIHelpers.repo_info_gitlab
        return unless owner && repo

        emit_ci_monitor_event(
          event_recorder,
          action: "gitlab_discover",
          status: "started",
          provider: "gitlab",
          remote: gl_remote,
          owner: owner,
          repo: repo,
          branch: branch,
          total: 1
        )
        puts "Ensuring GitLab pipeline passes on #{branch} (#{owner}/#{repo}) via remote '#{gl_remote}'"
        pbar = if defined?(ProgressBar)
          ProgressBar.create(title: "CI", total: 1, format: "%t %b %c/%C", length: 30)
        end
        keepalive_timer = keepalive_timer(keepalive)
        pipeline_failed = false
        loop do
          keepalive_timer.call
          pipe = Kettle::Dev::CIHelpers.gitlab_latest_pipeline(owner: owner, repo: repo, branch: branch)
          if pipe
            pipe_url = pipe["web_url"] || "https://gitlab.com/#{owner}/#{repo}/-/pipelines"
            if Kettle::Dev::CIHelpers.gitlab_success?(pipe)
              pbar&.increment unless pbar&.finished?
              emit_ci_monitor_event(
                event_recorder,
                action: "gitlab_pipeline",
                status: "ok",
                provider: "gitlab",
                url: pipe_url,
                run_status: pipe["status"],
                completed: 1,
                total: 1
              )
              break
            elsif Kettle::Dev::CIHelpers.gitlab_failed?(pipe)
              # Special-case: if failure is due to exhausted minutes/insufficient quota, treat as unknown and continue
              reason = (pipe["failure_reason"] || "").to_s
              if /insufficient|quota|minute/i.match?(reason)
                puts "\nGitLab reports pipeline cannot run due to quota/minutes exhaustion. Result is unknown; continuing."
                pbar&.finish unless pbar&.finished?
                emit_ci_monitor_event(
                  event_recorder,
                  action: "gitlab_pipeline",
                  status: "skipped",
                  provider: "gitlab",
                  url: pipe_url,
                  run_status: pipe["status"],
                  reason: reason,
                  completed: 0,
                  total: 1
                )
              else
                puts
                emit_ci_monitor_event(
                  event_recorder,
                  action: "gitlab_pipeline",
                  status: "failed",
                  provider: "gitlab",
                  url: pipe_url,
                  run_status: pipe["status"],
                  reason: reason,
                  completed: 0,
                  total: 1
                )
                url = pipe_url
                unless continue_ci_failures?
                  abort("Pipeline failed: #{url} Fix the pipeline, then restart this tool from CI validation with: #{restart_hint}")
                end

                pipeline_failed = true
                pbar&.increment unless pbar&.finished?
                puts "GitLab pipeline failed; continuing because K_RELEASE_CI_CONTINUE=true."
              end
              break
            elsif pipe["status"] == "blocked"
              # Blocked pipeline (e.g., awaiting approvals) — treat as unknown and continue
              puts "\nGitLab pipeline is blocked. Result is unknown; continuing."
              pbar&.finish unless pbar&.finished?
              emit_ci_monitor_event(
                event_recorder,
                action: "gitlab_pipeline",
                status: "skipped",
                provider: "gitlab",
                url: pipe_url,
                run_status: pipe["status"],
                reason: "blocked",
                completed: 0,
                total: 1
              )
              break
            end
          end
          sleep(1)
        end
        pbar&.finish unless pbar&.finished?
        emit_ci_monitor_event(
          event_recorder,
          action: "gitlab_complete",
          status: pipeline_failed ? "failed" : "ok",
          provider: "gitlab",
          completed: 1,
          total: 1,
          failed: pipeline_failed
        )
        puts pipeline_failed ? "\nGitLab pipeline failed; continuing because K_RELEASE_CI_CONTINUE=true." : "\nGitLab pipeline passing."
        !pipeline_failed
      end
      module_function :monitor_gitlab_internal!

      def emit_ci_monitor_event(event_recorder, action:, status:, provider:, **payload)
        mark = case status.to_s
        when "started"
          ">"
        when "ok", "skipped", "continued"
          "."
        when "failed"
          "!"
        else
          "?"
        end
        Kettle::Ndjson.emit_event(
          event_recorder,
          "ci_monitor",
          payload.merge(
            action: action,
            phase: "release",
            provider: provider,
            status: status,
            mark: mark
          )
        )
      end
      module_function :emit_ci_monitor_event

      # -- tiny wrappers around GitAdapter-like helpers used by ReleaseCLI --
      def remotes_with_urls
        Kettle::Dev::GitAdapter.new.remotes_with_urls
      end
      module_function :remotes_with_urls

      def remote_url(name)
        Kettle::Dev::GitAdapter.new.remote_url(name)
      end
      module_function :remote_url

      def github_remote_candidates
        remotes_with_urls.select { |n, u| u.include?("github.com") }.keys
      end
      module_function :github_remote_candidates

      def gitlab_remote_candidates
        remotes_with_urls.select { |n, u| u.include?("gitlab.com") }.keys
      end
      module_function :gitlab_remote_candidates

      def preferred_github_remote
        cands = github_remote_candidates
        return if cands.empty?

        explicit = cands.find { |n| n == "github" } || cands.find { |n| n == "gh" }
        return explicit if explicit
        return "origin" if cands.include?("origin")

        cands.first
      end
      module_function :preferred_github_remote

      def parse_github_owner_repo(url)
        Kettle::Dev::CIHelpers.parse_hosted_repo(url, "github.com") || [nil, nil]
      end
      module_function :parse_github_owner_repo
    end
  end
end
