# Design

This document describes the design of `yard-agentdocs` — a [YARD](https://yardoc.org/)
plugin that renders Ruby API reference documentation in a format meant for coding
agents to look up efficiently, rather than for human browsing.

It is a living design document, and currently reflects a **pre-implementation**
state: nothing below is finalized. Decisions get logged here as we make them, and
open questions stay open (and listed) until they're resolved. This file is the
source of truth for design; keep it in sync as understanding improves.

## Goals

- Let an agent fetch the reference info it needs for a Ruby class/method — e.g.
  "what are the params and return type of `Foo#bar`?" — via a single, cheap file
  read, instead of grepping/parsing source or crawling an HTML yardoc site.
- Minimize the input tokens an agent spends per lookup: both the size of any one
  file it reads, and the number of round trips (searches, index lookups) needed
  to find it.
- Cover the Ruby/YARD documentation surface an agent is actually likely to need:
  method signatures (including overloads), params, return/yield types, raised
  errors, inheritance and mixins, visibility, constants/attributes, and
  cross-references (`@see`, param/return types linking to other documented
  objects) — without forcing an agent to load unrelated context to resolve them.

## Non-goals

- Replacing YARD's normal HTML output for human browsing. This plugin adds an
  additional output format; it does not change or replace the default one.
- Being a general-purpose YARD template framework. The output format can be
  opinionated and narrow, tuned specifically for agent consumption.

## Design strategy: example-driven

Rather than deciding the output format up front in the abstract, we're building
it against a concrete worked example:

1. **`example/lib`** — hand-written Ruby source designed to exercise the range of
   Ruby/YARD documentation features we want the plugin to handle well: classes
   and modules (including nesting), inheritance, mixins, singleton methods,
   method overloads, attributes, constants, blocks/yields, visibility
   (public/protected/private), and common YARD tags (`@param`, `@return`,
   `@yield`/`@yieldparam`, `@raise`, `@see`, `@example`, `@deprecated`, `@since`,
   `@abstract`, etc.).
2. **`example/doc`** — the hand-authored, *ideal* target output for that source:
   what we want an agent to actually see when it looks up each of those
   documented objects. We iterate on this directly (as plain files we read and
   critique) until we're happy with the shape, granularity, and content of the
   output — before writing any plugin code to generate it.
3. Once `example/doc` is stable, the `(example/lib, example/doc)` pair becomes
   the primary test fixture for the real implementation: the plugin should
   generate output equivalent to `example/doc` when run against `example/lib`.

This lets us iterate quickly on the format (editing markdown by hand) before
sinking time into the YARD template/handler mechanics needed to generate it.

## Example coverage checklist

This is the working checklist of Ruby language features and YARD tags/directives
that `example/lib` should exercise, so `example/doc` ends up covering the
documentation surface an agent is actually likely to hit. Items are grouped by
category; unchecked boxes are proposed, not yet built. This list is expected to
grow/shrink as we build the example and find gaps or redundancy.

### Module/class structure

- [ ] Top-level class
- [ ] Top-level module (namespace only, no behavior)
- [ ] Nested namespacing (`Foo::Bar::Baz`), including a module that exists only
      to hold nested classes/modules
- [ ] A class reopened across two files/locations (docs should merge)
- [ ] Plain-old class with no superclass mentioned vs. explicit `< Object`
- [ ] Subclassing a class defined elsewhere in the example (inheritance chain
      of at least 3 levels, to test how ancestry is presented)
- [ ] A `Struct.new`-based class
- [ ] A `Data.define`-based class (Ruby 3.2+ value object, relevant given the
      gem's `>= 3.4` floor)
- [ ] Custom exception hierarchy (`class FooError < StandardError`, plus a more
      specific subclass of that)

### Mixins

- [ ] `include` of a module defining instance methods
- [ ] `extend` of a module defining singleton methods
- [ ] `prepend` (method resolution order should be visible/explained somehow)
- [ ] A module meant purely to be mixed in (documented as such, e.g. via
      `@abstract` or prose) rather than instantiated
- [ ] `extend self` pattern (module usable both as namespace and as mixin)
- [ ] `module_function`
- [ ] Mixing in a stdlib module (e.g. `Comparable` or `Enumerable`) to see how
      we handle methods whose docs live outside the example source entirely

### Methods — shapes & signatures

- [ ] Plain required positional params
- [ ] Optional positional params with default values (including a default that
      references a constant, not just a literal)
- [ ] Splat arg (`*args`)
- [ ] Required keyword args
- [ ] Optional keyword args with defaults
- [ ] Double-splat (`**opts`)
- [ ] Block param (`&block`) captured explicitly
- [ ] Implicit block usage (`yield` / `block_given?`) with no captured `&block`
      param
- [ ] A method combining several of the above (positional + optional + splat +
      kwargs + block) — the "kitchen sink" signature
- [ ] Multiple overloads via `@overload` (e.g. a method whose behavior/args
      differ enough that one Ruby signature doesn't tell the full story)
- [ ] A method that returns early with multiple distinct return shapes
      (documented return type is a union, e.g. `String, nil`)
- [ ] A method returning an `Enumerator` when called without a block, and
      yielding when called with one (tests combined `@yield`/`@return` docs)
- [ ] Operator method overload (e.g. `#+`, `#==`, `#<=>`, `#[]`, `#[]=`)
- [ ] `#to_s` / `#inspect` overrides
- [ ] Aliased method (`alias`/`alias_method`) — does the alias get its own
      entry or point back at the original?
- [ ] Singleton/class method (`def self.foo`) alongside instance methods on the
      same class
- [ ] Class methods defined via `class << self`
- [ ] A private class method
- [ ] Method-level `@private` tag on a method (vs. actual Ruby `private`)

### Visibility

- [ ] Public method (default/no comment needed)
- [ ] `private` method with doc comment (should it even appear in output?)
- [ ] `protected` method with doc comment (e.g. part of a `#<=>`/comparison
      implementation)

### Attributes & constants

- [ ] `attr_reader`, `attr_writer`, `attr_accessor` with doc comments
- [ ] Manually-defined reader/writer pair documented via `@attr`/`@attr_reader`/
      `@attr_writer` tags instead of relying on `attr_*`
- [ ] Simple constant (numeric/string literal) with a doc comment
- [ ] Structured constant (`Hash`, `Array`, `Regexp` literal)
- [ ] Constant that references another documented class (e.g.
      `DEFAULT_HANDLER = SomeClass.new`)
- [ ] Private constant (`private_constant`)

### YARD tags

- [ ] `@param` (including duck-type syntax, e.g. `@param [#to_s] x`)
- [ ] `@return` (including `void` and multi-type unions)
- [ ] `@option` (documenting keys of an options hash/kwargs)
- [ ] `@yield`, `@yieldparam`, `@yieldreturn`
- [ ] `@raise` (including a method that documents more than one exception
      type)
- [ ] `@see` — linking to another method, another class, and an external URL
- [ ] `@example` — both a bare example and a titled example
      (`@example Some title`), and a method with more than one `@example`
- [ ] `@deprecated` (with and without a replacement pointer)
- [ ] `@since`
- [ ] `@abstract` (on a class/module, and on a method meant to be overridden)
- [ ] `@note`
- [ ] `@todo`
- [ ] `@api` (e.g. `@api private` on something technically public)
- [ ] `@author`
- [ ] `@version`
- [ ] `@overload` (see also "Methods" above)

### YARD directives (for dynamically-defined methods/attrs)

- [ ] `@!attribute` (documenting an attribute defined through metaprogramming
      rather than `attr_*`)
- [ ] `@!method` (documenting a method defined via `define_method` in a loop,
      or via a class-level DSL macro — common in real-world gems)
- [ ] `@!group` / `@!endgroup` (method grouping) — stretch; only include if we
      decide the output format should reflect YARD groups

### Documentation content / prose patterns

- [ ] Single-line summary only
- [ ] Multi-paragraph description (summary + extended discussion)
- [ ] Markdown formatting in prose: code spans, a fenced code block, a list,
      a link
- [ ] A class-level doc comment (not just method-level)
- [ ] An intentionally undocumented public method (to decide how/whether the
      output format flags this)

### Cross-referencing scenarios

- [ ] Method `@param`/`@return` type referencing another class defined in the
      example (same file and a different file)
- [ ] `@see` pointing at another method in the same class
- [ ] `@see` pointing at a method in a different class/namespace
- [ ] A subclass method that overrides a documented parent method without
      redocumenting it (does output inherit/copy/link the parent doc?)
- [ ] A mixin method's docs as seen from an including class (does the output
      show it as if native, or point back at the module?)

## Open questions

Output format, indexing/lookup, and cross-referencing are now substantially
decided — see "Decisions" below. What's still open:

- **Mixin/inheritance content strategy** — when a class includes/extends/
  prepends a module, or inherits a method from a superclass, does the
  generated class file duplicate that method's docs inline (so one file read
  is self-sufficient) or link out to where it's actually defined (so there's
  a single source of truth but an extra hop to resolve it)? Orthogonal to
  file granularity — applies regardless of how files are split. Not yet
  exercised in `example/lib` (no mixins or inheritance there yet).
