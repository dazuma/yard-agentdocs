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

    # The block constructs `::RDoc::Markup` gives no meaning to, which it
    # therefore joins into one paragraph — see "Block constructs RDoc
    # doesn't parse: segment out and pass through" under "Decisions" in
    # docs/dev/DESIGN.md, and issue #8.
    describe "a block construct RDoc's own markup doesn't parse" do
      it "passes a fenced code block through verbatim, still converting the prose around it" do
        assert_equal(
          "Prose.\n\n```ruby\nx = 1\ny = 2\n```\n\nAfter `code`.",
          holder.markdownify("Prose.\n\n```ruby\nx = 1\ny = 2\n```\n\nAfter +code+.")
        )
      end

      it "passes a tilde-delimited fence through as well" do
        assert_equal("~~~\nx = 1\n~~~", holder.markdownify("~~~\nx = 1\n~~~"))
      end

      it "runs an unclosed fence to the end of the text rather than closing it" do
        assert_equal("Prose.\n\n```ruby\nx = 1", holder.markdownify("Prose.\n\n```ruby\nx = 1"))
      end

      it "leaves a heading-shaped line inside a fence undemoted" do
        source = "```ruby\n## a Ruby comment, not a heading\n```"
        assert_equal(source, holder.markdownify(source))
      end

      it "leaves an inline cross-reference inside a fence unresolved" do
        holder = holder_with_object(:rdoc, <<~RUBY, "Widget")
          class Widget; end

          class Other
            def m; end
          end
        RUBY
        source = "```ruby\n{Other#m}\n```"
        assert_equal(source, holder.markdownify(source))
      end

      it "passes a GFM table through verbatim" do
        assert_equal(
          "| a | b |\n|---|---|\n| 1 | 2 |\n\nAfter.",
          holder.markdownify("| a | b |\n|---|---|\n| 1 | 2 |\n\nAfter.")
        )
      end

      it "leaves pipe-bearing lines with no delimiter row under them to RDoc" do
        assert_equal("| a | b | | 1 | 2 |", holder.markdownify("| a | b |\n| 1 | 2 |"))
      end

      it "passes a Markdown blockquote through verbatim" do
        assert_equal("> one\n> two", holder.markdownify("> one\n> two"))
      end

      it "still converts RDoc's own `>>>` blockquote, which is not Markdown's marker" do
        assert_equal("> RDoc quotes this.", holder.markdownify(">>>\n  RDoc quotes this."))
      end

      it "leaves a prose line opening with an operator alone" do
        assert_equal(">= 0 : when the index is known", holder.markdownify(">= 0 : when the index is known"))
      end

      it "treats a line opening with an inline code span as prose, not as a fence" do
        assert_equal("```x``` is inline.", holder.markdownify("```x``` is inline."))
      end

      # Column 0, not CommonMark's three-space tolerance: an indented
      # line opens an RDoc verbatim block, which already survives
      # conversion (re-indented to four columns), so there is nothing to
      # rescue and a real block to avoid tearing apart.
      it "recognizes a block only at column 0, leaving an indented fence to RDoc's verbatim handling" do
        assert_equal(
          "Example:\n\n    ```ruby\n    x = 1\n    ```",
          holder.markdownify("Example:\n\n  ```ruby\n  x = 1\n  ```")
        )
      end

      # The cost of verbatim passthrough: a protected block's content is
      # never RDoc, even when the docstring around it is.
      it "does not convert RDoc inline markup inside a protected block" do
        source = "| a | b |\n|---|---|\n| +raw+ | *raw* |"
        assert_equal(source, holder.markdownify(source))
      end
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

  # The per-file dialect an extra file carries — see `serialize_extra_file`
  # in `fulldoc/agentdocs/setup.rb`, the only caller that passes `markup:`.
  describe "an explicit markup: override" do
    # A fenced block is the sharpest probe: under `:rdoc` its three lines
    # are ordinary prose, so RDoc joins them into one.
    let(:fenced) { "Prose.\n\n```ruby\nx = 1\n```" }

    it "wins over options.markup" do
      assert_equal(fenced, holder_for(:rdoc).markdownify(fenced, markup: :markdown))
    end

    it "still converts when the override names the dialect options.markup already names" do
      assert_equal("This has `code` in it.", holder_for(:markdown).markdownify("This has +code+ in it.", markup: :rdoc))
    end

    it "accepts a String, the form YARD records a #!markdown shebang as" do
      assert_equal(fenced, holder_for(:rdoc).markdownify(fenced, markup: "markdown"))
    end

    it "logs an error and passes through for a dialect this template doesn't support" do
      # What a `.txt` extra file resolves to: YARD maps the extension to
      # `:text`, which has no Markdown conversion here.
      logger = ::YARD::Logger.instance
      original_io = logger.io
      captured = ::StringIO.new
      logger.io = captured
      begin
        result = holder_for(:rdoc).markdownify("Plain +text+, unconverted.", markup: :text)
      ensure
        logger.io = original_io
      end

      assert_equal("Plain +text+, unconverted.", result)
      assert_match(/unsupported markup type `:text`/, captured.string)
    end
  end
end
