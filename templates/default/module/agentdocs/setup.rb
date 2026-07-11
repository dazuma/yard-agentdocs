# frozen_string_literal: true

include ::YARD::AgentDocs::AttributeInfo
include ::YARD::AgentDocs::CrossReferencing
include ::YARD::AgentDocs::ErbWithTrimMode
include ::YARD::AgentDocs::MethodSignature

def init
  sections :page
end

def page
  erb(:page)
end

# @group Member listings

def nested_objects
  list = object.children.select { |c| [:module, :class].include?(c.type) }
  run_verifier(list).sort_by { |o| o.name.to_s }
end

def constant_objects
  list = object.constants(inherited: false, included: false)
  run_verifier(list).sort_by { |o| o.name.to_s }
end

def attribute_objects
  entries = object.attributes[:instance].map do |name, rw|
    { name: name.to_s, read: rw[:read], write: rw[:write] }
  end
  entries = entries.select { |a| run_verifier([attribute_source_method(a)]).any? }
  entries.sort_by { |a| a[:name] }
end

def class_method_objects
  list = object.meths(inherited: false, included: false).select { |m| m.scope == :class }
  run_verifier(list).sort_by { |m| member_name(m) }
end

# Excludes both inherited (superclass) and mixed-in (`include`d module)
# methods: a superclass's or directly-`include`d module's methods are
# documented on their own page (and, for a mixin, pointed to via
# {includes_line}), not duplicated here — see the "Mixin/inheritance
# content strategy" decision in devdocs/DESIGN.md. `:inherited` is a no-op
# for modules (they have no superclass) but real for classes, since
# `ClassObject#meths` overrides the base `NamespaceObject#meths` to add it.
def instance_method_objects
  list = object.meths(inherited: false, included: false).select do |m|
    m.scope == :instance && !m.is_attribute? && !m.constructor?
  end
  run_verifier(list).sort_by { |m| member_name(m) }
end

def any_member_sections?
  constant_objects.any? || attribute_objects.any? || class_method_objects.any? || instance_method_objects.any?
end

# @group Ancestry (overridden for classes; modules show none of these lines)

def superclass_line
  nil
end

def includes_line
  nil
end

def extends_line
  nil
end

# @group Member rendering

def render_constant(const)
  @constant = const
  erb(:constant_entry).strip
end

def render_attribute(attr)
  @attribute = attr
  erb(:attribute_entry).strip
end

def render_method(meth)
  @method = meth
  erb(:method_entry).strip
end

# @group Member Summary bullet lines

def nested_summary_line(nested)
  "- [`#{nested.name}`](#{link_path(nested)}) — #{nested.docstring.summary}"
end

def constant_summary_line(const)
  "- `#{const.name}` — #{const.docstring.summary}"
end

def attribute_summary_line(attr)
  suffix = attribute_annotation_short(attr)
  "- `##{attr[:name]}`#{" (#{suffix})" if suffix} — #{attribute_docstring_summary(attr)}"
end

def method_summary_line(meth)
  "- `#{member_heading(meth)}` — #{meth.docstring.summary}"
end
