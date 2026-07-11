# Design

This document describes the design of `yard-agentdocs` — a [YARD](https://yardoc.org/)
plugin that renders Ruby API reference documentation in a format meant for coding
agents to look up efficiently, rather than for human browsing.

It is a living design document. Format, indexing, cross-referencing, and the
core YARD integration mechanics are decided and implemented (see
"Implementation" below) for the scope checked off in "Example coverage
checklist" — the rest of that checklist (and the still-open question in
"Open questions") remain to be designed/built as `example/lib` grows.
Decisions get logged here as we make them, and open questions stay open (and
listed) until they're resolved. This file is the source of truth for design;
keep it in sync as understanding improves.

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

### Coverage workflow (TDD loop)

Now that the template exists, every checklist item below gets built test-first,
one item (or a small handful of tightly-related variants) at a time. This is a
**collaborative, human-gated loop**, not something Claude runs autonomously —
the example files encode real design decisions (see "Decisions"/"Open
questions"), so the human reviews and iterates on them before any
implementation code gets touched:

1. **Human** proposes which unchecked checklist item(s) to tackle next.
2. **Claude** proposes the corresponding additions/edits to `example/lib`
   (Ruby source exercising the item) and `example/doc` (the hand-authored
   target output for it), asking clarifying questions along the way where the
   item raises a design choice not already settled in "Decisions".
3. **Human** reviews the proposed `example/lib`/`example/doc` changes; they
   iterate with Claude as needed until both are satisfied. Nothing outside
   `example/` (templates, `test/test_agentdocs_template.rb`) is touched during
   this step.
4. Once the human explicitly says the example changes are good, **Claude**
   implements: add any new source files to `test/test_agentdocs_template.rb`'s
   `generate` call's file list (output files are discovered automatically —
   no list to maintain there), confirm `toys test` fails against the new
   fixture, then update the template implementation until it passes
   byte-for-byte — no normalization/fuzzy comparison; fix the generator, don't
   loosen the
   assertion (see "ERB has no trim mode" for why this matters).
5. Check off the completed item(s) in the checklist below, recording any new
   decision reached in step 2 under "Decisions" (or "Open questions" if still
   unresolved).
6. Run `toys test` and `toys rubocop` before moving to the next item.

Do not skip ahead to step 4 (implementation) without an explicit go-ahead from
the human, even if the example changes look done — the review in step 3 is
the point of doing this test-first.

## Example coverage checklist

This is the working checklist of Ruby language features and YARD tags/directives
that `example/lib` should exercise, so `example/doc` ends up covering the
documentation surface an agent is actually likely to hit. Items are grouped by
category; unchecked boxes are proposed, not yet built. This list is expected to
grow/shrink as we build the example and find gaps or redundancy.

Checked boxes mean the current `example/lib`/`example/doc` pair and the
implemented `agentdocs` template actually exercise that scenario end-to-end
(parsed, rendered, asserted byte-for-byte in `test/test_agentdocs_template.rb`).
Where a single bullet bundles several genuinely distinct variants (e.g.
`attr_reader`/`attr_writer`/`attr_accessor`, or `@see`'s method/class/URL
targets), it's only checked once essentially all of them are covered — a
parenthetical *example* of a tag that's otherwise thoroughly exercised (e.g.
`@param`'s duck-type aside) doesn't block the check. Partial coverage stays
unchecked rather than being marked as done.

### Module/class structure

- [x] Top-level class — `Stopwatch`
- [x] Top-level module (namespace only, no behavior) — `Geometry` itself,
      once its one method moved to `Geometry::Computations`
- [ ] Nested namespacing (`Foo::Bar::Baz`), including a module that exists only
      to hold nested classes/modules
