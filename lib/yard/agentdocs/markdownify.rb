# frozen_string_literal: true

require "rdoc"
require "rdoc/markup/to_markdown"
require "strscan"

module YARD
  module AgentDocs
    ##
    # Docstring/tag-text markup-dialect conversion shared by the
    # `module`/`class` `agentdocs` templates. Dispatches on `options.markup`
    # (the `--markup` flag YARD is run with) so a docstring authored in
    # either Markdown or RDoc renders correctly in this template's Markdown
    # output — see "Docstring markup dialect" in `devdocs/DESIGN.md` for the
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
      # An ATX heading marker (1-3 `#`s) at the very start of a line,
      # followed by a space/tab or end of line — a heading shallow enough to
      # collide with this format's own `## `/`### ` structural headings. A
      # marker already 4+ `#`s deep is left alone: it can't collide (see
      # "Output format" in `devdocs/DESIGN.md`), and a marker indented by
      # leading whitespace is already invisible to the column-0-anchored
      # `grep '^## '`/`grep '^### '` this format's lookup mechanism relies
      # on, so it doesn't need demoting either.
      HEADING_MARKER = /^\#{1,3}(?=[ \t]|$)/

      ##
      # @param text [String, ::YARD::Docstring, nil] prose in the dialect
      #   declared by `options.markup`
      # @return [String] equivalent Markdown, stripped of surrounding
      #   whitespace, with any colliding heading demoted and inline
      #   `{Name}` cross-references resolved
      #
      def markdownify(text)
        text = text.to_s
        converted =
          case options.markup
          when :markdown
            text
          when :rdoc
            ::RDoc::Markup::ToMarkdown.new.convert(text)
          else
            log.error "yard-agentdocs: unsupported markup type `#{options.markup.inspect}` " \
                       "(only :markdown and :rdoc are supported) — passing prose through unconverted"
            text
          end
        resolve_references(demote_headings(converted.strip))
      end

      private

      # Demotes every top-of-line, 1-3-`#` ATX heading in +text+ to a fixed
      # 4 `#`s, so a prose-embedded heading (RDoc `=`/`==`/`===`, or a
      # literal Markdown `#`/`##`/`###`) can never be mistaken for one of
      # this format's own structural headings — see "Prose-embedded
      # headings" in `devdocs/DESIGN.md`. Skips backtick-delimited spans (of
      # any length, so this also covers a fenced ` ``` ` block) the same way
      # {CrossReferencing#resolve_references} does, so a `#` comment line
      # inside a fenced code sample is left alone.
      def demote_headings(text)
        scanner = ::StringScanner.new(text)
        result = +""
        until scanner.eos?
          if (run = scanner.scan(/`+/))
            closing = /(?<!`)#{::Regexp.quote(run)}(?!`)/
            span = scanner.scan_until(closing)
            result << run << (span || scanner.rest)
            scanner.terminate unless span
          else
            result << scanner.scan(/[^`]+/).gsub(HEADING_MARKER, "####")
          end
        end
        result
      end
    end
  end
end
