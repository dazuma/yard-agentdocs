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
        return "`#{name}`" if resolved.nil? || self_reference?(resolved)
        "[`#{name}`](#{link_path(resolved)})"
      end

      ##
      # A single YARD-style inline cross-reference within prose: `{Name}`
      # or `{Name label text}`, or an escaped `\{...}`/`!{...}` (the escape
      # character is captured in group 1 so {#resolve_references} can strip
      # it without attempting resolution — mirrors YARD's own
      # `HtmlHelper#resolve_links`, minus the HTML-specific escape/anchor
      # special cases that don't apply to a Markdown target).
      #
      REFERENCE = /(\\|!)?\{(?!\})(\S+?)(?:[ \t]+([^{}]*?))?\}/

      ##
      # Resolves YARD's inline `{Name}`/`{Name label text}` cross-reference
      # syntax within prose. Must run on already-dialect-converted text —
      # {Markdownify#markdownify} calls this as its final step, so template
      # code never needs to call it directly — mirroring how YARD's own
      # `resolve_links` runs on already-`htmlify`'d output (see "Docstring
      # markup dialect" under "Decisions" in `devdocs/DESIGN.md`).
      #
      # A reference inside a backtick code span (of any length, so this
      # also covers a fenced ` ``` ` block) is left completely alone, since
      # nothing inside a Markdown code span is ever markup. Escaped
      # (`\{...}`/`!{...}`) and unresolved references are also left
      # completely alone, braces included — never partially rewritten.
      #
      # @param text [String] Markdown prose
      # @return [String] the same prose with resolvable references rewritten
      #   as Markdown links
      #
      def resolve_references(text)
        scanner = ::StringScanner.new(text)
        result = +""
        until scanner.eos?
          if (run = scanner.scan(/`+/))
            closing = /(?<!`)#{::Regexp.quote(run)}(?!`)/
            span = scanner.scan_until(closing)
            result << run << (span || scanner.rest)
            scanner.terminate unless span
          else
            result << scanner.scan(/[^`]+/).gsub(REFERENCE) { render_reference(::Regexp.last_match) }
          end
        end
        result
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

      private

      # Renders one REFERENCE match: the literal text, unchanged, for an
      # escape or an unresolved name; otherwise a resolved link (or, for a
      # same-file self-reference, just the label/name with no link).
      def render_reference(match)
        escape = match[1]
        name = match[2]
        label = match[3]
        return match[0][1..] if escape
        resolved = ::YARD::Registry.resolve(object, name, true, false)
        return match[0] if resolved.nil?
        return label || "`#{name}`" if self_reference?(resolved)
        "[#{label || "`#{name}`"}](#{link_path(resolved)})"
      end

      # Whether +resolved+ lives in the same file as the object currently
      # being rendered — same policy `see_ref` uses.
      def self_reference?(resolved)
        owner = resolved.is_a?(::YARD::CodeObjects::NamespaceObject) ? resolved : resolved.namespace
        owner == object
      end
    end
  end
end
