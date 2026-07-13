# frozen_string_literal: true

require "helper"

describe ::YARD::AgentDocs::Markdownify do
  let(:holder_class) do
    Class.new do
      include ::YARD::AgentDocs::Markdownify

      attr_accessor :options
    end
  end

  def holder_for(markup)
    holder_class.new.tap { |h| h.options = ::Struct.new(:markup).new(markup) }
  end

  describe ":markdown dialect" do
    let(:holder) { holder_for(:markdown) }

    it "passes prose through unchanged, aside from stripping surrounding whitespace" do
      assert_equal("This is *already* Markdown.", holder.markdownify("  This is *already* Markdown.  \n"))
    end

    it "accepts a non-String (e.g. a Docstring) via #to_s" do
      assert_equal("some text", holder.markdownify(::YARD::Docstring.new("some text")))
    end

    it "returns an empty string for nil" do
      assert_equal("", holder.markdownify(nil))
    end
  end

  describe ":rdoc dialect" do
    let(:holder) { holder_for(:rdoc) }

    it "converts +teletype+ to a backtick code span" do
      assert_equal("This has `code` in it.", holder.markdownify("This has +code+ in it."))
    end

    it "converts *bold* to Markdown bold" do
      assert_equal("This is **bold** text.", holder.markdownify("This is *bold* text."))
    end

    it "converts an RDoc link to a Markdown link" do
      assert_equal(
        "See the [docs](https://example.com/docs).",
        holder.markdownify("See the {docs}[https://example.com/docs].")
      )
    end

    it "converts a top-level = heading to an ATX heading" do
      assert_equal("# Heading", holder.markdownify("= Heading"))
    end

    it "leaves a bare {Foo#bar} inline reference untouched, for later resolution" do
      assert_equal("See {Foo#bar} for details.", holder.markdownify("See {Foo#bar} for details."))
    end
  end

  describe "an unsupported markup type" do
    let(:holder) { holder_for(:textile) }

    it "logs an error and passes the raw text through unconverted" do
      assert_equal("Some *textile* text.", holder.markdownify("Some *textile* text."))
    end
  end
end
