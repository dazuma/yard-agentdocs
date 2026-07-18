# frozen_string_literal: true

include ::YARD::AgentDocs::ErbWithTrimMode

def init
  options.serializer.extension = "md" if options.serializer
  objects = run_verifier(options.objects).reject(&:root?)
  serialize_index(objects)
  objects.each { |object| serialize(object) }
end

def serialize_index(objects)
  @indexed_objects = objects.select { |o| [:class, :module].include?(o.type) }.sort_by(&:path)
  Templates::Engine.with_serializer("index.md", options.serializer) { erb(:index) }
end

def indexed_object_path(object)
  "#{object.path.split('::').join('/')}.md"
end

# No " — summary" suffix at all when the object has no doc comment — same
# "absence means empty" convention `module/agentdocs`'s summary lines use
# (see devdocs/DESIGN.md's "Intentionally undocumented objects" decision),
# rather than a dangling trailing dash. Named distinctly from
# `module/agentdocs`'s `TextLayout#summary_suffix(text)` (a same-named,
# different-signature method in a sibling template) — this one takes the
# raw code object and splices its summary unconverted, without
# `markdownify`, unlike that one.
def index_summary_suffix(object)
  summary = object.docstring.summary
  summary.empty? ? "" : " — #{summary}"
end

def serialize(object)
  options.object = object
  Templates::Engine.with_serializer(object, options.serializer) { T(object.type).run(options) }
end
