# frozen_string_literal: true

# External stdlib
require "open3"
require "net/http"
require "json"
require "uri"

module Kettle
  module Dev
    # GitHub API rejected the request because the token is invalid/revoked.
    class CIAuthError < StandardError; end

    # GitHub API quota exhausted. Recoverable: retry after the reset time.
    class CIRateLimitError < StandardError
      attr_reader :reset_at

      def initialize(message, reset_at: nil)
        @reset_at = reset_at
        super(message)
      end
    end

    # CI-related helper functions used by Rake tasks and release tooling.
    #
    # This module only exposes module-functions (no instance state) and is
    # intentionally small so it can be required by both Rake tasks and the
    # kettle-release executable.
    module CIHelpers
      module_function

      # Determine the project root directory.
      # @return [String] absolute path to the project root
      def project_root
        # Too difficult to test every possible branch here, so ignoring
        # simplecov:disable
        dir = if defined?(Rake) && Rake&.application&.respond_to?(:original_dir)
          Rake.application.original_dir
        end
        # simplecov:enable
        dir || Dir.pwd
      end

      # Return the repository root used by release CI monitoring. Monorepo
      # member releases execute from a subdirectory but monitor workflows
      # stored at the shared repository root.
      # @return [String] absolute CI project root
      def ci_project_root
        ENV.fetch("K_RELEASE_CI_ROOT", project_root)
      end

      # Parse the GitHub owner/repo from the configured origin remote.
      # Supports SSH and HTTPS remote URL forms.
      # @return [Array(String, String), nil] [owner, repo] or nil when unavailable
      def repo_info
        out, status = Open3.capture2("git", "config", "--get", "remote.origin.url")
        return unless status.success?

        parse_hosted_repo(out.strip, "github.com")
      end

      # Current git branch name, or nil when not in a repository.
      # @return [String, nil]
      def current_branch
        out, status = Open3.capture2("git", "rev-parse", "--abbrev-ref", "HEAD")
        status.success? ? out.strip : nil
      end

      # Current git commit SHA, or nil when unavailable.
      # @return [String, nil]
      def current_head_sha
        out, status = Open3.capture2("git", "rev-parse", "HEAD")
        status.success? ? out.strip : nil
      end

      # List workflow YAML basenames under .github/workflows at the given root.
      # Excludes maintenance workflows defined by {#exclusions}.
      # @param root [String] project root (defaults to {#project_root})
      # @return [Array<String>] sorted list of basenames (e.g., "ci.yml")
      def workflows_list(root = project_root)
        workflows_dir = File.join(root, ".github", "workflows")
        files = if Dir.exist?(workflows_dir)
          Dir[File.join(workflows_dir, "*.yml")] + Dir[File.join(workflows_dir, "*.yaml")]
        else
          []
        end
        basenames = files.map { |p| File.basename(p) }
        basenames = basenames.uniq - exclusions
        basenames.sort
      end

      # List of workflow files to exclude from interactive menus and checks.
      # @return [Array<String>]
      def exclusions
        %w[
          auto-assign.yml
          codeql-analysis.yml
          danger.yml
          dependency-review.yml
          discord-notifier.yml
          opencollective.yml
          scorecard-analysis.yml
        ]
      end

      # Fetch latest workflow run info for a given workflow and branch via GitHub API.
      # @param owner [String]
      # @param repo [String]
      # @param workflow_file [String] the workflow basename (e.g., "ci.yml")
      # @param branch [String, nil] branch to query; defaults to {#current_branch}
      # @param token [String, nil] OAuth token for higher rate limits; defaults to {#default_token}
      # @return [Hash{String=>String,Integer}, nil] minimal run info or nil on error/none
      def latest_run(owner:, repo:, workflow_file:, branch: nil, token: default_token, require_head: false, head_sha: nil)
        return unless owner && repo

        b = branch || current_branch
        return unless b

        # Scope to the exact commit SHA when available to avoid picking up a previous run on the same branch.
        sha = head_sha || current_head_sha
        data = github_get_json(
          "https://api.github.com/repos/#{owner}/#{repo}/actions/workflows/#{workflow_file}/runs?branch=#{URI.encode_www_form_component(b)}&per_page=100",
          token: token
        )
        return unless data

        runs = Array(data["workflow_runs"]) || []
        # Match by head_sha first. There may be multiple builds for one commit;
        # always select the most recent build rather than trusting API order.
        run = if sha
          match = preferred_head_run(runs.select { |r| r["head_sha"] == sha })
          match ||= latest_repository_workflow_run(owner: owner, repo: repo, workflow_file: workflow_file, branch: b, head_sha: sha, token: token)
          require_head ? match : (match || runs.first)
        else
          runs.first unless require_head
        end
        return unless run

        {
          "status" => run["status"],
          "conclusion" => run["conclusion"],
          "html_url" => run["html_url"],
          "id" => run["id"],
          "head_sha" => run["head_sha"]
        }
      rescue Kettle::Dev::CIAuthError, Kettle::Dev::CIRateLimitError
        # Auth failures are fatal; rate limits are recoverable but must reach
        # the monitor (which parks until the reset) — swallowing either turns
        # the poll into an infinite 0/N tick.
        # fail the same way, so swallowing this turns the monitor into an
        # infinite 0/N tick. Re-raise for the caller to abort with guidance.
        raise
      rescue => e
        Kettle::Dev.debug_error(e, __method__)
        nil
      end

      def latest_repository_workflow_run(owner:, repo:, workflow_file:, branch:, head_sha:, token:)
        data = github_get_json(
          "https://api.github.com/repos/#{owner}/#{repo}/actions/runs?branch=#{URI.encode_www_form_component(branch)}&per_page=100",
          token: token
        )
        return unless data

        workflow_path = ".github/workflows/#{workflow_file}"
        preferred_head_run(
          Array(data["workflow_runs"]).select do |run|
            run["head_sha"] == head_sha && run["path"] == workflow_path
          end
        )
      end

      # GitHub can return multiple builds for the same commit, including an
      # older failed run before a later retry. Select by run recency so an old
      # conclusion cannot mask the newest build. `updated_at` also matters for
      # reruns, which retain the original run's creation timestamp.
      def preferred_head_run(runs)
        runs.max_by do |run|
          created_at = run["created_at"].to_s
          updated_at = run["updated_at"].to_s
          effective_at = [created_at, updated_at].max
          [effective_at, run["run_number"].to_i, run["run_attempt"].to_i, run["id"].to_i]
        end
      end

      # Process-wide rate-limit state shared by every CIHelpers caller in this
      # process (the release runner polls many member/monitor children in one
      # process tree, and each child gets its own copy — this throttles within
      # a process; the budget is sized so even a fully parallel family run
      # stays inside GitHub's per-token allowance).
      CI_RATE_BUDGET_PER_MINUTE = (ENV["K_RELEASE_CI_REQUESTS_PER_MINUTE"] || 90).to_f
      CI_RATE_MIN_INTERVAL = CI_RATE_BUDGET_PER_MINUTE.positive? ? 60.0 / CI_RATE_BUDGET_PER_MINUTE : 0.0
      @ci_rate_last_request = 0.0
      @ci_rate_lock = Mutex.new

      def github_rate_limit_wait!
        return if CI_RATE_MIN_INTERVAL.zero?

        @ci_rate_lock.synchronize do
          now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          delta = now - @ci_rate_last_request
          if delta < CI_RATE_MIN_INTERVAL
            sleep(CI_RATE_MIN_INTERVAL - delta)
            now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          end
          @ci_rate_last_request = now
        end
      end

      def github_get_json(url, token:)
        github_rate_limit_wait!
        uri = URI(url)
        req = Net::HTTP::Get.new(uri)
        req["User-Agent"] = "kettle-dev/ci-helpers"
        req["Authorization"] = "token #{token}" if token && !token.empty?
        res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }
        # Dispatch on is_a? rather than `case`/===: verifying doubles
        # (instance_double(Net::HTTPOK)) used in specs do not reliably match
        # `Net::HTTPSuccess === res`, which silently degraded every stubbed
        # response to "no data".
        if res.is_a?(Net::HTTPSuccess)
          JSON.parse(res.body)
        elsif res.is_a?(Net::HTTPUnauthorized)
          # 401 is not retryable: an invalid or revoked token fails EVERY
          # request, so a monitor treating it as "no data yet" would tick
          # forever at 0/N. Abort with an actionable message.
          raise(
            Kettle::Dev::CIAuthError,
            "GitHub API rejected the request (401: invalid or revoked token) for #{url}. " \
              "Check GITHUB_TOKEN / GH_TOKEN."
          )
        elsif res.is_a?(Net::HTTPForbidden)
          if res["X-RateLimit-Remaining"].to_i.zero?
            # Rate limited: recoverable. Honor the reset time, then let the
            # caller retry the poll cycle.
            reset_at = Time.at(res["X-RateLimit-Reset"].to_i).utc
            raise(
              Kettle::Dev::CIRateLimitError,
              "GitHub API rate limit exceeded; resets at #{reset_at.strftime("%H:%M:%SZ")}"
            )
          end

          # Non-quota 403 (e.g. resource permissions): treat as no data, like
          # other transient responses.
          nil
        else
          nil
        end
      end

      # Whether a run has completed successfully.
      # @param run [Hash, nil]
      # @return [Boolean]
      def success?(run)
        run && run["status"] == "completed" && run["conclusion"] == "success"
      end

      # Whether a run has completed with a non-success conclusion.
      # @param run [Hash, nil]
      # @return [Boolean]
      def failed?(run)
        run && run["status"] == "completed" && run["conclusion"] && run["conclusion"] != "success"
      end

      # Jobs of a workflow run. Used to detect a failed job BEFORE the
      # workflow-level status completes: a large matrix keeps the run
      # in_progress for many minutes after its first job has already
      # concluded failure, while an operator watching the Actions UI sees
      # the red job immediately.
      # @param owner [String]
      # @param repo [String]
      # @param run_id [Integer, String]
      # @param token [String, nil]
      # @return [Array<Hash>] job summaries: name, status, conclusion, html_url
      def run_jobs(owner:, repo:, run_id:, token: default_token)
        return [] unless owner && repo && run_id

        data = github_get_json(
          "https://api.github.com/repos/#{owner}/#{repo}/actions/runs/#{run_id}/jobs?per_page=100",
          token: token
        )
        return [] unless data

        Array(data["jobs"]).map do |job|
          {
            "name" => job["name"],
            "status" => job["status"],
            "conclusion" => job["conclusion"],
            "html_url" => job["html_url"]
          }
        end
      rescue Kettle::Dev::CIAuthError, Kettle::Dev::CIRateLimitError
        # See latest_run: auth/rate-limit failures must abort or park the
        # monitor, not degrade
        # to "no jobs yet".
        raise
      rescue => e
        Kettle::Dev.debug_error(e, __method__)
        []
      end

      # Default GitHub token sourced from environment.
      # @return [String, nil]
      def default_token
        ENV["GITHUB_TOKEN"] || ENV["GH_TOKEN"]
      end

      # --- GitLab support ---

      # Raw origin URL string from git config
      # @return [String, nil]
      def origin_url
        out, status = Open3.capture2("git", "config", "--get", "remote.origin.url")
        status.success? ? out.strip : nil
      end

      # Parse GitLab owner/repo from origin if pointing to gitlab.com
      # @return [Array(String, String), nil]
      def repo_info_gitlab
        url = origin_url
        return unless url

        parse_hosted_repo(url, "gitlab.com")
      end

      # Default GitLab token from environment
      # @return [String, nil]
      def default_gitlab_token
        ENV["GITLAB_TOKEN"] || ENV["GL_TOKEN"]
      end

      # Fetch the latest pipeline for a branch on GitLab
      # @param owner [String]
      # @param repo [String]
      # @param branch [String, nil]
      # @param host [String]
      # @param token [String, nil]
      # @return [Hash{String=>String,Integer}, nil]
      def gitlab_latest_pipeline(owner:, repo:, branch: nil, host: "gitlab.com", token: default_gitlab_token)
        return unless owner && repo

        b = branch || current_branch
        return unless b

        project = URI.encode_www_form_component("#{owner}/#{repo}")
        uri = URI("https://#{host}/api/v4/projects/#{project}/pipelines?ref=#{URI.encode_www_form_component(b)}&per_page=1")
        req = Net::HTTP::Get.new(uri)
        req["User-Agent"] = "kettle-dev/ci-helpers"
        req["PRIVATE-TOKEN"] = token if token && !token.empty?
        res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }
        return unless res.is_a?(Net::HTTPSuccess)

        data = JSON.parse(res.body)
        return unless data.is_a?(Array)

        pipe = data.first
        return unless pipe.is_a?(Hash)

        # Attempt to enrich with failure_reason by querying the single pipeline endpoint
        begin
          if pipe["id"]
            detail_uri = URI("https://#{host}/api/v4/projects/#{project}/pipelines/#{pipe["id"]}")
            dreq = Net::HTTP::Get.new(detail_uri)
            dreq["User-Agent"] = "kettle-dev/ci-helpers"
            dreq["PRIVATE-TOKEN"] = token if token && !token.empty?
            dres = Net::HTTP.start(detail_uri.hostname, detail_uri.port, use_ssl: true) { |http| http.request(dreq) }
            if dres.is_a?(Net::HTTPSuccess)
              det = JSON.parse(dres.body)
              pipe["failure_reason"] = det["failure_reason"] if det.is_a?(Hash)
              pipe["status"] = det["status"] if det["status"]
              pipe["web_url"] = det["web_url"] if det["web_url"]
            end
          end
        rescue => e
          Kettle::Dev.debug_error(e, __method__)
          # ignore enrichment errors; fall back to basic fields
        end
        {
          "status" => pipe["status"],
          "web_url" => pipe["web_url"],
          "id" => pipe["id"],
          "failure_reason" => pipe["failure_reason"]
        }
      rescue => e
        Kettle::Dev.debug_error(e, __method__)
        nil
      end

      # Whether a GitLab pipeline has succeeded
      # @param pipeline [Hash, nil]
      # @return [Boolean]
      def gitlab_success?(pipeline)
        pipeline && pipeline["status"] == "success"
      end

      # Whether a GitLab pipeline has failed
      # @param pipeline [Hash, nil]
      # @return [Boolean]
      def gitlab_failed?(pipeline)
        pipeline && pipeline["status"] == "failed"
      end

      # Parse owner/repo from common hosted Git remote URL shapes.
      # @param url [String, nil]
      # @param host [String]
      # @return [Array(String, String), nil]
      def parse_hosted_repo(url, host)
        return unless url

        if url =~ %r{\Agit@#{Regexp.escape(host)}:(.+?)/(.+?)(?:\.git)?\z}
          return [Regexp.last_match(1), Regexp.last_match(2).sub(/\.git\z/, "")]
        end

        uri = URI.parse(url)
        return unless uri.host == host

        path = uri.path.to_s.sub(%r{\A/}, "")
        owner, repo = path.split("/", 2)
        return unless owner && repo && !owner.empty? && !repo.empty?

        [owner, repo.sub(/\.git\z/, "")]
      rescue URI::InvalidURIError
        nil
      end
    end
  end
end
