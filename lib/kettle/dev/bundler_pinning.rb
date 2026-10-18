# frozen_string_literal: true

require "bundler"
require "rubygems/dependency_installer"

module Kettle
  module Dev
    # Shared Bundler version resolution and maintenance for the release
    # toolchain. Both kettle-release (release prep pins BUNDLED WITH) and
    # kettle-family (bupb / update-bundler pin every member lockfile) need the
    # same three answers — what stable Bundler is installed, what stable
    # Bundler the registry serves, and how to install/pin one — and divergent
    # copies are how lockfiles drifted behind CI images.
    #
    # Every lookup rejects prereleases: bundler betas ship as "latest" and a
    # beta in BUNDLED WITH reinfects every child that boots the bundle.
    module BundlerPinning
      RUBYGEMS_SOURCE = "https://rubygems.org"

      module_function

      # Newest stable Bundler installed locally. Consults BOTH sources —
      # the activated spec and every installed spec — because bundler/setup
      # scoping can hide one from the other depending on how the process booted.
      #
      # The spec index itself is not enough: under `bundle exec`, Bundler
      # replaces the index with the ACTIVE BUNDLE's specs, so a lockfile that
      # pinned a prerelease (the 4.1.0.betaN reinfection vector) makes this
      # lookup see only that prerelease and wrongly report "no stable bundler".
      # The gemspec files on disk are read directly from every Gem.path to
      # escape that scoping.
      def installed_stable
        active = Gem.loaded_specs["bundler"]&.version
        versions = Gem::Specification.find_all_by_name("bundler").map(&:version)
        Array(Gem.path).each do |base|
          Dir.glob(File.join(base, "specifications", "bundler-*.gemspec")).each do |path|
            version = Gem::Version.new(File.basename(path, ".gemspec").delete_prefix("bundler-"))
            versions << version
          rescue ArgumentError
            nil
          end
        end
        versions.push(active) if active
        versions.reject(&:prerelease?).max
      end

      # Newest stable Bundler the registry serves; nil when the registry
      # cannot be consulted, so callers can fail open to local state.
      def published_stable
        numbers = Kettle::Dev::RubyGemsVersions.published_version_numbers("bundler")
        return nil unless numbers

        numbers.filter_map { |number| published_candidate(number) }.max
      end

      # Install a stable Bundler — the exact version given, or the latest
      # stable when nil. rubygems.org only, never prereleases, and a spec
      # reset so the just-installed version is visible to later gem lookups
      # in this process. Returns the installed specs.
      def install_stable(version = nil)
        original_sources = Gem.sources.to_a
        Gem.sources = [RUBYGEMS_SOURCE]
        requirements = version ? ["= #{version}"] : []
        specs = Gem::DependencyInstaller.new(domain: :remote, prerelease: false, document: []).install("bundler", *requirements)
        Gem::Specification.reset
        specs
      ensure
        Gem.sources = original_sources if original_sources
      end

      # The version a release should pin BUNDLED WITH to: the registry's
      # newest stable, installing it first when the executing Bundler lags.
      # A registry outage fails open to the executing Bundler rather than
      # blocking the release.
      def ensure_latest_stable(executing: Bundler::VERSION)
        current = Gem::Version.new(executing)
        latest = published_stable
        return current.to_s if latest.nil? || latest <= current

        install_stable(latest)
        latest.to_s
      end

      # Pinned argv for a bundler-update spawn. A bare `--bundler` lets
      # RubyGems resolve the newest bundler INCLUDING prereleases (the
      # recurring 4.1.0.betaN infection vector), so the version is pinned on
      # both the executable selector and the flag.
      def update_argv(version, extra_gems: [])
        ["bundle", "_#{version}_", "update", *extra_gems, "--bundler=#{version}"]
      end

      def published_candidate(number)
        candidate = Gem::Version.new(number)
        candidate unless candidate.prerelease?
      rescue ArgumentError
        nil
      end
    end
  end
end
