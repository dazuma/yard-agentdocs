# frozen_string_literal: true

include ::YARD::AgentDocs::CrossReferencing
include ::YARD::AgentDocs::DocstringSummary
include ::YARD::AgentDocs::ErbWithTrimMode
include ::YARD::AgentDocs::Frontmatter
include ::YARD::AgentDocs::Markdownify
include ::YARD::AgentDocs::NodocFilter
include ::YARD::AgentDocs::TextLayout
include ::YARD::AgentDocs::VisibilityInfo

def init
  options.serializer.extension = "md" if options.serializer
  objects = run_verifier(options.objects).reject(&:root?).reject { |o| bare_nodoc?(o) }
  serialize_navigating
  serialize_index(objects)
  options.files.each { |file| serialize_extra_file(file) }
  objects.each { |object| serialize(object) }
end

# Generator-owned page holding the path-derivation/member-lookup/etc.
# reading conventions for this tree — formerly an `index.md` preamble,
# relocated here so `index.md` itself is a conformant OKF §6 concept-listing
# (see "Root index.md restructured for OKF conformance" under "Decisions").
# Content is identical on every run (no per-object interpolation, and not
# sourced from a `--files` guide), so it's a plain string, same precedent as
# {#serialize_extra_file}'s own frontmatter construction.
def serialize_navigating
  content = <<~MARKDOWN
    ---
    type: Guide
    title: "Navigating these docs"
    ---

    # Navigating these docs

    - **Path derivation:** a class/module's file path mirrors its fully-qualified
      name, with `::` becoming a directory separator — e.g. `Foo::Bar` is
      `Foo/Bar.md`, `Foo::Bar::Baz` is `Foo/Bar/Baz.md`. If you already know the
      FQN you're after, go straight to that path; the index is only for
      discovering a name you don't have yet.
    - **Member lookup:** every constant, attribute, and method is its own `### `
      heading inside its class/module's file — `` ### NAME `` for constants,
      `` ### #name `` for instance methods/attributes, `` ### .name `` for class
      methods. `grep -n '^### '` in one file lists every member there with its
      exact line number; e.g. `grep -rn '^### #each' .` finds the `#each` method
      across the whole tree without knowing which class it belongs to.
    - **Inherited and mixed-in members aren't duplicated in full.** A
      class/module's file documents only members defined in its own source,
      plus a names-only **Inherited & Mixed-in Members** list in `## Member
      Summary` naming what its immediate superclass and directly-`include`d/
      `extend`ed modules each contribute — one hop only, not the full ancestry
      chain, and not anything from outside this project's own parsed source.
      For the actual docs behind any of those names, follow the
      `**Superclass:**`, `**Includes:**`, or `**Extends:**` link near the top
      of the file to that type's own file.
    - **Trailing metadata uses `*`, not `-`.** A member's own content bullets
      (`**Params:**`, `**Returns:**`, `**Raises:**`, etc.) always use `- `.
      Deprecation/note/abstract flags, aliasing, and trailing `**Since:**`/
      `**Version:**`/`**Author:**`/`**Defined in:**` lines always use `* `
      instead, and stack with no blank line between them — a deliberate marker
      change so they never render as part of the preceding content list.
  MARKDOWN
  Templates::Engine.with_serializer("navigating.md", options.serializer) { content }
end

# Renders one extra file (the README, or a `--files` guide) onto its own
# page, named after YARD's own `file.<name>.html` convention for extra
# files — `<name>` is the file's own basename, minus extension, so a
# guide's directory plays no part in its output path. Dialect conversion
# and inline `{Name}` reference resolution reuse the same `markdownify`
# pipeline docstrings go through, but with heading demotion disabled —
# see `Markdownify#markdownify`'s `demote_headings` param. Resolution
# context is pinned at the root namespace (an extra file isn't "about"
# any one class/module); {#current_dir} is already pinned at the doc root
# unconditionally for this whole template (see below), so no further
# override is needed here.
#
# Every extra file gets the same OKF-conformance frontmatter: a uniform
# `type: Guide` (README and `--files` guides render identically here, so
# neither earns its own `type`) and `title:` from `file.title` — the same
# value `index.md`'s own `## Guides` section already displays, always
# quoted since it's free-form text (a `# @title` comment, or a bare
# filename), never a guaranteed-safe identifier. No `description`: unlike
# a docstring, an extra file's body is unstructured, dialect-dependent
# prose with its own real heading structure, and OKF only requires
# `type` — see "Frontmatter on README/`--files` guide pages" under
# "Decisions".
def serialize_extra_file(file)
  self.object = ::YARD::Registry.root
  frontmatter = "---\ntype: Guide\ntitle: #{yaml_quote(file.title)}\n---\n\n"
  content = markdownify(file.contents, demote_headings: false)
  Templates::Engine.with_serializer("file.#{file.name}.md", options.serializer) { "#{frontmatter}#{content}" }
end

def serialize_index(objects)
  @indexed_objects = objects.select { |o| [:class, :module].include?(o.type) }.sort_by(&:path)
  Templates::Engine.with_serializer("index.md", options.serializer) { erb(:index) }
end

def indexed_object_path(object)
  "#{object.path.split('::').join('/')}.md"
end

# " - summary" suffix for one index row — dialect conversion, heading
# demotion, and inline `{Name}` reference resolution reuse the same
# `Markdownify#markdownify` pipeline `module/agentdocs`'s
# `nested_summary_line` uses; still "absence means empty" — no suffix at
# all when the object has no doc comment. Sets {#object} to +object+ first
# so cross-reference resolution/self-reference checks use *that row's*
# namespace as context — but {#current_dir} is overridden below to stay
# pinned at the doc root regardless, since every row's summary is rendered
# onto the one `index.md` file, not onto +object+'s own page.
#
# Deliberately doesn't delegate to the shared `TextLayout#summary_suffix`
# (used everywhere else in the tree — Member Summary bullets, Params,
# etc.): those stay `" — "` (em dash), unaffected. Only `index.md`'s own
# `* [Title](url) - description` rows use OKF's `" - "` (spaced hyphen)
# surface form, per §6 — see "Root index.md restructured for OKF
# conformance" under "Decisions".
def index_summary_suffix(object)
  self.object = object
  markdown = markdownify(smart_summary(object.docstring))
  markdown.empty? ? "" : " - #{indent_continuation(markdown)}"
end

def serialize(object)
  options.object = object
  Templates::Engine.with_serializer(object, options.serializer) { T(object.type).run(options) }
end

# `index.md` always lives at the doc root, no matter which object a given
# row's summary is about — see {#index_summary_suffix}.
def current_dir
  ::Pathname.new(".")
end
