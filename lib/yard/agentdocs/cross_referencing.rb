# frozen_string_literal: true

require "pathname"
require "strscan"

module YARD
  module AgentDocs
    ##
    # Cross-reference rendering shared by the `module`/`class` `agentdocs`
    # templates: resolving a documented name — a `@param`/`@return` type, a
    # `@see` target, or a superclass/mixin name — to either a plain backtick
    # (not resolvable, or a self-reference to the object currently being
    # rendered) or a Markdown link to that object's own file.
    #
    # Requires the including template to provide an `object` method
    # returning the `YARD::CodeObjects::Base` currently being rendered, as
    # `YARD::Templates::Template` already does.
    #
    module CrossReferencing
      ##
      # A single token within a YARD type string: a namespace path
      # (`Foo::Bar`), a duck-type method reference (`#to_s`), a string/symbol
      # literal, or a bare word (`nil`, `void`). Anything else (`<`, `>`,
      # `{`, `}`, `,`, whitespace) is collection/union syntax, not a name to
      # resolve. Deliberately written on a single line: a free-spacing (`/x`)
      # regex would treat the `#` in the duck-type alternative as a comment
      # marker instead of a literal character, silently dropping the rest of
      # that alternative (see `CrossReferencing#type_ref`'s test coverage of
      # duck-type tokens for what that bug looked like).
      #
      TYPE_TOKEN =
        /#{::YARD::CodeObjects::NAMESPACEMATCH}|#{::YARD::CodeObjects::ISEP}#{::YARD::CodeObjects::METHODNAMEMATCH}|"[^"]*"|'[^']*'|\w+/

      ##
      # Resolves a type name to either a plain backtick (unresolved, or a
      # self-reference to the object currently being rendered) or a markdown
      # link to the target's own file. A compound type (e.g. `Array<Point>`)
      # is scanned token by token: only names that actually resolve get
      # pulled out into their own link, and everything else (collection
      # syntax, unresolved names) is folded into the surrounding backtick
      # span(s) it sits next to, so container punctuation is never left bare
      # outside a code span and no two code spans ever end up touching
      # (which markdown would misparse as one longer span).
      #
      # @param type_name [String, nil] a YARD type string, e.g. `"Point"` or
      #   `"Array<Point>"`
      # @return [String] markdown, possibly empty
      #
      def type_ref(type_name)
        return "" if type_name.nil? || type_name.empty?
        scanner = ::StringScanner.new(type_name)
        result = +""
        buffer = +""
        until scanner.eos?
          token = scanner.scan(TYPE_TOKEN)
          if token.nil? || token.empty?
            buffer << scanner.getch
            next
          end
          resolved = ::YARD::Registry.resolve(object, token, true, false)
          unless resolved && resolved != object
            buffer << token
            next
          end
          result << "`#{buffer}`" unless buffer.empty?
          buffer = +""
          result << "[`#{token}`](#{link_path(resolved)})"
        end
        result << "`#{buffer}`" unless buffer.empty?
        result
      end

      ##
      # Resolves a `@see` tag to either a plain backtick (unresolved, or
      # pointing back into the object currently being rendered) or a
      # markdown link to the target's own file.
      #
      # @param tag [::YARD::Tags::Tag]
      # @return [String] markdown
      #
      def see_ref(tag)
        name = tag.name
        resolved = ::YARD::Registry.resolve(object, name, true, false)
        owner = resolved && (resolved.is_a?(::YARD::CodeObjects::NamespaceObject) ? resolved : resolved.namespace)
        return "`#{name}`" if resolved.nil? || owner == object
        "[`#{name}`](#{link_path(resolved)})"
      end

      ##
      # @param target [::YARD::CodeObjects::Base] a namespace, method,
      #   constant, or attribute
      # @return [String] a path to the target's file, relative to the file
      #   currently being rendered
      #
      def link_path(target)
        namespace = target.is_a?(::YARD::CodeObjects::NamespaceObject) ? target : target.namespace
        target_file = ::Pathname.new("#{namespace.path.split('::').join('/')}.md")
        current_dir = ::Pathname.new("#{object.path.split('::').join('/')}.md").dirname
        target_file.relative_path_from(current_dir).to_s
      end
    end
  end
end
