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
    # output — see "Docstring markup dialect" in `docs/dev/DESIGN.md` for the
    # full rationale.
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
      # marker already 4+ `#`s deep is left alone: it can't collide (see
      # "Output format" in `docs/dev/DESIGN.md`), and a marker indented by
      # leading whitespace is already invisible to the column-0-anchored
      # `grep '^## '`/`grep '^### '` this format's lookup mechanism relies
      # on, so it doesn't need demoting either.
      HEADING_MARKER = /^\#{1,3}(?=[ \t]|$)/

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
      # @return [String] equivalent Markdown, stripped of surrounding
      #   whitespace, with any colliding heading demoted (unless disabled)
      #   and inline `{Name}` cross-references resolved
      #
      def markdownify(text, markup: options.markup, demote_headings: true)
        text = strip_provenance(text)
        converted =
          case markup.to_sym
          when :markdown
            text
          when :rdoc
            RDocToMarkdown.new.convert(text)
          else
            log.error "yard-agentdocs: unsupported markup type `#{markup.to_sym.inspect}` " \
                       "(only :markdown and :rdoc are supported) — passing prose through unconverted"
            text
          end
        converted = converted.strip
        converted = self.demote_headings(converted) if demote_headings
        resolve_references(converted)
      end

      private

      # Demotes every top-of-line, 1-3-`#` ATX heading in +text+ to a fixed
      # 4 `#`s, so a prose-embedded heading (RDoc `=`/`==`/`===`, or a
      # literal Markdown `#`/`##`/`###`) can never be mistaken for one of
      # this format's own structural headings — see "Prose-embedded
      # headings" in `docs/dev/DESIGN.md`. Skips backtick-delimited spans (of
      # any length, so this also covers a fenced ` ``` ` block) via
      # {CrossReferencing#transform_outside_code_spans}, so a `#` comment
      # line inside a fenced code sample is left alone.
      def demote_headings(text)
        transform_outside_code_spans(text) { |segment| segment.gsub(HEADING_MARKER, "####") }
      end
    end
  end
end
