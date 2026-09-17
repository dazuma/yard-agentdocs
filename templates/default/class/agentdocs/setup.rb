# frozen_string_literal: true

# What only classes have, on top of everything `module/agentdocs` renders:
# the `**Superclass:**`/`**Includes:**`/`**Extends:**` metadata lines and
# the synthetic `.new` entry sourced from `#initialize`.

include T("default/module/agentdocs")

def class_method_objects(namespace = object)
  ctor = namespace.meths(inherited: false, included: false).find(&:constructor?)
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
  "- **Superclass:** #{ref}"
end
