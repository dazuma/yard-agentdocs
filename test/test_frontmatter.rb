# frozen_string_literal: true

require "helper"
require "yaml"

describe ::YARD::AgentDocs::Frontmatter do
  let(:holder) { agentdocs_holder(::YARD::AgentDocs::Frontmatter) }

  describe "#yaml_quote" do
    # Round-trips +text+ through a real `key: value` YAML line via Psych,
    # rather than just asserting the quoted string looks right, since the
    # actual hazard is a value that *parses* to something other than +text+
    # (or fails to parse at all) rather than one that merely looks odd.
    def assert_round_trips(text)
      quoted = holder.yaml_quote(text)
      parsed = ::YAML.safe_load("key: #{quoted}")
      assert_equal(text, parsed["key"])
    end

    it "round-trips plain text" do
      assert_round_trips("A point in two-dimensional space.")
    end

    it "round-trips text containing backticks" do
      assert_round_trips("Utility computations on `Point` values.")
    end

    it "round-trips text containing an apostrophe" do
      assert_round_trips("Raised when a string can't be parsed as a point.")
    end

    it "round-trips text starting with a Markdown/YAML indicator character" do
      assert_round_trips("- starts with a dash")
      assert_round_trips("* starts with a star")
      assert_round_trips("`starts with a backtick`")
    end

    it "round-trips text containing a colon-space" do
      assert_round_trips("Note: this is important.")
    end

    it "round-trips text ending in a colon" do
      assert_round_trips("Ends with colon:")
    end

    it "round-trips text containing an embedded double quote and backslash" do
      assert_round_trips('Has a "quoted" word and a \\backslash.')
    end

    it "round-trips an empty string" do
      assert_round_trips("")
    end
  end
end
