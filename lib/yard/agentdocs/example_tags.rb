# frozen_string_literal: true

module YARD
  module AgentDocs
    ##
    # `@example` rendering shared by the `module`/`class` `agentdocs`
    # templates — used for both a method's own examples and a
    # class/module's. Renders right after the object's docstring prose (the
    # same slot YARD's own default template places its "Examples:" section
    # in, immediately following the discussion and ahead of `@param`/
    # `@return`/`@raise`), under a single `**Examples:**` header regardless
    # of how many `@example` tags are present.
    #
    # A titled example (`@example Some title`) renders its title as a plain
    # italicized line above the code fence — not a Markdown heading, to
    # avoid colliding with the `## `/`### ` structural heading hierarchy the
    # rest of this format relies on. `@example` text is never passed
    # through {Markdownify#markdownify}: YARD parses it as raw code (the
    # `:with_title_and_text` tag factory), not RDoc/Markdown prose.
    #
    module ExampleTags
      ##
      # @param object [::YARD::CodeObjects::Base]
      # @return [String, nil] the full `**Examples:**` block, or `nil` if
      #   `object` has no `@example` tags
      #
      def examples_block(object)
        tags = object.tags(:example)
        return nil if tags.empty?

        entries = tags.map { |tag| example_entry(tag) }
        "**Examples:**\n\n#{entries.join("\n\n")}"
      end

      private

      def example_entry(tag)
        code = "```ruby\n#{tag.text}\n```"
        tag.name.empty? ? code : "*#{tag.name}*\n\n#{code}"
      end
    end
  end
end
