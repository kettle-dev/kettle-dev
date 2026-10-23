# frozen_string_literal: true

require "set"
require "uri"

module Kettle
  module Dev
    # Validates Markdown reference labels and local link destinations.
    #
    # This deliberately validates only the small Markdown subset needed by the
    # release gate. Available general-purpose parsers either reject reference
    # layouts accepted by existing project changelogs or discard unresolved
    # reference syntax, so they cannot provide these diagnostics. Keep the
    # scanner bounded to reference definitions/usages, local destinations, and
    # headings; it is not a general Markdown parser.
    class MarkdownReferenceValidator
      Issue = Struct.new(:path, :line, :message)
      Report = Struct.new(:file_count, :reference_count, :local_target_count, :issues)

      # CommonMark permits at most three leading spaces before a fenced block.
      FENCE_RE = /\A {0,3}(`{3,}|~{3,})/.freeze
      IGNORED_PATH_PREFIXES = %w[tmp/ .git/ spec/ test/].freeze
      REFERENCE_DEFINITION_RE = /\A {0,3}\[([^\]]+)\]:\s*(?:<([^>]+)>|(\S+))/
      REFERENCE_USAGE_RE = /!?\[([^\]]*)\]\[([^\]]*)\]/
      INLINE_LINK_RE = /!?\[[^\]]*\]\((<[^>]+>|[^)]*)\)/
      ATX_HEADING_RE = /\A {0,3}\#{1,6}\s+(.+?)\s*\#*\s*\z/
      SETEXT_HEADING_RE = /\A {0,3}(=+|-+)\s*\z/

      def initialize(root: Dir.pwd, files: nil)
        @root = File.expand_path(root)
        @files = (files || default_files).reject { |path| ignored_path?(path) }
      end

      def validate!
        documents = @files.each_with_object({}) do |path, result|
          absolute = absolute_path(path)
          result[path] = parse_document(path, absolute) if File.file?(absolute)
        end
        report = build_report(documents)
        return report if report.issues.empty?

        warn("[kettle-pre-release] Markdown reference validation failed:")
        report.issues.each do |issue|
          warn("  - #{Kettle::Dev.display_path(issue.path)}:#{issue.line}: #{issue.message}")
        end
        raise Kettle::Dev::Error, "Markdown reference validation failed (#{report.issues.size} issue(s))"
      end

      private

      def default_files
        if defined?(Kettle::Dev::PreReleaseCLI::Markdown)
          Kettle::Dev::PreReleaseCLI::Markdown.project_markdown_files.reject { |path| ignored_path?(path) }
        else
          Dir.glob(["**/*.md", "**/*.markdown", "**/*.md.example"]).reject { |path| ignored_path?(path) }.sort
        end
      end

      def ignored_path?(path)
        IGNORED_PATH_PREFIXES.any? { |prefix| path.to_s.start_with?(prefix) }
      end

      def absolute_path(path)
        File.expand_path(path, @root)
      end

      def parse_document(path, absolute)
        lines = File.readlines(absolute, chomp: true)
        definitions = {}
        usages = []
        local_targets = []
        headings = []
        in_fence = false
        fence_char = nil
        fence_length = 0
        previous_text = nil

        lines.each_with_index do |line, index|
          line_number = index + 1
          fence = line.match(FENCE_RE)
          if in_fence
            if fence && fence[1][0] == fence_char && fence[1].length >= fence_length
              in_fence = false
            end
            next
          elsif fence
            in_fence = true
            fence_char = fence[1][0]
            fence_length = fence[1].length
            next
          end

          definition = line.match(REFERENCE_DEFINITION_RE)
          if definition
            label = normalize_label(definition[1])
            target = definition[2] || definition[3]
            definitions[label] ||= []
            definitions[label] << [line_number, target]
            local_targets << [line_number, target]
            previous_text = nil
            next
          end

          line.to_enum(:scan, REFERENCE_USAGE_RE).each do
            match = Regexp.last_match
            next if markdown_bracket_expression?(line, match.begin(0))

            text, label = match.captures
            resolved_label = label.empty? ? text : label
            usages << [line_number, normalize_label(resolved_label)]
          end
          line.scan(INLINE_LINK_RE) do |destination|
            target = destination[0]
            target = target[1..-2] if target.start_with?("<") && target.end_with?(">")
            target = target.split(/\s+/, 2).first
            local_targets << [line_number, target] unless target.to_s.empty?
          end

          if line.match?(SETEXT_HEADING_RE) && previous_text
            headings << [line_number - 1, previous_text]
            previous_text = nil
          else
            heading = heading_for(line)
            headings << heading if heading
            previous_text = line.strip unless line.strip.empty?
          end
        end

        {
          path: path,
          definitions: definitions,
          usages: usages,
          local_targets: local_targets,
          headings: heading_slugs(headings)
        }
      rescue Errno::EACCES, Errno::ENOENT => error
        {
          path: path,
          definitions: {},
          usages: [],
          local_targets: [],
          headings: [],
          read_error: error
        }
      end

      def build_report(documents)
        issues = []
        reference_count = 0
        local_target_count = 0
        heading_cache = {}

        documents.each_value do |document|
          if document[:read_error]
            issues << Issue.new(document[:path], 1, "could not read Markdown file: #{document[:read_error].message}")
            next
          end

          document[:definitions].each do |label, definitions|
            if definitions.length > 1
              definitions.drop(1).each do |line_number, _target|
                issues << Issue.new(document[:path], line_number, "duplicate reference definition #{label.inspect}")
              end
            end
          end

          document[:usages].each do |line_number, label|
            next if label.include?("<") || label.include?(">")

            reference_count += 1
            next if document[:definitions].key?(label)

            issues << Issue.new(document[:path], line_number, "undefined Markdown reference #{label.inspect}")
          end

          document[:local_targets].each do |line_number, target|
            destination = local_destination(target)
            next unless destination

            local_target_count += 1
            target_path, fragment = destination
            target_document = target_path.empty? ? document : documents_for_path(documents, document[:path], target_path)
            if target_document.nil?
              issues << Issue.new(document[:path], line_number, "local Markdown target does not exist: #{target_path.inspect}")
              next
            end
            next if fragment.empty?

            slugs = heading_cache[target_document[:path]] ||= target_document[:headings]
            next if slugs.include?(fragment)

            issues << Issue.new(document[:path], line_number, "local heading target does not exist: ##{fragment}")
          end
        end

        Report.new(documents.size, reference_count, local_target_count, issues)
      end

      def documents_for_path(documents, source_path, target_path)
        candidate = File.expand_path(target_path, File.dirname(absolute_path(source_path)))
        documents.values.find { |document| absolute_path(document[:path]) == candidate }
      end

      def local_destination(target)
        value = target.to_s.strip
        return nil if value.empty? || value.start_with?("//")

        uri = URI.parse(value)
        return nil if uri.scheme || uri.host
        path = unescape(uri.path.to_s)
        fragment = unescape(uri.fragment.to_s).downcase
        return nil if fragment.empty?
        return nil unless path.empty? || markdown_path?(path)

        [path, fragment]
      rescue URI::InvalidURIError
        nil
      end

      def unescape(value)
        parser = defined?(URI::RFC2396_PARSER) ? URI::RFC2396_PARSER : URI::DEFAULT_PARSER
        parser.unescape(value)
      end

      def markdown_path?(path)
        path.downcase.end_with?(".md", ".markdown", ".md.example")
      end

      def normalize_label(label)
        label.to_s.downcase.gsub(/\s+/, " ").strip
      end

      def markdown_bracket_expression?(line, index)
        return false unless index.positive?

        line[index - 1].match?(/[[:alnum:]_\])]/)
      end

      def heading_for(line)
        match = line.match(ATX_HEADING_RE)
        match ? [line[/\A\s*/].to_s.length + 1, match[1]] : nil
      end

      def heading_slugs(headings)
        counts = Hash.new(0)
        headings.each_with_object(Set.new) do |(_line, text), slugs|
          slug = slugify(text)
          next if slug.empty?

          suffix = counts[slug]
          counts[slug] += 1
          slugs.add(suffix.zero? ? slug : "#{slug}-#{suffix}")
        end
      end

      def slugify(text)
        text.to_s.gsub(/<[^>]+>/, "").strip.downcase
          .gsub(/[*_~`]/, "")
          .gsub(/[^\p{Alnum}\s-]/u, "")
          .gsub(/\s+/, "-")
      end
    end
  end
end