- [ ] A class reopened across two files/locations (docs should merge)
- [ ] Plain-old class with no superclass mentioned vs. explicit `< Object`
- [x] Subclassing a class defined elsewhere in the example (inheritance chain
      of at least 3 levels, to test how ancestry is presented) — `Geometry::Shape`
      → `Polygon` → `Triangle`; also settled that `**Superclass:**` links to a
      resolved (in-example) superclass's own file, showing the name as written
      in source
- [x] A `Struct.new`-based class — `Geometry::Circle`
- [x] A `Data.define`-based class (Ruby 3.2+ value object, relevant given the
      gem's `>= 3.4` floor) — `Geometry::Vector`

### Mixins

- [x] `include` of a module defining instance methods — `Geometry::Taggable`
      mixed into `Geometry::Shape`; also settled the mixin content-strategy
      open question (link out to the module's own file, don't duplicate the
      method's docs inline)
- [ ] `extend` of a module defining singleton methods
- [ ] `prepend` (method resolution order should be visible/explained somehow)
- [ ] A module meant purely to be mixed in (documented as such, e.g. via
      `@abstract` or prose) rather than instantiated
- [ ] `extend self` pattern (module usable both as namespace and as mixin)
- [ ] `module_function`
- [ ] Mixing in a stdlib module (e.g. `Comparable` or `Enumerable`) to see how
      we handle methods whose docs live outside the example source entirely

### Methods — shapes & signatures

- [x] Plain required positional params
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
- [x] Operator method overload (e.g. `#+`, `#==`, `#<=>`, `#[]`, `#[]=`) —
      `Point#+`, rendered infix (`point + other → Point`)
- [ ] `#to_s` / `#inspect` overrides
- [ ] Aliased method (`alias`/`alias_method`) — does the alias get its own
      entry or point back at the original?
- [x] Singleton/class method (`def self.foo`) alongside instance methods on the
      same class — `Point.parse`/`Point.new` alongside `Point#+`/`#distance_to`
- [ ] Class methods defined via `class << self`
- [ ] A private class method
- [ ] Method-level `@private` tag on a method (vs. actual Ruby `private`)

### Visibility

- [x] Public method (default/no comment needed)
- [ ] `private` method with doc comment (should it even appear in output?)
- [ ] `protected` method with doc comment (e.g. part of a `#<=>`/comparison
      implementation)

### Attributes & constants

- [ ] `attr_reader`, `attr_writer`, `attr_accessor` with doc comments (only
      `attr_reader` exercised so far, via `Point#x`/`#y`)
- [ ] Manually-defined reader/writer pair documented via `@attr`/`@attr_reader`/
      `@attr_writer` tags instead of relying on `attr_*`
- [x] Simple constant (numeric/string literal) with a doc comment —
      `Point::DIMENSIONS`
- [ ] Structured constant (`Hash`, `Array`, `Regexp` literal)
- [ ] Constant that references another documented class (e.g.
      `DEFAULT_HANDLER = SomeClass.new`) — `Point::ORIGIN = new(0, 0)` is close
      but is a *self*-reference (an instance of the class it's defined on, not
      another one), so it exercises the value/type machinery but not this case
- [ ] Private constant (`private_constant`)

### YARD tags

- [x] `@param` (including duck-type syntax, e.g. `@param [#to_s] x`) — duck
      typing itself not exercised, but the tag is otherwise thorough
- [x] `@return` (including `void` and multi-type unions) — `void`/unions not
      exercised, but the tag is otherwise thorough
- [ ] `@option` (documenting keys of an options hash/kwargs)
- [ ] `@yield`, `@yieldparam`, `@yieldreturn`
- [ ] `@raise` (including a method that documents more than one exception
      type)
- [ ] `@see` — linking to another method, another class, and an external URL
      (only the "another method" case is exercised so far; see also the
      cross-referencing scenario below)
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

- [x] Single-line summary only — e.g. `Point#x`'s "The x-coordinate."
- [x] Multi-paragraph description (summary + extended discussion) — the
      `Geometry` module doc
- [ ] Markdown formatting in prose: code spans, a fenced code block, a list,
      a link (only code spans are exercised so far, e.g. `` `"x,y"` ``)
- [x] A class-level doc comment (not just method-level) — both `Geometry` and
      `Geometry::Point`
- [ ] An intentionally undocumented public method (to decide how/whether the
      output format flags this)

### Cross-referencing scenarios

- [x] Method `@param`/`@return` type referencing another class defined in the
      example (same file and a different file) — `Point#+` referencing
      `Point` itself (same file) and `Geometry.distance` referencing `Point`
      (different file) both render correctly (unlinked vs. linked)
- [ ] `@see` pointing at another method in the same class
- [x] `@see` pointing at a method in a different class/namespace —
      `Geometry.distance`'s `@see Point#distance_to`
- [ ] A subclass method that overrides a documented parent method without
      redocumenting it (does output inherit/copy/link the parent doc?)
- [ ] A mixin method's docs as seen from an including class (does the output
      show it as if native, or point back at the module?)

## Open questions

Output format, indexing/lookup, cross-referencing, and the core YARD
integration mechanics are now decided *and implemented* — see "Decisions" and
"Implementation" below. What's still open:

- **Mixin/inheritance content strategy for `extend`/`prepend`/superclass
  inheritance** — resolved for direct `include` as "link out, not
  duplicate" (see "Mixin content strategy" under "Decisions" below). Still
  open for `extend` (singleton methods) and `prepend` (MRO makes "which
  copy is authoritative" murkier), and for a subclass method inherited
  (not overridden) from a superclass — does the subclass's file duplicate,
  link out, or say nothing at all? Not yet exercised in `example/lib`.

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
   - `**Superclass:**` — the class's immediate superclass only (e.g. `Object`),
     not the full ancestor chain. We deliberately don't walk further: a more
     distant ancestor (or a module *it* mixes in) may be defined outside the
     parsed source (another gem, stdlib), so we can't reliably know the full
     chain in general — better to show one reliable hop than a chain that's
     silently incomplete for some classes. Rendered as a Markdown link to the
     superclass's own file when it resolves in the registry (e.g.
     `` [`Shape`](Shape.md) `` for `Geometry::Polygon`), or a plain backtick
     when it doesn't (e.g. `` `Object` ``, never parsed from source). Display
     text is always the name as it was actually written after `<` in the
     source, never forced to a fully-qualified path — same convention as
     `@param`/`@return`/`@see` cross-references (below), which also show
     whatever name the docstring author literally wrote rather than a
     resolved path.
   - `**Includes:**` — modules `include`d directly in the class's own parsed
     source, *not* ones mixed in transitively by its superclass (same
     reasoning as `Superclass` — we don't walk the chain, so we can't know
     those either). This means a plain class with an implicit `Object`
     superclass shows no `Includes` line at all (`Kernel` is never a direct
     `include` on the class itself).
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

### Mixin content strategy (direct `include`): link out, not duplicate

Resolves (for the `include` case) the "Mixin/inheritance content strategy"
open question below. Exercised via `Geometry::Taggable` (a module defining
one instance method, `#tag`) `include`d into `Geometry::Shape`.

A class's own file does **not** duplicate a directly-`include`d module's
method docs inline — `instance_method_objects`/`class_method_objects` pass
`included: false` to `NamespaceObject#meths` to exclude them. The class file
only gets the `**Includes:**` metadata line (a link to the module's own
file, same link/display-name convention as `**Superclass:**`); the mixed-in
method's full docs live solely on the module's page. Chosen over inlining
mainly because inlining can't be made to work uniformly — a mixin whose
docs live outside the parsed source (e.g. a stdlib module like `Comparable`,
still an open checklist item) can't be duplicated at all, so a class's
"is this method documented here or do I need another read" answer would
otherwise depend on where the mixin happens to be defined. Link-out is
simpler and consistent regardless.

**Latent bug fixed along the way:** `class_method_objects`/
`instance_method_objects` already passed `inherited: false` before this
change (correctly suppressing a superclass's methods — `ClassObject#meths`
overrides the base `NamespaceObject#meths` to add that option), but never
passed `included: false`, so `included: true`'s default meant any mixin's
methods would have leaked straight into the member list uncaught, since no
example exercised a mixin until `Taggable` gave us a case to catch it. Both
flags are real, independent options on `meths` — `:inherited` (superclass
methods, `ClassObject`-only) and `:included` (mixin methods, all
`NamespaceObject`s) — and this template wants both off, since class files
don't duplicate either superclass or mixin member docs.

### `Struct.new`/`Data.define`-based classes

Exercised via `Geometry::Circle` (`Circle = Struct.new(:radius) do ... end`)
and `Geometry::Vector` (`Vector = Data.define(:dx, :dy) do ... end`). No
template changes were needed — YARD's own `Struct`/`Data` handling maps
cleanly onto decisions already made for other cases:

- **Superclass** renders as a plain, unlinked `` `Struct` ``/`` `Data` `` —
  same as `Object` — since YARD represents it as an unresolved `Proxy`
  (neither is parsed source), matching the existing resolved-vs-unresolved
  rule.
- **No synthetic `.new` entry.** Unlike a hand-written `def initialize`,
  `Struct.new`/`Data.define` don't give YARD a real `#initialize` method to
  attach docs to (member accessors are synthesized, but not a constructor),
  so `class_method_objects`' `find(&:constructor?)` comes up empty and the
  `Class Methods` section is simply absent. Accepted as a real gap rather
  than worked around: the file still accurately reflects everything YARD
  could parse, and fabricating a constructor entry would violate the
  "reflect what's actually parseable" principle. An agent still learns the
  member names/types from `Attributes` and can infer `.new(radius)`-style
  construction from Ruby's own `Struct`/`Data` conventions.
- **Struct members are read-write; `Data.define` members are read-only** —
  YARD's handlers create both a reader and a writer for each `Struct.new`
  member but only a reader for each `Data.define` member, matching real
  Ruby semantics (`Data` objects are immutable). `Circle#radius` is this
  example set's first read-write attribute (no `(read-only)`/`(write-only)`
  annotation, since neither is `nil`).
