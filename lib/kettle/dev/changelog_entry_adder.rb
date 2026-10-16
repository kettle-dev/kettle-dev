# frozen_string_literal: true

# simplecov:disable -- deprecated transition class, removal in kettle-dev 4.0; behavior coverage lives in the kettle-changelog gem

warn("Kettle::Dev::ChangelogEntryAdder is deprecated and will be removed in kettle-dev 4.0; use Kettle::Changelog::EntryAdder from the kettle-changelog gem instead")

module Kettle
  module Dev
    class ChangelogEntryAdder
      SECTIONS = %w[Added Changed Deprecated Removed Fixed Security].freeze

      def initialize(section:, entry:, root: Kettle::Dev::CIHelpers.project_root)
        @root = root
        @section = section.to_s
        @entry = normalize_entry(entry)
        @changelog_path = ENV.fetch("K_CHANGELOG_PATH", File.join(@root, "CHANGELOG.md"))
      end

      def run
        raise Error, "unsupported changelog section #{@section.inspect}" unless SECTIONS.include?(@section)
        raise Error, "missing CHANGELOG.md in #{Kettle::Dev.display_path(@root)}" unless File.file?(@changelog_path)

        require_markly_crispr!
        source = File.read(@changelog_path)
        context = Ast::Crispr::Markdown::Markly.document_context(content: source, source_label: @changelog_path)
        sections = context.structural_owners(owner_scope: :heading_sections)
        unreleased = find_unreleased_heading!(sections)
        target = find_unreleased_section!(sections, unreleased)
        slice = target_slice(source, target)
        return :unchanged if entry_present?(slice)

        updated = insert_entry(source, target)
        File.write(@changelog_path, updated)
        :changed
      end

      private

      def normalize_entry(entry)
        text = entry.to_s.strip
        raise Error, "changelog entry must not be empty" if text.empty?

        text.start_with?("- ") ? text : "- #{text}"
      end

      def require_markly_crispr!
        require "ast/crispr/markdown/markly"
      rescue LoadError => error
        raise Error, "kettle-changelog add-unreleased-entry requires ast-crispr-markdown-markly (#{error.message})"
      end

      def find_heading!(sections, heading_text:, level:)
        matches = sections.select { |owner| owner.heading_text.to_s.strip == heading_text && owner.level == level }
        raise Error, "expected exactly one #{heading(level, heading_text)} section in CHANGELOG.md, found #{matches.length}" unless matches.length == 1

        matches.first
      end

      def find_unreleased_heading!(sections)
        matches = sections.select do |owner|
          owner.level == 2 && owner.heading_source.to_s.strip == "## [Unreleased]"
        end
        raise Error, "expected exactly one ## [Unreleased] section in CHANGELOG.md, found #{matches.length}" unless matches.length == 1

        matches.first
      end

      def find_unreleased_section!(sections, unreleased)
        matches = sections.select do |owner|
          owner.heading_text.to_s.strip == @section &&
            owner.level == 3 &&
            owner.location.start_line > unreleased.location.start_line &&
            owner.location.end_line <= unreleased.location.end_line
        end
        raise Error, "expected at least one #{heading(3, @section)} section under ## [Unreleased] in CHANGELOG.md, found none" if matches.empty?

        matches.first
      end

      def heading(level, text)
        "#{"#" * level} #{text}"
      end

      def target_slice(source, target)
        lines = source.lines
        lines[(target.location.start_line - 1)...target.location.end_line].to_a.join
      end

      def entry_present?(slice)
        slice.lines.any? { |line| line.chomp == @entry }
      end

      def insert_entry(source, target)
        lines = source.lines
        insertion_index = insertion_index(lines, target)
        payload = entry_payload(lines, insertion_index, target)
        lines.insert(insertion_index, payload)
        lines.join
      end

      def insertion_index(lines, target)
        first_content_index = target.location.start_line
        index = target.location.end_line
        while index > first_content_index && lines.fetch(index - 1).strip.empty?
          index -= 1
        end
        index
      end

      def entry_payload(lines, insertion_index, target)
        previous_line = lines[insertion_index - 1].to_s
        next_line = lines[insertion_index].to_s
        before = previous_line.strip.empty? ? "" : "\n"
        after = (next_line.empty? || next_line.strip.empty?) ? "" : "\n"
        "#{before}#{@entry}\n#{after}"
      end
    end
  end
end
