# frozen_string_literal: true

require "open3"
require "json"
require "net/http"
require "uri"
require "fileutils"
require "yaml"
require "kettle/ndjson"

module Kettle
  module Dev
    # CLI for updating CHANGELOG.md with new version sections
    #
    # Automatically extracts unreleased changes, formats them into a new version section,
    # includes coverage and YARD stats, and updates link references.
    class ChangelogCLI
      UNRELEASED_SECTION_HEADING = "[Unreleased]:"
      CHANGELOG_VERSION_PATTERN = /\d+\.\d+\.\d+(?:[.-][0-9A-Za-z]+)*/
      CHANGELOG_VERSION_PATTERN_SOURCE = CHANGELOG_VERSION_PATTERN.source
      # Matches a Markdown link-reference definition line, e.g. `[key]: https://...`
      LINK_REF_DEF_RE = /^\s*\[[^\]]+\]:\s+\S+/
      # Matches an ATX heading at H4 or deeper (####, #####, ...)
      DEEP_HEADING_RE = /^\#{4,}\s/

      # Initialize the changelog CLI
      # Sets up paths for CHANGELOG.md and coverage.json
      # @param strict [Boolean] when true (default), require coverage and yard data; raise errors if unavailable
      # @param enforce_coverage_thresholds [Boolean] when true, fail strict coverage generation below project thresholds
      # @param update_prep [Boolean] when true, update the most recent prepared release section in place
      # @param reformat_only [Boolean] when true, normalize structure without release-state planning
      # @param historical_backfill_version [String, nil] tagged release to document without moving Unreleased entries
      # @param version [String, nil] explicit version override for gems without a literal VERSION constant
      # @param yes [Boolean] when true, approve the selected release plan without prompting
      def initialize(strict: true, enforce_coverage_thresholds: true, update_prep: false, reformat_only: false, historical_backfill_version: nil, version: nil, root: Kettle::Dev::CIHelpers.project_root, refresh_cache: false, yes: false, event_stream: nil)
        @root = root
        @changelog_path = resolved_changelog_path
        @coverage_root = resolved_coverage_root
        @coverage_path = File.join(@coverage_root, "coverage", "coverage.json")
        @strict = strict
        @enforce_coverage_thresholds = enforce_coverage_thresholds
        @update_prep = update_prep
        @reformat_only = reformat_only
        @historical_backfill_version = Kettle::Dev::Versioning.normalize_explicit_version(historical_backfill_version)
        @version_override = Kettle::Dev::Versioning.normalize_explicit_version(version)
        @refresh_cache = refresh_cache
        @yes = !!yes
        @event_recorder = Kettle::Ndjson.event_recorder(event_stream, phase_timings: [])
      end

      # Main entry point to update CHANGELOG.md
      #
      # Detects current version, extracts unreleased changes, formats them into
      # a new version section with coverage/YARD stats, and updates all link references.
      #
      # @return [void]
      def run
        if @reformat_only
          reformat_changelog!(File.read(@changelog_path))
          emit_changelog_event(action: "reformat", status: "ok", plan: "reformat_only")
          return
        end

        if @historical_backfill_version
          backfill_historical_release!(@historical_backfill_version)
          return
        end

        version = detect_version
        today = Time.now.strftime("%Y-%m-%d")
        owner, repo = Kettle::Dev::CIHelpers.repo_info
        unless owner && repo
          warn("Could not determine GitHub owner/repo from origin remote.")
          warn("Make sure 'origin' points to github.com. Alternatively, set origin or update links manually afterward.")
        end

        changelog = File.read(@changelog_path)
        plan = @update_prep ? explicit_update_prep_plan(changelog) : detect_plan(changelog, version)
        confirm_plan!(plan)

        if plan.fetch(:action) == :reformat_only
          reformat_changelog!(changelog)
          return
        end

        if plan.fetch(:action) == :rollback_prepared_release
          rollback_prepared_release!(changelog, owner, repo, version)
          emit_changelog_event(action: "rollback", status: "ok", version: plan.fetch(:latest_changelog_version), plan: "rollback_prepared_release")
          return
        end

        line_cov_line, branch_cov_line = coverage_lines
        yard_line = yard_percent_documented

        if plan.fetch(:action) == :update_prepared_release
          update_prepared_release!(changelog, today, owner, repo, line_cov_line, branch_cov_line, yard_line)
          emit_changelog_event(action: "update", status: "ok", version: version, plan: plan.fetch(:action).to_s)
          return
        end

        unreleased_block, before, after = extract_unreleased(changelog)
        if unreleased_block.nil?
          abort("Could not find '## [Unreleased]' section in CHANGELOG.md")
        end

        if unreleased_block.strip.empty?
          warn("No entries found under Unreleased. Creating an empty version section anyway.")
        end

        prev_version = detect_previous_version(after)

        new_section = +""
        new_section << "## [#{version}] - #{today}\n"
        new_section << "- TAG: [v#{version}][#{version}t]\n"
        new_section << "- #{line_cov_line}\n" if line_cov_line
        new_section << "- #{branch_cov_line}\n" if branch_cov_line
        new_section << "- #{yard_line}\n" if yard_line
        new_section << filter_unreleased_sections(unreleased_block)
        # Ensure exactly one blank line separates this new section from the next section
        new_section.rstrip!
        new_section << "\n\n"

        # Reset the Unreleased section to empty category headings
        unreleased_reset = <<~MD
          ## [Unreleased]
          ### Added
          ### Changed
          ### Deprecated
          ### Removed
          ### Fixed
          ### Security
        MD

        # Preserve everything from the first released section down to the line containing the [Unreleased] link ref.
        # Many real-world changelogs intersperse stray link refs between sections; we should keep them.
        updated = before + unreleased_reset + "\n" + new_section
        # Find the [Unreleased]: link-ref line and append everything from the start of the first released section
        # through to the end of the file, but if a [Unreleased]: ref exists, ensure we do not duplicate the
        # section content above it.
        if after && !after.empty?
          # Split 'after' by lines so we can locate the first link-ref to Unreleased
          after_lines = after.lines
          unreleased_ref_idx = after_lines.index { |l| l.start_with?(UNRELEASED_SECTION_HEADING) }
          if unreleased_ref_idx
            # Keep all content prior to the link-ref (older releases and interspersed refs)
            preserved_body = after_lines[0...unreleased_ref_idx].join
            # Then append the tail starting from the Unreleased link-ref line to preserve the footer refs
            preserved_footer = after_lines[unreleased_ref_idx..-1].join
            updated << preserved_body << preserved_footer
          else
            # No Unreleased ref found; just append the remainder as-is
            updated << after
          end
        end

        updated = update_link_refs(updated, owner, repo, prev_version, version)

        # Transform legacy heading suffix tags into list items under headings
        updated = convert_heading_tag_suffix_to_list(updated)

        # Normalize spacing around headings to aid Markdown renderers
        updated = normalize_heading_spacing(updated)

        # Ensure exactly one trailing newline at EOF
        updated = updated.rstrip + "\n"

        File.write(@changelog_path, updated)
        emit_changelog_event(action: "update", status: "ok", version: version, plan: plan.fetch(:action).to_s)
        puts "CHANGELOG.md updated with v#{version} section."
      end

      def pending_release_status
        release_state
      end

      def release_state
        changelog_present = ensure_changelog_for_release_state!
        version = detect_version
        gem_name = detect_gem_name
        unless changelog_present
          latest_overall, latest_for_series, latest_for_major = latest_released_versions(gem_name, version)
          latest_target = latest_release_target(version, latest_overall, latest_for_series, latest_for_major)
          ahead = commits_ahead_of_release(latest_target || latest_overall)
          return {
            root: @root,
            gem_name: gem_name,
            version: version,
            changelog_present: false,
            pending: false,
            pending_release: false,
            unreleased_entries: false,
            prepared_release_pending: false,
            latest_changelog_version: nil,
            latest_released: latest_target || latest_overall,
            latest_released_overall: latest_overall,
            latest_released_for_current_major: latest_for_major,
            latest_released_for_current_series: latest_for_series,
            latest_release_target: latest_target,
            ahead: ahead
          }
        end

        changelog = File.read(@changelog_path)
        unreleased_block, _before, after = extract_unreleased(changelog)
        unreleased_entries = unreleased_block_has_entries?(unreleased_block)
        latest_changelog_version = detect_previous_version(after.to_s)
        release_lookup_version = latest_changelog_version || version
        latest_overall, latest_for_series, latest_for_major = latest_released_versions(gem_name, release_lookup_version)
        latest_target = latest_release_target(release_lookup_version, latest_overall, latest_for_series, latest_for_major)
        prepared_release_pending = !!latest_changelog_version && latest_target != latest_changelog_version
        ahead = commits_ahead_of_release(latest_target || latest_overall)

        {
          root: @root,
          gem_name: gem_name,
          version: version,
          changelog_present: true,
          pending: unreleased_entries || prepared_release_pending,
          pending_release: unreleased_entries || prepared_release_pending,
          unreleased_entries: unreleased_entries,
          prepared_release_pending: prepared_release_pending,
          latest_changelog_version: latest_changelog_version,
          latest_released: latest_target || latest_overall,
          latest_released_overall: latest_overall,
          latest_released_for_current_major: latest_for_major,
          latest_released_for_current_series: latest_for_series,
          latest_release_target: latest_target,
          ahead: ahead
        }
      end

      def release_state_table(state = release_state)
        rows = [
          ["gem", "version.rb", "latest released", "latest changelog", "ahead", "unreleased", "prepared", "pending"],
          [
            state.fetch(:gem_name),
            state.fetch(:version),
            state.fetch(:latest_released) || "unknown",
            state.fetch(:latest_changelog_version) || "none",
            state.fetch(:ahead, nil).nil? ? "unknown" : state.fetch(:ahead).to_s,
            yes_no(state.fetch(:unreleased_entries)),
            yes_no(state.fetch(:prepared_release_pending)),
            yes_no(state.fetch(:pending_release))
          ]
        ]
        widths = rows.transpose.map { |column| column.map(&:length).max }
        rows.map.with_index do |row, index|
          line = row.each_with_index.map { |value, i| value.ljust(widths.fetch(i)) }.join("  ").rstrip
          if index == 0
            [line, widths.map { |width| "-" * width }.join("  ")].join("\n")
          else
            line
          end
        end.join("\n")
      end

      private

      def abort(msg)
        Kettle::Dev::ExitAdapter.abort(msg)
      end

      def ensure_changelog_for_release_state!
        return true if File.file?(@changelog_path)

        if File.file?(File.join(@root, "Gemfile")) && Dir.glob(File.join(@root, "*", "*.gemspec")).any?
          abort("Could not find CHANGELOG.md in #{Kettle::Dev.display_path(@root)}. This looks like a gem-family root; run `kettle-family release-state` from this directory, or run `kettle-changelog --release-state` from an individual gem directory.")
        end

        false
      end

      def yes_no(value)
        value ? "yes" : "no"
      end

      def commits_ahead_of_release(version)
        tag = release_tag_for_version(version)
        branch = default_branch_ref
        return nil unless tag && branch

        stdout, ok = git_capture(["rev-list", "--count", "#{tag}..#{branch}"])
        ok ? stdout.to_i : nil
      end

      def release_tag_for_version(version)
        return nil if version.to_s.empty?

        ["v#{version}", version.to_s].find { |tag| git_ref_exists?("refs/tags/#{tag}^{commit}") }
      end

      def default_branch_ref
        stdout, ok = git_capture(["symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD"])
        return stdout.strip if ok && !stdout.strip.empty?

        %w[main master HEAD].find { |ref| git_ref_exists?(ref) }
      end

      def git_ref_exists?(ref)
        _stdout, ok = git_capture(["rev-parse", "--verify", "--quiet", ref])
        ok
      end

      def detect_plan(changelog, version)
        latest_overall = nil
        latest_for_series = nil
        gem_name = nil
        begin
          gem_name = detect_gem_name
          latest_overall, latest_for_series = latest_released_versions(gem_name, version)
        rescue => e
          warn("[kettle-changelog] RubyGems.org release check failed: #{e.class}: #{e.message}")
          warn("Proceeding without live release info.")
        end

        unreleased_block, _before, after = extract_unreleased(changelog)
        latest_changelog_version = detect_previous_version(after.to_s)
        section_exists = release_section_exists?(changelog, version)
        latest_target = latest_release_target(version, latest_overall, latest_for_series)

        if latest_target && Gem::Version.new(version) < Gem::Version.new(latest_target)
          abort("Aborting: version.rb (#{version}) is lower than the latest released version for this release line (#{latest_target}).")
        end

        if latest_target == version && latest_changelog_version && Gem::Version.new(latest_changelog_version) > Gem::Version.new(version)
          action = :rollback_prepared_release
        elsif section_exists && latest_changelog_version != version
          abort("Aborting: CHANGELOG.md already contains a #{version} section, but the most recent release section is #{latest_changelog_version || "missing"}.")
        else
          action = if section_exists && latest_target == version
            if unreleased_block_has_entries?(unreleased_block)
              abort("Aborting: version.rb (#{version}) matches the latest released version for this release line (#{latest_target}); bump version.rb before moving Unreleased entries into a release section.")
            end
            :reformat_only
          elsif section_exists
            :update_prepared_release
          elsif latest_target == version
            abort("Aborting: version.rb (#{version}) matches the latest released version, but CHANGELOG.md does not have #{version} as the most recent release section.")
          else
            :new_release
          end
        end

        {
          action: action,
          version: version,
          gem_name: gem_name,
          latest_overall: latest_overall,
          latest_for_series: latest_for_series,
          latest_target: latest_target,
          latest_changelog_version: latest_changelog_version
        }
      end

      def explicit_update_prep_plan(changelog)
        _unreleased_block, _before, after = extract_unreleased(changelog)
        prepared_version = detect_previous_version(after.to_s)
        abort("Could not find a prepared release section after '## [Unreleased]' in CHANGELOG.md") unless prepared_version

        {
          action: :update_prepared_release,
          version: prepared_version,
          gem_name: nil,
          latest_overall: nil,
          latest_for_series: nil,
          latest_target: nil,
          latest_changelog_version: prepared_version,
          explicit: true
        }
      end

      def confirm_plan!(plan)
        puts "kettle-changelog selected plan: #{plan_label(plan.fetch(:action))}"
        puts "  #{version_source_label(plan)}: #{plan.fetch(:version)}"
        puts "  latest released: #{plan.fetch(:latest_overall) || "unknown"}"
        puts "  latest released for current series: #{plan.fetch(:latest_for_series) || "unknown"}"
        puts "  latest CHANGELOG.md release: #{plan.fetch(:latest_changelog_version) || "none"}"
        puts "  gem: #{plan.fetch(:gem_name) || "unknown"}"
        emit_changelog_event(
          action: "plan",
          status: "ok",
          plan: plan.fetch(:action).to_s,
          version: plan.fetch(:version),
          gem_name: plan.fetch(:gem_name),
          latest_overall: plan.fetch(:latest_overall),
          latest_for_series: plan.fetch(:latest_for_series),
          latest_changelog_version: plan.fetch(:latest_changelog_version)
        )
        if @yes
          puts("Continue with this plan? [y/N]: y")
          return
        end

        print("Continue with this plan? [y/N]: ")
        ans = Kettle::Dev::InputAdapter.gets&.strip&.downcase
        return if ans == "y" || ans == "yes"

        abort("Aborting: changelog plan was not confirmed.")
      end

      def version_source_label(plan)
        return "prepared release" if plan.fetch(:explicit, false)
        return "version override" if @version_override

        "version.rb"
      end

      def plan_label(action)
        case action
        when :new_release
          "create a new release section"
        when :update_prepared_release
          "update the prepared release section in place"
        when :reformat_only
          "reformat CHANGELOG.md without adding a release section"
        else
          action.to_s
        end
      end

      def reformat_changelog!(changelog)
        updated = convert_heading_tag_suffix_to_list(changelog)
        updated = normalize_legacy_release_headings(updated)
        updated = remove_redundant_historical_placeholders(updated)
        updated = normalize_heading_spacing(updated)
        updated = ensure_footer_spacing(updated)
        updated = updated.rstrip + "\n"
        File.write(@changelog_path, updated)
        puts "CHANGELOG.md reformatted. No new version section added."
      end

      def normalize_legacy_release_headings(changelog)
        changelog.to_s.lines.map do |line|
          match = line.match(/^##\s+(?!\[)(v?\d+(?:\.\d+)+(?:[.-][0-9A-Za-z]+)?)(\s+-\s+.*)?\s*$/)
          next line unless match

          version = match[1].delete_prefix("v")
          next line unless Gem::Version.correct?(version)

          "## [#{version}]#{match[2]}\n"
        end.join
      end

      def remove_redundant_historical_placeholders(changelog)
        lines = changelog.to_s.lines
        sections = changelog_release_sections(lines)
        removals = sections.group_by { |section| section.fetch(:version) }.values.flat_map do |same_version|
          next [] unless same_version.size > 1
          next [] unless same_version.any? { |section| !section.fetch(:placeholder) }

          same_version.filter_map do |section|
            (section.fetch(:start)...section.fetch(:finish)) if section.fetch(:placeholder)
          end
        end
        return changelog if removals.empty?

        lines.each_with_index.reject { |_line, index| removals.any? { |range| range.cover?(index) } }.map(&:first).join
      end

      def changelog_release_sections(lines)
        headings = lines.each_index.filter_map do |index|
          match = lines[index].match(/^## \[(#{CHANGELOG_VERSION_PATTERN_SOURCE})\]/o)
          {version: match[1], start: index} if match
        end
        headings.each_with_index.map do |heading, index|
          next_heading = headings[index + 1]
          footer = lines.each_index.find do |line_index|
            line_index > heading.fetch(:start) && lines[line_index].start_with?(UNRELEASED_SECTION_HEADING)
          end
          finish = [next_heading&.fetch(:start), footer, lines.length].compact.min
          body = lines[heading.fetch(:start)...finish].join
          heading.merge(finish: finish, placeholder: body.include?("Historical release notes are unavailable in this changelog."))
        end
      end

      def backfill_historical_release!(version)
        changelog = File.read(@changelog_path)
        abort("CHANGELOG.md already contains a section for #{version}") if release_section_exists?(changelog, version)

        unreleased_block, before, after = extract_unreleased(changelog)
        abort("Could not find '## [Unreleased]' section in CHANGELOG.md") if unreleased_block.nil?

        date = tagged_release_date(version)
        owner, repo = Kettle::Dev::CIHelpers.repo_info
        abort("Could not determine GitHub owner/repo from origin remote") unless owner && repo

        section = <<~MD
          ## [#{version}] - #{date}
          - TAG: [v#{version}][#{version}t]

          ### Changed

          - Historical release notes are unavailable in this changelog.

        MD
        updated = before + "## [Unreleased]\n" + unreleased_block.rstrip + "\n\n" + section + after.to_s
        updated = update_link_refs(updated, owner, repo, nil, version)
        updated = normalize_heading_spacing(updated).rstrip + "\n"
        File.write(@changelog_path, updated)
        emit_changelog_event(action: "backfill", status: "ok", version: version, plan: "historical_release")
        puts "CHANGELOG.md backfilled with historical v#{version} section. Unreleased entries were preserved."
      end

      def tagged_release_date(version)
        tag = "v#{version}"
        output, status = Open3.capture2("git", "log", "-1", "--format=%as", tag, chdir: @root)
        abort("Local git tag #{tag} is required to backfill a historical release section") unless status.success? && !output.strip.empty?

        output.strip
      end

      def release_section_exists?(changelog, version)
        changelog.match?(/^## \[#{Regexp.escape(version)}\]/)
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
        data = Kettle::Dev::RubyGemsVersions.fetch(gem_name, version_hint: current_version, refresh: @refresh_cache)
        return [nil, nil, nil] unless data.is_a?(Array)

        versions = data.map { |h| h["number"] }.compact
        versions.reject! { |v| v.to_s.include?("-pre") || v.to_s.include?(".pre") || v.to_s.match?(/[a-zA-Z]/) }
        gversions = versions.map { |s| Gem::Version.new(s) }.sort
        latest_overall = gversions.last&.to_s

        cur = Gem::Version.new(current_version)
        series = cur.segments[0, 2]
        major = cur.segments.fetch(0)
        latest_series = gversions.reverse.find { |gv| gv.segments[0, 2] == series }&.to_s
        latest_major = gversions.reverse.find { |gv| gv.segments.fetch(0, nil) == major }&.to_s
        [latest_overall, latest_series, latest_major]
      rescue => e
        Kettle::Dev.debug_error(e, __method__)
        [nil, nil, nil]
      end

      def latest_release_target(version, latest_overall, latest_for_series, latest_for_major = nil)
        return unless latest_overall

        cur = Gem::Version.new(version)
        overall = Gem::Version.new(latest_overall)
        cur_series = cur.segments[0, 2]
        overall_series = overall.segments[0, 2]
        cur_major = cur.segments.fetch(0)
        overall_major = overall.segments.fetch(0)

        if latest_for_series
          lfs_series = Gem::Version.new(latest_for_series).segments[0, 2]
          latest_for_series = nil unless lfs_series == cur_series
        end

        if latest_for_major
          lfm_major = Gem::Version.new(latest_for_major).segments.fetch(0, nil)
          latest_for_major = nil unless lfm_major == cur_major
        end

        return latest_for_major || latest_for_series if cur_major < overall_major

        if (cur_series <=> overall_series) == -1
          latest_for_series
        else
          latest_overall
        end
      end

      def detect_version
        Kettle::Dev::Versioning.detect_version(@root, override: @version_override)
      end

      def extract_unreleased(content)
        lines = content.lines
        start_i = lines.index { |l| l.start_with?("## [Unreleased]") }
        return [nil, nil, nil] unless start_i

        # Find the next version heading after Unreleased
        next_i = (start_i + 1)
        while next_i < lines.length && !lines[next_i].start_with?("## [")
          next_i += 1
        end
        # Now next_i points to the next section heading or EOF
        before = lines[0..(start_i - 1)].join
        unreleased_body = lines[(start_i + 1)..(next_i - 1)] || []
        after_lines = lines[next_i..-1] || []

        # When this is the very first release there is no `## [X.Y.Z]` heading to act
        # as a boundary, so the footer link-ref block ([Unreleased]: ...) sits at the
        # end of the unreleased body.  Move everything from the [Unreleased]: line
        # onward into `after` so those refs are not mistaken for section content.
        if next_i == lines.length
          footer_i = unreleased_body.index { |l| l.start_with?(UNRELEASED_SECTION_HEADING) }
          if footer_i
            after_lines = unreleased_body[footer_i..-1] + after_lines
            unreleased_body = unreleased_body[0...footer_i]
          end
        end

        unreleased_block = unreleased_body.join
        after = after_lines.join
        [unreleased_block, before, after]
      end

      def detect_previous_version(after_text)
        # after_text begins with the first released section following Unreleased
        m = after_text.match(/^## \[(#{CHANGELOG_VERSION_PATTERN_SOURCE})\]/o)
        return m[1] if m

        nil
      end

      def update_prepared_release!(changelog, today, owner, repo, line_cov_line, branch_cov_line, yard_line)
        unreleased_block, before, after = extract_unreleased(changelog)
        abort("Could not find '## [Unreleased]' section in CHANGELOG.md") if unreleased_block.nil?

        release_heading = after.to_s.match(/\A## \[(#{CHANGELOG_VERSION_PATTERN_SOURCE})\][^\n]*\n/o)
        abort("Could not find a prepared release section after '## [Unreleased]' in CHANGELOG.md") unless release_heading

        prepared_version = release_heading[1]
        release_and_tail = after.lines
        next_release_index = release_and_tail[1..-1].to_a.index { |line| line.start_with?("## [") }
        release_line_count = next_release_index ? next_release_index + 1 : release_and_tail.length
        release_lines = release_and_tail[0...release_line_count]
        tail = release_and_tail[release_line_count..-1].to_a.join

        release_body = release_lines[1..-1].to_a.join
        merged_body = merge_release_body_with_unreleased(release_body, unreleased_block)

        release_section = +""
        release_section << "## [#{prepared_version}] - #{today}\n"
        release_section << "- TAG: [v#{prepared_version}][#{prepared_version}t]\n"
        release_section << "- #{line_cov_line}\n" if line_cov_line
        release_section << "- #{branch_cov_line}\n" if branch_cov_line
        release_section << "- #{yard_line}\n" if yard_line
        release_section << merged_body
        release_section.rstrip!
        release_section << "\n\n"

        unreleased_reset = <<~MD
          ## [Unreleased]
          ### Added
          ### Changed
          ### Deprecated
          ### Removed
          ### Fixed
          ### Security
        MD

        previous_version = detect_previous_version(tail)
        updated = before + unreleased_reset + "\n" + release_section + tail
        updated = update_link_refs(updated, owner, repo, previous_version, prepared_version)
        updated = convert_heading_tag_suffix_to_list(updated)
        updated = normalize_heading_spacing(updated)
        updated = updated.rstrip + "\n"

        File.write(@changelog_path, updated)
        puts "CHANGELOG.md updated in place for v#{prepared_version}."
      end

      def rollback_prepared_release!(changelog, owner, repo, published_version)
        unreleased_block, before, after = extract_unreleased(changelog)
        release_lines = after.to_s.lines
        heading = release_lines.first.to_s.match(/\A## \[(#{CHANGELOG_VERSION_PATTERN_SOURCE})\]/o)
        abort("Could not find a prepared release section after '## [Unreleased]' in CHANGELOG.md") unless heading

        finish = release_lines.each_index.drop(1).find do |index|
          release_lines[index].start_with?("## [", UNRELEASED_SECTION_HEADING)
        end || release_lines.length
        prepared_version = heading[1]
        merged = merge_release_body_with_unreleased(release_lines[1...finish].join, unreleased_block)
        unreleased = "## [Unreleased]\n" + merged.rstrip + "\n\n"
        tail = release_lines[finish, release_lines.length].to_a.reject { |line| line.start_with?("[#{prepared_version}]:", "[#{prepared_version}t]:") }.join
        updated = before + unreleased + tail
        updated = update_link_refs(updated, owner, repo, nil, published_version)
        File.write(@changelog_path, normalize_heading_spacing(updated).rstrip + "\n")
        puts "CHANGELOG.md rolled back prepared v#{prepared_version} into Unreleased."
      end

      def merge_release_body_with_unreleased(release_body, unreleased_block)
        existing = strip_release_metadata(release_body)
        incoming = filter_unreleased_sections(unreleased_block)
        return existing if incoming.strip.empty?
        return incoming if existing.strip.empty?

        leading, sections = split_h3_sections(existing)
        _incoming_leading, incoming_sections = split_h3_sections(incoming)
        return [existing.rstrip, incoming.rstrip, ""].join("\n\n") if sections.empty? || incoming_sections.empty?

        incoming_sections.each do |incoming_section|
          section = sections.find { |candidate| candidate.fetch(:heading) == incoming_section.fetch(:heading) }
          if section
            section.fetch(:lines) << "\n" unless section.fetch(:lines).empty? || section.fetch(:lines).last.to_s.strip.empty?
            section.fetch(:lines).concat(trim_blank_lines(incoming_section.fetch(:lines)))
          else
            sections << incoming_section
          end
        end

        ([leading] + sections.map { |section| section.fetch(:heading) + trim_blank_lines(section.fetch(:lines)).join }).join.rstrip + "\n"
      end

      def strip_release_metadata(release_body)
        lines = release_body.lines
        while lines.any? && lines.first.strip.empty?
          lines.shift
        end
        while lines.any?
          stripped = lines.first.strip
          break unless stripped.start_with?("- TAG:", "- COVERAGE:", "- BRANCH COVERAGE:") || stripped.match?(/\A- \d+(?:\.\d+)?%\s+documented\z/)

          lines.shift
        end
        lines.join
      end

      def split_h3_sections(text)
        leading = +""
        sections = []
        current = nil
        text.lines.each do |line|
          if line.start_with?("### ")
            current = {heading: line, lines: []}
            sections << current
          elsif current
            current.fetch(:lines) << line
          else
            leading << line
          end
        end
        [leading, sections]
      end

      def trim_blank_lines(lines)
        trimmed = lines.dup
        trimmed.shift while trimmed.any? && trimmed.first.to_s.strip.empty?
        trimmed.pop while trimmed.any? && trimmed.last.to_s.strip.empty?
        trimmed << "\n" if trimmed.any? && !trimmed.last.end_with?("\n")
        trimmed
      end

      # From the Unreleased block, keep only sections that have content.
      # We detect sections as lines starting with '### '. A section has content if there is at least
      # one non-empty, non-heading line under it before the next '###' or '##'. Typically these are list items.
      # Returns a string that includes only the non-empty sections with their content.
      def filter_unreleased_sections(unreleased_block)
        lines = unreleased_block.lines
        out = []
        i = 0
        while i < lines.length
          line = lines[i]
          if line.start_with?("### ")
            header = line
            i += 1
            chunk = []
            while i < lines.length && !lines[i].start_with?("### ") && !lines[i].start_with?("## ")
              chunk << lines[i]
              i += 1
            end
            # A section has real content only if it contains at least one non-blank line that is
            # neither a link-reference definition ([key]: url) nor a deeper heading (H4+).
            # Link-ref defs and H4+ headings alone are not meaningful section content.
            content_present = chunk.any? { |l| l.strip != "" && l !~ LINK_REF_DEF_RE && l !~ DEEP_HEADING_RE }
            if content_present
              # Trim leading blank lines so there is no blank line after the header
              while chunk.any? && chunk.first.strip == ""
                chunk.shift
              end
              # Trim trailing blank lines
              while chunk.any? && chunk.last.strip == ""
                chunk.pop
              end
              out << header
              out.concat(chunk)
              out << "\n" unless out.last&.end_with?("\n")
            end
            next
          else
            # Lines outside sections are ignored for released sections
            i += 1
          end
        end
        out.join
      end

      def unreleased_block_has_entries?(unreleased_block)
        !filter_unreleased_sections(unreleased_block.to_s).strip.empty?
      end

      def coverage_lines
        if @strict
          # Always generate fresh coverage data in strict mode
          # Delete old coverage files to ensure we get current data
          coverage_dir = File.dirname(@coverage_path)
          if Dir.exist?(coverage_dir)
            puts "Cleaning old coverage data from #{Kettle::Dev.display_path(coverage_dir)}..."
            emit_changelog_event(action: "coverage_clean", status: "started", path: Kettle::Dev.display_path(coverage_dir))
            Dir.glob(File.join(coverage_dir, "*")).each do |file|
              File.delete(file) if File.file?(file)
            end
            emit_changelog_event(action: "coverage_clean", status: "ok", path: Kettle::Dev.display_path(coverage_dir))
          end

          puts "Generating fresh coverage data by running: bundle exec kettle-test"
          emit_changelog_event(action: "coverage", status: "started", command: "bundle exec kettle-test", root: Kettle::Dev.display_path(@coverage_root))

          success = system(changelog_coverage_env, "bundle", "exec", "kettle-test", chdir: @coverage_root)

          unless success
            emit_changelog_event(action: "coverage", status: "failed", command: "bundle exec kettle-test", root: Kettle::Dev.display_path(@coverage_root), reason: "exit status #{$?.exitstatus || "unknown"}")
            raise "bundle exec kettle-test failed with exit status #{$?.exitstatus || "unknown"}"
          end

          puts "Coverage generation complete."
          emit_changelog_event(action: "coverage", status: "ok", command: "bundle exec kettle-test", root: Kettle::Dev.display_path(@coverage_root))

          ensure_changelog_coverage_json!
        else
          # Non-strict mode: check if coverage.json exists, warn if not
          unless File.file?(@coverage_path)
            warn(coverage_json_missing_message)
            warn("Run: K_SOUP_COV_FORMATTERS=json bundle exec kettle-test to generate it")
            return [nil, nil]
          end
        end

        # Parse the coverage data
        data = JSON.parse(File.read(@coverage_path))
        files = data["coverage"] || {}
        file_count = 0
        total_lines = 0
        covered_lines = 0
        total_branches = 0
        covered_branches = 0
        files.each_value do |h|
          lines = h["lines"] || []
          line_relevant = lines.count { |x| x.is_a?(Integer) }
          line_covered = lines.count { |x| x.is_a?(Integer) && x > 0 }
          if line_relevant > 0
            file_count += 1
            total_lines += line_relevant
            covered_lines += line_covered
          end
          branches = h["branches"] || []
          branches.each do |b|
            next unless b.is_a?(Hash)

            cov = b["coverage"]
            next unless cov.is_a?(Numeric)

            total_branches += 1
            covered_branches += 1 if cov > 0
          end
        end
        line_pct = (total_lines > 0) ? ((covered_lines.to_f / total_lines) * 100.0) : 0.0
        branch_pct = (total_branches > 0) ? ((covered_branches.to_f / total_branches) * 100.0) : 0.0
        line_str = format("COVERAGE: %.2f%% -- %d/%d lines in %d files", line_pct, covered_lines, total_lines, file_count)
        branch_str = format("BRANCH COVERAGE: %.2f%% -- %d/%d branches in %d files", branch_pct, covered_branches, total_branches, file_count)
        [line_str, branch_str]
      rescue JSON::ParserError => e
        if @strict
          raise "Failed to parse coverage JSON at #{@coverage_path}: #{e.class}: #{e.message}"
        else
          warn("Failed to parse coverage: #{e.class}: #{e.message}")
          [nil, nil]
        end
      rescue => e
        if @strict
          raise "Failed to get coverage data: #{e.class}: #{e.message}"
        else
          warn("Failed to get coverage data: #{e.class}: #{e.message}")
          [nil, nil]
        end
      end

      def emit_changelog_event(action:, status:, **payload)
        mark = case status.to_s
        when "started"
          ">"
        when "ok", "skipped"
          "."
        when "failed"
          "!"
        else
          "?"
        end
        Kettle::Ndjson.emit_event(
          @event_recorder,
          "changelog",
          payload.merge(
            action: action,
            phase: "release",
            status: status,
            mark: mark
          )
        )
      end

      def changelog_coverage_env
        env = BundlerEnvGuard.unbundled_env.merge(
          "PATH" => ENV.fetch("PATH", ""),
          "RUBYOPT" => nil,
          "K_SOUP_COV_DO" => "true",
          "K_SOUP_COV_FORMATTERS" => "json",
          "K_SOUP_COV_MIN_HARD" => @enforce_coverage_thresholds ? "true" : "false",
          "K_SOUP_COV_MULTI_FORMATTERS" => "false",
          "K_SOUP_COV_OPEN_BIN" => ""
        )
        env.merge!(changelog_coverage_workflow_thresholds)
        gemfile = File.join(@coverage_root, "Gemfile")
        env["BUNDLE_GEMFILE"] = gemfile if File.file?(gemfile)
        env
      end

      # The changelog coverage run is the final local test gate before a
      # release commit is pushed. Reuse the checked-in CI workflow thresholds
      # rather than silently falling back to kettle-soup-cover defaults.
      def changelog_coverage_workflow_thresholds
        path = ["coverage.yml", "coverage.yaml"]
          .map { |name| File.join(@coverage_root, ".github", "workflows", name) }
          .find { |candidate| File.file?(candidate) }
        return {} unless path

        workflow = YAML.safe_load_file(path, permitted_classes: [], aliases: false)
        workflow_env = (workflow.is_a?(Hash) && workflow["env"].is_a?(Hash)) ? workflow["env"] : {}
        %w[K_SOUP_COV_MIN_LINE K_SOUP_COV_MIN_BRANCH].each_with_object({}) do |key, thresholds|
          value = workflow_env[key]
          thresholds[key] = value.to_s unless value.nil? || value.to_s.empty?
        end
      rescue Psych::Exception => error
        raise "Unable to read coverage thresholds from #{path}: #{error.message}"
      end

      def ensure_changelog_coverage_json!
        return if File.file?(@coverage_path)

        raise coverage_json_missing_message
      end

      def coverage_json_missing_message
        [
          "Coverage JSON not found at #{Kettle::Dev.display_path(@coverage_path)} after running bundle exec kettle-test.",
          "kettle-test runs specs in parallel and is expected to collate parallel SimpleCov results into this canonical file.",
          "If it is missing, coverage was not enabled in ENV config or the rake/task hooks did not load the coverage integration."
        ].join(" ")
      end

      def yard_percent_documented
        commands = yard_documentation_commands
        if commands.empty?
          if @strict
            raise "bin/rake and bin/yard not found or not executable; ensure rake and yard are installed via bundler"
          else
            warn("bin/rake and bin/yard not found or not executable; ensure rake and yard are installed via bundler")
            return
          end
        end

        # Run the canonical docs task to get the documentation percentage.
        commands.each do |command|
          prepare_yard_fence_tmp_files if command.include?(File.join(@root, "bin", "yard"))
          output, status = capture_yard_command(command)
          unless command_successful?(status)
            return handle_yard_documentation_failure(yard_command_failure_message(command, output, status))
          end
          line = documented_percent_line(output)
          return line if line
        end

        handle_yard_documentation_failure("Could not find documented percentage in YARD output")
      end

      def capture_yard_command(command)
        Open3.capture2e(*command, {chdir: @root})
      rescue => e
        ["#{e.class}: #{e.message}", false]
      end

      def handle_yard_documentation_failure(message)
        if @strict
          raise message
        else
          warn(message)
          nil
        end
      end

      def command_successful?(status)
        return status if status == true || status == false

        !status.respond_to?(:success?) || status.success?
      end

      def yard_command_failure_message(command, output, status)
        exit_status = status.respond_to?(:exitstatus) ? status.exitstatus : nil
        message = "Failed to run #{yard_command_label(command)}"
        message = "#{message} (exit #{exit_status})" if exit_status
        output = output.to_s.strip
        message = "#{message}: #{output}" unless output.empty?
        message
      end

      def yard_command_label(command)
        command = Array(command)
        bin = command.find { |part| [File.join(@root, "bin", "rake"), File.join(@root, "bin", "yard")].include?(part) }.to_s
        if bin == File.join(@root, "bin", "rake")
          "bin/rake #{command.drop_while { |part| part != bin }.drop(1).join(" ")}".strip
        elsif bin == File.join(@root, "bin", "yard")
          "bin/yard"
        else
          command.join(" ")
        end
      end

      def yard_documentation_commands
        commands = []
        rake = File.join(@root, "bin", "rake")
        commands << [RbConfig.ruby, rake, "yard"] if File.file?(rake)
        yard = File.join(@root, "bin", "yard")
        commands << [RbConfig.ruby, yard] if File.file?(yard)
        commands
      end

      def resolved_changelog_path
        path = ENV.fetch("K_CHANGELOG_PATH", "").to_s.strip
        path = "CHANGELOG.md" if path.empty?
        File.expand_path(path, @root)
      end

      def resolved_coverage_root
        path = ENV.fetch("K_CHANGELOG_COVERAGE_ROOT", "").to_s.strip
        return @root if path.empty?

        File.expand_path(path, @root)
      end

      def prepare_yard_fence_tmp_files
        yardopts = File.join(@root, ".yardopts")
        return unless File.file?(yardopts)
        return unless File.read(yardopts).include?("tmp/yard-fence")

        require "yard/fence"
        outdir = File.join(@root, "tmp", "yard-fence")
        FileUtils.rm_rf(outdir)
        FileUtils.mkdir_p(outdir)
        Dir.glob(File.join(@root, Yard::Fence::GLOB_PATTERN)).each do |src|
          next unless File.file?(src)

          content = File.read(src)
          sanitized = Yard::Fence.sanitize_text(content)
          File.write(File.join(outdir, File.basename(src)), sanitized)
        end
      end

      def documented_percent_line(output)
        line = output.lines.find { |l| /\d+(?:\.\d+)?%\s+documented/.match?(l) }
        line&.strip
      end

      # Transform legacy release headings that include a tag suffix, e.g.:
      #   "## [1.2.3] 2022-08-29 ([tag][1.2.3t])"
      # into a heading followed by a list item:
      #   "## [1.2.3] 2022-08-29\n\n- TAG: [v1.2.3][1.2.3t]"
      # The method is idempotent: if the next non-blank line already starts with "- TAG:",
      # no new list item is inserted. Case-insensitive match for [tag].
      def convert_heading_tag_suffix_to_list(text)
        lines = text.lines
        # Build a set of versions that have a tag reference (e.g., "[1.2.3t]: ...").
        # IMPORTANT: Only scan the footer link-ref block (starting at the [Unreleased]: line)
        # to avoid accidentally picking up body content.
        scan_start = lines.index { |l| l.start_with?(UNRELEASED_SECTION_HEADING) } || lines.length
        t_versions = {}
        non_t_tag_refs = {}
        lines[scan_start..-1].to_a.each do |l|
          # Case A: explicit tag ref key like [1.2.3t]: ...
          if (m = l.match(/^\[(#{CHANGELOG_VERSION_PATTERN_SOURCE})t\]:\s+(\S+)/o))
            t_versions[m[1]] = true
            next
          end
          # Case B: non-t ref that nevertheless points to a tag URL (GitHub or GitLab)
          if (m2 = l.match(/^\[(#{CHANGELOG_VERSION_PATTERN_SOURCE})\]:\s+(\S+)/o))
            url = m2[2]
            # Accept only when the URL clearly points to a tag for the SAME version
            # Support both GitHub and GitLab style tag URLs
            if (murl = url.match(%r{/(?:releases/)?tags?/v(#{CHANGELOG_VERSION_PATTERN_SOURCE})}io))
              version_in_url = murl[1]
              if version_in_url == m2[1]
                non_t_tag_refs[m2[1]] = url
              end
            end
          end
        end
        # Any version that has either explicit t-ref or a non-t tag-ref is considered tagged
        tag_ref_versions = {}
        t_versions.keys.each { |v| tag_ref_versions[v] = true }
        non_t_tag_refs.keys.each { |v| tag_ref_versions[v] = true }

        out = []
        i = 0
        while i < lines.length
          line = lines[i]
          # Case 1: Heading contains legacy tag suffix we should convert
          m = line.match(/^## \[(#{CHANGELOG_VERSION_PATTERN_SOURCE})\](.*)\(\[tag\]\[(#{CHANGELOG_VERSION_PATTERN_SOURCE})t\]\)\s*$/io)
          if m && m[1] == m[3]
            ver = m[1]
            middle = m[2]
            new_heading = ("## [#{ver}]" + middle).rstrip + "\n"
            out << new_heading
            # If the next non-blank line is already a TAG list item, don't add another
            k = i + 1
            k += 1 while k < lines.length && lines[k].strip == ""
            unless k < lines.length && lines[k].lstrip.start_with?("- TAG:")
              out << "\n"
              out << "- TAG: [v#{ver}][#{ver}t]\n"
              out << "\n"
            end
            # Skip any existing blank lines following the heading to avoid duplicate spacing
            i = k
            next
          end

          # Case 2: Heading does NOT contain suffix, but a matching tag ref exists; ensure a TAG list item
          if (m2 = line.match(/^## \[(#{CHANGELOG_VERSION_PATTERN_SOURCE})\](.*)$/o))
            ver2 = m2[1]
            # Skip Unreleased heading and non-release headings
            unless ver2.nil?
              k = i + 1
              k += 1 while k < lines.length && lines[k].strip == ""
              needs_tag = tag_ref_versions[ver2] && !(k < lines.length && lines[k].lstrip.start_with?("- TAG:"))
              if needs_tag
                out << (line.end_with?("\n") ? line : line + "\n")
                out << "\n"
                out << "- TAG: [v#{ver2}][#{ver2}t]\n"
                out << "\n"
                i = k
                next
              end
            end
          end

          # Footer duplication: if we are in the footer block and encounter a non-t tag-ref
          # without a matching t-ref, emit the t-ref immediately after with the same URL.
          if i >= scan_start
            if (mref = line.match(/^\[(#{CHANGELOG_VERSION_PATTERN_SOURCE})\]:\s+(\S+)/o))
              vref = mref[1]
              mref[2]
              if non_t_tag_refs[vref] && !t_versions[vref]
                out << line
                out << "[#{vref}t]: #{non_t_tag_refs[vref]}\n"
                t_versions[vref] = true
                i += 1
                next
              end
            end
          end

          out << line
          i += 1
        end
        out.join
      end

      def update_link_refs(content, owner, repo, prev_version, new_version)
        # Convert any GitLab links to GitHub
        content = content.gsub(%r{https://gitlab\.com/([^/]+)/([^/]+)/-/compare/([^.]+)\.\.\.([^\s]+)}) do
          o = owner || Regexp.last_match(1)
          r = repo || Regexp.last_match(2)
          from = Regexp.last_match(3)
          to = Regexp.last_match(4)
          "https://github.com/#{o}/#{r}/compare/#{from}...#{to}"
        end
        content = content.gsub(%r{https://gitlab\.com/([^/]+)/([^/]+)/-/tags/(v[^\s\]]+)}) do
          o = owner || Regexp.last_match(1)
          r = repo || Regexp.last_match(2)
          tag = Regexp.last_match(3)
          "https://github.com/#{o}/#{r}/releases/tag/#{tag}"
        end

        # Append or update the bottom reference links
        lines = content.lines

        # Identify the true start of the footer reference block: the line with the [Unreleased] link-ref.
        # Do NOT assume the first link-ref after the Unreleased heading starts the footer, because
        # some changelogs contain interspersed link-refs within section bodies.
        unreleased_ref_idx = lines.index { |l| l.start_with?(UNRELEASED_SECTION_HEADING) }
        # If no [Unreleased]: ref is present, consider the reference block to start at EOF
        first_ref = unreleased_ref_idx || lines.length

        # Ensure Unreleased points to GitHub compare from new tag to HEAD
        if owner && repo
          unreleased_ref = "[Unreleased]: https://github.com/#{owner}/#{repo}/compare/v#{new_version}...HEAD\n"
          # Update an existing Unreleased ref only if it appears after Unreleased heading; otherwise append
          idx = nil
          lines.each_with_index do |l, i|
            if l.start_with?(UNRELEASED_SECTION_HEADING) && i >= first_ref
              idx = i
              break
            end
          end
          if idx
            lines[idx] = unreleased_ref
          else
            lines << unreleased_ref
          end
        end

        if owner && repo
          # Add compare link for the new version
          from = prev_version ? "v#{prev_version}" : detect_initial_compare_base(lines)
          new_compare = "[#{new_version}]: https://github.com/#{owner}/#{repo}/compare/#{from}...v#{new_version}\n"
          unless lines.any? { |l| l.start_with?("[#{new_version}]:") }
            lines << new_compare
          end
          # Add tag link for the new version
          new_tag = "[#{new_version}t]: https://github.com/#{owner}/#{repo}/releases/tag/v#{new_version}\n"
          unless lines.any? { |l| l.start_with?("[#{new_version}t]:") }
            lines << new_tag
          end
        end

        # Rebuild and sort the reference block so Unreleased is first, then newest to oldest versions, preserving everything above first_ref
        ref_lines = lines[first_ref..-1].select { |l| /^\[[^\]]+\]:\s+http/.match?(l) }
        # Deduplicate by key (text inside the square brackets)
        by_key = {}
        ref_lines.each do |l|
          if l =~ /^\[([^\]]+)\]:\s+/
            by_key[$1] = l
          end
        end
        unreleased_line = by_key.delete("Unreleased")
        # Separate version compare and tag links
        compares = {}
        tags = {}
        by_key.each do |k, v|
          if k =~ /^(#{CHANGELOG_VERSION_PATTERN_SOURCE})$/o
            compares[$1] = v
          elsif k =~ /^(#{CHANGELOG_VERSION_PATTERN_SOURCE})t$/o
            tags[$1] = v
          end
        end
        # Build a unified set of versions that appear in either compares or tags
        version_keys = (compares.keys | tags.keys)
        # Sort versions descending (newest to oldest)
        sorted_versions = version_keys.map { |s| Gem::Version.new(s) }.sort.reverse.map(&:to_s)

        new_ref_block = []
        new_ref_block << unreleased_line if unreleased_line
        sorted_versions.each do |v|
          new_ref_block << compares[v] if compares[v]
          new_ref_block << tags[v] if tags[v]
        end
        # Replace the old block
        head = lines[0...first_ref]
        # Ensure exactly one blank line separating body content from the reference block
        if head.any? && head.last.to_s.strip != ""
          head << "\n"
        end
        rebuilt = head + new_ref_block + ["\n"]
        rebuilt.join
      end

      # Ensure every Markdown atx-style heading line (e.g., "# ", "## ") has exactly one blank line
      # before and after it, skipping content inside fenced code blocks.
      def normalize_heading_spacing(text)
        lines = text.split("\n", -1)
        out = []
        in_fence = false
        fence_re = /^\s*```/
        heading_re = /^\s*#+\s+.+/
        lines.each_with_index do |ln, idx|
          if fence_re.match?(ln)
            in_fence = !in_fence
            out << ln
            next
          end
          if !in_fence && heading_re.match?(ln)
            # Ensure previous line is blank (unless start of file or already blank)
            prev_blank = out.empty? ? false : out.last.to_s.strip == ""
            out << "" unless out.empty? || prev_blank
            out << ln
            # Peek at next line in source to decide if we need to inject a blank now.
            nxt = lines[idx + 1]
            out << "" unless nxt.to_s.strip == ""
          else
            out << ln
          end
        end
        # Collapse multiple consecutive blank lines down to a single between regions that our logic might have doubled
        collapsed = []
        lines_enum = out
        lines_enum.each do |l|
          if l.strip == "" && collapsed.last.to_s.strip == ""
            next
          end
          collapsed << l
        end
        collapsed.join("\n")
      end

      def ensure_footer_spacing(text)
        lines = text.split("\n", -1)
        # Find the Unreleased link-ref which denotes start of footer refs
        idx = lines.index { |l| l.start_with?(UNRELEASED_SECTION_HEADING) }
        return text unless idx
        head = lines[0...idx]
        tail = lines[idx..-1]
        # Ensure exactly one blank line between body and refs
        if head.any? && head.last.to_s.strip != ""
          head << ""
        elsif head.any? && head.last.to_s.strip == "" && head[-2].to_s.strip == ""
          # Collapse multiple blanks before footer to a single
          head.pop while head.any? && head.last.to_s.strip == ""
          head << ""
        end
        (head + tail).join("\n")
      end

      # Determine the "from" side of the compare URL for the very first release.
      #
      # Priority:
      #   1. KETTLE_CHANGELOG_INITIAL_SHA env var — explicit override, required for hard-forks
      #      (e.g. turbo_tests2 which forked from an upstream commit SHA).
      #   2. `git rev-list --max-parents=0 HEAD` — the root commit of this repository.
      #      Correct for the overwhelming majority of new gems.
      #   3. "HEAD^" — last-resort fallback when git is unavailable or the command fails.
      #
      # @param _lines [Array<String>] kept for API compatibility (no longer used)
      # @return [String] the compare base: a commit SHA, tag, or fallback string
      def detect_initial_compare_base(_lines = nil)
        env_sha = ENV.fetch("KETTLE_CHANGELOG_INITIAL_SHA", nil)
        return env_sha.strip if env_sha && !env_sha.strip.empty?

        sha = git_root_commit
        return sha if sha

        warn(
          "Could not determine initial git root commit; using HEAD^ as compare base. " \
            "Set KETTLE_CHANGELOG_INITIAL_SHA to override."
        )
        "HEAD^"
      end

      # Return the root commit SHA of the current repository, or nil on failure.
      # Uses the generic GitAdapter#capture escape hatch so tests can stub it.
      def git_root_commit
        out, ok = git_capture(["rev-list", "--max-parents=0", "HEAD"])
        sha = out.to_s.lines.last&.strip   # take last line in case of multiple root commits
        (ok && sha && !sha.empty?) ? sha : nil
      rescue
        nil
      end

      def git_capture(args)
        Kettle::Dev::GitAdapter.new(@root).capture(args)
      end
    end
  end
end