- **YARD integration mechanics** — how the plugin hooks into YARD's
  template/handler system (custom template path vs. registered output format
  vs. standard `yard-*` plugin conventions), and how it's invoked (`yard doc
  -f agentdocs`, a Toys task, a CLI wrapper, etc.). Not yet touched — this is
  about generating the format, not the format itself.

## Decisions

### File granularity: one file per class/module, members as sections

Each documented class/module gets exactly one output file (path derived from
its fully-qualified namespace, e.g. `Geometry::Point` → `Geometry/Point.md`).
Methods, attributes, and constants are documented as sections *within* that
file, not as separate files.

We considered one file per method/attribute/constant instead. It makes
cross-referencing trivial (a reference is just a path) and gives free
directory-listing-as-index (`ls` on a class's directory enumerates its
members). But it was rejected because:

- Operator/non-alphanumeric method names (`+`, `<=>`, `[]`, `[]=`, unary
  `-@`, etc.) don't map cleanly to filenames — some contain characters that
  are illegal or reserved in paths (`/` is a path separator; `<`, `>`, `|`,
  `?`, `*` are illegal on Windows) — requiring an escaping/mangling scheme
  the agent would also need to understand.
- Class-method vs. instance-method name collisions (e.g. a class-level and
  instance-level method sharing a name) need a disambiguating suffix, echoing
  the `-class_method`/`-instance_method` split YARD's own HTML anchors
  already use — evidence this problem is real, not hypothetical.
- It loses co-location of shared class-level context (description, ancestry,
  mixins, sibling methods); a lone method file either duplicates that context
  or forces a second read of the class anyway.
- File count scales with total methods across the whole dependency tree, not
  classes — risking tens of thousands of files for large gems, which stresses
  `ls`/glob/git/IDE tooling more than it needs to.

The main cost of the class-file approach is the precision problem: how does
an agent read *just* one member's section without reading the whole file?
Solved with consistent, greppable headings and a per-file member summary —
see "Output format" below for the concrete template. In the common case
(most classes have well under ~20 documented members) a full-file read is
cheap enough — a few thousand tokens — that the precision mechanism is a
nice-to-have, not a requirement, for most lookups.

**Deferred escape valve, not designed yet:** for unusually large classes
(100+ methods), consider splitting further, e.g. one file per member-kind
(constants / class methods / instance methods) within the class's namespace,
bounding worst-case file size without going all the way to full atomization.
Not needed until we have evidence a real target class needs it.

### Output format: per-file Markdown template

Settled shape for a class/module's Markdown file, worked out against
`example/doc` (see `Geometry.md` and `Geometry/Point.md`):

1. **`# FullyQualifiedName`** title.
2. **Metadata block** — bold key-value lines, only the lines that apply:
   - `**Ancestors:**` — the pure superclass chain only (e.g. `Object` →
     `BasicObject`), *excluding* mixed-in modules.
   - `**Includes:**` — modules mixed into the ancestry, listed separately
     from `Ancestors`, even if inherited transitively (e.g. `Kernel` shows up
     here for any class, via `Object`, without that class including it
     directly) rather than declared on the class itself.
   - `**Defined in:**` — source file path (no line number at this
     granularity; it's a whole-class/module reference).
   - No `Namespace:` line: the enclosing namespace is already fully legible
     from the title (`Geometry::Point` implies `Geometry`), and unlike method
     names, namespace segments are always plain Ruby constant identifiers
     with no escaping ambiguity — so it's cheaply derivable and would just be
     restating the title.
3. **Prose description** (the class/module doc comment).
4. **`## Member Summary`** — one grouped, linkless bullet list, acting as
   the single table of contents for everything in the file:
   - Subgroups in order: `**Nested Classes & Modules**`, `**Constants**`,
     `**Attributes**`, `**Class Methods**`, `**Instance Methods**`.
   - Each bullet: sigil+name (see step 5) + one-line summary.
   - **Nested Classes & Modules** is the one subgroup with links (each
     nested type has its own file and no further expansion in this one, so
     the summary line *is* the only pointer to it — see `Geometry.md`, which
     folds what used to be a separate `## Contents` section in here instead
     of duplicating the same one-liner twice in the same file).
   - Any subgroup with zero members is omitted entirely — no empty section,
     no "None." placeholder. Absence means empty; this holds at every level
     (whole sections, and subgroups within Member Summary).
   - Utility/cost tradeoff: this section is pure overhead for a lookup where
     the agent already knows the exact member it wants (it's about to reread
     that info in the full section below). Its value is for *discovery* —
     "does this class have a way to do X?" — where a bare heading grep gives
     names but not semantics. Worth keeping as insurance for classes with
     many or non-obviously-named members; low-stakes to remove later since
     it's pure summary, not a source of truth.
5. **Per-kind sections**, same order as the summary subgroups (skipping any
   kind with zero members): `## Constants`, `## Attributes`,
   `## Class Methods`, `## Instance Methods`. Each is an `H2`; each member
   within it is an `H3` titled with a sigil: `#name` (instance method or
   attribute), `.name` (class method), bare `NAME` (constant, already
   visually distinct via `SCREAMING_CASE`). This two-level heading scheme
   makes `grep -n '^## '` list section kinds and `grep -n '^### '` list every
   member with its exact line number — "read from this heading's line to the
   next" is then a mechanical, precise fetch with no separately-maintained
   index.
   - **Method entries** (class or instance): a ` ```ruby ` signature block
     first, using natural call syntax (`Point.parse(str) → Point` for class
     methods, `point.distance_to(other) → Float` for instance methods,
     infix form for binary operators — `point + other → Point`), then prose,
     then `**Params:**` (bullet list, `` `name` (`Type`) — description ``),
     `**Returns:** Type — description`, `**See also:**` (see
     "Cross-referencing" below), then `**Defined in:** path:line`.
   - **Constant/attribute entries**: `**Type:**`/`**Value:**` (constants) or
     `**Type:**`/`**Read-only.**`/etc. (attributes) as bold key-value lines
     in place of a signature block (there's no call syntax to show), then
     prose, then `**Defined in:** path:line`.
   - Ruby's implicit constructor gets a synthetic `.new` entry (sourced from
     `#initialize`'s docs, since `Point.new(x, y)` is how it's actually
     called) with a one-line italic note pointing back at `#initialize` so
     it isn't confusing against the real source.

