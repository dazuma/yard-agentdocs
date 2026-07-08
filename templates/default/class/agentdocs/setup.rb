# frozen_string_literal: true

include T("default/module/agentdocs")

def class_method_objects
  ctor = object.meths(inherited: false).find(&:constructor?)
  list = super
  list += [ctor] if ctor
  list.sort_by { |m| member_name(m) }
end

# Only the immediate superclass, not the full chain: a class's more distant
# ancestors (and the modules they mix in) may be defined outside the parsed
# source (another gem, stdlib), so we can't reliably know them in general.
def superclass_line
  superclass = object.superclass
  return nil unless superclass
  path = superclass.respond_to?(:path) ? superclass.path : superclass.to_s
  "**Superclass:** `#{path}`"
end

# Only modules `include`d directly in the parsed source, not ones mixed in
# transitively by a superclass (which, per {superclass_line}, we don't walk).
def includes_line
  mods = object.mixins(:instance).map(&:path)
  return nil if mods.empty?
  "**Includes:** #{mods.map { |name| "`#{name}`" }.join(', ')}"
end
