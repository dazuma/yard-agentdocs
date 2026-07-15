# frozen_string_literal: true

module YARD
  module AgentDocs
    ##
    # `@deprecated`/`@note`/`@abstract`/`@since` rendering shared by the
    # `module`/`class` `agentdocs` templates. `@deprecated`, `@abstract`, and
    # `@note` render as bold flag lines in the same "before prose" slot
    # {VisibilityInfo}'s private-API annotation already occupies — fixed
    # order when more than one is present (Private API, Deprecated,
    # Abstract, Note), matching YARD's own default template's
    # `private`/`deprecated`/`abstract`/`note` ordering (`todo` is
    # deliberately skipped — not yet a supported tag here). `@since` renders
    # as a trailing `**Since:**` key-value line instead: a version string
    # isn't a flag to call out up front, so it's placed wherever each object
    # kind already puts its own trailing/metadata key-value lines.
    #
    # Requires the including template to also mix in {VisibilityInfo} (for
    # the private-API annotation) and {Markdownify} (for tag-text
    # rendering) — true of every current caller; `module/agentdocs/setup.rb`
    # includes all three.
    #
    module AuxiliaryTags
      ##
      # Bold-line annotations to render before an object's prose, in
      # {VisibilityInfo}/`@deprecated`/`@abstract`/`@note` order — only the
      # ones actually present.
      #
      # @param object [::YARD::CodeObjects::Base]
      # @return [::Array<String>] each already fully formatted, e.g.
      #   `"**Deprecated.** Use `Foo#bar` instead."`
      #
      def annotation_lines(object)
        annotation = private_api_annotation(object)
        [
          annotation && "**#{annotation}**",
          deprecated_line(object),
          abstract_line(object),
          note_line(object),
        ].compact
      end

      ##
      # Short annotations for a Member Summary bullet, same order/subset as
      # {#annotation_lines}.
      #
      # @param object [::YARD::CodeObjects::Base]
      # @return [::Array<String>]
      #
      def annotation_lines_short(object)
        [
          private_api_annotation_short(object),
          ("deprecated" if object.has_tag?(:deprecated)),
          ("abstract" if object.has_tag?(:abstract)),
        ].compact
      end

      ##
      # @param object [::YARD::CodeObjects::Base]
      # @return [String, nil] `"**Since:** 1.0.0"`, or `nil` if untagged
      #
      def since_line(object)
        tag = object.tag(:since)
        return nil unless tag

        "**Since:** #{markdownify(tag.text)}"
      end

      private

      def deprecated_line(object)
        return nil unless object.has_tag?(:deprecated)

        text = markdownify(object.tag(:deprecated).text)
        text.empty? ? "**Deprecated.**" : "**Deprecated.** #{text}"
      end

      def note_line(object)
        return nil unless object.has_tag?(:note)

        text = markdownify(object.tag(:note).text)
        text.empty? ? "**Note:**" : "**Note:** #{text}"
      end

      def abstract_line(object)
        return nil unless object.has_tag?(:abstract)

        text = markdownify(object.tag(:abstract).text)
        text.empty? ? "**Abstract.**" : "**Abstract.** #{text}"
      end
    end
  end
end
