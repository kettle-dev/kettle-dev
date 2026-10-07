# frozen_string_literal: true

require "fileutils"
require "json"
require "net/http"
require "time"
require "uri"

module Kettle
  module Dev
    class Error < StandardError; end unless const_defined?(:Error, false)
    ENV_TRUE_RE = /\A(1|true|y|yes)\z/i unless const_defined?(:ENV_TRUE_RE, false)

    module RubyGemsVersions
      CACHE_BUST_TTL_SECONDS = 30 * 24 * 60 * 60
      VERSION_CACHE_TTL_SECONDS = 30 * 24 * 60 * 60
      HTTP_OPEN_TIMEOUT_SECONDS = 5
      HTTP_READ_TIMEOUT_SECONDS = 10
      DEFAULT_SOURCE = "https://rubygems.org"
      ENV_REFRESH = "KETTLE_RUBYGEMS_REFRESH"
      ENV_MARKER_PATH = "KETTLE_RUBYGEMS_CACHE_BUST_PATH"
      ENV_VERSION_CACHE_PATH = "KETTLE_RUBYGEMS_VERSION_CACHE_PATH"
      ENV_LEGACY_VERSION_CACHE_PATH = "KETTLE_JEM_DEPS_FLOOR_CACHE"

      class << self
        # Query a RubyGems-compatible versions API.
        #
        # +source+ selects which registry to ask, because a private registry
        # such as gem.coop can lag rubygems.org: a version present on one may
        # be absent from the other. Cache entries are keyed by source for the
        # same reason, so the two registries cannot poison each other.
        def fetch(gem_name, version_hint: nil, refresh: false, source: DEFAULT_SOURCE)
          name = gem_name.to_s
          key = cache_key(name, source)
          cached = cached_versions(key)
          cache_bust = refresh || env_refresh? || fresh_release_marker?(name, version_hint) || cached_behind_version?(cached, version_hint)
          return cached if cached && !cache_bust

          uri = versions_uri(gem_name, source: source, cache_bust: cache_bust)
          request = Net::HTTP::Get.new(uri)
          if cache_bust
            request["Cache-Control"] = "no-cache"
            request["Pragma"] = "no-cache"
          end
          response = Net::HTTP.start(
            uri.host,
            uri.port,
            use_ssl: uri.scheme == "https",
            open_timeout: HTTP_OPEN_TIMEOUT_SECONDS,
            read_timeout: HTTP_READ_TIMEOUT_SECONDS
          ) do |http|
            http.request(request)
          end
          if response.code.to_i == 404
            write_versions(key, [])
            return []
          end
          return cached unless response.is_a?(Net::HTTPSuccess)

          data = JSON.parse(response.body)
          write_versions(key, data) if data.is_a?(Array)
          data
        rescue => error
          return cached if cached

          raise error
        end

        # Published version numbers for a gem on one registry, or nil when the
        # registry could not be consulted (caller must treat that as "unknown",
        # never as "unpublished", so offline runs are not blocked).
        #
        # +source+ is matched against the remote a lockfile actually recorded,
        # since a private registry such as gem.coop can lag rubygems.org.
        #
        # +version+ is the version the caller is asking about, forwarded as
        # fetch's version_hint. That makes cache-busting precise: the on-disk
        # release marker written by kettle-release busts the cache only for the
        # exact gem+version just published, instead of for every gem released
        # within the marker TTL. Without it a caller cannot tell "this version
        # was published moments ago in this very run" from "this gem was
        # released at some point in the last month".
        def published_version_numbers(gem_name, source: DEFAULT_SOURCE, version: nil)
          versions = fetch(gem_name, version_hint: version, source: normalize_source(source))
          return nil if versions.nil?

          versions.filter_map { |entry| entry["number"] if entry.is_a?(Hash) }
        rescue
          nil
        end

        # Whether kettle-release's on-disk marker says this exact gem+version
        # was published recently enough that cached registry data must not be
        # trusted for it.
        #
        # The marker file is the authority on what this machine just published,
        # so any process-local cache layered on top of the registry must consult
        # it rather than serve a pre-publish answer.
        def recently_released?(gem_name, version = nil)
          fresh_release_marker?(gem_name.to_s, version&.to_s)
        end

        def mark_released(gem_name, version)
          return if gem_name.to_s.empty? || version.to_s.empty?

          path = marker_path
          data = read_marker(path)
          data["releases"] ||= {}
          data["releases"][gem_name.to_s] = {
            "version" => version.to_s,
            "released_at" => Time.now.utc.iso8601
          }
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, JSON.pretty_generate(data) << "\n")
        rescue => error
          warn("[kettle-dev] could not update RubyGems.org cache-bust marker: #{error.class}: #{error.message}") if Kettle::Dev::DEBUGGING
        end

        def marker_path
          configured = ENV.fetch(ENV_MARKER_PATH, "").to_s
          return configured unless configured.empty?

          state_home = ENV["XDG_STATE_HOME"]
          state_home = File.join(Dir.home, ".local", "state") if state_home.to_s.empty?
          File.join(state_home, "kettle-dev", "rubygems-cache-bust.json")
        end

        def version_cache_path
          configured = ENV.fetch(ENV_VERSION_CACHE_PATH, "").to_s
          return "" if configured.match?(/\A(?:false|0|no|off|disabled)\z/i)
          return configured unless configured.empty?

          legacy_configured = ENV.fetch(ENV_LEGACY_VERSION_CACHE_PATH, "").to_s
          return "" if legacy_configured.match?(/\A(?:false|0|no|off|disabled)\z/i)
          return legacy_configured unless legacy_configured.empty?

          cache_home = ENV["XDG_CACHE_HOME"]
          cache_home = File.join(Dir.home, ".cache") if cache_home.to_s.empty?
          File.join(cache_home, "kettle-jem", "deps-floor-rubygems-versions.json")
        end

        private

        # Cache entries are namespaced by source host so a version list fetched
        # from a private registry cannot be served for rubygems.org, or vice
        # versa. The default source keeps the historical bare gem name as its
        # key so existing caches remain valid.
        def cache_key(gem_name, source)
          normalized = normalize_source(source)
          return gem_name.to_s if normalized == DEFAULT_SOURCE

          "#{URI(normalized).host}:#{gem_name}"
        rescue URI::InvalidURIError
          "#{normalized}:#{gem_name}"
        end

        def normalize_source(source)
          source.to_s.sub(%r{/+\z}, "")
        end

        def versions_uri(gem_name, source:, cache_bust:)
          uri = URI("#{normalize_source(source)}/api/v1/versions/#{gem_name}.json")
          uri.query = "_kettle_cache_bust=#{Time.now.to_i}" if cache_bust
          uri
        end

        def fresh_release_marker?(gem_name, version_hint)
          entry = read_marker(marker_path).fetch("releases", {})[gem_name.to_s]
          return false unless entry
          return false if version_hint && entry["version"].to_s != version_hint.to_s

          released_at = Time.iso8601(entry["released_at"].to_s)
          released_at >= Time.now.utc - CACHE_BUST_TTL_SECONDS
        rescue ArgumentError
          false
        end

        def cached_behind_version?(cached, version_hint)
          return false unless cached && version_hint

          cached_versions = cached.each_with_object([]) do |entry, versions|
            value = entry["number"] if entry.is_a?(Hash)
            next if value.to_s.empty? || value.to_s =~ /[a-zA-Z]/

            versions << Gem::Version.new(value)
          end
          return false if cached_versions.empty?

          cached_versions.max < Gem::Version.new(version_hint)
        rescue ArgumentError
          false
        end

        def read_marker(path)
          return {} unless File.file?(path)

          parsed = JSON.parse(File.read(path))
          parsed.is_a?(Hash) ? parsed : {}
        rescue JSON::ParserError
          {}
        end

        def env_refresh?
          ENV.fetch(ENV_REFRESH, "").match?(Kettle::Dev::ENV_TRUE_RE)
        end

        def cached_versions(cache_key)
          path = version_cache_path
          return nil if path.empty?

          entry = read_version_cache(path).fetch("versions", {})[cache_key]
          return nil unless entry.is_a?(Hash)
          return nil unless fresh_version_cache_entry?(entry)

          Array(entry["entries"])
        end

        def write_versions(cache_key, entries)
          path = version_cache_path
          return if path.empty?

          data = read_version_cache(path)
          data["versions"] ||= {}
          data["versions"][cache_key] = {
            "cached_at" => Time.now.utc.iso8601,
            "entries" => entries
          }
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, JSON.pretty_generate(data) << "\n")
        rescue => error
          warn("[kettle-dev] could not update RubyGems version cache: #{error.class}: #{error.message}") if Kettle::Dev::DEBUGGING
        end

        def read_version_cache(path)
          return {} unless File.file?(path)

          parsed = JSON.parse(File.read(path))
          parsed.is_a?(Hash) ? parsed : {}
        rescue JSON::ParserError
          {}
        end

        def fresh_version_cache_entry?(entry)
          cached_at = Time.iso8601(entry["cached_at"].to_s)
          cached_at >= Time.now.utc - VERSION_CACHE_TTL_SECONDS
        rescue ArgumentError
          false
        end
      end
    end
  end
end
