# frozen_string_literal: true

require "rdoc"
require "yard/agentdocs/provenance_marker"
require "yard/agentdocs/rdoc_to_markdown"

module YARD
  module AgentDocs
    ##
    # Docstring/tag-text markup-dialect conversion shared by the
    # `module`/`class` `agentdocs` templates. Dispatches on `options.markup`
    # (the `--markup` flag YARD is run with) so a docstring authored in
    # either Markdown or RDoc renders correctly in this template's Markdown
    # output.
    #
    # Requires the including template to provide an `options` method (the
    # current `YARD::Templates::TemplateOptions`), as
    # `YARD::Templates::Template` already does, and — since the final step
    # is resolving inline cross-references — must also have
    # {CrossReferencing} mixed in (true of every current caller;
    # `module/agentdocs/setup.rb` includes both).
    #
    module Markdownify
      include ProvenanceMarker

      # An ATX heading marker (1-3 `#`s) at the very start of a line,
      # followed by a space/tab or end of line — a heading shallow enough to
      # collide with this format's own `## `/`### ` structural headings. A
      # marker already 4+ `#`s deep is left alone: it can't collide, and a
      # marker indented by leading whitespace is already invisible to the
      # column-0-anchored
      # `grep '^## '`/`grep '^### '` this format's lookup mechanism relies
      # on, so it doesn't need demoting either.
      HEADING_MARKER = /^\#{1,3}(?=[ \t]|$)/

      ##
      # The markup dialects {#markdownify} converts to Markdown.
      #
      CONVERTED_DIALECTS = [:markdown, :rdoc].freeze

      ##
      # Whether +markup+ is one of the dialects YARD renders without any
      # provider gem (`:text`, `:pre`, `:none`, `:html`, `:ruby`) — the
      # types whose `MARKUP_PROVIDERS` entry is empty. Read from YARD's own
      # table rather than listed here, so {Yardoc} and this module can't
      # disagree with YARD about which dialects those are.
      #
      # @param markup [Symbol, String] a markup dialect
      # @return [Boolean]
      #
      def self.provider_less?(markup)
        ::YARD::Templates::Helpers::MarkupHelper::MARKUP_PROVIDERS[markup.to_sym] == []
      end

      ##
      # Whether +markup+ is a dialect this template can neither convert nor
      # pass through: one YARD needs a provider gem for (`textile`, `org`,
      # `asciidoc`, ...), or one YARD doesn't know at all, such as a
      # misspelled `#!markdwon` shebang. {Yardoc} fails a build whose
      # run-wide `--markup` is one of these, and `fulldoc/agentdocs/setup.rb`
      # includes an extra file written in one verbatim, so {#markdownify}
      # never sees one.
      #
      # @param markup [Symbol, String] a markup dialect
      # @return [Boolean]
      #
      def self.unsupported?(markup)
        !CONVERTED_DIALECTS.include?(markup.to_sym) && !provider_less?(markup)
      end

      ##
      # @param text [String, ::YARD::Docstring, nil] prose in the dialect
      #   named by +markup+
      # @param markup [Symbol, String] the dialect +text+ is written in.
      #   Defaults to `options.markup` (the run-wide `--markup` flag),
      #   correct for every docstring/tag-text call site, since a docstring
      #   has no per-file dialect of its own. An extra file does — see
      #   `fulldoc/agentdocs/setup.rb`, which resolves one per file and
      #   passes it here. Accepts a String as well as a Symbol, since YARD
      #   records a `#!markdown` shebang as the former.
      # @param demote_headings [Boolean] whether a colliding `#`/`##`/`###`
      #   heading gets demoted (see {#demote_headings}). Defaults to `true`,
      #   correct for every docstring/tag-text call site, where the
      #   converted text is embedded into a page that already owns those
      #   heading levels structurally. Pass `false` for text rendered onto
      #   its own standalone page (an extra file's contents — see
      #   `fulldoc/agentdocs/setup.rb`), where there's no structural
      #   heading to collide with and demoting would just flatten the
      #   file's own heading hierarchy.
      # @param single_line [Boolean] whether +text+ is a Summary, which
      #   must convert to a single line (see {RDocToMarkdown}). Defaults to
      #   `false`. Has no effect on Markdown-dialect text, which passes
      #   through unconverted.
      # @param inline [Boolean] whether the result is spliced onto a line
      #   after other text (tag text after a `* **Since:** ` or ` — `
      #   prefix), rather than starting a block of its own. Matters only to
      #   a provider-less dialect (see {#convert_provider_less}). Defaults
      #   to +single_line+, since a Summary is always inline.
      # @return [String] equivalent Markdown, stripped of surrounding
      #   whitespace, with any colliding heading demoted (unless disabled)
      #   and inline `{Name}` cross-references resolved
      #
      def markdownify(text, markup: options.markup, demote_headings: true, single_line: false, inline: single_line)
        text = strip_provenance(text)
        converted =
          case markup.to_sym
          when :markdown
            text
          when :rdoc
            RDocToMarkdown.new(single_line: single_line).convert(text)
          else
            # Callers screen out every unsupported dialect first (see
            # {.unsupported?}), so reaching this with one is a bug.
            unless Markdownify.provider_less?(markup)
              raise ::ArgumentError, "yard-agentdocs: cannot convert markup type `#{markup.to_sym.inspect}`"
            end
            convert_provider_less(text, markup.to_sym, inline: inline)
          end
        converted = converted.strip
        converted = self.demote_headings(converted) if demote_headings
        resolve_references(converted)
      end

      ##
      # +text+, minus surrounding blank lines, as one fenced code block whose
      # info string is +info+. Nothing inside is converted, demoted, or
      # resolved. The fence is one backtick longer than the longest backtick
      # run anywhere in +text+, so no line inside can close it early.
      #
      # @param text [String]
      # @param info [String, Symbol] the fence's info string, naming
      #   +text+'s language or dialect
      # @return [String] the fenced block, or an empty string when +text+
      #   is blank
      #
      def verbatim_block(text, info)
        text = text.to_s.sub(/\A(?:[ \t]*\n)+/, "").rstrip
        return "" if text.empty?
        fence = "`" * [3, (text.scan(/`+/).map(&:length).max || 0) + 1].max
        "#{fence}#{info}\n#{text}\n#{fence}"
      end

      private

      # Converts prose in one of the dialects YARD renders without a
      # provider gem ({.provider_less?}), mirroring YARD's own
      # `HtmlHelper#html_markup_*` for each.
      #
      # In block position, `:text`, `:pre`, and `:none` become a `text`
      # fence, and `:ruby` a `ruby` fence. YARD shows each as the author's
      # characters, line by line, and a fence is Markdown's way to say that.
      # The literal alternative, YARD's escaped text with hard line breaks,
      # would mean backslash-escaping every Markdown-significant character:
      # more tokens, and text a plain `grep` no longer matches. The fence
      # also keeps a top-of-line `#` from reading as a heading, and leaves
      # any `{...}` literal — in plain text, far likelier a hash or block
      # than a YARD reference. `:html` passes through verbatim, as YARD does,
      # since Markdown already allows raw HTML.
      #
      # A fence can't sit after a `* **Since:** ` or ` — ` prefix, so inline
      # every one of these dialects collapses its whitespace onto one line
      # and otherwise passes through unescaped: the author's own characters,
      # which is what an agent reading the raw Markdown wants.
      def convert_provider_less(text, markup, inline:)
        return text.gsub(/\s+/, " ") if inline

        case markup
        when :html then text
        when :ruby then verbatim_block(text, "ruby")
        else verbatim_block(text, "text")
        end
      end

      # Demotes every top-of-line, 1-3-`#` ATX heading in +text+ to a fixed
      # 4 `#`s, so a prose-embedded heading (RDoc `=`/`==`/`===`, or a
      # literal Markdown `#`/`##`/`###`) can never be mistaken for one of
      # this format's own structural headings. Skips backtick-delimited
      # spans (of any length, so this also covers a fenced ` ``` ` block) via
      # {CrossReferencing#transform_outside_code_spans}, so a `#` comment
      # line inside a fenced code sample is left alone.
      def demote_headings(text)
        transform_outside_code_spans(text) { |segment| segment.gsub(HEADING_MARKER, "####") }
      end
    end
  end
end
