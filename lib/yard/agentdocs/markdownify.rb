# frozen_string_literal: true

require "rdoc"
require "rdoc/markup/to_markdown"

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
    # `YARD::Templates::Template` already does.
    #
    module Markdownify
      ##
      # @param text [String, ::YARD::Docstring, nil] prose in the dialect
      #   declared by `options.markup`
      # @return [String] equivalent Markdown, stripped of surrounding
      #   whitespace
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
        converted.strip
      end
    end
  end
end
