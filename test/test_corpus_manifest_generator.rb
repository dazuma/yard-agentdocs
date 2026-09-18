# frozen_string_literal: true

require "helper"
require "corpus/config"
require "corpus/manifest_generator"

# Returns the ranked names it was built with, ignoring the window, and
# truncating to the requested limit exactly as a real query's LIMIT would.
#
# The doubles live at the top level rather than inside the `describe` block,
# since a class defined in a block reads as an accident and RuboCop says so.
class CorpusFakeRanker
  def initialize(lists)
    @lists = lists
    @requests = []
  end

  attr_reader :requests

  def rank(strategy, limit:, window_days:)
    @requests << {strategy: strategy, limit: limit, window_days: window_days}
    @lists.fetch(strategy).first(limit)
  end
end

# Resolves every name to a version derived from the name, except those listed
# as missing, which stand in for a gem with no current release.
class CorpusFakeResolver
  def initialize(missing: [])
    @missing = missing
    @calls = []
  end

  attr_reader :calls

  def resolve(name)
    @calls << name
    return nil if @missing.include?(name)
    "1.#{name.length}.0"
  end
end

describe ::Corpus::ManifestGenerator do
  def config(pins: [], exclude: [], families: [])
    ::Corpus::Config.new(
      {
        "pins" => pins.map { |n| {"name" => n, "reason" => "because"} },
        "exclude" => exclude.map { |n| {"name" => n, "reason" => "because"} },
        "families" => families,
      }
    )
  end

  def generate(ranker:, count:, resolver: CorpusFakeResolver.new, strategies: ["a", "b"], **kwargs)
    ::Corpus::ManifestGenerator.new(
      config: kwargs[:config] || config, ranker: ranker, resolver: resolver,
      count: count, strategies: strategies, window_days: 90,
      today: ::Date.new(2026, 9, 18)
    ).generate
  end

  def names(manifest)
    manifest["gems"].map { |entry| entry["name"] }
  end

  describe "interleaving" do
    it "alternates between strategies by rank" do
      ranker = CorpusFakeRanker.new("a" => ["a1", "a2", "a3"], "b" => ["b1", "b2", "b3"])
      manifest = generate(ranker: ranker, count: 4)
      # Selection order is a1, b1, a2, b2; the file is alphabetical.
      assert_equal ["a1", "a2", "b1", "b2"], names(manifest)
    end

    it "does not select the same gem twice when both strategies rank it" do
      ranker = CorpusFakeRanker.new("a" => ["shared", "a2"], "b" => ["shared", "b2"])
      manifest = generate(ranker: ranker, count: 3)
      assert_equal ["a2", "b2", "shared"], names(manifest)
    end

    it "records the rank under every strategy that ranked the gem" do
      ranker = CorpusFakeRanker.new("a" => ["x", "shared"], "b" => ["shared", "y"])
      manifest = generate(ranker: ranker, count: 3)
      shared = manifest["gems"].find { |entry| entry["name"] == "shared" }
      assert_equal({"a" => 2, "b" => 1}, shared["ranks"])
    end

    it "falls back to one strategy when the other is exhausted" do
      ranker = CorpusFakeRanker.new("a" => ["a1", "a2", "a3", "a4"], "b" => ["b1"])
      manifest = generate(ranker: ranker, count: 4)
      assert_equal ["a1", "a2", "a3", "b1"], names(manifest)
    end

    it "overfetches by the documented factor" do
      ranker = CorpusFakeRanker.new("a" => ["a1"], "b" => ["b1"])
      generate(ranker: ranker, count: 2)
      assert_equal([8, 8], ranker.requests.map { |r| r[:limit] })
      assert_equal([90, 90], ranker.requests.map { |r| r[:window_days] })
    end
  end

  describe "family caps" do
    def aws_family(cap)
      [{"name" => "aws", "match" => "^aws-", "cap" => cap, "reason" => "because"}]
    end

    it "stops taking from a family once its cap is reached" do
      ranker = CorpusFakeRanker.new(
        "a" => ["aws-1", "aws-2", "aws-3", "aws-4", "other"], "b" => []
      )
      manifest = generate(ranker: ranker, count: 3, config: config(families: aws_family(2)))
      assert_equal ["aws-1", "aws-2", "other"], names(manifest)
    end

    it "counts a family across both strategies" do
      ranker = CorpusFakeRanker.new("a" => ["aws-1", "other1"], "b" => ["aws-2", "aws-3", "other2"])
      manifest = generate(ranker: ranker, count: 4, config: config(families: aws_family(2)))
      assert_equal ["aws-1", "aws-2", "other1", "other2"], names(manifest)
    end

    it "exempts pinned gems from the cap and does not let them consume it" do
      ranker = CorpusFakeRanker.new("a" => ["aws-1", "aws-2", "aws-3"], "b" => [])
      manifest = generate(
        ranker: ranker, count: 3,
        config: config(pins: ["aws-pinned"], families: aws_family(2))
      )
      assert_equal ["aws-1", "aws-2", "aws-pinned"], names(manifest)
    end
  end

  describe "pins and exclusions" do
    it "always includes a pinned gem and marks it" do
      ranker = CorpusFakeRanker.new("a" => ["a1"], "b" => ["b1"])
      manifest = generate(ranker: ranker, count: 3, config: config(pins: ["pinned"]))
      assert_equal ["a1", "b1", "pinned"], names(manifest)
      pinned = manifest["gems"].find { |entry| entry["name"] == "pinned" }
      assert_equal true, pinned["pinned"]
      refute pinned.key?("ranks")
    end

    it "marks a pinned gem that also ranks, and keeps its ranks" do
      ranker = CorpusFakeRanker.new("a" => ["pinned", "a2"], "b" => [])
      manifest = generate(ranker: ranker, count: 2, config: config(pins: ["pinned"]))
      pinned = manifest["gems"].find { |entry| entry["name"] == "pinned" }
      assert_equal true, pinned["pinned"]
      assert_equal({"a" => 1}, pinned["ranks"])
      assert_equal ["a2", "pinned"], names(manifest)
    end

    it "pins count against the requested total" do
      ranker = CorpusFakeRanker.new("a" => ["a1", "a2", "a3"], "b" => [])
      manifest = generate(ranker: ranker, count: 2, config: config(pins: ["pinned"]))
      assert_equal 2, manifest["gems"].size
      assert_equal ["a1", "pinned"], names(manifest)
    end

    it "never selects an excluded gem" do
      ranker = CorpusFakeRanker.new("a" => ["bad", "a2"], "b" => ["bad", "b2"])
      manifest = generate(ranker: ranker, count: 2, config: config(exclude: ["bad"]))
      assert_equal ["a2", "b2"], names(manifest)
    end

    it "fails when a pinned gem has no current release" do
      ranker = CorpusFakeRanker.new("a" => ["a1"], "b" => [])
      error = assert_raises(::Corpus::ManifestGenerator::GenerationError) do
        generate(ranker: ranker, count: 2, resolver: CorpusFakeResolver.new(missing: ["pinned"]),
                 config: config(pins: ["pinned"]))
      end
      assert_match(/pinned gem "pinned" has no current release/, error.message)
    end

    it "fails when more gems are pinned than are wanted" do
      ranker = CorpusFakeRanker.new("a" => [], "b" => [])
      error = assert_raises(::Corpus::ManifestGenerator::GenerationError) do
        generate(ranker: ranker, count: 1, config: config(pins: ["p1", "p2"]))
      end
      assert_match(/2 gems are pinned but only 1 are wanted/, error.message)
    end
  end

  describe "version resolution" do
    it "skips a ranked gem with no current release and takes the next" do
      ranker = CorpusFakeRanker.new("a" => ["gone", "a2"], "b" => [])
      manifest = generate(ranker: ranker, count: 1, resolver: CorpusFakeResolver.new(missing: ["gone"]))
      assert_equal ["a2"], names(manifest)
    end

    it "asks about an unresolvable gem only once across both strategies" do
      resolver = CorpusFakeResolver.new(missing: ["gone"])
      ranker = CorpusFakeRanker.new("a" => ["gone", "a2"], "b" => ["gone", "b2"])
      generate(ranker: ranker, count: 2, resolver: resolver)
      assert_equal 1, resolver.calls.count("gone")
    end

    it "records the resolved version" do
      ranker = CorpusFakeRanker.new("a" => ["abc"], "b" => [])
      manifest = generate(ranker: ranker, count: 1)
      assert_equal "1.3.0", manifest["gems"].first["version"]
    end
  end

  describe "manifest shape" do
    it "carries the header fields" do
      ranker = CorpusFakeRanker.new("a" => ["a1"], "b" => ["b1"])
      manifest = generate(ranker: ranker, count: 2)
      assert_equal "2026-09-18", manifest["generated_at"]
      assert_equal 90, manifest["window_days"]
      assert_equal ["a", "b"], manifest["strategies"]
      assert_equal 2, manifest["count"]
    end

    it "sorts entries alphabetically rather than by selection order" do
      ranker = CorpusFakeRanker.new("a" => ["zeta", "alpha"], "b" => ["mid"])
      manifest = generate(ranker: ranker, count: 3)
      assert_equal ["alpha", "mid", "zeta"], names(manifest)
    end

    it "fails rather than writing a short corpus when the rankings run out" do
      ranker = CorpusFakeRanker.new("a" => ["a1"], "b" => ["b1"])
      error = assert_raises(::Corpus::ManifestGenerator::GenerationError) do
        generate(ranker: ranker, count: 5)
      end
      assert_match(/only 2 of 5 gems could be selected/, error.message)
    end

    it "serializes with a do-not-edit banner and parses back" do
      ranker = CorpusFakeRanker.new("a" => ["a1"], "b" => [])
      generator = ::Corpus::ManifestGenerator.new(
        config: config, ranker: ranker, resolver: CorpusFakeResolver.new, count: 1,
        strategies: ["a"], window_days: 90, today: ::Date.new(2026, 9, 18)
      )
      text = generator.serialize(generator.generate)
      assert_match(/\A# Generated by `toys corpus manifest`\. Do not edit\./, text)
      assert_equal ["a1"], names(::YAML.safe_load(text))
    end
  end
end
