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
    # Also home to {#transform_outside_code_spans}, a private
    # backtick-code-span-skipping scanner with no cross-reference logic of
    # its own — it lives here (rather than in a third module) because
    # {#resolve_references} is one of its two callers, and {Markdownify},
    # its other caller, already requires this module to be mixed in.
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
      # {#type_ref} for every type a tag declares, comma-joined — the
      # repeated `tag.types && tag.types.join(", ")` dig, in one place. Same
      # "a same-tag union and multiple tags of the same kind are both just
      # 'more than one type token'" policy the "Multiple return types"
      # decision in devdocs/DESIGN.md settled for Returns/Yield Returns/the
      # signature arrow, extended here to every remaining bullet-list site
      # that funnels through this helper (`@param`, `@option`, `@yieldparam`,
      # `@raise`) — see "Union types on the remaining first-type-only tag
      # sites" under "Decisions". Despite the name, kept as-is rather than
      # renamed: it's still "the tag's type(s), rendered," and every call
      # site already reads naturally with it.
      #
      # @param tag [::YARD::Tags::Tag, nil]
      # @return [String] markdown, possibly empty (for a `nil` tag, or one
      #   with no declared types)
      #
      def type_ref_first(tag)
        type_ref(tag && tag.types && tag.types.join(", "))
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
        transform_outside_code_spans(text) do |segment|
          segment.gsub(REFERENCE) { render_reference(::Regexp.last_match) }
        end
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
        target_file.relative_path_from(current_dir).to_s
      end

      private

      # The directory {#link_path} resolves a relative path from — the
      # directory of the file currently being rendered. Defaults to
      # {#object}'s own file location, which is correct for every
      # `module`/`class`-template page: the page's location and its
      # cross-reference resolution context (also {#object}) are one and the
      # same object there. `fulldoc/agentdocs`'s index page overrides this:
      # it lists many different objects' summaries on one page fixed at the
      # doc root, so the resolution context (still each row's own object,
      # via {#object}) and the path base (always the root) diverge — see
      # "index.md's per-entry summary" under "Decisions" in
      # `devdocs/DESIGN.md`.
      #
      # @return [::Pathname]
      #
      def current_dir
        ::Pathname.new("#{object.path.split('::').join('/')}.md").dirname
      end

      # Scans +text+ for backtick code spans (of any length, so this also
      # covers a fenced ` ``` ` block) and yields every segment *outside*
      # one of those spans to the block for rewriting, passing each code
      # span itself through untouched. Shared by {#resolve_references}
      # (which must never rewrite a `{...}` reference sitting inside a code
      # span) and {Markdownify#demote_headings} (same requirement, for a
      # `#` heading marker) — both need the same nontrivial
      # backtick-run-skipping scan, so it lives here once; {Markdownify}'s
      # own docstring notes it requires {CrossReferencing} to be mixed in
      # for exactly this reason.
      #
      # @param text [String]
      # @yieldparam segment [String] a run of +text+ containing no backtick
      #   code span
      # @yieldreturn [String] the segment, rewritten
      # @return [String] +text+ with every non-code-span segment replaced by
      #   the block's return value, and every code span left exactly as-is
      #
      def transform_outside_code_spans(text)
        scanner = ::StringScanner.new(text)
        result = +""
        until scanner.eos?
          if (run = scanner.scan(/`+/))
            # A closing run of the same backtick length, not itself
            # adjacent to another backtick (so ``` doesn't prematurely
            # close on the first two backticks of a four-backtick run).
            closing = /(?<!`)#{::Regexp.quote(run)}(?!`)/
            span = scanner.scan_until(closing)
            result << run << (span || scanner.rest)
            scanner.terminate unless span
          else
            result << yield(scanner.scan(/[^`]+/))
          end
        end
        result
      end

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