No YAML front matter, and not designed for human skimming as a goal (though
it happens to be readable) — plain Markdown throughout.

### Cross-referencing

Resolved for the two cases exercised so far: a `@param`/`@return` type
naming another documented class, and a `@see` tag pointing at another
method.

- A type/`@see` reference to something in a **different** file renders as a
  Markdown link to that *file* — e.g. `` [`Point`](Geometry/Point.md) `` or,
  for a `@see` to a specific method, `` [`Point#distance_to`](Geometry/Point.md) ``
  (link text is the YARD-native `Class#method`/`Class.method` form, which
  also happens to match our own heading sigils). A **self**-reference within
  the same file (e.g. `Point`'s own methods mentioning `Point` as a param
  type) stays a plain, unlinked backtick — nothing to navigate to.
- Links point at the *file*, never at an anchor fragment or a line number,
  even when referencing one specific member. Two more-precise alternatives
  were considered and rejected:
  - **Anchor fragments** (`Geometry/Point.md#distance_to`) — these work for
    alphanumeric member names under GitHub-style slugification, but break
    exactly like the file-per-member filenames did: operator methods (`#+`,
    `#<=>`, ...) strip to an empty or colliding slug. A convention that's
    reliable for most members but silently wrong for operators isn't
    acceptable as the one convention.
  - **Doc-file line numbers** (`Geometry/Point.md:124`) — precise and cheap
    for the agent to consume, but requires the generator to know, while
    rendering the referencing file, exactly which line the target heading
    will land on in the *other* file — i.e. a two-pass generation (lay out
    every file, record heading positions, then resolve references). More
    machinery than the alternative needs.
  - Instead: the link's only job is getting the agent to the right file;
    once there, the same `grep '^### '`-then-range-read mechanism from
    "Output format" resolves the precise member, reusing a mechanism that
    already has to exist anyway rather than adding a second one.

### Indexing/lookup

- **Path derivation.** A class/module's file path is mechanically derived
  from its fully-qualified name, mirroring Ruby's own file-layout
  convention: `::` becomes a directory separator (`Geometry::Point` →
  `Geometry/Point.md`). No escaping scheme is needed at this level — unlike
  method names, namespace segments are always plain constant identifiers.
- **Root index file** (`example/doc/index.md`) lists top-level namespaces
  with links, as an entry point for an agent that doesn't yet know the
  FQN it's after. An agent that already knows the FQN doesn't need it —
  it can go straight to the derived path.
- Resolving a *member* name to its location once a class/module's file is
  open is covered under "Output format" (headings + grep), not here.
