# frozen_string_literal: true

require "net/http"
require "uri"

module Corpus
  ##
  # Downloads a gem's `.gem` file from rubygems.org.
  #
  # Downloads go straight to rubygems.org's download endpoint rather than
  # through `gem fetch`, so the result does not depend on whatever `sources`
  # the local RubyGems configuration names. rubygems.org is also where the
  # manifest's versions were resolved, so the corpus is fetched from the same
  # place it was chosen from.
  #
  # Only the `ruby` platform is ever fetched, because that is the variant that
  # carries a native gem's C sources — which YARD documents — rather than a
  # precompiled binary it cannot read. The URL for that variant is the bare
  # `<name>-<version>.gem`, with no platform suffix.
  #
  class GemFetcher
    # @return [String] Base URL of the gem download endpoint.
    BASE_URL = "https://rubygems.org/downloads"

    ##
    # @param base_url [String] Override the download base URL.
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
    # Downloads one gem version's `ruby`-platform `.gem` file.
    #
    # @param name [String] Gem name.
    # @param version [String] Exact gem version.
    # @param path [String] Where to write the `.gem` file.
    # @return [void]
    # @raise [FetchError] if the file could not be downloaded.
    #
    def fetch(name, version, path)
      body = download(::URI.parse("#{@base_url}/#{::URI.encode_uri_component("#{name}-#{version}")}.gem"))
      ::File.binwrite(path, body)
    end

    ##
    # Raised when a gem file cannot be downloaded.
    #
    class FetchError < ::StandardError
    end

    private

    # A 404 — or the 403 the endpoint's storage backend actually answers for a
    # missing object — means the version is not there to fetch, typically
    # because it was yanked after the manifest was written. Retrying cannot
    # change that. Anything else is retried, because a single transient 503
    # partway through a few hundred downloads should not cost that gem.
    def download(uri)
      last_error = nil
      @attempts.times do |attempt|
        sleep(@backoff * (2**(attempt - 1))) if attempt.positive?
        begin
          response = ::Net::HTTP.get_response(uri)
          return response.body if response.is_a?(::Net::HTTPSuccess)
          if response.is_a?(::Net::HTTPNotFound) || response.is_a?(::Net::HTTPForbidden)
            raise FetchError, "#{uri} is not available (HTTP #{response.code}); was it yanked?"
          end
          last_error = "HTTP #{response.code}"
        rescue FetchError
          raise
        rescue ::StandardError => e
          last_error = "#{e.class}: #{e.message}"
        end
      end
      raise FetchError, "could not download #{uri} after #{@attempts} attempts (#{last_error})"
    end
  end
end
