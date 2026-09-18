# frozen_string_literal: true

desc "Regenerate the durable test-corpus manifest"

long_desc \
  "Chooses which gems, at which exact versions, make up the corpus that" \
    " structural-invariant checks run against, and writes the result to" \
    " `.toys/.data/corpus-manifest.yml`.",
  "",
  "This is a repo-internal development tool. It is not part of the" \
    " `yard-agentdocs` gem and is not run by `toys ci`.",
  "",
  "## Why there is a manifest at all",
  "",
  "Rankings move every day, and the service that serves them is a free" \
    " third-party endpoint with no availability guarantee. A check that" \
    " re-derived its own gem list would never run against the same corpus" \
    " twice, and would stop working the day that service did. So selection" \
    " happens here, rarely and deliberately, and its output is committed.",
  "",
  "## How gems are chosen",
  "",
  "Two rankings are consulted. `downloads` totals downloads over a trailing" \
    " window; `dependents` counts how many gems declare a runtime dependency" \
    " on each, over current releases only. They measure different things:" \
    " download counts are dominated by transitive pulls, so a library many" \
    " gems depend on directly can rank far lower there than its actual reach" \
    " suggests.",
  "",
  "Candidates are taken round-robin by rank rather than by unioning each" \
    " ranking's top slice, so `--count` means the number of gems you get" \
    " rather than a number multiplied by an overlap fraction nobody controls." \
    " Each selected gem records its rank under every ranking that placed it," \
    " not only the one that drew it.",
  "",
  "Pins, exclusions and family caps come from `.toys/.data/corpus-config.yml`" \
    " and are merged in on every run. That file is the only place a human" \
    " decision survives: the manifest is regenerated in full and holds" \
    " nothing worth preserving.",
  "",
  "## What it talks to",
  "",
  "Rankings come from the public ClickHouse dataset behind ClickGems, which" \
    " rubygems.org links from its own stats page. Versions come from" \
    " rubygems.org, one request per selected gem — the ClickHouse mirror of" \
    " the version table has duplicated rows and a stale `latest` flag, so it" \
    " answers this question wrongly and silently.",
  "",
  "A run takes a couple of minutes, almost all of it version lookups. Any" \
    " failure aborts without writing, so a half-finished run cannot leave" \
    " behind a manifest that merely looks like a smaller corpus.",
  "",
  "## Exit codes",
  "",
  ["    0    the manifest was written, or printed with --dry-run"],
  ["    1    generation failed and nothing was written"]

flag :count, "--count N",
     accept: ::Integer,
     default: 250,
     desc: "How many gems the corpus should contain (defaults to 250)",
     long_desc:
       "How many gems the manifest should name. Build time is what limits" \
         " this corpus, so this is the number that matters: below roughly" \
         " 150 the family caps bite hard enough that little but stdlib and" \
         " Rails survives, and past 300 the download curve is flat enough" \
         " that rank stops meaning much."

flag :strategy, "--strategy NAME",
     accept: ["downloads", "dependents"],
     handler: :push,
     default: [],
     desc: "Ranking to use; repeatable, defaults to all of them",
     long_desc:
       "Use this ranking. May be given more than once, and the order given" \
         " is the order they are interleaved in. With no `--strategy` at" \
         " all, every ranking is used."

flag :window, "--window DAYS",
     accept: ::Integer,
     default: 90,
     desc: "Trailing window for the downloads ranking (defaults to 90)",
     long_desc:
       "The trailing window, in days, that the `downloads` ranking totals" \
         " over. Has no effect on `dependents`, which reads the current" \
         " dependency graph and has no time dimension to window."

flag :dry_run, "--[no-]dry-run",
     default: false,
     desc: "Print the manifest instead of writing it",
     long_desc:
       "Write the manifest to standard output and leave the file on disk" \
         " untouched. Everything else about the run is the same, including" \
         " the queries and the version lookups."

# Required here rather than at the top of the file so that the corpus tools'
# dependencies are loaded only when one of them actually runs.
def run
  require "corpus/config"
  require "corpus/clickhouse_ranker"
  require "corpus/manifest_generator"
  require "corpus/rubygems_resolver"
  generator = build_generator
  dry_run ? print(generator.serialize(generator.generate)) : write_manifest(generator)
rescue ::Corpus::Config::ConfigError,
       ::Corpus::ManifestGenerator::GenerationError,
       ::Corpus::ClickHouseRanker::QueryError,
       ::Corpus::RubygemsResolver::ResolveError => e
  $stderr.puts("ERROR: #{e.message}")
  exit(1)
end

# Builds the generator from the config file and the flags.
def build_generator
  ::Corpus::ManifestGenerator.new(
    config: ::Corpus::Config.load_file(data_file("corpus-config.yml")),
    ranker: ::Corpus::ClickHouseRanker.new,
    resolver: ::Corpus::RubygemsResolver.new,
    count: count,
    strategies: strategy.empty? ? ::Corpus::ClickHouseRanker::STRATEGIES : strategy,
    window_days: window
  )
end

# Writes the manifest and reports what landed.
def write_manifest(generator)
  path = data_file("corpus-manifest.yml")
  data = generator.write(path)
  pinned = data["gems"].count { |entry| entry["pinned"] }
  puts "Wrote #{data['count']} gems (#{pinned} pinned) to #{path}"
end

# Locates a file in the tools' data directory. `find_data` only resolves
# files that already exist, which is why the manifest is committed as an
# empty file rather than created on first run.
def data_file(name)
  find_data(name) ||
    raise(::Corpus::Config::ConfigError, "#{name} is missing from .toys/.data")
end
