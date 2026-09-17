# frozen_string_literal: true

# The shared rendering logic — member gathering, signature building,
# cross-reference resolution, per-entry rendering — used directly for
# modules and `include`d wholesale by `class/agentdocs`, mirroring
# upstream's own `class/setup.rb` doing `include T('default/module')`.
#
# Two conventions govern this directory and `lib/yard/agentdocs/`. Both are
# preferences for new code, and the existing code follows them.
#
# **Document structure and control flow belong in the `.erb` file.** Which
# sections exist, in what order, looped over which members, should be
# visible in the template as ordinary `<%- if -%>`/`<%- each -%>`, so the
# `.erb` reads as a skeleton of the output. A Ruby method here that
# pre-builds and joins strings hides exactly that shape. This is viable
# because {YARD::AgentDocs::ErbWithTrimMode} turns trim mode on — without
# it, a conditional or loop leaks its surrounding blank lines into the
# output, which is what once forced the string-assembly approach. What
# stays Ruby: single-value formatting helpers with no multi-line structure
# to leak whitespace from (`type_ref`, `signature_text`, the various
# `*_summary_line`s), read as one-line `<%= %>` calls from the loops above.
#
# **A helper graduates to a `lib/yard/agentdocs/` mixin** once it is both
# generic enough that another template module could want it and nontrivial
# enough to deserve isolated unit tests — branching logic, parsing, regexes,
# anything bug-prone. `include` it here rather than leaving it a bare
# top-level method. Test it against a stub class that includes just that
# module (see `test/test_cross_referencing.rb`), so a failure names the one
# helper that broke instead of surfacing as a fixture mismatch. The mixins
# live under `lib/` rather than in a `setup.rb` because `fulldoc` and
# `module` are separate template modules and neither inherits the other's
# methods.

include ::YARD::AgentDocs::AttributeInfo
include ::YARD::AgentDocs::AuxiliaryTags
include ::YARD::AgentDocs::CrossReferencing
include ::YARD::AgentDocs::DocstringSummary
include ::YARD::AgentDocs::ErbWithTrimMode
include ::YARD::AgentDocs::ExampleTags
include ::YARD::AgentDocs::Frontmatter
include ::YARD::AgentDocs::Markdownify
include ::YARD::AgentDocs::MemberListing
include ::YARD::AgentDocs::MemberRoster
include ::YARD::AgentDocs::MethodSignature
include ::YARD::AgentDocs::NodocFilter
include ::YARD::AgentDocs::TextLayout
include ::YARD::AgentDocs::VisibilityInfo

def init
  sections :page
end

def page
  erb(:page)
end

# @group Frontmatter (OKF conformance — see docs/dev/OKF.md)

def frontmatter_type
  "Ruby #{object.type == :class ? 'Class' : 'Module'}"
end

# The same summary sentence {#nested_summary_line}/{#index_summary_suffix}
# extract, YAML-double-quoted (never left unquoted: a summary can start
# with a Markdown indicator character or contain ": ", either of which
# breaks an unquoted YAML plain scalar) — +nil+ when the object has no
# docstring, so {#frontmatter} can omit the key entirely rather than
# render `description: ""`.
def frontmatter_description
  summary = markdownify(smart_summary(object.docstring))
  return nil if summary.empty?

  yaml_quote(summary)
end

# @group Ancestry (superclass_line overridden for classes; modules have no
# superclass of their own)

def superclass_line
  nil
end

# Modules/classes `include`d directly in the parsed source, not ones mixed
# in transitively by a superclass (which {superclass_line} deliberately
# doesn't walk, so we can't know those either).
def includes_line
  mixin_line("Includes", object.mixins(:instance))
end

# Modules/classes `extend`ed directly in the parsed source (their instance
# methods become singleton/class methods). Same link-out convention as
# {includes_line} — a Class/Instance Methods section never duplicates an
# extended module's methods; only this line, and the module's own file,
# document them. Also covers the `extend self` pattern (a module extending
# itself): {mixin_line} renders that as an unlinked self-reference, the same
# policy prose cross-references already use (see
# {CrossReferencing#self_reference?}) — no synthetic class-method entry is
# fabricated for it. YARD's own default HTML template makes the same call:
# it surfaces the fact via an "Extended by" line but doesn't duplicate the
# method into a second listing.
def extends_line
  mixin_line("Extends", object.mixins(:class))
end

