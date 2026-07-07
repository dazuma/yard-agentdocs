# frozen_string_literal: true

def init
  options.serializer.extension = "md" if options.serializer
  objects = run_verifier(options.objects).reject(&:root?)
  serialize_index(objects)
  objects.each { |object| serialize(object) }
end

def serialize_index(objects)
  @top_level_objects = objects.select { |o| o.namespace.root? }.sort_by { |o| o.name.to_s }
  Templates::Engine.with_serializer("index.md", options.serializer) { erb(:index) }
end

def top_level_summary_lines
  @top_level_objects.map do |o|
    "- [`#{o.name}`](#{o.path.split('::').join('/')}.md) — #{o.docstring.summary}"
  end.join("\n")
end

def serialize(object)
  options.object = object
  Templates::Engine.with_serializer(object, options.serializer) { T(object.type).run(options) }
end
