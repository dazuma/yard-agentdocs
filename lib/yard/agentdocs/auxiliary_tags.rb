# frozen_string_literal: true

module YARD
  module AgentDocs
    ##
    # `@deprecated`/`@note`/`@abstract`/`@todo`/`@since`/`@version`/`@author`
    # rendering shared by the `module`/`class` `agentdocs` templates.
    # `@deprecated`, `@abstract`, `@note`, and `@todo` render as bold flag
    # lines in the same "before prose" slot {VisibilityInfo}'s private-API
    # annotation already occupies — fixed order when more than one is
    # present (Private API, Deprecated, Abstract, Note, Todo), matching
    # YARD's own default template's `private`/`deprecated`/`abstract`/`note`
    # ordering, with `todo` appended last (YARD's own template renders it
    # separately, as a distinct callout, so there's no existing order to
    # match it against). `@since`/`@version`/`@author` instead render as
    # trailing `**Label:**` key-value lines: a version string or author
    # name isn't a flag to call out up front, so each is placed wherever the
    # including template already puts its own trailing/metadata key-value
    # lines.
    #
    # Requires the including template to also mix in {VisibilityInfo} (for
    # the private-API annotation) and {Markdownify} (for tag-text
    # rendering) — true of every current caller; `module/agentdocs/setup.rb`
    # includes all three.
    #
    module AuxiliaryTags
      ##
      # Bold-line annotations to render before an object's prose, in
      # {VisibilityInfo}/`@deprecated`/`@abstract`/`@note`/`@todo` order —
      # only the ones actually present.
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
          todo_line(object),
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

      ##
      # @param object [::YARD::CodeObjects::Base]
      # @return [String, nil] `"**Version:** 1.2.0"`, or `nil` if untagged
      #
      def version_line(object)
        tag = object.tag(:version)
        return nil unless tag

        "**Version:** #{markdownify(tag.text)}"
      end

      ##
      # @param object [::YARD::CodeObjects::Base]
      # @return [String, nil] `"**Author:** Jane Doe"`, comma-joining every
      #   `@author` tag present (same "one label, join the values" policy
      #   this template's own `defined_in_line` helper already uses for
      #   multiple file paths), or `nil` if untagged
      #
      def author_line(object)
        tags = object.tags(:author)
        return nil if tags.empty?

        "**Author:** #{tags.map { |tag| markdownify(tag.text) }.join(', ')}"
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

      def todo_line(object)
        return nil unless object.has_tag?(:todo)

        text = markdownify(object.tag(:todo).text)
        text.empty? ? "**Todo:**" : "**Todo:** #{text}"
      end
    end
  end
end
