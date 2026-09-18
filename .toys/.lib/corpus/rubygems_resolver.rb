# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Corpus
  ##
  # Resolves a gem name to the exact version the manifest should name, using
  # the rubygems.org API.
  #
  # ## Why not the ranking dataset
  #
  # The ClickHouse dataset mirrors rubygems.org's own `versions` table and so
  # looks like it could answer this in the same query that ranks the names,
  # saving a few hundred round trips. It cannot, and the reasons are not
  # visible from the data:
  #
  # * Rows are duplicated. The mirror is an un-merged `ReplacingMergeTree`, so
  #   a straightforward join returns each version twice.
  # * The `latest` flag is stale and not unique per gem. `rubyzip` carries
  #   `latest = 't'` on both 3.4.0 and 3.4.1; so do `crass`, `rdoc`,
  #   `globalid` and `websocket-driver`.
  #
  # Both are silent: the query succeeds and returns a plausible version that
  # is simply wrong. When this was measured, the mirror claimed `json` was at
  # 2.20.0 while rubygems.org had already published 3.0.2. Working around it
  # means reimplementing version ordering on top of data already known to be
  # unreliable, to save a step that takes about a minute.
  #
  # So: ClickHouse ranks names, rubygems.org resolves versions.
  #
  class RubygemsResolver
    # @return [String] Base URL of the gem info API.
    BASE_URL = "https://rubygems.org/api/v1/gems"

    ##
    # @param base_url [String] Override the API base URL.
    # @param attempts [Integer] Tries per gem before giving up.
    # @param backoff [Numeric] Seconds to wait after the first failure,
    #   doubling thereafter.
    #
    def initialize(base_url: BASE_URL, attempts: 3, backoff: 1.0)
      @base_url = base_url
      @attempts = attempts
      @backoff = backoff
    end

    ##
    # Returns the version the manifest should name, or nil if the gem has no
    # release suitable for documenting.
    #
    # The endpoint reports the current non-prerelease, `ruby`-platform
    # release, so the platform check below almost never fires — `nokogiri`
    # answers `1.19.4/ruby` even though it publishes six platform variants.
    # It stays as a guard because a gem that only ever ships a native variant
    # would otherwise enter the manifest as a version that cannot be resolved
    # on another machine.
    #
    # @param name [String] Gem name.
    # @return [String,nil] Version string, or nil if there is none to use.
    #
    def resolve(name)
      body = fetch(name)
      return nil if body.nil?
      data = ::JSON.parse(body)
      return nil unless data["platform"] == "ruby"
      version = data["version"].to_s
      version.empty? ? nil : version
    rescue ::JSON::ParserError => e
      raise ResolveError, "malformed response for #{name.inspect}: #{e.message}"
    end

    ##
    # Raised when a gem's metadata cannot be retrieved.
    #
    class ResolveError < ::StandardError
    end

    private

    # A 404 means the gem does not exist, which is an answer rather than a
    # failure — a ranking can name a gem that has since been yanked entirely.
    # Anything else is retried, because a single transient 503 partway through
    # a few hundred lookups should not cost the whole run.
    def fetch(name)
      uri = ::URI.parse("#{@base_url}/#{::URI.encode_uri_component(name)}.json")
      last_error = nil
      @attempts.times do |attempt|
        sleep(@backoff * (2**(attempt - 1))) if attempt.positive?
        begin
          response = ::Net::HTTP.get_response(uri)
          return nil if response.is_a?(::Net::HTTPNotFound)
          return response.body if response.is_a?(::Net::HTTPSuccess)
          last_error = "HTTP #{response.code}"
        rescue ::StandardError => e
          last_error = "#{e.class}: #{e.message}"
        end
      end
      raise ResolveError, "could not resolve #{name.inspect} after #{@attempts} attempts (#{last_error})"
    end
  end
end
