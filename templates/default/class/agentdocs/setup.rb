# frozen_string_literal: true

include T("default/module/agentdocs")

def class_method_objects
  ctor = object.meths(inherited: false, included: false).find(&:constructor?)
  list = super
  list += [ctor] if ctor
  list.sort_by { |m| member_name(m) }
end

# Only the immediate superclass, not the full chain: a class's more distant
# ancestors (and the modules they mix in) may be defined outside the parsed
# source (another gem, stdlib), so we can't reliably know them in general.
#
# Links to the superclass's own file when it's a real, parsed class (an
# unresolved `CodeObjects::Proxy`, e.g. `Object`, stays a plain backtick —
# nothing to link to). Display text is always the name as it was actually
# written after `<` in the source (`Proxy#name`/`Base#name` never
# fully-qualify), matching how {type_ref}/{see_ref} display whatever the
# docstring author wrote, rather than the resolved fully-qualified path.
def superclass_line
  superclass = object.superclass
  return nil unless superclass
  name = superclass.name.to_s
  ref = superclass.is_a?(CodeObjects::Proxy) ? "`#{name}`" : "[`#{name}`](#{link_path(superclass)})"
  "**Superclass:** #{ref}"
end

# Only modules `include`d directly in the parsed source, not ones mixed in
# transitively by a superclass (which, per {superclass_line}, we don't walk).
#
# Links to the module's own file when it's a real, parsed module (an
# unresolved `CodeObjects::Proxy` stays a plain backtick); display text is
# always the name as written in the `include` call, same convention as
# {superclass_line}.
def includes_line
  mods = object.mixins(:instance)
  return nil if mods.empty?
  refs = mods.map do |mod|
    name = mod.name.to_s
    mod.is_a?(CodeObjects::Proxy) ? "`#{name}`" : "[`#{name}`](#{link_path(mod)})"
  end
  "**Includes:** #{refs.join(', ')}"
end

# Modules `extend`ed directly in the parsed source (their instance methods
# become this class's singleton/class methods). Same link-out convention as
# {includes_line} — the class's own Class Methods section does not duplicate
# an extended module's methods; only this line, and the module's own file
# has the full docs.
def extends_line
  mods = object.mixins(:class)
  return nil if mods.empty?
  refs = mods.map do |mod|
    name = mod.name.to_s
    mod.is_a?(CodeObjects::Proxy) ? "`#{name}`" : "[`#{name}`](#{link_path(mod)})"
  end
  "**Extends:** #{refs.join(', ')}"
end
