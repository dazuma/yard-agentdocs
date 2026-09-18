# frozen_string_literal: true

require "helper"
require "yaml"
require "corpus/config"

# Checks the committed corpus files against each other. This is the only test
# that reads `.toys/.data`, and it is deliberately offline: it catches the
# realistic failure, which is someone editing `corpus-config.yml` and not
# regenerating the manifest, without depending on either remote service.
#
# It does not check that the manifest is *current* — that would need the
# network and would fail every time a gem released, which is the opposite of
# what a committed manifest is for.
describe "corpus files" do
  def data_dir
    ::File.expand_path("../.toys/.data", __dir__)
  end

  def config
    @config ||= ::Corpus::Config.load_file(::File.join(data_dir, "corpus-config.yml"))
  end

  def manifest
    @manifest ||= ::YAML.safe_load_file(::File.join(data_dir, "corpus-manifest.yml"))
  end

  def entries
    manifest["gems"]
  end

  def names
    entries.map { |entry| entry["name"] }
  end

  describe "the config" do
    it "loads, which is what enforces its shape" do
      assert_kind_of ::Corpus::Config, config
    end

    it "has at least one pin, since the known edge cases are why pins exist" do
      refute_empty config.pins
    end
  end

  describe "the manifest" do
    it "has the header fields" do
      assert_match(/\A\d{4}-\d{2}-\d{2}\z/, manifest["generated_at"])
      assert_kind_of ::Integer, manifest["window_days"]
      refute_empty manifest["strategies"]
    end

    it "agrees with its own count" do
      assert_equal manifest["count"], entries.size
    end

    it "names every gem exactly once" do
      assert_empty(names.tally.select { |_name, n| n > 1 })
    end

    it "is sorted alphabetically" do
      assert_equal names.sort, names
    end

    it "gives every gem a name and a version" do
      entries.each do |entry|
        refute_empty entry["name"].to_s
        refute_empty entry["version"].to_s, "#{entry['name']} has no version"
      end
    end
  end

  describe "the manifest against the config" do
    it "includes every pinned gem, marked as pinned" do
      config.pins.each do |name|
        entry = entries.find { |candidate| candidate["name"] == name }
        refute_nil entry, "pinned gem #{name} is missing; regenerate with `toys corpus manifest`"
        assert_equal true, entry["pinned"], "#{name} is pinned in the config but not in the manifest"
      end
    end

    it "marks nothing as pinned that the config does not pin" do
      marked = entries.select { |entry| entry["pinned"] }.map { |entry| entry["name"] }
      assert_equal config.pins.sort, marked.sort
    end

    it "includes no excluded gem" do
      config.excludes.each do |name|
        refute_includes names, name, "#{name} is excluded in the config but present in the manifest"
      end
    end

    it "keeps every family within its cap" do
      # Pins are exempt from caps by design, so they are not counted here.
      ranked = entries.reject { |entry| entry["pinned"] }.map { |entry| entry["name"] }
      config.families.each do |family|
        matched = ranked.count { |name| family.matches?(name) }
        assert_operator matched, :<=, family.cap,
                        "family #{family.name} has #{matched} gems but a cap of #{family.cap}"
      end
    end
  end
end
