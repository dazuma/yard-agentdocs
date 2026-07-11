# frozen_string_literal: true

require "pathname"

include ::YARD::AgentDocs::ErbWithTrimMode

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

# @group Ancestry (overridden for classes; modules show neither line)

def superclass_line
  nil
end

def includes_line
  nil
end

# @group Cross-referencing

# Resolves a type/`@see` name to either a plain backtick (unresolved, or a
# self-reference to the object currently being rendered) or a markdown link
# to the target's own file.
def type_ref(type_name)
  return "" if type_name.nil? || type_name.empty?
  resolved = Registry.resolve(object, type_name, true, false)
  return "`#{type_name}`" if resolved.nil? || resolved == object
  "[`#{type_name}`](#{link_path(resolved)})"
end

def see_ref(tag)
  name = tag.name
  resolved = Registry.resolve(object, name, true, false)
  owner = resolved && (resolved.is_a?(CodeObjects::NamespaceObject) ? resolved : resolved.namespace)
  return "`#{name}`" if resolved.nil? || owner == object
  "[`#{name}`](#{link_path(resolved)})"
end

# @param [CodeObjects::Base] target a namespace, method, constant, or attribute
# @return [String] a path to the target's file, relative to the file currently
#   being rendered
def link_path(target)
  namespace = target.is_a?(CodeObjects::NamespaceObject) ? target : target.namespace
  target_file = Pathname.new("#{namespace.path.split('::').join('/')}.md")
  current_dir = Pathname.new("#{object.path.split('::').join('/')}.md").dirname
  target_file.relative_path_from(current_dir).to_s
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

# @group Attribute helpers

def attribute_source_method(attr)
  attr[:read] || attr[:write]
end

def attribute_type(attr)
  tag = attribute_source_method(attr).tag(:return)
  tag&.types&.first
end

# Bold-line annotation, e.g. for a `**Read-only.**` metadata line.
def attribute_annotation(attr)
  return "Read-only." if attr[:write].nil?
  return "Write-only." if attr[:read].nil?
  nil
end

# Parenthetical annotation for a Member Summary bullet, e.g. `(read-only)`.
def attribute_annotation_short(attr)
  return "read-only" if attr[:write].nil?
  return "write-only" if attr[:read].nil?
  nil
end

def attribute_docstring(attr)
  attribute_source_method(attr).docstring.strip
end

def attribute_docstring_summary(attr)
  attribute_source_method(attr).docstring.summary
end

def attribute_file(attr)
  attribute_source_method(attr).file
end

def attribute_line(attr)
  attribute_source_method(attr).line
end

# @group Method signatures

OPERATOR_METHOD_NAMES = [
  "+", "-", "*", "/", "%", "**", "==", "!=", "<=>", "<", ">", "<=", ">=",
  "<<", ">>", "&", "|", "^", "~", "!", "[]", "[]=", "=~", "+@", "-@"
].freeze

def operator?(meth)
  OPERATOR_METHOD_NAMES.include?(meth.name.to_s)
end

# The display name for a member: the constructor is always shown as `new`
# (documenting `#initialize` under the synthetic `Class.new` entry).
def member_name(meth)
  meth.constructor? ? "new" : meth.name.to_s
end

# Whether a member is addressed with `.` (class-level, or the constructor) or
# `#` (instance-level).
def class_level?(meth)
  meth.constructor? || meth.scope == :class
end

def member_heading(meth)
  "#{class_level?(meth) ? '.' : '#'}#{member_name(meth)}"
end

def receiver_name(meth)
  class_level?(meth) ? object.name.to_s : object.name.to_s.downcase
end

def param_names(meth)
  meth.parameters.map { |name, _default| name.to_s }
end

def signature_return_type(meth)
  return object.name.to_s if meth.constructor?
  tag = meth.tag(:return)
  tag&.types&.first
end

def signature_text(meth)
  name = member_name(meth)
  params = param_names(meth)
  call =
    if !meth.constructor? && operator?(meth) && meth.scope == :instance && params.size == 1
      "#{receiver_name(meth)} #{name} #{params.first}"
    else
      "#{receiver_name(meth)}.#{name}(#{params.join(', ')})"
    end
  return_type = signature_return_type(meth)
  return_type ? "#{call} → #{return_type}" : call
end

# @group Method body (everything below the heading in a method entry)

def method_return_tag(meth)
  meth.constructor? ? nil : meth.tag(:return)
end
