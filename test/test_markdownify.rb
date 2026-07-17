# frozen_string_literal: true

require "helper"
require "stringio"

describe ::YARD::AgentDocs::Markdownify do
  # No source parsed, no object set: fine for any test whose input has no
  # (unescaped) `{...}` for #resolve_references — markdownify's final step
  # — to stumble over.
  def holder_for(markup)
    agentdocs_holder(::YARD::AgentDocs::CrossReferencing, ::YARD::AgentDocs::Markdownify, markup: markup)
  end

  # Parses +source+ into a fresh registry and returns a holder whose
  # +object+ is +current_path+, for tests that exercise inline
  # cross-reference resolution end to end.
  def holder_with_object(markup, source, current_path)
    agentdocs_holder(
      ::YARD::AgentDocs::CrossReferencing, ::YARD::AgentDocs::Markdownify,
      source: source, at: current_path, markup: markup
    )
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

    it "demotes a level-1/2/3 heading to #### to avoid colliding with structural headings" do
      assert_equal("#### One", holder.markdownify("# One"))
      assert_equal("#### Two", holder.markdownify("## Two"))
      assert_equal("#### Three", holder.markdownify("### Three"))
    end

    it "leaves a heading already at level 4+ unchanged" do
      assert_equal("#### Four", holder.markdownify("#### Four"))
      assert_equal("##### Five", holder.markdownify("##### Five"))
    end

    it "leaves a heading-shaped line inside a fenced code block unchanged" do
      source = "```ruby\n# a comment, not a heading\nputs 1\n```"
      assert_equal(source, holder.markdownify(source))
    end

    it "leaves an indented heading-shaped line unchanged (not column-0, so not a grep collision)" do
      assert_equal("Intro.\n\n  ## Indented", holder.markdownify("Intro.\n\n  ## Indented"))
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

    it "converts a top-level = heading to an ATX heading, demoted to ####" do
      assert_equal("#### Heading", holder.markdownify("= Heading"))
    end

    it "leaves an unresolvable bare {Foo#bar} inline reference untouched" do
      assert_equal("See {Foo#bar} for details.", holder.markdownify("See {Foo#bar} for details."))
    end

    it "resolves a bare inline reference once RDoc conversion has run" do
      holder = holder_with_object(:rdoc, <<~RUBY, "Widget")
        class Widget; end

        class Other
          def m; end
        end
      RUBY
      assert_equal("See [`Other#m`](Other.md) for details.", holder.markdownify("See {Other#m} for details."))
    end
  end

  describe "an unsupported markup type" do
    let(:holder) { holder_for(:textile) }

    it "logs an error and passes the raw text through unconverted" do
      logger = ::YARD::Logger.instance
      original_io = logger.io
      captured = ::StringIO.new
      logger.io = captured
      begin
        result = holder.markdownify("Some *textile* text.")
      ensure
        logger.io = original_io
      end

      assert_equal("Some *textile* text.", result)
      assert_match(/unsupported markup type `:textile`/, captured.string)
    end
  end
end
