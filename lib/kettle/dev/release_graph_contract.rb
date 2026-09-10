# frozen_string_literal: true

require "json"

module Kettle
  module Dev
    # Parsed contract supplied by kettle-family for a single release target.
    # Direct kettle-release calls receive the safe registry-only default.
    class ReleaseGraphContract
      ENV_KEY = "KETTLE_RELEASE_GRAPH_CONTRACT_JSON"
      NAMES = %w[registry_only wave_transition monorepo_ci_local branch_terminal].freeze

      attr_reader :name, :ci_root, :local_path_roots, :selector_env

      def self.from_environment(root:)
        raw = (ENV[ENV_KEY] || "").strip
        return new(name: "registry_only", root: root, ci_root: root) if raw.empty?

        data = JSON.parse(raw)
        new(
          name: data["name"],
          ci_root: data["ci_root"] || root,
          local_path_roots: data["local_path_roots"] || [],
          selector_env: data["selector_env"] || {},
          root: root
        )
      rescue JSON::ParserError, KeyError, TypeError => error
        raise Error, "invalid #{ENV_KEY}: #{error.message}"
      end

      def initialize(name:, root:, ci_root:, local_path_roots: [], selector_env: {})
        @name = String(name)
        @root = File.realpath(root)
        @ci_root = canonical_path(ci_root)
        @local_path_roots = Array(local_path_roots).map { |path| canonical_path(path) }.uniq.freeze
        @selector_env = selector_env.to_h.map { |key, value| [String(key), String(value)] }.to_h.freeze
        validate!
        freeze
      end

      def local_paths?
        !local_path_roots.empty?
      end

      def registry_only?
        name == "registry_only" || name == "branch_terminal"
      end

      def allowed_path?(path)
        candidate = canonical_path(path)
        local_path_roots.any? { |root| path_within_root?(candidate, root) }
      end

      def normalization_environment
        selector_env
      end

      private

      def validate!
        raise Error, "unknown release graph contract #{name.inspect}" unless NAMES.include?(name)

        if registry_only? && (local_paths? || !selector_env.empty?)
          raise Error, "#{name} release graph cannot declare local paths or selectors"
        end
        return unless %w[wave_transition monorepo_ci_local].include?(name)

        raise Error, "#{name} release graph requires local path roots" unless local_paths?
        raise Error, "#{name} release graph requires local path selectors" if selector_env.empty?

        selector_env.each_value do |value|
          next if allowed_path?(value)

          raise Error, "#{name} selector #{value.inspect} is outside its declared local path roots"
        end
        return unless name == "monorepo_ci_local"

        unless path_within_root?(@root, ci_root)
          raise Error, "monorepo_ci_local release root #{@root.inspect} is outside CI root #{ci_root.inspect}"
        end
        local_path_roots.each do |path|
          next if path_within_root?(path, ci_root)

          raise Error, "monorepo_ci_local path #{path.inspect} is outside CI root #{ci_root.inspect}"
        end
      end

      def canonical_path(path)
        expanded = File.expand_path(path, @root)
        File.realpath(expanded)
      rescue Errno::ENOENT
        expanded
      end

      def path_within_root?(path, root)
        path == root || (path[0, root.length] == root && path[root.length] == "/")
      end
    end
  end
end
