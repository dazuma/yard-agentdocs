# frozen_string_literal: true

require "rdoc/markup/to_markdown"

module YARD
  module AgentDocs
    ##
    # A `::RDoc::Markup::ToMarkdown` that fixes two fidelity gaps in the
    # stdlib converter: it never falls back to raw HTML for styled inline
    # text, and it never flattens a block construct RDoc's own markup
    # gives no meaning to.
    #
    # **Inline: no raw-HTML fallback** for `<tt>`/`<code>`, `<b>`/`<i>`/
    # `<em>`, `<s>`/`<del>`, and their `+word+`/`` `word` ``/`*word*`/
    # `_word_` shorthand equivalents. The stdlib converter takes that
    # raw-HTML branch whenever the styled content has any character
    # outside plain word characters/whitespace — routine in Ruby prose
    # (`+valid?+`, `+save!+`, `+Foo::Bar+`) — leaking literal
    # `<code>...</code>`/`<strong>...</strong>` etc. into what's supposed
    # to be pure Markdown. See "`RDoc::Markup::ToMarkdown` raw-HTML leaks"
    # under "Decisions" in docs/dev/DESIGN.md for the full survey.
    #
    # Overrides {#add_tag} (the single choke point `handle_BOLD`/
    # `handle_EM`/`handle_STRIKE`/`handle_TT` funnel single-string content
    # through) and {#handle_tag} (their shared multi-node/nested-content
    # path — e.g. `<b>foo *bar* baz</b>`), so neither ever takes the
    # upstream raw-HTML branch. `<tt>`/`<code>` never reach `handle_tag`'s
    # multi-node branch in the first place: RDoc's own parser captures
    # their content as one literal string, never nested nodes, so a
    # look-alike like `<tt>foo <b>bar</b> baz</tt>` was already correct
    # before this class existed — {#add_tag} alone covers it. Recursively
    # wrapping nested content in the same Markdown delimiter (rather than
    # flattening it) is safe even when the same delimiter repeats back to
    # back (e.g. `**foo **bar** baz**`): verified against a real CommonMark
    # parser (`commonmarker`) that this parses as nested `<strong>`, not a
    # prematurely-closed span.
    #
    # **Block: fenced code blocks, GFM tables, and Markdown blockquotes
    # pass through verbatim.** `::RDoc::Markup` joins consecutive
    # unindented lines into one paragraph, and none of those three is
    # RDoc syntax, so each is otherwise flattened onto a single line. For
    # a fence that is structural damage rather than cosmetic: the stray
    # backticks left behind open a code block that never closes, so every
    # `## `/`### ` heading below reads as being inside it, breaking the
    # greppable structure this format depends on. {#convert} segments
    # those blocks out and converts only the prose runs around them. See
    # "Block constructs RDoc doesn't parse: segment out and pass through"
    # under "Decisions" in docs/dev/DESIGN.md, and issue #8.
    #
    # Deliberately does not touch `accept_verbatim`: a verbatim/code-example
    # block's content is copied straight through by the upstream class
    # without ever calling {#add_tag}/{#handle_tag}, so literal `<code>`/
    # `<tt>` text a docstring author wrote on purpose (e.g. inside an
    # indented code sample) is unaffected by this override.
    #
    class RDocToMarkdown < ::RDoc::Markup::ToMarkdown
      # A fenced code block's opening delimiter, plus its info string.
      # Anchored at column 0, rather than at CommonMark's (and
      # `HybridMarkdown`'s) three-space tolerance, because indentation is
      # meaningful to RDoc: an indented line opens a verbatim block, so a
      # ` ``` ` inside one is that block's content, not a fence. YARD's
      # own hybrid parser effectively agrees — `parse_blocks` tests
      # `indented_code_block_start?` (two columns or more) before
      # `fenced_code_start?`.
      FENCE_OPENER = /\A(`{3,}|~{3,})(.*)\z/
      private_constant :FENCE_OPENER

      # A GFM table's delimiter row, e.g. `|---|:--:|`. A leading `|` is
      # required: a pipe-less delimiter row is legal GFM, but without that
      # anchor the pattern starts matching ordinary prose.
      TABLE_DELIMITER_ROW = /\A\|(?:\s*:?-+:?\s*\|)+(?:\s*:?-+:?\s*)?\s*\z/
      private_constant :TABLE_DELIMITER_ROW

      # A Markdown blockquote marker. The required space (or end of line)
      # after the `>` is what keeps this off RDoc's *own* blockquote
      # marker, `>>>`, which still has to reach the converter, and off a
      # prose line opening with an operator like `>= 0`.
      BLOCKQUOTE_MARKER = /\A>(?:[ \t]|\z)/
      private_constant :BLOCKQUOTE_MARKER

      ##
      # Converts +text+ to Markdown, emitting any fenced code block, GFM
      # table, or Markdown blockquote verbatim and converting only the
      # prose runs between them.
      #
      # @param text [String] prose in RDoc markup
      # @return [String] the equivalent Markdown — protected blocks
      #   byte-identical to their source, one blank line between blocks
      #
      def convert(text)
        chunks = segment(text).filter_map do |kind, lines|
          block = lines.join
          next if block.strip.empty?

          converted = kind == :prose ? super(block) : block
          converted.sub(/\A\n+/, "").sub(/\n+\z/, "")
        end
        chunks.empty? ? "" : "#{chunks.join("\n\n")}\n"
      end

      ##
      # @param _tag [String] the HTML tag name (unused — the raw-HTML
      #   branch this override removes is the only caller that needed it)
      # @param simple_tag [String] the Markdown delimiter (e.g. `` "`" ``,
      #   `"**"`, `"*"`, `"~~"`)
      # @param content [String] the already-converted inline text to wrap
      # @return [void]
      #
      def add_tag(_tag, simple_tag, content)
        emit_inline("#{simple_tag}#{content}#{simple_tag}")
      end

      ##
      # @param nodes [Array<String, Hash>] the tag's inline child nodes —
      #   a single plain string is handled by delegating to the upstream
      #   implementation (which itself now calls the overridden
      #   {#add_tag}); anything else (multiple nodes, or none, as in an
      #   empty tag) wraps the recursively-converted content in
      #   +simple_tag+ instead of a raw HTML tag
      # @param simple_tag [String] the Markdown delimiter
      # @param tag [String] the HTML tag name (only used by the
      #   single-string path, via `super`)
      # @return [void]
      #
      def handle_tag(nodes, simple_tag, tag)
        if nodes.size == 1 && String === nodes[0]
          super
        else
          emit_inline(simple_tag)
          traverse_inline_nodes(nodes)
          emit_inline(simple_tag)
        end
      end

      private

      # Splits +text+ into `[:prose, lines]` and `[:passthrough, lines]`
      # runs, in source order, every line landing in exactly one run.
      def segment(text)
        lines = text.lines
        segments = []
        prose = []
        index = 0
        while index < lines.length
          run = fenced_run(lines, index) || table_run(lines, index) || blockquote_run(lines, index)
          if run
            segments << [:prose, prose] unless prose.empty?
            prose = []
            segments << [:passthrough, run]
            index += run.length
          else
            prose << lines[index]
            index += 1
          end
        end
        segments << [:prose, prose] unless prose.empty?
        segments
      end

      # The lines of the fenced code block opening at +index+, or nil if
      # none opens there. An unclosed fence runs to the end of +lines+,
      # as CommonMark closes one at the end of its container.
      def fenced_run(lines, index)
        match = FENCE_OPENER.match(lines[index].chomp)
        return nil unless match

        delimiter = match[1]
        # CommonMark forbids a backtick in a backtick fence's info string,
        # so a line opening with an inline code span is not a fence.
        # `HybridMarkdown#parse_fence_opener` rejects the same shape.
        return nil if delimiter.start_with?("`") && match[2].include?("`")

        run = [lines[index]]
        index += 1
        while index < lines.length
          run << lines[index]
          break if fence_closer?(lines[index], delimiter)

          index += 1
        end
        run
      end

      # Whether +line+ closes a fence opened with +delimiter+: a run of
      # the same character, at least as long, with nothing after it but
      # whitespace. Up to three columns of indentation are allowed, as
      # CommonMark (and `HybridMarkdown#fence_closer?`) allow for a
      # closer — unlike an opener, an indented closer can't be confused
      # with the start of an RDoc verbatim block.
      def fence_closer?(line, delimiter)
        stripped = line.sub(/\A {0,3}/, "").strip
        char = delimiter[0]
        return false unless stripped.start_with?(char)

        closer = stripped[/\A#{::Regexp.escape(char)}+/]
        closer.length >= delimiter.length && stripped.delete_prefix(closer).empty?
      end

      # The lines of the GFM table starting at +index+ — a header row, a
      # delimiter row, and any body rows — or nil if none starts there.
      def table_run(lines, index)
        return nil unless table_row?(lines[index])
        return nil unless lines[index + 1]&.match?(TABLE_DELIMITER_ROW)

        run = [lines[index], lines[index + 1]]
        index += 2
        while index < lines.length && table_row?(lines[index])
          run << lines[index]
          index += 1
        end
        run
      end

      # Whether +line+ is a table row: a column-0 `|`, plus at least one
      # character a delimiter row could not contain, so that a second
      # delimiter-shaped row ends the table rather than extending it.
      def table_row?(line)
        line.start_with?("|") && line.match?(/[^|:\-\s]/)
      end

      # The lines of the Markdown blockquote starting at +index+, or nil
      # if none starts there. Only consecutively marked lines are taken:
      # a lazy continuation line ends the run and converts as prose,
      # which costs it the blank line the source didn't have.
      def blockquote_run(lines, index)
        return nil unless BLOCKQUOTE_MARKER.match?(lines[index].chomp)

        run = []
        while index < lines.length && BLOCKQUOTE_MARKER.match?(lines[index].chomp)
          run << lines[index]
          index += 1
        end
        run
      end
    end
  end
end
