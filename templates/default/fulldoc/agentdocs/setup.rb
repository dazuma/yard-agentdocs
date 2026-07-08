# frozen_string_literal: true

include ::YARD::AgentDocs::ErbWithTrimMode

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

def top_level_object_path(object)
  "#{object.path.split('::').join('/')}.md"
end

def serialize(object)
  options.object = object
  Templates::Engine.with_serializer(object, options.serializer) { T(object.type).run(options) }
end
