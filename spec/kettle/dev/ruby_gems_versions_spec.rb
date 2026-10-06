# frozen_string_literal: true

require "tmpdir"
require "kettle/dev/ruby_gems_versions"

RSpec.describe Kettle::Dev::RubyGemsVersions do
  def ok_response(body)
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.instance_variable_set(:@read, true)
    response.body = body
    response
  end

  around do |example|
    Dir.mktmpdir do |dir|
      @cache_bust_path = File.join(dir, "rubygems-cache-bust.json")
      @version_cache_path = File.join(dir, "rubygems-version-cache.json")
      example.run
    end
  end

  before do
    stub_env(
      "KETTLE_RUBYGEMS_CACHE_BUST_PATH" => @cache_bust_path,
      "KETTLE_RUBYGEMS_REFRESH" => nil,
      "KETTLE_RUBYGEMS_VERSION_CACHE_PATH" => @version_cache_path,
      "KETTLE_JEM_DEPS_FLOOR_CACHE" => nil
    )
  end

  it "records recently published gem versions in a best-effort marker file", freeze: Time.utc(2026, 7, 21, 12, 0, 0) do
    described_class.mark_released("demo", "1.2.3")

    marker = JSON.parse(File.read(@cache_bust_path))
    expect(marker.dig("releases", "demo")).to eq(
      "version" => "1.2.3",
      "released_at" => "2026-07-21T12:00:00Z"
    )
  end

  it "cache-busts version lookups for freshly published matching gem versions", freeze: Time.utc(2026, 7, 21, 12, 5, 0) do
    write_marker("demo", "1.2.3", "2026-07-21T12:00:00Z")
    response = ok_response(JSON.generate([{"number" => "1.2.3"}]))
    request_uri = nil
    request_headers = nil
    http = instance_double(Net::HTTP)
    allow(http).to receive(:request) do |request|
      request_uri = request.uri
      request_headers = request.to_hash
      response
    end
    allow(Net::HTTP).to receive(:start).and_yield(http)

    versions = described_class.fetch("demo", version_hint: "1.2.3")

    expect(versions).to eq([{"number" => "1.2.3"}])
    expect(Net::HTTP).to have_received(:start).with(
      "rubygems.org",
      443,
      use_ssl: true,
      open_timeout: described_class::HTTP_OPEN_TIMEOUT_SECONDS,
      read_timeout: described_class::HTTP_READ_TIMEOUT_SECONDS
    )
    expect(request_uri.query).to include("_kettle_cache_bust=")
    expect(request_headers.fetch("cache-control")).to eq(["no-cache"])
    expect(request_headers.fetch("pragma")).to eq(["no-cache"])
  end

  it "uses normal version lookup URLs outside the thirty-day marker freshness window", freeze: Time.utc(2026, 8, 21, 12, 0, 1) do
    write_marker("demo", "1.2.3", "2026-07-21T12:00:00Z")
    response = ok_response(JSON.generate([]))
    request_uri = nil
    http = instance_double(Net::HTTP)
    allow(http).to receive(:request) do |request|
      request_uri = request.uri
      response
    end
    allow(Net::HTTP).to receive(:start).and_yield(http)

    described_class.fetch("demo", version_hint: "1.2.3")

    expect(request_uri.query).to be_nil
  end

  it "uses fresh cached versions without a live RubyGems request", freeze: Time.utc(2026, 7, 30, 12, 0, 0) do
    write_version_cache("demo", "2026-07-01T12:00:00Z", [{"number" => "1.2.3"}])
    allow(Net::HTTP).to receive(:start)

    versions = described_class.fetch("demo", version_hint: "1.2.3")

    expect(versions).to eq([{"number" => "1.2.3"}])
    expect(Net::HTTP).not_to have_received(:start)
  end

  it "refreshes a fresh cache when it predates the requested version", freeze: Time.utc(2026, 7, 30, 12, 0, 0) do
    write_version_cache("demo", "2026-07-01T12:00:00Z", [{"number" => "1.2.2"}])
    response = ok_response(JSON.generate([{"number" => "1.2.3"}]))
    request_uri = nil
    http = instance_double(Net::HTTP)
    allow(http).to receive(:request) do |request|
      request_uri = request.uri
      response
    end
    allow(Net::HTTP).to receive(:start).and_yield(http)

    versions = described_class.fetch("demo", version_hint: "1.2.3")

    expect(versions).to eq([{"number" => "1.2.3"}])
    expect(request_uri.query).to include("_kettle_cache_bust=")
  end

  it "refreshes cached versions when a fresh release marker exists", freeze: Time.utc(2026, 7, 30, 12, 0, 0) do
    write_version_cache("demo", "2026-07-01T12:00:00Z", [{"number" => "1.2.2"}])
    write_marker("demo", "1.2.3", "2026-07-30T11:59:00Z")
    response = ok_response(JSON.generate([{"number" => "1.2.3"}]))
    allow(Net::HTTP).to receive(:start).and_yield(instance_double(Net::HTTP, request: response))

    versions = described_class.fetch("demo", version_hint: "1.2.3")

    expect(versions).to eq([{"number" => "1.2.3"}])
    expect(JSON.parse(File.read(@version_cache_path)).dig("versions", "demo", "entries")).to eq([{"number" => "1.2.3"}])
  end

  it "falls back to fresh cached versions when the live RubyGems request fails", freeze: Time.utc(2026, 7, 30, 12, 0, 0) do
    write_version_cache("demo", "2026-07-01T12:00:00Z", [{"number" => "1.2.2"}])
    write_marker("demo", "1.2.3", "2026-07-30T11:59:00Z")
    response = Net::HTTPInternalServerError.new("1.1", "500", "Internal Server Error")
    allow(Net::HTTP).to receive(:start).and_yield(instance_double(Net::HTTP, request: response))

    versions = described_class.fetch("demo", version_hint: "1.2.3")

    expect(versions).to eq([{"number" => "1.2.2"}])
  end

  it "treats a never-published gem as having no released versions" do
    response = Net::HTTPNotFound.new("1.1", "404", "Not Found")
    allow(Net::HTTP).to receive(:start).and_yield(instance_double(Net::HTTP, request: response))

    versions = described_class.fetch("never-published")

    expect(versions).to be_empty
    expect(JSON.parse(File.read(@version_cache_path)).dig("versions", "never-published", "entries")).to be_empty
  end

  it "queries the requested source instead of rubygems.org" do
    response = ok_response(JSON.generate([{"number" => "9.9.9"}]))
    request_uri = nil
    http = instance_double(Net::HTTP)
    allow(http).to receive(:request) do |request|
      request_uri = request.uri
      response
    end
    allow(Net::HTTP).to receive(:start).and_yield(http)

    versions = described_class.fetch("demo", source: "https://gem.coop")

    expect(versions).to eq([{"number" => "9.9.9"}])
    expect(Net::HTTP).to have_received(:start).with(
      "gem.coop",
      443,
      use_ssl: true,
      open_timeout: described_class::HTTP_OPEN_TIMEOUT_SECONDS,
      read_timeout: described_class::HTTP_READ_TIMEOUT_SECONDS
    )
    expect(request_uri.path).to eq("/api/v1/versions/demo.json")
  end

  it "keeps per-source cache entries separate so registries cannot poison each other" do
    # A private registry lagging rubygems.org is the motivating case: the same
    # gem can legitimately have different published versions on each source.
    coop_response = ok_response(JSON.generate([{"number" => "1.0.0"}]))
    rubygems_response = ok_response(JSON.generate([{"number" => "2.0.0"}]))
    hosts = []
    allow(Net::HTTP).to receive(:start) do |host, _port, **_opts, &block|
      hosts << host
      response = (host == "gem.coop") ? coop_response : rubygems_response
      block.call(instance_double(Net::HTTP, request: response))
    end

    expect(described_class.fetch("demo", source: "https://gem.coop")).to eq([{"number" => "1.0.0"}])
    expect(described_class.fetch("demo")).to eq([{"number" => "2.0.0"}])
    expect(hosts).to eq(%w[gem.coop rubygems.org])

    cached = JSON.parse(File.read(@version_cache_path)).fetch("versions")
    expect(cached.fetch("gem.coop:demo").fetch("entries")).to eq([{"number" => "1.0.0"}])
    expect(cached.fetch("demo").fetch("entries")).to eq([{"number" => "2.0.0"}])
  end

  it "serves a fresh source-scoped cache entry without a live request", freeze: Time.utc(2026, 7, 30, 12, 0, 0) do
    write_version_cache("gem.coop:demo", "2026-07-01T12:00:00Z", [{"number" => "1.0.0"}])
    allow(Net::HTTP).to receive(:start)

    versions = described_class.fetch("demo", source: "https://gem.coop", version_hint: "1.0.0")

    expect(versions).to eq([{"number" => "1.0.0"}])
    expect(Net::HTTP).not_to have_received(:start)
  end

  it "returns nil from published_version_numbers when the registry cannot be consulted" do
    allow(Net::HTTP).to receive(:start).and_raise(Errno::ECONNREFUSED)

    expect(described_class.published_version_numbers("demo", source: "https://gem.coop")).to be_nil
  end

  it "returns version numbers from published_version_numbers for a reachable registry" do
    response = ok_response(JSON.generate([{"number" => "1.2.3"}, {"number" => "1.2.2"}, "not-a-hash"]))
    allow(Net::HTTP).to receive(:start).and_yield(instance_double(Net::HTTP, request: response))

    expect(described_class.published_version_numbers("demo", source: "https://gem.coop")).to eq(%w[1.2.3 1.2.2])
  end

  it "returns an empty list from published_version_numbers for a never-published gem" do
    response = Net::HTTPNotFound.new("1.1", "404", "Not Found")
    allow(Net::HTTP).to receive(:start).and_yield(instance_double(Net::HTTP, request: response))

    expect(described_class.published_version_numbers("never-published", source: "https://gem.coop")).to be_empty
  end

  def write_marker(gem_name, version, released_at)
    File.write(
      @cache_bust_path,
      JSON.generate("releases" => {gem_name => {"version" => version, "released_at" => released_at}})
    )
  end

  def write_version_cache(gem_name, cached_at, entries)
    File.write(
      @version_cache_path,
      JSON.generate("versions" => {gem_name => {"cached_at" => cached_at, "entries" => entries}})
    )
  end
end