# A class/module reopened purely to nest another class/module inside it
# (e.g. `module Geometry; class Foo; ...; end; end`, once per nested type's
# own file) doesn't gain a new entry here just for that — the nested type
# already gets its own file and its own `- **Defined in:**` line pointing at
# that same path, so repeating it on the *namespace's* line would list
# every file in a multi-file gem (this is `object.files`' raw behavior;
# every file wrapping a nested class/module in the namespace counts as
# "reopening" it, which drowns out the signal for the common case of a
# namespace module that holds no direct members of its own). Only a file
# that contributes one of the object's own direct members (a constant,
# attribute, or method — not a nested class/module) counts as a second
# "reopened" location, alongside a primary file (see below).
#
# The primary file is `object.file` when the object has a docstring
# somewhere (deterministic: YARD always prioritizes whichever file carried
# the comment, regardless of parse order — verified directly against
# `CodeObjects::Base#files`). But when the object has *no* docstring
# anywhere (e.g. a bare `module Foo; end` stub, reopened only to nest
# something else inside it — settled rendering, see "Intentionally
# undocumented objects"), `object.file` falls back to whichever file YARD's
# parser happened to register first, which silently depends on `Dir.glob`'s
# directory-traversal order rather than anything meaningful (caught via
# `Geometry::ThreeD`: glob visits the `three_d/` subdirectory, and thus
# `three_d/point.rb`, before the sibling `three_d.rb`, even though
# `three_d.rb` sorts first lexicographically). To keep this line
# deterministic and independent of glob/parse order in that case, fall back
# to the lexicographically-first path among all the object's files instead.
#
# Multiple paths render as one comma-separated `- ` list item rather than
# switching to a per-path bulleted list like {#summary_suffix}'s callers do,
# since a bare path (no per-entry description, and no line number at this
# whole-object granularity) doesn't need one.
def defined_in_line
  member_files = object.children.reject { |c| c.is_a?(CodeObjects::NamespaceObject) }.map(&:file)
  primary = object.docstring.empty? ? object.files.map(&:first).min : object.file
  paths = ([primary] + member_files).compact.uniq
  "- **Defined in:** #{paths.map { |path| "`#{path}`" }.join(', ')}"
end

# Shared by {includes_line}/{extends_line}: a bulleted `- **Label:** ref,
# ref` metadata line, or +nil+ when +mods+ is empty. Each ref links to the
# mixin's own file when it resolves to real, parsed source and isn't a
# self-reference (e.g. `extend self`); otherwise it's a plain, unlinked
# backtick — same resolved/unresolved/self-reference policy every other
# cross-reference in this template already follows.
def mixin_line(label, mods)
  return nil if mods.empty?
  refs = mods.map do |mod|
    name = mod.name.to_s
    if mod.is_a?(CodeObjects::Proxy) || self_reference?(mod)
      "`#{name}`"
    else
      "[`#{name}`](#{link_path(mod)})"
    end
  end
  "- **#{label}:** #{refs.join(', ')}"
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

# @group Tag-text joining

# An `@option` tag's key/type/default/description quadruple, rendered as one
# **Options (`param`):** bullet. The default has no natural-syntax home in
# the signature the way an ordinary optional param's does (it's a key
# inside a captured hash, not a `def`-level parameter with its own `=
# default`), so — unlike {MethodSignature}'s "default renders in the
# signature only" policy — it's folded into the type parenthetical here,
# the only place left to put it.
def option_line(tag)
  pair = tag.pair
  default = pair.defaults&.first
  type = type_ref_first(pair)
  type_part = default ? "#{type}, default `#{default}`" : type
  "- `#{pair.name}` (#{type_part})#{summary_suffix(pair.text)}"
end

def nested_summary_line(nested)
  suffix = private_api_annotation_short(nested)
  link = "[`#{nested.name}`](#{link_path(nested)})"
  "- #{link}#{" (#{suffix})" if suffix}#{summary_suffix(smart_summary(nested.docstring))}"
end

def constant_summary_line(const)
  "- `#{const.name}`#{summary_suffix(smart_summary(const.docstring))}"
end

# Same `**Type:**` fallback as {AttributeInfo#attribute_type}: a constant
# with no `@return` tag (or one with no declared types) — a bare, comment-
# less assignment — falls back to `"Object"` rather than rendering blank,
# matching YARD's own human-facing template default for the same case.
def constant_type(const)
  types = const.tag(:return)&.types
  types.nil? || types.empty? ? "Object" : types.join(", ")
end

def attribute_summary_line(attr)
  suffix = ([attribute_annotation_short(attr)].compact + annotation_lines_short(attr.source_method)).join(", ")
  summary = attribute_docstring_summary(attr)
  "- `#{attribute_heading(attr)}`#{" (#{suffix})" unless suffix.empty?}#{summary_suffix(summary)}"
end

def method_summary_line(meth)
  suffix = (annotation_lines_short(meth) + [overrides_annotation_short(meth)].compact).join(", ")
  summary = meth.is_alias? ? "**Alias for:** `#{alias_original_heading(meth)}`" : smart_summary(meth.docstring)
  "- `#{member_heading(meth)}`#{" (#{suffix})" unless suffix.empty?}#{summary_suffix(summary)}"
end