- **Attribute type/text default to `` `Object` ``/"Returns the value of
  attribute `name`"** when no `@attr`/`@attr_reader`/`@attr_writer` tag is
  given on the class — confirmed this is a general YARD fallback for *any*
  undocumented attribute (a bare `attr_reader :bar` with no comment gets
  the same boilerplate), not specific to `Struct`/`Data`. Kept as-is rather
  than filtered: matching YARD's exact generated strings to suppress them
  would be fragile (silently breaks if YARD rewords them) and hard to
  distinguish from a legitimately terse user-written docstring. Revisit
  this as a general policy — not a `Struct`/`Data`-specific one — if/when
  the still-unchecked undocumented-`attr_reader`/`writer`/`accessor`
  checklist item is tackled.

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

## Implementation

The `agentdocs` template is implemented and generates output *identical*
(byte-for-byte) to `example/doc` when run against `example/lib` — verified by
`test/test_agentdocs_template.rb`, which runs `YARD::CLI::Yardoc` in-process
and asserts equality against the fixture files directly (no fuzzy/normalized
comparison needed; see "ERB has no trim mode" below for why that used to be
tempting). Scope is intentionally narrow: it covers exactly what's checked off
in "Example coverage checklist" above, not the full checklist.

### Architecture

- `lib/yard-agentdocs.rb` calls
  `YARD::Templates::Engine.register_template_path` with the gem's `templates/`
  dir. This is the entire integration point — no custom output-format
  registration, no handler classes.
