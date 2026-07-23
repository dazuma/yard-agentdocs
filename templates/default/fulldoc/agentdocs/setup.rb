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
  serialize_index(objects)
  options.files.each { |file| serialize_extra_file(file) }
  objects.each { |object| serialize(object) }
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

# " — summary" suffix for one index row, run through the same
# `TextLayout#summary_suffix`/`Markdownify#markdownify` pipeline
# `module/agentdocs`'s `nested_summary_line` uses (dialect conversion,
# heading demotion, inline `{Name}` reference resolution; still "absence
# means empty" — no suffix at all when the object has no doc comment). Sets
# {#object} to +object+ first so `summary_suffix`'s cross-reference
# resolution/self-reference checks use *that row's* namespace as context —
# but {#current_dir} is overridden below to stay pinned at the doc root
# regardless, since every row's summary is rendered onto the one `index.md`
# file, not onto +object+'s own page.
def index_summary_suffix(object)
  self.object = object
  summary_suffix(smart_summary(object.docstring))
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
