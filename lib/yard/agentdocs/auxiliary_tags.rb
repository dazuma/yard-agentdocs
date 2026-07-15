# frozen_string_literal: true

module YARD
  module AgentDocs
    ##
    # `@deprecated`/`@note`/`@abstract`/`@todo`/`@since`/`@version`/`@author`
    # rendering shared by the `module`/`class` `agentdocs` templates.
    # `@deprecated`, `@abstract`, `@note`, and `@todo` render as bulleted flag
    # lines in the same "before prose" slot {VisibilityInfo}'s private-API
    # annotation already occupies — fixed order when more than one is
    # present (Private API, Deprecated, Abstract, Note, Todo), matching
    # YARD's own default template's `private`/`deprecated`/`abstract`/`note`
    # ordering, with `todo` appended last (YARD's own template renders it
    # separately, as a distinct callout, so there's no existing order to
    # match it against). `@since`/`@version`/`@author` instead render as
    # trailing `- **Label:**` bulleted key-value lines: a version string or
    # author name isn't a flag to call out up front, so each is placed
    # wherever the including template already puts its own trailing/metadata
    # key-value lines. Every line here is a `- ` list item, never a bare bold
    # paragraph line — stacking bare lines with only a single `\n` between
    # them lets a CommonMark renderer merge them into one flowing paragraph
    # (confirmed with a real parser), and since these all splice in raw,
    # possibly multi-line/multi-paragraph tag text via `markdownify`, a bare
    # line also risks the same embedded-newline corruption
    # `indent_continuation` (`templates/default/module/agentdocs/setup.rb`)
    # already exists to prevent for `@param`/`@raise`/etc. — reused here via
    # `indent_continuation` on every value built from tag text.
    #
    # Requires the including template to also mix in {VisibilityInfo} (for
    # the private-API annotation), {Markdownify} (for tag-text rendering),
    # and expose `indent_continuation` (defined directly in
    # `module/agentdocs/setup.rb`) — true of every current caller;
    # `module/agentdocs/setup.rb` includes both mixins and defines
    # `indent_continuation` itself.
    #
    module AuxiliaryTags
      ##
      # Bulleted-line annotations to render before an object's prose, in
      # {VisibilityInfo}/`@deprecated`/`@abstract`/`@note`/`@todo` order —
      # only the ones actually present.
      #
      # @param object [::YARD::CodeObjects::Base]
      # @return [::Array<String>] each already fully formatted, e.g.
      #   `"- **Deprecated.** Use `Foo#bar` instead."`
      #
      def annotation_lines(object)
        annotation = private_api_annotation(object)
        [
          annotation && "- **#{annotation}**",
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
      # @return [String, nil] `"- **Since:** 1.0.0"`, or `nil` if untagged
      #
      def since_line(object)
        tag = object.tag(:since)
        return nil unless tag

        "- **Since:** #{indent_continuation(markdownify(tag.text))}"
      end

      ##
      # @param object [::YARD::CodeObjects::Base]
      # @return [String, nil] `"- **Version:** 1.2.0"`, or `nil` if untagged
      #
      def version_line(object)
        tag = object.tag(:version)
        return nil unless tag

        "- **Version:** #{indent_continuation(markdownify(tag.text))}"
      end

      ##
      # @param object [::YARD::CodeObjects::Base]
      # @return [String, nil] `"- **Author:** Jane Doe"`, comma-joining every
      #   `@author` tag present (same "one label, join the values" policy
      #   this template's own `defined_in_line` helper already uses for
      #   multiple file paths), or `nil` if untagged
      #
      def author_line(object)
        tags = object.tags(:author)
        return nil if tags.empty?

        text = tags.map { |tag| markdownify(tag.text) }.join(", ")
        "- **Author:** #{indent_continuation(text)}"
      end

      private

      def deprecated_line(object)
        return nil unless object.has_tag?(:deprecated)

        text = markdownify(object.tag(:deprecated).text)
        text.empty? ? "- **Deprecated.**" : "- **Deprecated.** #{indent_continuation(text)}"
      end

      def note_line(object)
        return nil unless object.has_tag?(:note)

        text = markdownify(object.tag(:note).text)
        text.empty? ? "- **Note:**" : "- **Note:** #{indent_continuation(text)}"
      end

      def abstract_line(object)
        return nil unless object.has_tag?(:abstract)

        text = markdownify(object.tag(:abstract).text)
        text.empty? ? "- **Abstract.**" : "- **Abstract.** #{indent_continuation(text)}"
      end

      def todo_line(object)
        return nil unless object.has_tag?(:todo)

        text = markdownify(object.tag(:todo).text)
        text.empty? ? "- **Todo:**" : "- **Todo:** #{indent_continuation(text)}"
      end
    end
  end
end
