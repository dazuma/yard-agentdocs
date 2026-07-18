# frozen_string_literal: true

module YARD
  module AgentDocs
    ##
    # `@deprecated`/`@note`/`@abstract`/`@todo`/`@since`/`@version`/`@author`
    # rendering shared by the `module`/`class` `agentdocs` templates, split
    # across two slots by how actionable each tag is. `@deprecated`,
    # `@abstract`, and `@note` render as bulleted flag lines in the same
    # "before prose" slot {VisibilityInfo}'s private-API annotation already
    # occupies — fixed order when more than one is present (Private API,
    # Deprecated, Abstract, Note), matching YARD's own default template's
    # `private`/`deprecated`/`abstract`/`note` ordering. These are genuine
    # caveats that change how the rest of the entry should be read (a
    # thread-safety warning, a deprecation notice), so they need to be seen
    # before the description, not after it.
    #
    # `@todo`/`@since`/`@version`/`@author` instead render as a trailing
    # block, placed by the including template wherever its own trailing
    # metadata already goes (right before `- **Defined in:**`, or — for a
    # class/module, which puts `- **Defined in:**` at the *top* of the page
    # instead — right after the docstring/examples, before `## Member
    # Summary`). These are lower-priority: a to-do about future changes or
    # version/author provenance doesn't change how to use the object *now*,
    # so burying it below the description (rather than making a reader
    # or agent wade through it before reaching the actual content) is the
    # right trade-off.
    #
    # Every line here is a `- ` list item, never a bare bold paragraph line —
    # stacking bare lines with only a single `\n` between them lets a
    # CommonMark renderer merge them into one flowing paragraph (confirmed
    # with a real parser), and since these all splice in raw, possibly
    # multi-line/multi-paragraph tag text via `markdownify`, a bare line also
    # risks the same embedded-newline corruption `indent_continuation`
    # ({TextLayout}) already exists to prevent for `@param`/`@raise`/etc. —
    # reused here via `indent_continuation` on every value built from tag
    # text.
    #
    # Requires the including template to also mix in {VisibilityInfo} (for
    # the private-API annotation), {Markdownify} (for tag-text rendering),
    # and {TextLayout} (for `indent_continuation`) — true of every current
    # caller; `module/agentdocs/setup.rb` includes all three.
    #
    module AuxiliaryTags
      ##
      # Bulleted-line annotations to render before an object's prose, in
      # {VisibilityInfo}/`@deprecated`/`@abstract`/`@note` order — only the
      # ones actually present. See {#trailing_annotation_lines} for
      # `@todo`/`@since`/`@version`/`@author`, rendered separately, after the
      # prose.
      #
      # @param obj [::YARD::CodeObjects::Base]
      # @return [::Array<String>] each already fully formatted, e.g.
      #   `"- **Deprecated.** Use `Foo#bar` instead."`
      #
      def annotation_lines(obj)
        annotation = private_api_annotation(obj)
        [
          annotation && "* **#{annotation}**",
          deprecated_line(obj),
          abstract_line(obj),
          note_line(obj),
        ].compact
      end

      ##
      # Bulleted trailing-metadata lines to render after an object's prose
      # (and any Params/Returns/etc.), in `@todo`/`@since`/`@version`/
      # `@author` order — only the ones actually present. See
      # {#annotation_lines} for the higher-priority tags rendered before the
      # prose instead.
      #
      # @param obj [::YARD::CodeObjects::Base]
      # @return [::Array<String>] each already fully formatted, e.g.
      #   `"- **Since:** 1.0.0"`
      #
      def trailing_annotation_lines(obj)
        [
          todo_line(obj),
          since_line(obj),
          version_line(obj),
          author_line(obj),
        ].compact
      end

      ##
      # Short annotations for a Member Summary bullet, same order/subset as
      # {#annotation_lines}.
      #
      # @param obj [::YARD::CodeObjects::Base]
      # @return [::Array<String>]
      #
      def annotation_lines_short(obj)
        [
          private_api_annotation_short(obj),
          ("deprecated" if obj.has_tag?(:deprecated)),
          ("abstract" if obj.has_tag?(:abstract)),
        ].compact
      end

      ##
      # @param obj [::YARD::CodeObjects::Base]
      # @return [String, nil] `"- **Since:** 1.0.0"`, or `nil` if untagged
      #
      def since_line(obj)
        tag = obj.tag(:since)
        return nil unless tag

        "* **Since:** #{indent_continuation(markdownify(tag.text))}"
      end

      ##
      # @param obj [::YARD::CodeObjects::Base]
      # @return [String, nil] `"- **Version:** 1.2.0"`, or `nil` if untagged
      #
      def version_line(obj)
        tag = obj.tag(:version)
        return nil unless tag

        "* **Version:** #{indent_continuation(markdownify(tag.text))}"
      end

      ##
      # @param obj [::YARD::CodeObjects::Base]
      # @return [String, nil] `"- **Author:** Jane Doe"`, comma-joining every
      #   `@author` tag present (same "one label, join the values" policy
      #   this template's own `defined_in_line` helper already uses for
      #   multiple file paths), or `nil` if untagged
      #
      def author_line(obj)
        tags = obj.tags(:author)
        return nil if tags.empty?

        text = tags.map { |tag| markdownify(tag.text) }.join(", ")
        "* **Author:** #{indent_continuation(text)}"
      end

      private

      def deprecated_line(obj)
        return nil unless obj.has_tag?(:deprecated)

        text = markdownify(obj.tag(:deprecated).text)
        text.empty? ? "* **Deprecated.**" : "* **Deprecated.** #{indent_continuation(text)}"
      end

      def note_line(obj)
        return nil unless obj.has_tag?(:note)

        text = markdownify(obj.tag(:note).text)
        text.empty? ? "* **Note:**" : "* **Note:** #{indent_continuation(text)}"
      end

      def abstract_line(obj)
        return nil unless obj.has_tag?(:abstract)

        text = markdownify(obj.tag(:abstract).text)
        text.empty? ? "* **Abstract.**" : "* **Abstract.** #{indent_continuation(text)}"
      end

      def todo_line(obj)
        return nil unless obj.has_tag?(:todo)

        text = markdownify(obj.tag(:todo).text)
        text.empty? ? "* **Todo:**" : "* **Todo:** #{indent_continuation(text)}"
      end
    end
  end
end