- `lib/yard/agentdocs/` holds plain Ruby helpers shared across `setup.rb`
  files belonging to different template modules (`module/agentdocs` and
  `fulldoc/agentdocs` don't inherit from each other, so a method defined in
  one's `setup.rb` isn't visible in the other's) — currently just
  `ErbWithTrimMode`, `include`d by both.
- Templates live under `templates/default/{fulldoc,module,class}/agentdocs/`,
  mirroring YARD's own directory convention (`<template>/<type>/<format>/`):
  - `fulldoc/agentdocs` is the driver: walks the object list YARD hands it,
    writes `index.md` (top-level namespaces), then serializes one file per
    class/module.
  - `module/agentdocs` holds the shared rendering logic — member gathering,
    cross-reference resolution, signature building, per-entry rendering —
    used directly for modules and `include`d by `class/agentdocs` (mirroring
    upstream's own `class/setup.rb` doing `include T('default/module')`).
  - `class/agentdocs` adds what only classes have: the `**Superclass:**`/
    `**Includes:**` metadata lines and the synthetic `.new` entry sourced from
    `#initialize`.
  - No `root/agentdocs` or `layout/agentdocs` — `index.md` is a one-off
    generated directly by the fulldoc driver, and per-object rendering calls
    `T(object.type)` directly instead of going through YARD's generic
    `layout`/multi-format dispatch (that machinery exists to share code across
    html/text/dot; this plugin only ever targets one format).
  - ERB templates hold the actual document structure and control flow
    (loops over members, conditional sections); Ruby methods in each
    `setup.rb` do data-gathering and single-value formatting only — see
    "Template coding convention" below for why, and "ERB has no trim mode"
    below for the YARD quirk that made this need a small workaround.

### Template coding convention: structure and control flow belong in `.erb`

Preference, going forward: a class/module's document structure — which
sections exist, in what order, looped over which members — should be
visible in the `.erb` file itself via ordinary `<% if %>`/`<% each %>`, not
hidden inside a Ruby method that pre-builds and joins strings. The `.erb`
file is meant to double as a readable skeleton of the output shape; burying
that shape in `setup.rb` string-assembly defeats the point, even though it
was the original workaround (see "ERB has no trim mode" below).

This is viable now because `YARD::AgentDocs::ErbWithTrimMode`
(`lib/yard/agentdocs/erb_with_trim_mode.rb`) overrides `Template#erb_with` —
the method YARD's `#erb`/`#superb` both call to build the `ERB` instance —
to always construct `ERB.new(content, trim_mode: "-")`, rather than
accepting YARD's own version (trim mode only for its built-in `:text`
format, `nil` otherwise). Both `module/agentdocs/setup.rb` and
`fulldoc/agentdocs/setup.rb` `include` this shared mixin (it lives under
`lib/` rather than duplicated per `setup.rb`, since neither template module
inherits the other's overrides — see "Architecture" above). `.erb` files
then use explicit `<%- -%>` / `<%- ... -%>` tags to suppress the surrounding
blank line/indentation a conditional or loop would otherwise leak, exactly
where needed. Confirmed this doesn't change output for any template that
uses ordinary `<% %>`/`<%= %>` without the dash markers — trim mode `-` is a
no-op for those.

Applied throughout: `page.erb` composes the page from three sub-templates —
`metadata.erb`, `member_summary.erb`, `member_sections.erb` — each an
`erb(:name)` call, rather than a Ruby method that pre-assembles the block as
a string. `member_summary.erb` and `member_sections.erb` loop over the same
`nested_objects`/`constant_objects`/`attribute_objects`/
`class_method_objects`/`instance_method_objects` data-gathering methods
directly with `<%- ... each do |x| -%>`, guarding each optional group/section
with `<%- if ... -%>`/`<%- end -%>`. Within a section, entry-to-entry blank
lines use an `each_with_index` + `unless i.zero?` leading-separator (not
trailing), so N entries get exactly N-1 separators with no special-casing of
the last one. `method_entry.erb` and `attribute_entry.erb` similarly inline
their optional lines (constructor note, params list, returns, see-also;
type/read-only annotation) as `<%- if/unless -%>` blocks instead of an
array-building Ruby method. `fulldoc/agentdocs`'s `index.erb` loops over
`@top_level_objects` the same way — it also `include`s `ErbWithTrimMode`
directly (see `fulldoc/agentdocs/setup.rb`) since it's a separate template
module from `module/agentdocs` and doesn't inherit its `include`.

What's left as Ruby, deliberately: single-value/single-line computations
with no optional multi-line structure to leak whitespace from — `type_ref`,
`link_path`, `signature_text`, `nested_summary_line`/`constant_summary_line`/
`attribute_summary_line`/`method_summary_line`, `superclass_line`/
`includes_line`, etc. These aren't the workaround pattern being replaced;
they're ordinary formatting helpers, same as upstream YARD templates use,
and read fine as one-line `<%= helper(x) %>` calls inside the `.erb` loops
above.

### Non-obvious techniques, patterns, and quirks

A few things that weren't obvious going in, worth not re-discovering:

- **The directory is `fulldoc`, not `fulldocs`.** YARD's dispatch is
  `Engine.generate` → `template(options.template, :fulldoc, options.format)`
  — literally, mechanically singular. Easy typo, silently means "no such
  template" at runtime.
- **`T()` behaves differently depending on where you call it.** At *runtime*
  (an instance method, e.g. inside `fulldoc`'s `init`), `T(:module)`
  auto-prepends `options.template` and appends `options.format`, resolving to
  `default/module/agentdocs`. At *setup.rb top level* (class-method context,
  e.g. `include T(...)`), `T` does **not** decorate the path — you must spell
  out the full literal path, exactly like upstream's own
  `include T('default/module')` in `class/setup.rb`.
- **The serializer's extension defaults to `html`.** Set
  `options.serializer.extension = "md"` explicitly in the fulldoc driver's
  `init`; `FileSystemSerializer#serialized_path` otherwise already does the
  right thing (namespace-mirrored paths) for free.
- **`Registry.resolve(namespace, name, true, false)`** (inheritance search on,
  proxy-fallback off) is the right primitive for both `@param`/`@return` type
  names and `@see` targets: it returns a real `CodeObject` or `nil`, which is
  exactly "is this actually documented, worth a link" vs. "plain backtick."
- **`Object`, `BasicObject`, and `Kernel` are never in the Registry** unless
  their source is actually parsed — they show up only as unresolved `Proxy`
  stand-ins with no ancestry/mixin data of their own, so there's no way to
  derive their own superclass/includes from the registry. This is exactly why
  `superclass_line`/`includes_line` (`class/agentdocs/setup.rb`) stop at one
  hop instead of walking the chain: `object.superclass` and
  `object.mixins(:instance)` are reliable for the class actually being
  rendered, but the same calls on an unparsed `Proxy` ancestor wouldn't be.
- **YARD auto-synthesizes an `@return` tag on constructors** — even when
  `#initialize` has no explicit `@return`, `method.tag(:return)` comes back
  with text like "a new instance of Point". Left unhandled, the synthetic
  `.new` entry gets a spurious **Returns:** line under our formatting rule
  (only show it when a real `@return` tag exists). Fix: explicitly treat
  constructors as having no return tag for that purpose, regardless of what
  `#tag(:return)` reports.
- **`Docstring#all` reconstructs the whole original comment, tags included**
  — for a method with `@param`/`@return`/`@see`, `.all` returns the prose
  *plus* raw `"@param ...\n@return ...\n"` lines. For prose-only rendering
  (what goes in the body text, since tags are rendered separately), use the
  plain `Docstring` itself (`object.docstring`), not `.all`.
- **ERB has no trim mode for custom formats — by default.** YARD only passes
  `trim_mode: '<>'` to `ERB.new` when `options.format == :text` (its own
  built-in format) — a custom format like `agentdocs` otherwise gets
  untrimmed ERB. That means a `<% if cond %>` / `<% end %>` pair's
  surrounding text (including any blank "spacer" lines written for
  readability) is emitted unconditionally *around* the conditional content,
  and a `<% each %>` loop's per-iteration leading/trailing text repeats every
  time — both leak stray blank lines into the output regardless of whether
  the branch/loop actually produced anything. Originally worked around by
  pushing every optional/repeated piece into a plain Ruby array and
  `.compact.join`-ing it, avoiding `<% if %>`/`<% each %>` inside `.erb`
  entirely; superseded by the `erb_with` override described in "Template
  coding convention" above, which enables real `<%- if -%>`/`<%- each -%>`
  with explicit trim markers instead. This is also why the test asserts
  byte-for-byte equality rather than whitespace-normalized equality — once
  the leaks were fixed at the source, normalization was no longer needed,
  and keeping it would have hidden future regressions of this exact
  kind.
- **`YARD::CLI::Yardoc` auto-loads a `.yardopts` file from the current
  directory** unless told not to. Driving it programmatically (as the test
  does) needs `--no-yardopts`, or it silently merges in this gem's own
  `.yardopts` file list — which is how a spurious extra "YARD" top-level
  namespace first showed up in test output (from `lib/yard/agentdocs.rb`
  getting parsed alongside the intended `example/lib` files).
- **`bundle exec yard doc -f agentdocs` alone won't find the template.**
  Bundler activates a path-based gem dependency but doesn't `require` it.
  Either pass `-e ./lib/yard-agentdocs.rb` (loads the file first, registering
  the template path) or gem-install the plugin for real, so YARD's own
  `yard-*`-prefix plugin autoload picks it up.
- **Method line numbers are the `def` line itself**, not a preceding
  comment/blank line — don't hand-count when writing fixtures; check against
  actual parser output.
- **Constant values are raw source text, implicit receivers included.**
  `Point::ORIGIN = new(0, 0)` (written inside `class Point`, so `new` means
  `Point.new`) records verbatim as `"new(0, 0)"`, not `"Point.new(0, 0)"`. We
  don't rewrite/expand these — the fixture reflects the raw text.
- **`spec.files` needs `templates/**/*` explicitly** — it isn't swept in by
  the `lib/**/*.rb` glob, and a built gem silently ships without its own
  templates otherwise. Worth remembering for any other non-`lib/` directory
  this gem grows.
- **(Harmless, but easy to mistake for a bug of ours.)** The first time
  anything actually calls `YARD.parse` in a process, YARD 0.9.44's own
  `lib/yard/parser/ruby/ruby_parser.rb` reliably prints three "method
  redefined" warnings (`on_hshptn`, `on_aryptn`, `on_fndptn`). It's
  intentional on YARD's part — a generic per-event codegen pass early in the
  file defines default handlers for every Ripper event, then hand-written
  Ruby-3-pattern-matching-aware overrides later in the *same file* redefine
  those three. Nothing to fix on our end; it's pre-existing and lazily
  triggered, which is why it never showed up before this template's test
  started actually driving the parser.

### Testing approach

`test/test_agentdocs_template.rb` runs `YARD::CLI::Yardoc.new.run(...)`
in-process (not shelling out), from inside `Dir.chdir(project_root)` so
recorded source paths come out relative (`example/lib/geometry.rb`, matching
the fixtures) rather than absolute. It asserts each generated file is exactly
equal to its `example/doc` counterpart — no normalization. A manual
end-to-end sanity check (`yard doc -f agentdocs -e ./lib/yard-agentdocs.rb
...` from the command line) is worth re-running after any template change,
since it's the only check that exercises the real CLI entry point rather than
`YARD::CLI::Yardoc.new.run` directly.
