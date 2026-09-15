# frozen_string_literal: true

include ::YARD::AgentDocs::CrossReferencing
include ::YARD::AgentDocs::DocstringSummary
include ::YARD::AgentDocs::ErbWithTrimMode
include ::YARD::AgentDocs::Frontmatter
include ::YARD::AgentDocs::Markdownify
include ::YARD::AgentDocs::NodocFilter
include ::YARD::AgentDocs::TextLayout
include ::YARD::AgentDocs::VisibilityInfo

# For `markup_for_file`, which resolves one extra file's markup dialect —
# see {#serialize_extra_file}. YARD's own templates reach it the same way,
# via `HtmlHelper`, which includes this module.
include ::YARD::Templates::Helpers::MarkupHelper

def init
  options.serializer.extension = "md" if options.serializer
  objects = run_verifier(options.objects).reject(&:root?).reject { |o| bare_nodoc?(o) }
  serialize_bundle_info
  serialize_index(objects)
  options.files.each { |file| serialize_extra_file(file) }
  objects.each { |object| serialize(object) }
end

# Generator-owned page carrying everything true of this bundle as a whole:
# per-build metadata in frontmatter, and the path-derivation/member-lookup/
# etc. reading conventions in the body. Those conventions were formerly an
# `index.md` preamble, then a standalone `navigating.md`; merging them here
# means one file answers both "how do I read this tree" and "is it still
# true", and the cold agent that follows `index.md` into the reading
# conventions gets the freshness signal at no extra read. See "Bundle-level
# `bundle.md`: freshness plus reading conventions in one file" under
# "Decisions".
#
# The page is almost entirely constant text — only the `generated:` pair in
# its OKF v0.2 concept header varies per build — so `bundle.erb` holds it
# verbatim, the same way every other page in this template is authored.
def serialize_bundle_info
  Templates::Engine.with_serializer("bundle.md", options.serializer) { erb(:bundle) }
end

# The OKF v0.2 §7 actor string identifying what produced this bundle
# (`<producer>/<version>`). The `agentdocs_generated_by` option overrides it
# so the byte-exact fixture comparison in `test/test_agentdocs_template.rb`
# doesn't break on every release bump.
def generated_by
  options[:agentdocs_generated_by] || "yard-agentdocs/#{::YARD::AgentDocs::VERSION}"
end

# Build wall-clock as an RFC 3339 UTC timestamp — deliberately *not* OKF
# v0.2 §5.2's "content's last meaningful change", which cannot answer the
# staleness question at all (regenerating unchanged source would leave it
# untouched, reading as fresh). Seconds granularity is likewise deliberate:
# the failure this signal exists to catch is source edited minutes ago,
# which a date alone can't see. The `agentdocs_generated_at` option (a
# +Time+) pins it for the fixture comparison.
def generated_at
  time = options[:agentdocs_generated_at] || ::Time.now
  time.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
end

# Renders one extra file (the README, or a `--files` guide) onto its own
# page, named after YARD's own `file.<name>.html` convention for extra
# files — `<name>` is the file's own basename, minus extension, so a
# guide's directory plays no part in its output path. Inline `{Name}`
# reference resolution reuses the same `markdownify` pipeline docstrings
# go through, but with heading demotion disabled — see
# `Markdownify#markdownify`'s `demote_headings` param. Resolution
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
#
# The dialect, unlike a docstring's, is resolved *per file* rather than
# from the run-wide `--markup` flag, exactly as YARD's own template does
# it (`templates/default/layout/html/setup.rb#diskfile`): a `#!markdown`
# shebang, which `ExtraFileObject` has already recorded in
# `attributes[:markup]`, wins; failing that `markup_for_file` maps the
# file's extension through `MarkupHelper::MARKUP_EXTENSIONS`; failing
# that it falls back to `options.markup`. A gem documenting a Markdown
# README under YARD's `rdoc` default is the common case this exists for —
# see "Extra files carry their own markup dialect" under "Decisions".
def serialize_extra_file(file)
  self.object = ::YARD::Registry.root
  frontmatter = "---\ntype: Guide\ntitle: #{yaml_quote(file.title)}\n---\n\n"
  file.attributes[:markup] ||= markup_for_file("", file.filename)
  content = markdownify(file.contents, markup: file.attributes[:markup], demote_headings: false)
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
