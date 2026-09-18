# frozen_string_literal: true

require "net/http"
require "uri"

module Corpus
  ##
  # Ranks gem names using the public ClickHouse dataset that backs ClickGems,
  # the analytics site rubygems.org itself links from its stats page.
  #
  # ## Why not rubygems.org
  #
  # rubygems.org publishes only cumulative counters. `/api/v1/gems/NAME.json`
  # gives all-time and current-version totals, `/stats` gives an all-time top
  # 100, and the `from`/`to` parameters people cite on the downloads endpoint
  # are silently ignored — the response is byte-identical with and without
  # them. There is no time-windowed ranking anywhere in that API, and no
  # ordering by downloads in its search. An all-time ranking is a poor
  # substitute: it integrates over history, so it over-weights gems that were
  # huge years ago and under-weights anything recent.
  #
  # The weekly PostgreSQL dumps have the same limitation and cost 630 MB plus
  # a local Postgres to answer a question about a few hundred gem names.
  #
  # ## What this depends on
  #
  # A free third-party service with no availability guarantee. That is
  # precisely why its output is committed as a manifest rather than consulted
  # at check time: if this endpoint disappears, the corpus still works and
  # only regeneration stops.
  #
  class ClickHouseRanker
    # @return [String] The public playground endpoint.
    ENDPOINT = "https://sql-clickhouse.clickhouse.com/?user=demo&password="

    # @return [Array<String>] Strategy names this ranker understands.
    STRATEGIES = ["downloads", "dependents"].freeze

    ##
    # @param endpoint [String] Override the query endpoint.
    # @param timeout [Integer] Read timeout in seconds.
    #
    def initialize(endpoint: ENDPOINT, timeout: 120)
      @endpoint = endpoint
      @timeout = timeout
    end

    ##
    # Returns gem names in rank order, best first.
    #
    # @param strategy [String] One of {STRATEGIES}.
    # @param limit [Integer] How many names to return.
    # @param window_days [Integer] Trailing window, used by `downloads` only;
    #   `dependents` reads the current dependency graph, which has no time
    #   dimension to window.
    # @return [Array<String>] Gem names, best-ranked first.
    #
    def rank(strategy, limit:, window_days:)
      limit = Integer(limit)
      window_days = Integer(window_days)
      sql =
        case strategy
        when "downloads" then downloads_sql(limit, window_days)
        when "dependents" then dependents_sql(limit)
        else raise ::ArgumentError, "unknown strategy #{strategy.inspect}"
        end
      execute(sql).lines(chomp: true).reject(&:empty?)
    end

    ##
    # Raised when the ranking service cannot be queried.
    #
    class QueryError < ::StandardError
    end

    private

    # Total downloads over a trailing window. `downloads_per_day` is the live
    # table: its sibling `daily_downloads` looks equivalent but stopped being
    # updated in June 2025, so a query against it silently ranks stale data.
    def downloads_sql(limit, window_days)
      <<~SQL
        SELECT gem FROM rubygems.downloads_per_day
        WHERE date >= today() - #{window_days}
        GROUP BY gem ORDER BY sum(count) DESC
        LIMIT #{limit} FORMAT TabSeparated
      SQL
    end

    # How many distinct gems declare a runtime dependency on this one, counted
    # over current releases only. A different signal from downloads, and a
    # less distorted one: download counts are dominated by transitive pulls,
    # so a gem nobody depends on directly can outrank a widely-used library.
    #
    # `rubygem_id != 0` drops the unresolved rows the dump carries for
    # dependencies on gems that were never published under that name.
    #
    # Counts accumulate over every gem ever published, so this ranking
    # surfaces long-abandoned gems -- `dm-core`, `hpricot`, `compass`,
    # `bootstrap-sass`, `fog` and `hoe` all place in the top 1000. That was
    # considered and kept: RDoc-era gems with idiosyncratic docstrings are
    # exactly the structural variety the corpus exists to cover, and they are
    # the same category as the `fileutils` and `psych` cases that motivated
    # it. It does mean this is not a measure of *current* use. If that is
    # ever wanted, the change is a `created_at` floor on the `latest` CTE,
    # not a different ranking.
    def dependents_sql(limit)
      <<~SQL
        WITH latest AS (
          SELECT DISTINCT id, rubygem_id FROM rubygems.versions
          WHERE latest = 't' AND indexed = 't'
        )
        SELECT r.name FROM rubygems.dependencies d
        INNER JOIN latest l ON d.version_id = l.id
        INNER JOIN rubygems.rubygems r ON d.rubygem_id = r.id
        WHERE d.scope = 'runtime' AND d.rubygem_id != 0
        GROUP BY r.name ORDER BY count(DISTINCT l.rubygem_id) DESC
        LIMIT #{limit} FORMAT TabSeparated
      SQL
    end

    # ClickHouse reports some failures as a 200 whose body begins with a code,
    # so the status check alone is not enough to tell success from failure.
    def execute(sql)
      uri = ::URI.parse(@endpoint)
      response = post(uri, sql)
      unless response.is_a?(::Net::HTTPSuccess)
        raise QueryError, "ranking query failed (HTTP #{response.code}): #{response.body.to_s[0, 300]}"
      end
      body = response.body.to_s
      raise QueryError, "ranking query failed: #{body[0, 300]}" if body.start_with?("Code: ")
      body
    end

    def post(uri, sql)
      http = ::Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.read_timeout = @timeout
      http.open_timeout = 30
      request = ::Net::HTTP::Post.new(uri)
      request.body = sql
      http.request(request)
    rescue ::StandardError => e
      raise QueryError, "ranking query could not be sent: #{e.class}: #{e.message}"
    end
  end
end
