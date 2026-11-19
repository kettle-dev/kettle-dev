# frozen_string_literal: true

require "open3"

module Kettle
  module Dev
    # Tip check + safe rebase-sync for one checkout, shared by every kettle
    # tool that mutates a checkout in place (kettle-family template / release
    # / gha-sha-pins, kettle-release, kettle-changelog, ...).
    #
    # Contract:
    #   * behind or diverged from upstream -> `git pull --rebase --autostash`
    #   * rebase conflict -> capture conflicted paths, then
    #     `git rebase --abort`, which reapplies the pull autostash (verified:
    #     abort prints "Applied autostash"), leaving the checkout exactly as
    #     found; reported as :conflict with the path list
    #   * up to date -> :ok, no rebase
    #   * no upstream, or an unreachable one -> skipped, proceeding with local
    #     state (fail-open; offline work is never blocked)
    #   * nested inside an outer kettle command that already synced
    #     (KETTLE_REBASE_NESTED set) -> skipped
    module Rebase
      # Orchestrators (kettle-family, kettle-release) set this in child
      # process env so nested kettle tools skip the preflight — the outer
      # command synced once, up front.
      NESTED_ENV = "KETTLE_REBASE_NESTED"

      FALSEY = %w[false 0 no off].freeze

      # Outcome of a call. #status is one of :updated, :ok, :skipped_nested,
      # :skipped_no_upstream, :skipped_unreachable, :conflict, :error.
      class Result
        attr_reader :status, :branch, :upstream, :ahead, :behind, :conflicts, :message

        def initialize(status:, message:, branch: nil, upstream: nil, ahead: nil, behind: nil, conflicts: [])
          @status = status
          @message = message
          @branch = branch
          @upstream = upstream
          @ahead = ahead
          @behind = behind
          @conflicts = conflicts
        end

        def ok?
          ![:error, :conflict].include?(status)
        end

        def synced?
          status == :updated
        end
      end

      module_function

      def call(root:, env: ENV)
        return Result.new(status: :skipped_nested, message: "nested kettle run; the outer command already synced") if nested?(env)

        branch = current_branch(root)
        return Result.new(status: :error, message: "not a git repository: #{root}") unless branch
        return Result.new(status: :error, message: "#{root} is on a detached HEAD; refusing to rebase") if branch.empty?

        upstream = upstream_for(root)
        return Result.new(status: :skipped_no_upstream, branch: branch, message: "#{branch} has no upstream; nothing to sync") unless upstream

        ahead, behind = tip_state(root)
        if behind.nil?
          return Result.new(status: :skipped_unreachable, branch: branch, upstream: upstream, message: "could not fetch #{upstream}; proceeding with local #{branch}")
        end

        return Result.new(status: :ok, branch: branch, upstream: upstream, ahead: ahead, behind: 0, message: up_to_date_message(branch, upstream, ahead)) if behind.zero?

        rebase(root, branch, upstream, ahead, behind)
      end

      def nested?(env)
        value = env[NESTED_ENV]
        return false if value.nil?

        !FALSEY.include?(value.to_s.strip.downcase)
      end

      def up_to_date_message(branch, upstream, ahead)
        return "#{branch} is up to date with #{upstream}" if ahead.zero?

        "#{branch} is up to date with #{upstream} (ahead by #{ahead})"
      end

      def rebase(root, branch, upstream, ahead, behind)
        _stdout, stderr, status = Open3.capture3("git", "pull", "--rebase", "--autostash", chdir: root)
        if status.success?
          return Result.new(status: :updated, branch: branch, upstream: upstream, ahead: ahead, behind: behind, message: "rebased #{branch} onto #{upstream} (was behind by #{behind})")
        end

        conflicts = conflicted_paths(root)
        abort_stalled_rebase(root)
        conflict_note = conflicts.empty? ? "" : " (conflicts: #{conflicts.join(", ")})"
        hint = stderr.to_s.lines.map(&:strip).reject(&:empty?).last
        detail = hint ? " Last output: #{hint}" : nil
        Result.new(
          status: :conflict,
          branch: branch,
          upstream: upstream,
          ahead: ahead,
          behind: behind,
          conflicts: conflicts,
          message: "rebase of #{branch} onto #{upstream} failed#{conflict_note}; the checkout was restored to its pre-rebase state — resolve manually, then re-run.#{detail}"
        )
      end

      # `git rebase --abort` reapplies the pull --autostash stash (verified:
      # abort prints "Applied autostash"), restoring the pre-pull worktree.
      # Best-effort: a failure before the rebase started leaves nothing to
      # abort, and the error is noise.
      def abort_stalled_rebase(root)
        Open3.capture3("git", "rebase", "--abort", chdir: root)
      end

      def conflicted_paths(root)
        stdout, _stderr, status = Open3.capture3("git", "diff", "--name-only", "--diff-filter=U", chdir: root)
        return [] unless status.success?

        stdout.lines.map(&:strip).reject(&:empty?)
      end

      # Current branch short name; "" on a detached HEAD, nil when the root
      # is not a git repository (or git cannot answer).
      def current_branch(root)
        stdout, _stderr, status = Open3.capture3("git", "branch", "--show-current", chdir: root)
        status.success? ? stdout.strip : nil
      rescue SystemCallError
        nil
      end

      def upstream_for(root)
        stdout, _stderr, status = Open3.capture3("git", "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}", chdir: root)
        status.success? ? stdout.strip : nil
      rescue SystemCallError
        nil
      end

      # [ahead, behind] vs the upstream after a fetch, or [nil, nil] when the
      # remote cannot be fetched / compared (fail-open: callers treat nil as
      # "unknown", never as "stale").
      def tip_state(root)
        _stdout, _stderr, fetch_status = Open3.capture3("git", "fetch", "--quiet", chdir: root)
        return [nil, nil] unless fetch_status.success?

        stdout, _stderr, status = Open3.capture3("git", "rev-list", "--left-right", "--count", "HEAD...@{upstream}", chdir: root)
        return [nil, nil] unless status.success?

        stdout.strip.split(/\s+/).map { |part| part.to_i }
      rescue SystemCallError
        [nil, nil]
      end
    end
  end
end
