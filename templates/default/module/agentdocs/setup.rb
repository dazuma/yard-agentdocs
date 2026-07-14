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
