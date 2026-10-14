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

    describe "a paragraph or list item longer than 78 columns" do
      let(:words) { ::Array.new(20) { |i| "word#{i}" } }

      it "is emitted on one line, joining its source lines" do
        source = "#{words[0, 10].join(' ')}\n#{words[10, 10].join(' ')}"
        assert_equal(words.join(" "), holder.markdownify(source))
      end

      it "is emitted on one line as a list item" do
        source = "* #{words[0, 10].join(' ')}\n  #{words[10, 10].join(' ')}\n* short"
        assert_equal("*   #{words.join(' ')}\n*   short", holder.markdownify(source))
      end
    end

    describe "a label-list item" do
      it "renders as a bullet with a bold label by default" do
        assert_equal("-   **Label:** text", holder.markdownify("[Label] text"))
      end

      it "renders consecutive items as one tight list" do
        assert_equal("-   **a:** one
-   **b:** two", holder.markdownify("a:: one
b:: two"))
      end

      it "separates the list from following prose by one blank line" do
        assert_equal("-   **Label:** text

More prose.", holder.markdownify("[Label] text

More prose."))
      end

      it "joins several labels on one item" do
        assert_equal("-   **a**, **b:** text", holder.markdownify("[a]
[b] text"))
      end

      it "does not add a second colon to a label ending in one" do
        assert_equal("-   **NOTE:** text", holder.markdownify("[NOTE:] text"))
      end

      it "renders a nested item as a sub-list, keeping the outer label" do
        assert_equal("-   **Author:**
    -   **Jane Copyright:** 2026",
                     holder.markdownify("Author:: Jane Copyright:: 2026"))
      end

      it "renders a label with no text without a colon, ahead of a following list" do
        assert_equal("-   **Label**

*   a
*   b", holder.markdownify("[Label]
* a
* b"))
      end

      it "renders a bracketed label inline in single-line mode" do
        assert_equal("Label: text", holder.markdownify("[Label] text", single_line: true))
      end

      it "renders a double-colon label inline in single-line mode" do
        assert_equal("Label: text", holder.markdownify("Label:: text", single_line: true))
      end

      it "keeps every label of a nested item in single-line mode" do
        assert_equal("Author: Jane Copyright: 2026",
                     holder.markdownify("Author:: Jane Copyright:: 2026", single_line: true))
      end

      it "converts inline markup in the label in single-line mode" do
        assert_equal("`code`: text", holder.markdownify("[+code+] text", single_line: true))
      end

      it "does not add a second colon to a label ending in one in single-line mode" do
        assert_equal("NOTE: text", holder.markdownify("[NOTE:] text", single_line: true))
      end

      it "renders a label with no text in single-line mode" do
        assert_equal("Label:", holder.markdownify("[Label]", single_line: true))
      end
    end

    describe "a <br> hard break" do
      it "renders as a Markdown hard line break by default" do
        assert_equal("one  \n two", holder.markdownify("one<br>\ntwo"))
      end

      it "renders as one space in single-line mode, absorbing the joined line break" do
        assert_equal("one two", holder.markdownify("one<br>\ntwo", single_line: true))
      end

      it "renders as one space in single-line mode before styled text" do
        assert_equal("one `two` three", holder.markdownify("one<br>+two+ three", single_line: true))
      end
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
    # therefore joins into one paragraph. See issue #8.
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

  # Every caller screens these out first, so reaching one is a bug.
  describe "an unsupported markup type" do
    it "raises" do
      error = assert_raises(::ArgumentError) { holder_for(:textile).markdownify("Some *textile* text.") }
      assert_match(/cannot convert markup type `:textile`/, error.message)
    end
  end

  # The dialects YARD renders with no provider. Each is the Markdown
  # counterpart of YARD's own `html_markup_*` helper for it: a fence where
  # YARD shows the author's characters as written, verbatim where YARD
  # passes HTML through. Inline, where a fence can't sit, each collapses
  # onto one line instead.
  describe "a provider-less dialect" do
    it "fences :text, :pre, and :none as text" do
      [:text, :pre, :none].each do |markup|
        result = holder_for(markup).markdownify("One line\nand *another*.\n")
        assert_equal("```text\nOne line\nand *another*.\n```", result, markup.inspect)
      end
    end

    it "fences :ruby as Ruby" do
      assert_equal("```ruby\nputs 1\n```", holder_for(:ruby).markdownify("puts 1"))
    end

    it "lengthens the fence past the longest backtick run inside" do
      source = "Before\n```ruby\nx\n```"
      assert_equal("````text\n#{source}\n````", holder_for(:text).markdownify(source))
    end

    it "strips surrounding blank lines, inside the fence" do
      assert_equal("```text\n  indented\n```", holder_for(:text).markdownify("\n\n  indented\n\n"))
    end

    it "leaves a fenced heading-shaped line and reference literal" do
      assert_equal("```text\n# Not a heading {Other}\n```", holder_for(:text).markdownify("# Not a heading {Other}"))
    end

    it "returns an empty string for blank or nil text, rather than an empty fence" do
      assert_equal("", holder_for(:text).markdownify("  \n"))
      assert_equal("", holder_for(:ruby).markdownify(nil))
    end

    it "passes :html through verbatim" do
      source = "<p>Some <em>HTML</em>.</p>\n\n<pre>\nx = 1\n</pre>"
      assert_equal(source, holder_for(:html).markdownify(source))
    end

    it "still demotes a colliding heading in :html" do
      assert_equal("<p>Intro.</p>\n\n#### Heading", holder_for(:html).markdownify("<p>Intro.</p>\n\n# Heading"))
    end

    it "still resolves a reference in :html" do
      holder = holder_with_object(:html, <<~RUBY, "Widget")
        class Widget; end

        class Other
          def m; end
        end
      RUBY
      assert_equal("<p>See [`Other#m`](Other.md).</p>", holder.markdownify("<p>See {Other#m}.</p>"))
    end

    it "logs nothing" do
      logger = ::YARD::Logger.instance
      original_io = logger.io
      captured = ::StringIO.new
      logger.io = captured
      begin
        [:text, :pre, :none, :html, :ruby].each { |markup| holder_for(markup).markdownify("Some text.") }
      ensure
        logger.io = original_io
      end
      assert_empty(captured.string)
    end

    describe "inline" do
      it "collapses every whitespace run onto one line, and otherwise passes through" do
        [:text, :pre, :none, :html, :ruby].each do |markup|
          result = holder_for(markup).markdownify("  One *line*\n  and\tanother.\n", inline: true)
          assert_equal("One *line* and another.", result, markup.inspect)
        end
      end

      it "is implied by single_line:" do
        result = holder_for(:text).markdownify("One line\nand another.", single_line: true)
        assert_equal("One line and another.", result)
      end

      it "still resolves a reference" do
        holder = holder_with_object(:text, <<~RUBY, "Widget")
          class Widget; end

          class Other
            def m; end
          end
        RUBY
        assert_equal("See [`Other#m`](Other.md).", holder.markdownify("See\n{Other#m}.", inline: true))
      end

      it "leaves :markdown and :rdoc unaffected" do
        assert_equal("Two\nlines.", holder_for(:markdown).markdownify("Two\nlines.", inline: true))
      end
    end
  end

  describe ".provider_less?" do
    it "is true of every dialect YARD renders without a provider" do
      [:text, :pre, :none, :html, :ruby].each do |markup|
        assert(::YARD::AgentDocs::Markdownify.provider_less?(markup), markup.inspect)
      end
    end

    it "is false of a dialect YARD needs a provider for, or doesn't know" do
      [:markdown, :rdoc, :textile, :no_such_markup].each do |markup|
        refute(::YARD::AgentDocs::Markdownify.provider_less?(markup), markup.inspect)
      end
    end
  end

  describe ".unsupported?" do
    it "is false of a converted or provider-less dialect" do
      [:markdown, :rdoc, :text, "markdown"].each do |markup|
        refute(::YARD::AgentDocs::Markdownify.unsupported?(markup), markup.inspect)
      end
    end

    it "is true of a provider-backed dialect or an unknown one" do
      [:textile, :textile_strict, :org, :asciidoc, "markdwon"].each do |markup|
        assert(::YARD::AgentDocs::Markdownify.unsupported?(markup), markup.inspect)
      end
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

    it "converts a provider-less dialect, the form a `.txt` extra file resolves to" do
      result = holder_for(:rdoc).markdownify("Plain +text+, unconverted.", markup: :text)
      assert_equal("```text\nPlain +text+, unconverted.\n```", result)
    end
  end
end
