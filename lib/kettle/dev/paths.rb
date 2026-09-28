# frozen_string_literal: true

module Kettle
  module Dev
    # Filesystem path operations shared by Kettle tools.
    module Paths
      module_function

      # Expands a path and resolves its longest existing ancestor. This keeps
      # comparisons useful for generated paths that do not exist yet.
      def canonical(path, base: nil)
        expanded = File.expand_path(path, base)
        existing = expanded
        suffix = []
        until File.exist?(existing) || File.symlink?(existing)
          parent = File.dirname(existing)
          return expanded if parent == existing

          suffix.unshift(File.basename(existing))
          existing = parent
        end

        suffix.reduce(File.realpath(existing)) { |resolved, component| File.join(resolved, component) }
      rescue Errno::EACCES, Errno::ENOENT
        expanded
      end

      # Uses filesystem identity for existing paths, so symlink aliases and
      # platform-specific aliases are compared by the operating system.
      def same?(left, right, base: nil)
        left_path = canonical(left, base: base)
        right_path = canonical(right, base: base)
        return true if left_path == right_path

        return File.identical?(left_path, right_path) if File.exist?(left_path) && File.exist?(right_path)

        comparable_parts(left_path) == comparable_parts(right_path)
      rescue Errno::EACCES, Errno::ENOENT, Errno::ENOTDIR, NotImplementedError
        comparable_parts(left_path || left) == comparable_parts(right_path || right)
      end

      # Tests containment by path components, not by a string prefix.
      def within?(path, root, base: nil)
        candidate = canonical(path, base: base)
        boundary = canonical(root, base: base)
        return true if same?(candidate, boundary)

        candidate_parts = comparable_parts(candidate)
        boundary_parts = comparable_parts(boundary)
        candidate_parts[0, boundary_parts.length] == boundary_parts
      rescue Errno::EACCES, Errno::ENOENT, Errno::ENOTDIR
        false
      end

      def path_parts(path)
        path.tr("\\", "/").split("/").reject(&:empty?)
      end

      def comparable_parts(path)
        parts = path_parts(path)
        Gem.win_platform? ? parts.map(&:downcase) : parts
      end
    end
  end
end
