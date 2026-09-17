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
          resolved = resolve_name(token)
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
      # 'more than one type token'" policy already settled for Returns/Yield
      # Returns/the signature arrow, extended here to every remaining
      # bullet-list site that funnels through this helper (`@param`,
      # `@option`, `@yieldparam`, `@raise`). Despite the name, kept as-is
      # rather than
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
      # Resolves a `@see` tag's target to a markdown link — the same
      # bare-URL handling {#render_url_reference} gives an inline `{url}`
      # reference, or a plain backtick (unresolved, or pointing back into
      # the object currently being rendered) or link to the target's own
      # file for an object name. Deliberately ignores +tag.text+ (the
      # optional trailing description, e.g. `@see Foo#bar Some label`) —
      # the caller dash-joins that separately, the same "reference, then
      # ` — description`" split every other multi-entry tag
      # (`@raise`/`@param`/...) already uses, rather than folding the
      # description into the link's own display text the way an inline
      # `{url label}` reference does.
      #
      # @param tag [::YARD::Tags::Tag]
      # @return [String] markdown
      #
      def see_ref(tag)
        name = tag.name
        return render_url_reference(name, nil) if url_reference?(name)
        resolved = resolve_name(name)
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
      # Prefix marking a {REFERENCE} name as a `{file:path}`/`{file:path
      # label text}` guide reference (YARD's own `file:` `linkify` form)
      # rather than an object name — {#render_reference} dispatches to
      # {#render_file_reference} when a match's name starts with this.
      #
      FILE_REFERENCE_PREFIX = "file:"

      ##
      # `{include:file:path}` — YARD's other spelling of a `file:`
      # reference (`BaseHelper#linkify`'s `include:file:` form). Checked
      # ahead of {FILE_REFERENCE_PREFIX} in {#render_reference} (a name
      # starting with this also starts with `"include:"`) and dispatches to
      # the very same {#render_file_reference}: `{include:...}`/`{render:...}`
      # collapse to plain links here rather than the content-embedding/
      # whole-page duplication real YARD does for them.
      #
      INCLUDE_FILE_REFERENCE_PREFIX = "include:file:"

      ##
      # `{include:Name}`/`{render:Name}` — YARD's own content-embedding
      # forms, repurposed here as plain aliases for a bare `{Name}`
      # reference (see {INCLUDE_FILE_REFERENCE_PREFIX}'s note).
      # {#render_reference} strips whichever of these prefixes matched
      # before falling through to its ordinary object-resolution path, so
      # both resolve identically to `{Name}` — including from the same
      # scope, a deliberate unification rather than preserving YARD's own
      # differing `include:`/`render:` resolution roots (`object.namespace`
      # and `object`, respectively): there's no reason two spellings of
      # "link to this" should ever resolve from different places.
      #
      OBJECT_REFERENCE_ALIAS_PREFIXES = ["include:", "render:"].freeze

      ##
      # Marks a {REFERENCE} name as a bare-URL reference (YARD's own
      # `linkify` form for `{http://example.com}`) rather than an object
      # name or a `file:`/`include:`/`render:` form — mirrors
      # `BaseHelper#linkify`'s own dispatch exactly (`name` contains this
      # anywhere). Unlike every other {REFERENCE} form, there's no lookup
      # involved: the URL text itself *is* the target, so a match here
      # always "resolves."
      #
      URL_REFERENCE_PATTERN = %r{://}

      ##
      # {URL_REFERENCE_PATTERN}'s companion: marks a {REFERENCE} name as a
      # `{mailto:foo@example.com}` reference — YARD's other `linkify` form
      # for a bare-URL-shaped target, which has no `"://"` to match on.
      #
      MAILTO_REFERENCE_PREFIX = "mailto:"

      ##
      # Resolves YARD's inline `{Name}`/`{Name label text}` cross-reference
      # syntax within prose. Must run on already-dialect-converted text —
      # {Markdownify#markdownify} calls this as its final step, so template
      # code never needs to call it directly — mirroring how YARD's own
      # `resolve_links` runs on already-`htmlify`'d output.
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

      # Resolves +name+ against the object currently being rendered, then —
      # if that fails — retries from each successively higher lexical
      # ancestor until one succeeds or the root namespace is exhausted.
      #
      # Works around a real YARD limitation: `RegistryResolver#lookup_by_path`
      # caps *lexical* (non-inheritance) method lookups at exactly one
      # namespace hop from wherever resolution started, silently discarding
      # an otherwise-valid match found further up. A plain single
      # `Registry.resolve(object, ...)`
      # call inherits that cap relative to +object+'s own position. Retrying
      # with a *different* starting namespace doesn't lift the cap directly
      # (this deliberately never reaches into `RegistryResolver`'s private
      # internals to do that) — instead, each retry is a fresh top-level
      # call, whose own internal hop count resets to zero relative to its
      # own start, so a retry from close enough to the real target always
      # lands within the one-hop allowance on its own. Verified against
      # YARD's own source to recover every real case the plain single call
      # misses, with no false positives.
      #
      # @param name [String]
      # @return [::YARD::CodeObjects::Base, nil]
      #
      def resolve_name(name)
        # `true, false` is inheritance search on, proxy fallback off: the
        # call returns a real `CodeObject` or `nil`, which is exactly the
        # "is this documented, and therefore worth linking" question. With
        # proxy fallback on it would answer with a `Proxy` for any name at
        # all, and every backticked type would become a broken link.
        resolved = ::YARD::Registry.resolve(object, name, true, false)
        return resolved if resolved
        namespace = object&.namespace
        while namespace
          resolved = ::YARD::Registry.resolve(namespace, name, true, false)
          return resolved if resolved
          namespace = namespace.namespace
        end
        nil
      end

      # The directory {#link_path} resolves a relative path from — the
      # directory of the file currently being rendered. Defaults to
      # {#object}'s own file location, which is correct for every
      # `module`/`class`-template page: the page's location and its
      # cross-reference resolution context (also {#object}) are one and the
      # same object there. `fulldoc/agentdocs`'s index page overrides this:
      # it lists many different objects' summaries on one page fixed at the
      # doc root, so the resolution context (still each row's own object,
      # via {#object}) and the path base (always the root) diverge.
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
        return render_url_reference(name, label) if url_reference?(name)
        if name.start_with?(INCLUDE_FILE_REFERENCE_PREFIX)
          return render_file_reference(name.delete_prefix(INCLUDE_FILE_REFERENCE_PREFIX), label, match[0])
        end
        if name.start_with?(FILE_REFERENCE_PREFIX)
          return render_file_reference(name.delete_prefix(FILE_REFERENCE_PREFIX), label, match[0])
        end
        object_name = object_reference_name(name)
        resolved = resolve_name(object_name)
        return match[0] if resolved.nil?
        return label || "`#{object_name}`" if self_reference?(resolved)
        "[#{label || "`#{object_name}`"}](#{link_path(resolved)})"
      end

      # Strips a leading `{OBJECT_REFERENCE_ALIAS_PREFIXES}` entry (present
      # for an `{include:Name}`/`{render:Name}` reference), or returns
      # +name+ unchanged for an ordinary bare `{Name}` reference.
      def object_reference_name(name)
        prefix = OBJECT_REFERENCE_ALIAS_PREFIXES.find { |candidate| name.start_with?(candidate) }
        prefix ? name.delete_prefix(prefix) : name
      end

      # Whether a {REFERENCE} name is a bare-URL/`mailto:` reference — see
      # {URL_REFERENCE_PATTERN}.
      def url_reference?(name)
        name.match?(URL_REFERENCE_PATTERN) || name.start_with?(MAILTO_REFERENCE_PREFIX)
      end

      # Renders a `{url}`/`{url label text}` reference: always resolves (the
      # URL itself is the target, no lookup involved) to a Markdown link,
      # backticked display text when unlabeled (same convention every other
      # unlabeled {REFERENCE} form uses) or the label as plain prose when
      # given. The destination is always wrapped in angle brackets
      # (`(<url>)`, not `(url)`) — verified against several real Markdown
      # parsers — to keep an unescaped `(`/`)` pair in the URL
      # itself (e.g. a Wikipedia disambiguation link) from corrupting the
      # surrounding `[...](...)` link syntax.
      def render_url_reference(url, label)
        "[#{label || "`#{url}`"}](<#{url}>)"
      end

      # Renders a `{file:path}`/`{file:path label text}` reference: +path+
      # (matched against each `--files`/`--readme` entry's own +filename+ —
      # the literal path passed on the CLI, same convention `link_path`'s
      # object resolution already follows) resolves to a Markdown link to
      # that guide's own rendered page. A path matching no registered guide
      # is left completely untouched, braces included — same "never rewrite
      # what doesn't resolve" policy {#render_reference} already applies to
      # an unresolved `{Name}`, and a deliberate departure from real YARD's
      # `file:` link, which resolves any path on disk whether or not a page
      # for it actually exists.
      def render_file_reference(path, label, original)
        file = options.files.find { |candidate| candidate.filename == path }
        return original if file.nil?
        target = ::Pathname.new("file.#{file.name}.md").relative_path_from(current_dir).to_s
        "[#{label || "`#{file.title}`"}](#{target})"
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
