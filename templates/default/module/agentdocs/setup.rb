# frozen_string_literal: true

include ::YARD::AgentDocs::AttributeInfo
include ::YARD::AgentDocs::AuxiliaryTags
include ::YARD::AgentDocs::CrossReferencing
include ::YARD::AgentDocs::ErbWithTrimMode
include ::YARD::AgentDocs::ExampleTags
include ::YARD::AgentDocs::Markdownify
include ::YARD::AgentDocs::MethodSignature
include ::YARD::AgentDocs::VisibilityInfo

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

def any_members?
  nested_objects.any? || any_member_sections?
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

# Shared by {includes_line}/{extends_line}: a bold `**Label:** ref, ref`
# metadata line, or +nil+ when +mods+ is empty. Each ref links to the
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
  "**#{label}:** #{refs.join(', ')}"
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

# No " — text" suffix at all when +text+ is blank (e.g. no doc comment, or
# a tag with no trailing description) — same "absence means empty"
# convention as an empty Member Summary subgroup, rather than a dangling
# trailing dash. For a fixed, unconditionally-rendered prefix (Member
# Summary bullets; a Params/Yield Params bullet's already-parenthesized
# type).
def summary_suffix(text)
  markdown = markdownify(text)
  markdown.empty? ? "" : " — #{indent_continuation(markdown)}"
end

# Like {#summary_suffix}, but for a prefix that can itself be legitimately
# blank (a tag with no bracketed type, or no yielded names) — joins
# whichever of +prefix+/+text+ are non-blank with " — ", instead of always
# rendering +prefix+ first. Used for Returns/Yield Returns/Raises/Yields,
# where the type isn't wrapped in its own always-present punctuation the
# way a Params bullet's parens are.
def dash_join(prefix, text)
  markdown = markdownify(text)
  [prefix, indent_continuation(markdown)].reject { |s| s.to_s.empty? }.join(" — ")
end

# Every caller of {#summary_suffix}/{#dash_join} splices its result onto a
# single `- ` list-item bullet (Member Summary, Params/Yield Params/Raises,
# and — per the Returns/Yields/Yield Returns bullet-list shape — those too).
# A tag's raw +text+ can itself be multi-line (a soft-wrapped description,
# or genuine multi-paragraph prose with a nested list — real-world docstrings
# do this, e.g. API-client gems generated from language-agnostic specs), and
# splicing that verbatim would place later lines at column 0 in the output
# file — silently breaking out of the list item (or worse: an unmatched
# ` ``` ` landing at a line start opens an unclosed fence that swallows the
# rest of the document as code, verified against a real CommonMark parser).
# Indenting every line after the first by the width of a `- ` marker keeps
# the content nested as that one list item's continuation (verified this
# doesn't need to match the bullet's own, longer, visible prefix — just the
# marker) — and, as a side effect, keeps a prose-embedded `#`/`##` line from
# ever matching this format's own `grep '^## '`-style heading lookup, since
# it's indented, not at true column 0.
def indent_continuation(markdown, width: 2)
  lines = markdown.split("\n", -1)
  return markdown if lines.size <= 1
  indent = " " * width
  ([lines.first] + lines[1..].map { |line| line.empty? ? line : "#{indent}#{line}" }).join("\n")
end

def nested_summary_line(nested)
  "- [`#{nested.name}`](#{link_path(nested)})#{summary_suffix(nested.docstring.summary)}"
end

def constant_summary_line(const)
  "- `#{const.name}`#{summary_suffix(const.docstring.summary)}"
end

def attribute_summary_line(attr)
  suffix = attribute_annotation_short(attr)
  "- `##{attr[:name]}`#{" (#{suffix})" if suffix}#{summary_suffix(attribute_docstring_summary(attr))}"
end

def method_summary_line(meth)
  suffix = annotation_lines_short(meth).join(", ")
  "- `#{member_heading(meth)}`#{" (#{suffix})" unless suffix.empty?}#{summary_suffix(meth.docstring.summary)}"
end
