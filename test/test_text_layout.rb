# frozen_string_literal: true

require "helper"

describe ::YARD::AgentDocs::TextLayout do
  let(:holder_class) do
    Class.new do
      include ::YARD::AgentDocs::TextLayout
      include ::YARD::AgentDocs::CrossReferencing
      include ::YARD::AgentDocs::Markdownify

      attr_accessor :options, :object
    end
  end

  let(:holder) do
    holder_class.new.tap { |h| h.options = ::Struct.new(:markup).new(:markdown) }
  end

  describe "#indent_continuation" do
    it "passes a single-line input through unchanged" do
      assert_equal("one line", holder.indent_continuation("one line"))
    end

    it "indents every line after the first by 2 spaces" do
      assert_equal("first\n  second\n  third", holder.indent_continuation("first\nsecond\nthird"))
    end

    it "leaves blank lines unindented" do
      assert_equal("first\n\n  third", holder.indent_continuation("first\n\nthird"))
    end

    it "honors the width: keyword" do
      assert_equal("first\n    second", holder.indent_continuation("first\nsecond", width: 4))
    end
  end

  describe "#summary_suffix" do
    it "is empty for blank text" do
      assert_equal("", holder.summary_suffix(""))
    end

    it "is empty for nil text" do
      assert_equal("", holder.summary_suffix(nil))
    end

    it "prefixes non-empty text with ' — ', markdownified" do
      assert_equal(" — some `Foo` text", holder.summary_suffix("some `Foo` text"))
    end
  end

  describe "#dash_join" do
    it "joins a present prefix and text with ' — '" do
      assert_equal("String — some text", holder.dash_join("String", "some text"))
    end

    it "is just the text when the prefix is blank" do
      assert_equal("some text", holder.dash_join("", "some text"))
    end

    it "is just the prefix when the text is blank" do
      assert_equal("String", holder.dash_join("String", ""))
    end

    it "is empty when both are blank" do
      assert_equal("", holder.dash_join("", ""))
    end
  end
end
