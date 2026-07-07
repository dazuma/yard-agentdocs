# frozen_string_literal: true

include T("default/module/agentdocs")

# Ruby core ancestry that's never actually parsed from source (Object,
# BasicObject, Kernel have no Ruby source for YARD to read), so it can't be
# derived generically from the registry. Narrow on purpose: covers the common
# "plain class with an implicit Object superclass" case, not general stdlib
# ancestry resolution.
CORE_ANCESTRY = {
  "BasicObject" => { superclass: nil, includes: [] },
  "Object" => { superclass: "BasicObject", includes: ["Kernel"] },
}.freeze

def class_method_objects
  ctor = object.meths(inherited: false).find(&:constructor?)
  list = super
  list += [ctor] if ctor
  list.sort_by { |m| member_name(m) }
end

def ancestors_line
  chain = pure_ancestor_chain
  return nil if chain.empty?
  "**Ancestors:** #{chain.map { |name| "`#{name}`" }.join(' → ')}"
end

def includes_line
  mods = mixin_modules
  return nil if mods.empty?
  "**Includes:** #{mods.map { |name| "`#{name}`" }.join(', ')}"
end

# @return [Array<String>] the class's pure superclass chain (excluding mixed-in
#   modules), by name, walking real parsed classes directly and falling back
#   to {CORE_ANCESTRY} once the chain reaches an unparsed proxy.
def pure_ancestor_chain
  chain = []
  current = object.superclass
  while current
    path = current.respond_to?(:path) ? current.path : current.to_s
    chain << path
    current = current.respond_to?(:superclass) ? current.superclass : CORE_ANCESTRY.dig(path, :superclass)
  end
  chain
end

# @return [Array<String>] modules mixed into the class's ancestry, by name:
#   both real `include`s in the parsed source and any contributed transitively
#   by {CORE_ANCESTRY} (e.g. `Kernel` via `Object`).
def mixin_modules
  mods = object.mixins(:instance).map(&:path)
  pure_ancestor_chain.each { |name| mods.concat(CORE_ANCESTRY.dig(name, :includes) || []) }
  mods.uniq
end
