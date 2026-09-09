# frozen_string_literal: true

require "set"
require "shellwords"
require "fileutils"
require "open3"
require "tmpdir"
require "bundler"
require "ripper"

require_relative "bundler_env_guard"

module Kettle
  module Dev
    class LockfileReset
      DEFAULT_DISABLED_ENV = {
        "KETTLE_DEV_DEV" => "false",
        "K_JEM_TEMPLATING" => "false",
        "STRUCTUREDMERGE_DEV" => "false",
        "TREE_SITTER_LANGUAGE_PACK_DEV" => "false",
        "RUBOCOP_LTS_LOCAL" => "false",
        "GALTZO_FLOSS_DEV" => "false",
        "UR_BRAIN_DEV" => "false"
      }.freeze
      ALLOWED_LOCAL_PATH_ROOTS_ENV = "KETTLE_RELEASE_ALLOWED_LOCAL_PATH_ROOTS"
      ALLOWED_LOCAL_PATH_ENVS_ENV = "KETTLE_RELEASE_ALLOWED_LOCAL_PATH_ENVS"
      RELEASE_LOCKFILES_TARGET = "release-lockfiles"
      SUPPORTED_TARGETS = ["Gemfile.lock", "Appraisal.root.gemfile.lock", RELEASE_LOCKFILES_TARGET].freeze
      UNBUNDLED_ENV_KEYS = (BundlerEnvGuard::RESET_ENV_KEYS + %w[
        RUBYLIB
        RUBYOPT
      ]).freeze

      class << self
        def local_path_remote_lines_from_source(lockfile_source)
          in_path = false
          lockfile_source.each_line.with_index(1).filter_map do |line, index|
            stripped = line.strip
            if stripped.match?(/\A[A-Z][A-Z ]*\z/)
              in_path = stripped == "PATH"
              next
            end
            next unless in_path
            next unless stripped.start_with?("remote:")
            next if stripped == "remote: ."
            next unless stripped.start_with?("remote: /", "remote: ./", "remote: ../")

            index
          end
        end

        def checksum_entries_from_source(lockfile_source)
          in_checksums = false
          entries = {}
          lockfile_source.each_line do |line|
            stripped = line.chomp
            if stripped == "CHECKSUMS"
              in_checksums = true
              next
            end
            next unless in_checksums
            break if !stripped.empty? && stripped == stripped.upcase && !stripped.start_with?(" ")
            next unless stripped.start_with?("  ")

            parsed = parse_lockfile_spec_line(stripped)
            entries[[parsed.fetch(:name), parsed.fetch(:version)]] = parsed.fetch(:suffix) if parsed
          end
          in_checksums ? entries : nil
        end

        def gem_specs_from_source(lockfile_source)
          in_gem = false
          in_specs = false
          specs = []
          lockfile_source.each_line do |line|
            stripped = line.chomp
            if stripped == "GEM"
              in_gem = true
              in_specs = false
              next
            end
            next unless in_gem
            break if !stripped.empty? && stripped == stripped.upcase && !stripped.start_with?(" ")

            if stripped == "  specs:"
              in_specs = true
              next
            end
            next unless in_specs
            next unless line.start_with?("    ") && !line.start_with?("      ")

            parsed = parse_lockfile_spec_line(stripped)
            specs << [parsed.fetch(:name), parsed.fetch(:version)] if parsed
          end
          specs.uniq
        end

        private

        def parse_lockfile_spec_line(line)
          stripped = line.to_s.strip
          return nil if stripped.empty? || !stripped.include?(" (")

          name, remainder = stripped.split(" (", 2)
          version, suffix = remainder.to_s.split(")", 2)
          return nil if name.to_s.empty? || version.to_s.empty?

          {name: name, version: version, suffix: suffix.to_s.strip}
        end
      end

      def initialize(root:, command_runner:)
        @root = root
        @command_runner = command_runner
        @release_platforms = {}
        @allowed_local_path_roots = configured_allowed_local_path_roots
        @allowed_local_path_env_names = configured_allowed_local_path_env_names
      end

      def reset(target, skip_changelog_dependency: false)
        BundlerEnvGuard.warn_unexpected_env!
        paths = lockfile_paths_for(target)
        # A monorepo lockfile may deliberately use paths rooted in the
        # repository's members directory. Keep that valid development graph;
        # only rebuild when an unapproved path or other diagnostic remains.
        force_full_update = release_lockfiles_target?(target) &&
          (allowed_local_path_roots.empty? || paths.any? { |path| normalization_needed?(path) })
        platforms = release_platforms_for(paths) if force_full_update
        uninstall_unreleased_local_gems(paths) if force_full_update
        paths.each do |path|
          if force_full_update || normalization_needed?(path)
            reset_lockfile!(
              path,
              full_update: force_full_update,
              platforms: platforms&.fetch(path),
              skip_changelog_dependency: skip_changelog_dependency,
              update_bundler: force_full_update
            )
          end
        end
        if force_full_update && uninstall_unreleased_local_gems(paths)
          paths.each do |path|
            reset_lockfile!(
              path,
              full_update: true,
              platforms: platforms.fetch(path),
              skip_changelog_dependency: skip_changelog_dependency,
              update_bundler: true
            )
          end
        end
        diagnostics = paths.flat_map { |path| diagnostics(path) }
        raise Error, validation_message(target, diagnostics) unless diagnostics.empty?

        paths
      end

      def reset_lockfile!(path, full_update: false, platforms: nil, skip_changelog_dependency: false, update_bundler: false)
        gemfile = gemfile_for_lockfile(path)
        unless gemfile && File.file?(gemfile)
          warn("Cannot reset #{display_path(path)} because its Gemfile was not found.")
          return
        end

        with_isolated_gem_paths do |gem_home|
          install_gemfile_bootstrap_gems!(gemfile: gemfile, lockfile: path, gem_home: gem_home)
          command = reset_command(
            path: path,
            gemfile: gemfile,
            full_update: full_update,
            platforms: platforms,
            skip_changelog_dependency: skip_changelog_dependency,
            update_bundler: update_bundler,
            isolated_gem_home: gem_home
          )
          if full_update || has_local_path_remote?(path)
            rebuild_lockfile(path) { command_runner.call(command) }
          else
            command_runner.call(command)
          end
        end
      end

      def reset_command(path:, gemfile:, full_update: false, platforms: nil, skip_changelog_dependency: false, update_bundler: false, isolated_gem_home: nil, isolated_gem_path: nil)
        update_gems = (full_update || has_local_path_remote?(path)) ? [] : reset_update_gems(path)
        platforms ||= reset_platforms(path)
        removed_platforms = full_update ? [] : lockfile_platforms(path) - platforms
        env = normalization_env.merge(
          "BUNDLE_GEMFILE" => gemfile,
          "BUNDLE_LOCKFILE" => path
        )
        env["KETTLE_DEV_SKIP_CHANGELOG_DEPENDENCY"] = "true" if skip_changelog_dependency
        if isolated_gem_home
          env["GEM_HOME"] = isolated_gem_home
          env["GEM_PATH"] = isolated_gem_path || isolated_gem_home
        end
        command_prefix = bundler_command_prefix(env)
        command = +"#{command_prefix} bundle lock"
        # Bundler accepts each platform option once followed by a list. Repeating
        # either option silently keeps only the final occurrence with Bundler 4.
        command << " --remove-platform #{removed_platforms.sort.map { |platform| Shellwords.escape(platform) }.join(" ")}" unless removed_platforms.empty?
        command << " --add-platform #{platforms.map { |platform| Shellwords.escape(platform) }.join(" ")}" unless platforms.empty?
        command << " --update"
        command << " #{update_gems.map { |gem_name| Shellwords.escape(gem_name) }.join(" ")}" unless update_gems.empty?
        command << " --add-checksums" unless update_bundler
        return command unless update_bundler

        # `bundle lock --bundler` accepts a requirement and retains a locked
        # prerelease that satisfies it. `bundle update --bundler=VERSION`
        # records the exact Bundler that is executing the reset instead.
        # Finish with `bundle lock --add-checksums`, since `bundle update`
        # does not support that option.
        bundler_version = Shellwords.escape(Bundler::VERSION)
        command << " && #{command_prefix} bundle update --bundler=#{bundler_version}"
        command << " && #{command_prefix} bundle lock --add-checksums"
        command
      end

      def bundler_command_prefix(env)
        command = +"env"
        UNBUNDLED_ENV_KEYS.each do |key|
          command << " -u #{key}"
        end
        env.each do |key, value|
          command << " #{key}=#{Shellwords.escape(value)}"
        end
        command
      end

      def reset_platforms(path)
        platforms = lockfile_platforms(path)
        platforms = [Gem::Platform.local.to_s] if platforms.empty?
        platforms.reject(&:empty?).sort
      end

      def release_platforms_for(paths)
        paths.each_with_object({}) do |path, platforms|
          platforms[path] = (@release_platforms[path] ||= reset_platforms(path))
        end
      end

      def lockfile_platforms(path)
        in_platforms = false
        File.readlines(path).filter_map do |line|
          stripped = line.strip
          if stripped.match?(/\A[A-Z][A-Z ]*\z/)
            in_platforms = stripped == "PLATFORMS"
            next
          end
          next unless in_platforms
          next if stripped.empty?

          stripped
        end
      end

      def reset_update_gems(path)
        (
          path_source_gems(path).to_a |
          path_dependency_gems(path).to_a |
          empty_registry_checksums(path).map(&:first) |
          unreleased_workspace_registry_specs(path).map(&:first)
        ).uniq.sort
      end

      def normalization_needed?(path)
        has_local_path_remote?(path) ||
          !empty_registry_checksums(path).empty? ||
          !unreleased_workspace_registry_specs(path).empty? ||
          bundled_with_checksum_mismatch?(path)
      end

      def diagnostics(path)
        diagnostics = []
        disallowed_local_path_remote_lines(path).each do |line_number|
          diagnostics << "#{display_path(path)} has local path remote at line #{line_number}"
        end
        empty_registry_checksums(path).each do |name, version, line_number|
          diagnostics << "#{display_path(path)} CHECKSUMS has no sha256 for #{name} #{version} at line #{line_number}"
        end
        unreleased_workspace_registry_specs(path).each do |name, version, line_number|
          diagnostics << "#{display_path(path)} locks local workspace gem #{name} #{version} as a registry gem, but that version is not resolvable from the configured gem source at line #{line_number}"
        end
        if bundled_with_checksum_mismatch?(path)
          diagnostics.push("#{display_path(path)} BUNDLED WITH #{bundled_with_version(path)} has no matching Bundler checksum")
        end
        diagnostics
      end

      def lockfile_paths
        candidates = [
          File.join(root, "Gemfile.lock"),
          File.join(root, "Appraisal.root.gemfile.lock")
        ]
        candidates.select { |path| File.file?(path) }.sort
      end

      def lockfile_path_for(target)
        paths = lockfile_paths_for(target)
        raise Error, "reset target #{target.inspect} resolves to multiple lockfiles; use lockfile_paths_for" if paths.length != 1

        paths.first
      end

      def lockfile_paths_for(target)
        normalized = target.to_s.strip
        raise Error, "reset requires TARGET" if normalized.empty?
        if release_lockfiles_target?(normalized)
          paths = lockfile_paths
          raise Error, "no release lockfiles found" if paths.empty?

          return paths
        end
        supported = SUPPORTED_TARGETS.reject { |candidate| candidate == RELEASE_LOCKFILES_TARGET }
        match = supported.find { |candidate| candidate.casecmp(normalized).zero? }
        unless match
          raise Error, "reset target #{normalized.inspect} is not supported; supported targets: #{SUPPORTED_TARGETS.join(", ")}"
        end

        [File.join(root, match)]
      end

      def release_lockfiles_target?(target)
        target.to_s.strip.casecmp(RELEASE_LOCKFILES_TARGET).zero?
      end

      def gemfile_for_lockfile(path)
        basename = File.basename(path)
        return File.join(root, "Gemfile") if basename == "Gemfile.lock"

        path.delete_suffix(".lock")
      end

      def normalization_env
        DEFAULT_DISABLED_ENV
          .reject { |name, _| allowed_local_path_env_names.include?(name) }
          .merge(dynamic_local_path_env)
      end

      # Appraisal generation normally uses the release-normalized environment.
      # During family templating it instead needs the caller's deliberately
      # selected local graph so generated Appraisal Gemfiles can resolve
      # unpublished sibling dependencies.
      def appraisal_normalization_env
        env = normalization_env
        return env unless template_local_environment?

        env.reject do |name, _value|
          name == "K_JEM_TEMPLATING" || active_local_path_env?(name)
        end
      end

      def dynamic_local_path_env
        ENV.each_with_object({}) do |(key, value), env|
          next unless key.end_with?("_DEV", "_LOCAL")
          next unless local_path_env_value?(value)
          next if allowed_local_path_env_names.include?(key)

          env[key] = "false"
        end
      end

      def local_path_env_value?(value)
        text = value.to_s.strip
        return false if text.empty? || text.casecmp("false").zero?
        return true if text.start_with?("/", "./", "../", "~")

        text.include?(File::SEPARATOR)
      end

      def template_local_environment?
        %w[1 true yes on].include?(ENV.fetch("K_JEM_TEMPLATING", "").to_s.strip.downcase)
      end

      def active_local_path_env?(name)
        local_path_env_value?(ENV[name])
      end

      def has_local_path_remote?(path)
        !disallowed_local_path_remote_lines(path).empty?
      end

      def local_path_remote_lines(path)
        self.class.local_path_remote_lines_from_source(File.read(path))
      end

      attr_reader :allowed_local_path_roots, :allowed_local_path_env_names

      def disallowed_local_path_remote_lines(path)
        local_path_remote_lines(path).reject do |line_number|
          allowed_local_path?(local_path_remote_at(path, line_number))
        end
      end

      def configured_allowed_local_path_roots
        ENV.fetch(ALLOWED_LOCAL_PATH_ROOTS_ENV, "").split(File::PATH_SEPARATOR).filter_map do |value|
          next if value.strip.empty?

          canonical_path(value)
        end.uniq
      end

      def configured_allowed_local_path_env_names
        ENV.fetch(ALLOWED_LOCAL_PATH_ENVS_ENV, "").split(",").map(&:strip).reject(&:empty?).uniq
      end

      def local_path_remote_at(path, line_number)
        File.readlines(path)[line_number - 1].to_s.split("remote:", 2).last.to_s.strip
      end

      def allowed_local_path?(path)
        remote = canonical_path(path)
        allowed_local_path_roots.any? { |root| remote == root || remote.start_with?("#{root}/") }
      end

      def canonical_path(path)
        expanded = File.expand_path(path, root)
        File.realpath(expanded)
      rescue Errno::ENOENT
        expanded
      end

      def empty_registry_checksums(path)
        non_registry_gems = non_registry_source_gems(path) | path_dependency_gems(path)
        in_checksums = false
        entries = File.readlines(path).filter_map.with_index(1) do |line, index|
          stripped = line.strip
          if stripped == "CHECKSUMS"
            in_checksums = true
            next
          end
          next unless in_checksums
          next if stripped.empty?
          next if stripped == "BUNDLED WITH"

          match = stripped.match(/\A([A-Za-z0-9_.-]+) \(([^)]+)\)(?:\s+(sha256=.*))?\z/)
          next unless match

          name = match[1]
          checksum = match[3].to_s
          next unless checksum.empty?
          next if non_registry_gems.include?(name)

          [name, match[2], index]
        end
        return [] unless has_any_sha_checksum?(path)

        entries
      end

      def unreleased_workspace_registry_specs(path)
        local_names = local_workspace_gem_names
        return [] if local_names.empty?

        source_urls = registry_source_urls(path)
        registry_specs_with_lines(path).filter_map do |name, version, line_number|
          next unless local_names.include?(name)
          next if gem_source_version_available?(name, version, source_urls)

          [name, version, line_number]
        end
      end

      def has_any_sha_checksum?(path)
        in_checksums = false
        File.readlines(path).any? do |line|
          stripped = line.strip
          if stripped == "CHECKSUMS"
            in_checksums = true
            next false
          end
          next false unless in_checksums

          stripped.include?("sha256=")
        end
      end

      # A release reset updates both `BUNDLED WITH` and CHECKSUMS. When a
      # nested tool leaked its Bundler into a member lockfile, a later cleanup
      # can otherwise replace only the checksum entry and leave an impossible
      # lockfile behind. Only flag a mismatch when the lockfile already tracks
      # Bundler in CHECKSUMS, preserving older lockfiles that lack that entry.
      def bundled_with_checksum_mismatch?(path)
        version = bundled_with_version(path)
        return false if version.empty?

        checksums = self.class.checksum_entries_from_source(File.read(path))
        return false unless checksums&.keys&.any? { |name, _checksum_version| name == "bundler" }

        !checksums.key?(["bundler", version])
      end

      def bundled_with_version(path)
        lines = File.readlines(path)
        marker = lines.index { |line| line.strip == "BUNDLED WITH" }
        return "" unless marker

        lines[marker.succ..-1].each do |line|
          version = line.strip
          return version unless version.empty?
        end
        ""
      end

      def path_source_gems(path)
        lockfile_parser(path).specs.each_with_object(Set.new) do |spec, gems|
          source = spec.source
          gems << spec.name if path_source?(source) && !self_path_source?(source)
        end
      end

      def non_registry_source_gems(path)
        lockfile_parser(path).specs.each_with_object(Set.new) do |spec, gems|
          gems << spec.name unless registry_source?(spec.source)
        end
      end

      def path_dependency_gems(path)
        lockfile_parser(path).dependencies.each_value.each_with_object(Set.new) do |dependency, gems|
          source = dependency.source
          gems << dependency.name if path_source?(source) && !self_path_source?(source)
        end
      end

      def display_path(path)
        Kettle::Dev.display_path(path)
      end

      private

      attr_reader :root, :command_runner

      def with_isolated_gem_paths
        base = File.join(root, "tmp", "kettle-reset")
        FileUtils.mkdir_p(base)
        Dir.mktmpdir("gem-home-", base) do |gem_home|
          yield(gem_home)
        end
      end

      # Bundler evaluates a Gemfile and its static eval_gemfile inputs before it
      # resolves declared gems. Install only literal bootstrap requires into the
      # reset sandbox so unrelated gems from the invoking Ruby cannot influence
      # resolution.
      def install_gemfile_bootstrap_gems!(gemfile:, lockfile:, gem_home:)
        gemfile_bootstrap_gems(gemfile).each do |name, required_by_root_gemfile|
          version = locked_registry_gem_version(lockfile, name)
          source_url = registry_source_urls(lockfile).first
          needs_install = required_by_root_gemfile || (version && source_url)
          next unless needs_install

          if !version || !source_url
            raise Error, "Cannot isolate Gemfile bootstrap #{name.inspect}: #{display_path(lockfile)} does not lock it from a registry source"
          end

          command_runner.call(bootstrap_gem_install_command(name, version, source_url, gem_home))
        end
      end

      def gemfile_bootstrap_gems(gemfile)
        gemfile_source_paths(gemfile).each_with_index.each_with_object({}) do |(path, index), gems|
          calls = require_calls_from_ripper(Ripper.sexp(File.read(path)))
          calls.filter_map { |method_name, argument| bootstrap_gem_name(method_name, argument) }.each do |name|
            gems[name] = gems.fetch(name, false) || index.zero?
          end
        end
      end

      def gemfile_source_paths(gemfile, seen = Set.new)
        path = File.expand_path(gemfile)
        return [] if seen.include?(path) || !File.file?(path)

        seen << path
        calls = require_calls_from_ripper(Ripper.sexp(File.read(path)))
        nested_paths = calls.filter_map do |method_name, argument|
          next unless method_name == "eval_gemfile" && argument

          File.expand_path(argument, File.dirname(path))
        end
        [path, *nested_paths.flat_map { |nested_path| gemfile_source_paths(nested_path, seen) }]
      end

      def require_calls_from_ripper(node, calls = [])
        return calls unless node.is_a?(Array)

        case node.first
        when :command
          calls << [node.dig(1, 1), string_literal_value(node[2])]
        when :method_add_arg
          calls << [node.dig(1, 1, 1), string_literal_value(node[2])]
        end
        node.each { |child| require_calls_from_ripper(child, calls) if child.is_a?(Array) }
        calls
      end

      def string_literal_value(node)
        return unless node.is_a?(Array)

        parts = []
        collect_string_content(node, parts)
        parts.join unless parts.empty?
      end

      def collect_string_content(node, parts)
        return unless node.is_a?(Array)

        parts << node[1] if node.first == :@tstring_content
        node.each { |child| collect_string_content(child, parts) if child.is_a?(Array) }
      end

      def bootstrap_gem_name(method_name, argument)
        return unless method_name == "require" && argument == "nomono/bundler"

        "nomono"
      end

      def locked_registry_gem_version(lockfile, name)
        lockfile_parser(lockfile).specs.find do |spec|
          spec.name == name && registry_source?(spec.source)
        end&.version&.to_s
      end

      def bootstrap_gem_install_command(name, version, source_url, gem_home)
        env = unbundled_env.merge("GEM_HOME" => gem_home, "GEM_PATH" => gem_home)
        command = +"env"
        env.each do |key, value|
          assignment = value.nil? ? " -u #{key}" : " #{key}=#{Shellwords.escape(value)}"
          command << assignment
        end
        command << " gem install #{Shellwords.escape(name)}"
        command << " -v #{Shellwords.escape("= #{version}")}"
        command << " --source #{Shellwords.escape(source_url)} --clear-sources --no-document"
        command << " --install-dir #{Shellwords.escape(gem_home)}"
        command
      end

      def lockfile_parser(path)
        # Bundler validates checksum digest syntax while parsing, but this class
        # only needs Bundler's source model here. Keep checksum diagnostics in
        # the line scanner below so malformed or empty checksum entries can be
        # reported without breaking source classification.
        Bundler::LockfileParser.new(lockfile_source_content(path))
      end

      def lockfile_source_content(path)
        in_checksums = false
        File.readlines(path).filter_map do |line|
          stripped = line.strip
          if stripped == "CHECKSUMS"
            in_checksums = true
            next
          end
          if in_checksums && stripped.match?(/\A[A-Z][A-Z ]*\z/)
            in_checksums = false
          end
          next if in_checksums

          line
        end.join
      end

      def path_source?(source)
        source.instance_of?(::Bundler::Source::Path)
      end

      def registry_source?(source)
        source.instance_of?(::Bundler::Source::Rubygems)
      end

      def self_path_source?(source)
        path_source?(source) && source.path.to_s == "."
      end

      def rebuild_lockfile(path)
        backup = backup_path_for(path)
        FileUtils.mkdir_p(File.dirname(backup))
        FileUtils.cp(path, backup)
        FileUtils.rm_f(path)
        yield
        FileUtils.mv(backup, path, force: true) unless File.file?(path)
        FileUtils.rm_f(backup)
      rescue
        FileUtils.mv(backup, path, force: true) if File.file?(backup)
        raise
      end

      def backup_path_for(path)
        backup_dir = File.join(root, "tmp", "kettle-reset")
        "#{File.join(backup_dir, File.basename(path))}.#{Process.pid}.bak"
      end

      def uninstall_unreleased_local_gems(paths)
        local_names = local_workspace_gem_names
        return false if local_names.empty?

        uninstalled = false
        locked_registry_specs(paths).each do |name, version|
          next unless local_names.include?(name)
          next unless locally_installed?(name, version)
          next if gem_source_version_available?(name, version, source_urls_for_lockfiles(paths))

          uninstall_unreleased_local_gem(name, version)
          uninstalled = true
        end
        uninstalled
      end

      def uninstall_unreleased_local_gem(name, version)
        command_runner.call(uninstall_command(name, version))
      rescue => error
        # Family release waves can ask several member processes to remove the same
        # unreleased sibling version. If another process won that race, the reset
        # goal is already satisfied; otherwise keep the original uninstall failure.
        raise error if locally_installed?(name, version)
      end

      def locked_registry_specs(paths)
        paths.flat_map { |path| registry_specs(path) }.uniq.sort
      end

      def registry_specs(path)
        registry_specs_with_lines(path).map { |name, version, _line_number| [name, version] }
      end

      def registry_specs_with_lines(path)
        specs = []
        in_gem = false
        in_specs = false
        File.readlines(path).each.with_index(1) do |line, line_number|
          stripped = line.chomp
          if stripped == "GEM"
            in_gem = true
            in_specs = false
            next
          end
          next unless in_gem
          break if !stripped.empty? && stripped == stripped.upcase && !stripped.start_with?(" ")

          if stripped == "  specs:"
            in_specs = true
            next
          end
          next unless in_specs

          match = stripped.match(/\A    ([A-Za-z0-9_.-]+) \(([^)]+)\)/)
          specs << [match[1], match[2], line_number] if match
        end
        specs
      end

      def locally_installed?(name, version)
        _stdout, _stderr, status = Open3.capture3(
          unbundled_env,
          "gem",
          "specification",
          name,
          "--version",
          version.to_s,
          "--local"
        )
        status.success?
      rescue SystemCallError
        false
      end

      def unbundled_env
        UNBUNDLED_ENV_KEYS.each_with_object({}) do |key, env|
          env[key] = nil
        end
      end

      def gem_source_version_available?(name, version, source_urls)
        urls = Array(source_urls).compact.uniq
        return false if urls.empty?

        urls.any? { |source_url| bundler_inline_version_available?(name, version, source_url) }
      end

      def bundler_inline_version_available?(name, version, source_url)
        @gem_source_version_available ||= {}
        cache_key = [source_url, name, version]
        return @gem_source_version_available[cache_key] if @gem_source_version_available.key?(cache_key)

        @gem_source_version_available[cache_key] = GemSourceProbe.new(source_url: source_url).available?(name, version)
      end

      def source_urls_for_lockfiles(paths)
        paths.flat_map { |path| registry_source_urls(path) }.uniq
      end

      def registry_source_urls(path)
        urls = []
        in_gem = false
        File.readlines(path).each do |line|
          stripped = line.strip
          if stripped == "GEM"
            in_gem = true
            next
          end
          if stripped.match?(/\A[A-Z][A-Z ]*\z/)
            in_gem = stripped == "GEM"
            next
          end
          next unless in_gem && stripped.start_with?("remote:")

          urls << stripped.delete_prefix("remote:").strip
        end
        urls
      end

      def uninstall_command(name, version)
        command = +"env"
        UNBUNDLED_ENV_KEYS.each do |key|
          command << " -u #{key}"
        end
        command << " gem uninstall #{Shellwords.escape(name)} -v #{Shellwords.escape(version)} -x -I"
        command
      end

      def local_workspace_gem_names
        paths = dynamic_local_path_env.keys.filter_map do |key|
          value = ENV[key].to_s.strip
          value unless value.empty?
        end
        paths << File.expand_path("..", root)
        paths.each_with_object(Set.new) do |path, names|
          next unless File.directory?(path)

          workspace_children(path).each do |child|
            next unless directory?(child)

            Dir[File.join(child, "*.gemspec")].each do |gemspec|
              names << File.basename(gemspec, ".gemspec")
            end
          end
        end
      end

      def workspace_children(path)
        Dir.entries(path).reject { |child| child == "." || child == ".." }.map { |child| File.join(path, child) }
      rescue SystemCallError
        []
      end

      def directory?(path)
        File.stat(path).directory?
      rescue SystemCallError
        false
      end

      def validation_message(target, diagnostics)
        <<~MSG
          Reset #{target} failed validation:
          #{diagnostics.map { |diagnostic| "  - #{diagnostic}" }.join("\n")}
        MSG
      end
    end
  end
end
