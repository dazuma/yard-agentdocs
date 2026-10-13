# frozen_string_literal: true

require "rdoc/markup/to_markdown"

module YARD
  module AgentDocs
    ##
    # A `::RDoc::Markup::ToMarkdown` that fixes three fidelity gaps in the
    # stdlib converter: it never falls back to raw HTML for styled inline
    # text, it never flattens a block construct RDoc's own markup gives no
    # meaning to, and it never re-wraps a paragraph or list item. It also
    # renders label lists as CommonMark, and has a single-line mode, for
    # text that must stay on one line.
    #
    # **Inline: no raw-HTML fallback** for `<tt>`/`<code>`, `<b>`/`<i>`/
    # `<em>`, `<s>`/`<del>`, and their `+word+`/`` `word` ``/`*word*`/
    # `_word_` shorthand equivalents. The stdlib converter takes that
    # raw-HTML branch whenever the styled content has any character
    # outside plain word characters/whitespace — routine in Ruby prose
    # (`+valid?+`, `+save!+`, `+Foo::Bar+`) — leaking literal
    # `<code>...</code>`/`<strong>...</strong>` etc. into what's supposed
    # to be pure Markdown.
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
    # issue #8.
    #
    # Deliberately does not touch `accept_verbatim`: a verbatim/code-example
    # block's content is copied straight through by the upstream class
    # without ever calling {#add_tag}/{#handle_tag}, so literal `<code>`/
    # `<tt>` text a docstring author wrote on purpose (e.g. inside an
    # indented code sample) is unaffected by this override.
    #
    # Fixing the leak in the converter rather than in its output is what
    # buys that. Sweeping a regex over the rendered string — the obvious
    # cheaper fix, alongside {Markdownify}'s existing `demote_headings`
    # pass — cannot work, and not merely in theory: at the string level a
    # real leak and an author's deliberate literal `<code>` inside a
    # verbatim block are byte-identical, and `transform_outside_code_spans`
    # doesn't rescue it either, since `ToMarkdown` indents verbatim blocks
    # by four spaces rather than fencing them, leaving no marker to skip.
    # RDoc's visitor design already separates verbatim content from
    # inline-formatted prose, so intervening here excludes that
    # false-positive class by construction.
    #
    # **No re-wrapping.** The upstream `wrap` breaks every paragraph and
    # list item at 78 columns. RDoc has already joined the author's source
    # lines by then, so those breaks are the converter's own invention, and
    # they split a summary — which must stay on one line to be greppable —
    # across lines. {#wrap} emits the text on one line instead. Fixing this
    # in the output string instead would leave runs of spaces where a
    # list item's continuation indent had been. See issue #20.
    #
    # **Label lists as CommonMark bullets.** RDoc has two label-list
    # syntaxes, `[label] text` and `label:: text`. The upstream converter
    # renders them as a PHP-Markdown-Extra definition list
    # (`label\n:   text`), which is not CommonMark, follows the list with
    # two blank lines, and drops the outer label of a nested item. This
    # class renders each item as `-   **label:** text` instead, in one
    # tight list. Labels sharing an item render as `**a**, **b:**`, after
    # YARD's HTML, which shares one `<dd>` between them. A label with no
    # text gets no colon. A nested item becomes a sub-list, keeping every
    # label. The marker is `-` rather than the `*` of upstream bullets
    # because CommonMark merges adjacent lists that share a marker. That
    # matters most for a label with no text followed by a bullet list
    # (nokogiri's `[Parameters]` sections), where RDoc parses the bullet
    # list as a sibling, not as the item's content. The label is bold
    # rather than a code span because it can carry inline markup. See
    # issue #24.
    #
    # **Single-line mode** (`single_line: true`) is for a Summary, which
    # must stay on one line on every surface it renders on. A Summary
    # reaches the converter as one line of source, and two constructs turn
    # one line into several. One is a label list (`[label] text` or
    # `label:: text`). Its upstream form, `label\n:   text`, is multi-line
    # by construction (and not CommonMark), so this mode renders each item
    # inline as `label: text` instead, adding no second colon to a label
    # that already ends in one. Items nest recursively the same way:
    # joining a two-line `Author:: x` / `Copyright:: y` header makes RDoc
    # parse a note item whose text is a second one, and the upstream
    # converter drops the outer label there. Prose RDoc misreads as a label
    # (`Uses Foo:: as a prefix.`) loses one colon, which YARD's HTML
    # misreads the same way. Keeping the source form instead was rejected:
    # it leaks RDoc syntax, and a leading `[label]` reads as a Markdown
    # shortcut reference. The other is a `<br>` hard break, which this mode
    # renders as a space, absorbing the whitespace that follows it, since
    # the author's line break after a `<br>` has already become one. See
    # issue #23.
    #
    # `::RDoc::Markup::Raw` nodes need no handling and are not worth
    # re-investigating: only RDoc's competing Markdown parser
    # (`rdoc/markdown.rb`) ever constructs them, never the plain
    # `:rdoc`-dialect parser this class sits behind.
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
      # @param single_line [Boolean] whether to render each label-list item
      #   inline, so that one line of source converts to one line of
      #   output (see the class docs)
      #
      def initialize(single_line: false)
        super()
        @single_line = single_line
      end

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

      ##
      # Starts a label-list item as a bullet, `-   **label:** `, rather
      # than as a definition list. In single-line mode, instead appends
      # the item's labels to the pending prefix as `label: `. The prefix
      # is still pending when a nested item starts, so nested labels
      # accumulate in order.
      #
      # @param list_item [::RDoc::Markup::ListItem]
      # @return [void]
      #
      def accept_list_item_start(list_item)
        return super unless label_item?

        labels = Array(list_item.label).map { |label| attributes(label).strip }
        if @single_line
          @prefix = "#{@prefix}#{labels.map { |label| "#{with_colon(label)} " }.join}"
        else
          @prefix = (" " * @indent) + "-   #{bold_labels(labels, list_item)} "
          @indent += 4
        end
      end

      ##
      # Ends a label-list item without the upstream trailing blank line,
      # so consecutive items form one tight list. A label with no text is
      # emitted on its own.
      #
      # @param list_item [::RDoc::Markup::ListItem]
      # @return [void]
      #
      def accept_list_item_end(list_item)
        return super unless label_item?

        flush_label_prefix
        @indent -= 4 unless @single_line
      end

      ##
      # Emits a pending label-item prefix before a nested list starts,
      # rather than letting the nested item's own prefix overwrite it, as
      # the upstream converter does.
      #
      # @param list [::RDoc::Markup::List]
      # @return [void]
      #
      def accept_list_start(list)
        flush_label_prefix if label_item? && !@single_line
        super
      end

      ##
      # Emits a pending label-item prefix before a blank line, so that a
      # label with no text stays ahead of whatever follows it.
      #
      # @param blank_line [::RDoc::Markup::BlankLine]
      # @return [void]
      #
      def accept_blank_line(blank_line)
        flush_label_prefix if label_item? && !@single_line
        super
      end

      ##
      # In single-line mode, emits a hard break as a space, rather than as
      # a Markdown hard line break.
      #
      # @return [void]
      #
      def handle_HARD_BREAK
        return super unless @single_line

        emit_inline(" ")
        @after_hard_break = true
      end

      ##
      # Drops the whitespace that follows a single-line-mode hard break,
      # which {#handle_HARD_BREAK} has already emitted as a space.
      #
      # @param text [String] plain inline text
      # @return [void]
      #
      def handle_TEXT(text)
        super(@after_hard_break ? text.sub(/\A[ \t]+/, "") : text)
      end

      ##
      # Tracks whether anything has been emitted since the last
      # single-line-mode hard break, for {#handle_TEXT}.
      #
      # @param text [String] the inline text to emit
      # @return [void]
      #
      def emit_inline(text)
        @after_hard_break = false
        super
      end

      ##
      # Emits +text+ on one line, rather than wrapping it at a fixed width
      # as the upstream implementation does. +text+ contains a newline
      # only where the author wrote a `<br>` hard break, outside
      # single-line mode.
      #
      # @param text [String] a paragraph or list item's converted text
      # @return [void]
      #
      def wrap(text)
        return if text.nil? || text.empty?

        @res << (@prefix || (" " * @indent)) << text << "\n"
        @prefix = nil
      end

      private

      # Whether the innermost list being visited is a label list.
      def label_item?
        [:NOTE, :LABEL].include?(@list_type.last)
      end

      # +label+ followed by a colon, unless it already ends in one.
      def with_colon(label)
        label.end_with?(":") ? label : "#{label}:"
      end

      # The bold labels of a body-mode item: `**a**, **b:**`. The colon
      # introduces the item's content, so a label with none gets none.
      def bold_labels(labels, list_item)
        has_content = list_item.parts.any? { |part| !part.is_a?(::RDoc::Markup::BlankLine) }
        *leading, last = labels
        last = with_colon(last) if has_content
        (leading + [last]).map { |label| "**#{label}**" }.join(", ")
      end

      # Emits the pending label-item prefix, if any, on a line of its own.
      def flush_label_prefix
        return if @prefix.nil?

        @res << @prefix.rstrip << "\n"
        @prefix = nil
      end

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
