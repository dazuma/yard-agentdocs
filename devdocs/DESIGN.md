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

## Design heuristic: agent reference needs mirror human reference needs

When a format/policy decision isn't dictated by the goals above, default to
matching how a gem would already choose to present that information to a
human reader in its own reference docs (YARD's default HTML template is the
concrete reference point) — rather than inventing a bespoke agent-specific
policy from scratch. An agent looking up how to use a dependency is doing
essentially the same task a human engineer would.

The two dimensions where this project *should* diverge from human-facing
conventions are:

- **Terseness/formatting** — visual affordances that help a human scan (CSS,
  layout, verbose multi-line warning paragraphs) are dead weight for an agent
  parsing text; prefer compact inline annotations over a human template's
  more elaborate treatment of the same information.
- **Structured search/cross-reference cost** — favor forms that let an
  automation find/parse/cross-reference elements cheaply (consistent
  headings, predictable file paths, minimal tokens) over forms optimized for
  visual browsing.

Where neither dimension is in play, don't reinvent a policy a human-facing
template already settled.

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

1. **Human** proposes which unchecked checklist item(s) to tackle next
   (see "Prioritization and roadmap" below for suggested ordering and for
   how much design latitude each item carries).
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

Each unchecked item carries a **(design)**/**(mech)**/**(stretch)** marker —
see "Prioritization and roadmap" just below for what they mean and how to
pick the next item.

### Prioritization and roadmap

Each unchecked checklist item is marked so that a fresh session can tell how
much design latitude it involves:

- **(design)** — forces a format decision not yet settled under "Decisions".
  Expect real back-and-forth in steps 2–3 of the TDD loop; the `example/`
  proposal is the medium for *making* the decision, not a formality. Where
  several items share one decision, the item says so — settle it once on the
  first item tackled, and the rest effectively become (mech).
- **(mech)** — the expected output should follow mechanically from existing
  "Decisions"; the `example/` proposal should be predictable and review is a
  sanity check. Good candidates for quick sessions. Caveat: if a (mech) item
  surfaces a surprise (YARD reports something unexpected, or no existing
  decision actually covers the rendering), treat it as (design) on the spot —
  stop and review with the human rather than improvising a format.
- **(stretch)** — don't tackle unless evidence from real usage demands it.

Suggested ordering: prefer (design) items early — each one settled reduces
the risk of late format churn invalidating already-approved fixtures — and
use (mech) items as filler between them. Every item, regardless of marker,
still goes through the human-gated workflow above; the marker only
calibrates how much iteration to expect.

**Dogfood milestone:** once the checklist is substantially covered, run the
template against a real, mid-size gem (YARD itself is a fitting candidate)
and diff-read the output. The hand-written example drives format decisions
well, but it will systematically miss what real docstrings do — markup
dialects, inline references, odd whitespace, very large classes that would
trigger the deferred "escape valve" under "File granularity". Harvest
anything the run surfaces back into this checklist as new items rather than
fixing ad hoc.

### Module/class structure

- [x] Top-level class — `Stopwatch`
- [x] Top-level module (namespace only, no behavior) — `Geometry` itself,
      once its one method moved to `Geometry::Computations`
- [ ] (mech) Nested namespacing (`Foo::Bar::Baz`), including a module that
      exists only to hold nested classes/modules — path derivation is
      settled; the namespace-only module's rendering depends on the
      undocumented-class/module policy item under "Documentation content /
      prose patterns"
- [ ] (design) A class reopened across two files/locations (docs should
      merge — how do multiple `**Defined in:**` locations render?)
- [ ] (mech) A custom exception class (`class ParseError < StandardError`) —
      very common in real gems, pairs with `@raise` lookups, and exercises
      an *unresolved* superclass that isn't `Object`/`Struct`/`Data`
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
- [x] `extend` of a module defining singleton methods — `Geometry::Named`
      extended into `Triangle`; settled the `extend` content-strategy open
      question (link out via `**Extends:**`, same as `include`)
- [x] `prepend` (method resolution order should be visible/explained somehow)
      — `Geometry::Loud` prepended into `Polygon`, overriding `#describe`;
      settled the `prepend` content-strategy open question (fold into
      `**Includes:**`, indistinguishable from `include` at the metadata
      level — see "`prepend` content strategy" under "Decisions")
- [ ] (mech) A module meant purely to be mixed in (documented as such, e.g.
      via `@abstract` or prose) rather than instantiated — `@abstract`'s own
      rendering is its own item under "YARD tags"
- [ ] (design) `extend self` pattern (module usable both as namespace and as
      mixin) — shares one decision with `module_function` below: how methods
      that are simultaneously class- and instance-level should present
- [ ] (design) `module_function` (same decision as `extend self` above)
- [ ] (mech) Mixing in a stdlib module (e.g. `Comparable` or `Enumerable`) to
      see how we handle methods whose docs live outside the example source
      entirely — link-out is already decided; an unresolved module should
      render as a plain backtick, same as an unresolved superclass

### Methods — shapes & signatures

- [x] Plain required positional params
- [x] Optional positional params with default values (including a default that
      references a constant, not just a literal) — `Stopwatch#reset(to = DEFAULT_ELAPSED)`;
      settled that the default renders in the signature only (natural `def`
      syntax, e.g. `stopwatch.reset(to = DEFAULT_ELAPSED) → Float`), not as
      extra annotation on the `**Params:**` bullet — see "Optional param
      default rendering" under "Decisions"
- [x] Splat arg (`*args`) — `Geometry::Computations.centroid(*points)`; also
      surfaced the need for compound-type inner-identifier linking (a
      `Array<Point>`-shaped `@param`), see "Compound-type cross-referencing"
      under "Decisions"
- [x] Required keyword args — `Geometry::Point.from_polar(radius:, angle:)`
- [x] Optional keyword args with defaults — `Geometry::Point#round(precision: 0)`;
      surfaced and fixed a `param_names` bug that rendered the default as
      `` precision: = 0 `` instead of natural Ruby's `` precision: 0 `` (YARD
      includes the trailing `:` in the parameter name itself, so a keyword
      default needs no `=`)
- [x] Double-splat (`**opts`) — `Geometry::Point#translate(**deltas)`; also
      supplied the `example/` appearance for the `Hash{}` half of
      "Compound-type variants beyond `Array<Point>`" below, via its
      `Hash{Symbol => Numeric}`-typed `@param`
- [x] Block param (`&block`) captured explicitly — `Stopwatch#measure(&block)`;
      settled how a block renders in the natural-call-syntax signature line,
      shared with the implicit-block item below and the `@yield` family
      under "YARD tags" — see "Block presentation" under "Decisions"
- [x] Implicit block usage (`yield`) with no captured `&block` param —
      `Geometry::Polygon#each_side`/`Geometry::Computations.each_point`
      (same block-presentation decision as above); `block_given?` itself
      not separately exercised (no new rendering question — the format
      doesn't track block optionality)
- [x] A method combining several of the above (positional + optional +
      splat + kwargs + block) — `Stopwatch#describe`, the "kitchen sink"
      signature; confirmed purely mechanical, no template changes needed —
      `param_names`/`signature_text` already assembled every shape together
      correctly
- [ ] (design) Multiple overloads via `@overload` (e.g. a method whose
      behavior/args differ enough that one Ruby signature doesn't tell the
      full story)
- [ ] (mech) A method that returns early with multiple distinct return shapes
      (documented return type is a union, e.g. `String, nil`); also cover
      `@return [self]` (chainable methods — a type token that's neither
      resolvable nor an ordinary class name) and `@return [void]` here
- [ ] (design) A method returning an `Enumerator` when called without a
      block, and yielding when called with one (tests combined
      `@yield`/`@return` docs)
- [x] Infix binary operator method — `Point#+`, rendered infix
      (`point + other → Point`)
- [ ] (design) Remaining operator forms — `#[]` / `#[]=` (`point[i]`,
      `point[i] = v`), `#<=>` / `#==`, unary `-@` / `+@` (`-point`) — each
      has a distinct natural-call-syntax rendering that the infix-binary
      case doesn't settle
- [ ] (design) Aliased method (`alias`/`alias_method`) — does the alias get
      its own entry or point back at the original?
- [x] Singleton/class method (`def self.foo`) alongside instance methods on the
      same class — `Point.parse`/`Point.new` alongside `Point#+`/`#distance_to`
- [ ] (mech) Class methods defined via `class << self` — should render
      identically to `def self.foo`
- [x] (mech) A private class method — `Geometry::Computations.average`
      (`private_class_method`-marked, backing `.centroid`'s x/y averaging);
      confirmed omitted with zero template changes, same policy as instance
      `private`/`protected`

### Visibility

- [x] Public method (default/no comment needed)
- [x] (design) `private` method with doc comment (should it even appear in
      output?) — `Stopwatch#current_time`, backing `#measure`; settled that
      Ruby-scope `private`/`protected` are omitted entirely, relying on
      YARD's own default visibility flags rather than template-level
      enforcement — see "Visibility policy" under "Decisions". Also settles
      `protected`, private class methods, and `private_constant` (all `mech`
      follow-ups under the same policy).
- [x] (mech) `protected` method with doc comment (e.g. part of a
      `#<=>`/comparison implementation) — `Stopwatch#elapsed`, backing the
      new `Stopwatch#<=>`; confirmed omitted with zero template changes,
      same as `private`
- [x] (design) Tag-based privacy — `@private` tag or `@api private` on a
      technically public method — `Stopwatch#raw_elapsed_s`; settled that,
      unlike Ruby-scope privacy, these render but are flagged (`**Private
      API.**` full-entry line, `(private API)` Member Summary suffix) —
      see "Visibility policy" under "Decisions"

### Attributes & constants

- [ ] (mech) `attr_reader`, `attr_writer`, `attr_accessor` with doc comments
      (only `attr_reader` exercised so far, via `Point#x`/`#y`) — also the
      trigger for revisiting the undocumented-attribute boilerplate policy
      noted under the `Struct`/`Data` decision
- [ ] (mech) Manually-defined reader/writer pair documented via
      `@attr`/`@attr_reader`/`@attr_writer` tags instead of relying on
      `attr_*` — escalate to (design) if YARD doesn't merge the pair into
      one attribute cleanly
- [x] Simple constant (numeric/string literal) with a doc comment —
      `Point::DIMENSIONS`
- [ ] (design) Structured constant (`Hash`, `Array`, `Regexp` literal) — a
      multiline literal forces a decision on how `**Value:**` renders when
      the raw source text doesn't fit one line
- [ ] (mech) Constant that references another documented class (e.g.
      `DEFAULT_HANDLER = SomeClass.new`) — `Point::ORIGIN = new(0, 0)` is close
      but is a *self*-reference (an instance of the class it's defined on, not
      another one), so it exercises the value/type machinery but not this case
- [x] (mech) Private constant (`private_constant`) — `Stopwatch::CLOCK`,
      backing `#current_time`; confirmed omitted with zero template changes,
      same policy as instance/class-method privacy

### YARD tags

- [x] `@param` (including duck-type syntax, e.g. `@param [#to_s] x`) — duck
      typing itself not exercised, but the tag is otherwise thorough
- [x] `@return` (including `void` and multi-type unions) — `void`/unions not
      exercised, but the tag is otherwise thorough
- [ ] (design) `@option` (documenting keys of an options hash/kwargs)
- [x] `@yield`, `@yieldparam`, `@yieldreturn` — shared the block-presentation
      decision with the `&block`/implicit-block items under "Methods"; see
      "Block presentation" under "Decisions"
- [x] `@raise` (including a method that documents more than one exception
      type) — `Geometry::Computations.centroid` (single `@raise`, unresolved
      `ArgumentError`) and `Geometry::Point.parse` (two `@raise` tags,
      `ArgumentError`/`TypeError`); settled the always-bulleted `**Raises:**`
      list format — see "`@raise`: always-bulleted `**Raises:**` list" under
      "Decisions"
- [ ] (mech) `@see` — linking to another method, another class, and an
      external URL, plus the trailing-description form
      (`@see Foo#bar Some label`); only the "another method" case is
      exercised so far (see also the cross-referencing scenarios below)
- [ ] (design) `@example` — both a bare example and a titled example
      (`@example Some title`), and a method with more than one `@example`
- [ ] (design, one decision) Auxiliary one-line tags — `@deprecated` (with
      and without a replacement pointer), `@since`, `@note`: settle
      placement, ordering, and format of auxiliary annotations *once*, then
      cover each representative (the rest become mechanical). Include at
      least one such tag on a non-method object (`@deprecated` on a class,
      `@since` on a constant) — the format shouldn't be method-only.
- [ ] (design) `@abstract` (on a class/module, and on a method meant to be
      overridden) — likely follows the auxiliary-tags decision above, but
      may warrant more prominence than a one-line annotation
- [ ] (design, one decision) Remaining free-form/low-value tags — `@todo`,
      `@author`, `@version`, and anything similar: a single policy (render
      generically or deliberately drop). These are rarely what an agent
      needs; per-tag treatment isn't worth it.

### YARD directives (for dynamically-defined methods/attrs)

- [ ] (mech) `@!attribute` (documenting an attribute defined through
      metaprogramming rather than `attr_*`)
- [ ] (mech) `@!method` (documenting a method defined via `define_method` in
      a loop, or via a class-level DSL macro — common in real-world gems)
- [ ] (stretch) `@!group` / `@!endgroup` (method grouping) — only include if
      we decide the output format should reflect YARD groups

### Documentation content / prose patterns

- [x] Single-line summary only — e.g. `Point#x`'s "The x-coordinate."
- [x] Multi-paragraph description (summary + extended discussion) — the
      `Geometry` module doc
- [ ] (mech) Markdown formatting in prose: code spans, a fenced code block, a
      list, a link (only code spans are exercised so far, e.g. `` `"x,y"` ``)
      — safe now that the markup-dialect decision keeps Markdown sources
      passthrough (see "Docstring markup dialect" under "Decisions"). Also
      the place to eventually resolve a wrinkle surfaced while building the
      `:rdoc` dialect path: a prose-embedded heading (RDoc `=`, or a literal
      Markdown `# `) converts/passes through into an ATX heading that
      collides with the file's own `# class Foo`/`## Member
      Summary`/`### #method` heading hierarchy `grep '^## '` relies on — not
      exercised in either dialect's fixture yet, deliberately deferred.
- [x] Docstring markup dialect — dispatch on `options.markup`, `:markdown`
      passes through, `:rdoc` converts via `RDoc::Markup::ToMarkdown`
      (`YARD::AgentDocs::Markdownify#markdownify`). Covers docstring bodies,
      `@param`/`@return` tag text, and Member Summary one-line summaries —
      see "Docstring markup dialect" under "Decisions" for the full scope
      and unsupported-dialect behavior settled while implementing this.
- [ ] (design) Prose/summary containing Markdown metacharacters (backticks,
      `*`, `_`, `[`) — the Member Summary embeds one-line summaries in
      bullet lists and headings embed member names, so this forces an
      escaping policy
- [x] A class-level doc comment (not just method-level) — both `Geometry` and
      `Geometry::Point`
- [ ] (design) Intentionally undocumented objects — a public method with no
      doc comment, and an entirely undocumented class/module (one policy
      decision: flag it, render a stub, or omit entirely)

### Cross-referencing scenarios

- [x] Method `@param`/`@return` type referencing another class defined in the
      example (same file and a different file) — `Point#+` referencing
      `Point` itself (same file) and `Geometry.distance` referencing `Point`
      (different file) both render correctly (unlinked vs. linked)
- [x] Inline `{Foo#bar}` references in prose — YARD's idiomatic in-prose
      link syntax, including the labeled form (`{Foo#bar label text}`),
      escaping (`\{...}`/`!{...}`), same-file self-references, unresolved
      references, and code-span/fenced-block exclusion. See "Inline
      cross-references in prose" under "Decisions" for the full scope and
      rendering rules.
- [x] `Hash{K => V}` compound type — the `=>`/`{`/`}` tokens needed no scanner
      changes (`type_ref` was already written to buffer any punctuation
      generically, not just `Array`'s `<`/`>`; see "Compound-type
      cross-referencing" under "Decisions"), just proof: unit tests in
      `test/test_cross_referencing.rb` for both the resolving
      (`Hash{Baz => Baz}`) and nothing-resolves (`Hash{Symbol => Numeric}`)
      cases, plus `Geometry::Point#translate`'s `Hash{Symbol => Numeric}`-typed
      `@param` as the `example/` appearance.
- [ ] (mech) Remaining compound-type variants — parenthesized
      `Array(Float, Float)`, nested generics (e.g. `Array<Hash{Symbol =>
      Point}>`): the `(`/`)` tokens and multi-level nesting still aren't
      proven by any existing case. Unit-test coverage in
      `test/test_cross_referencing.rb` plus at least one `example/`
      appearance.
- [ ] (mech) `@see` pointing at another method in the same class
- [x] `@see` pointing at a method in a different class/namespace —
      `Geometry.distance`'s `@see Point#distance_to`
- [ ] (design) A subclass method that overrides a documented parent method
      without redocumenting it (does output inherit/copy/link the parent
      doc?) — pairs with the inherited-method open question below
- [ ] (mech) A mixin method's docs as seen from an including class — largely
      settled by the mixin content-strategy decisions (link out, never
      duplicate); this item just verifies nothing about the module-page side
      remains undecided

### Indexing & discovery

- [x] (design) Flat full-FQN index — see "Flat full-FQN index: classes/modules
      only, replacing the top-level list" under "Decisions".

## Open questions

Output format, indexing/lookup, cross-referencing, and the core YARD
integration mechanics are now decided *and implemented* — see "Decisions" and
"Implementation" below. What's still open:

- **Content strategy for a subclass method inherited (not overridden) from a
  superclass** — does the subclass's file duplicate, link out, or say
  nothing at all? Resolved for `include` (see "Mixin content strategy"
  under "Decisions"), `extend` (see "`extend` content strategy"), and
  `prepend` (see "`prepend` content strategy") — all three "link out, not
  duplicate" (or, for `prepend`, indistinguishable from `include`). Still
  open for plain superclass inheritance itself. Not yet exercised in
  `example/lib`.
- **Flat full-FQN index** — tracked as a (design) checklist item under
  "Indexing & discovery" rather than re-described here. (Docstring markup
  dialect, formerly also listed here, is now decided — see "Docstring markup
  dialect" under "Decisions".)
- **The "no custom handler classes" integration principle** — a standing
  watch, not a specific item. The `prepend` limitation (see "`prepend`
  content strategy" under "Decisions") was this principle's first real
  cost: YARD's stock handlers discard the include-vs-prepend distinction,
  and we accepted a permanent gap rather than write a handler. That was the
  right call in isolation, but if the dogfood milestone (see
  "Prioritization and roadmap") surfaces more cases where stock handlers
  discard data the output format wants, revisit the principle once,
  deliberately — rather than accumulating "permanent gap" decisions one at
  a time.

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

1. **`# class FullyQualifiedName`** / **`# module FullyQualifiedName`** title —
   explicit about which it is (`object.type`) rather than leaving an agent to
   infer it from the presence/absence of a `**Superclass:**` line, which
   requires already knowing that every Ruby class implicitly has `Object` as
   a superclass even when unstated. Mirrors Ruby's own `class Foo`/
   `module Foo` declaration syntax, same convention the format already uses
   for method signatures (natural call syntax over an invented schema).
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
   - Within a subgroup, members are sorted alphabetically by their display
     name (`member_name` — the sigil-less name, `new` for the constructor),
     not by source-file definition order. Applies to both the summary
     bullets here and the per-kind sections in step 5 below.
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

### Optional param default rendering: signature only

Settled while exercising "optional positional params with default values"
(`Stopwatch#reset(to = DEFAULT_ELAPSED)`). An optional param's default value
shows up **only** in the signature line, using natural Ruby `def` syntax —
`` stopwatch.reset(to = DEFAULT_ELAPSED) → Float `` — rather than as extra
annotation on the `**Params:**` bullet (e.g. `` `to` (`Float`, optional,
default `DEFAULT_ELAPSED`) ``). One place to look for the default, no
duplication between the signature and the params list; the prose/`@param`
text is still free to mention the default in words when that reads more
naturally (as `#reset`'s does: "defaults to `DEFAULT_ELAPSED`").
`param_names` (`templates/default/module/agentdocs/setup.rb`) renders each
parameter as `` "#{name} = #{default}" `` when YARD reports a default,
`` name `` otherwise — a param with no default (required) is unaffected, so
every already-covered signature (required-positional-only) renders exactly
as before.

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

### `extend` content strategy: link out, same as `include`

Resolves the `extend` half of the (now former) "Mixin/inheritance content
strategy" open question, mirroring the `include` decision above (`prepend`
is resolved separately below). Exercised via `Geometry::Named` (a module
defining one instance method, `#kind`, meant to be `extend`ed rather than
`include`d) `extend`ed into `Geometry::Triangle`.

A class's own file does **not** duplicate an `extend`ed module's methods as
Class Methods entries — `class_method_objects` already passed
`included: false`, and YARD's `included_meths` uses that same flag for both
`include` (`:instance` scope) and `extend` (`:class` scope, wrapped in
`ExtendedMethodObject`), so no template change was needed there; the fix
that made `included: false` apply at all was already made for `include`
(see "Latent bug fixed along the way" above). The class file instead gets a
new `**Extends:**` metadata line (`class/agentdocs/setup.rb#extends_line`,
reading `object.mixins(:class)`), rendered right after `**Includes:**` in
`metadata.erb` — same link/display-name convention as `**Superclass:**`/
`**Includes:**`. The `extend`ed module's own file keeps documenting its
method(s) as ordinary instance methods (how they're actually written in
source), same as a directly-`include`d module's page does; only the
*extending* class's page needs to know it was mixed in via `extend` rather
than `include`.

Scoped to classes only for now, same as `**Includes:**`/`**Superclass:**`
(`extends_line` returns `nil` unconditionally in `module/agentdocs/setup.rb`)
— a module extending another module isn't yet exercised, matching
`**Includes:**`'s existing class-only scope.

### `prepend` content strategy: folded into `**Includes:**`, undistinguished

Resolves the `prepend` half of the (now former) "Mixin/inheritance content
strategy" open question — but as an accepted limitation, not a clean
mirror of `include`/`extend`. Exercised via `Geometry::Loud` (overrides
`#describe` by calling `super.upcase`) `prepend`ed into `Geometry::Polygon`,
which defines its own `#describe`.

**The limitation:** YARD's `Handlers::Ruby::MixinHandler` handles both
`include` and `prepend` with the same code path, pushing the mixin onto the
same `object.mixins(:instance)` array either way — confirmed by inspecting
the handler source and by a scratch script parsing a two-mixin class: the
resulting `ModuleObject`s are plain and untagged, with no attribute
recording which keyword brought each one in. Array order isn't a usable
substitute either — `include` `unshift`s and `prepend` `push`es, but tracing
through a 4-statement example (alternating `include`/`prepend`) shows the
two kinds interleave in the final array with no clean split to exploit.
Getting a real distinction would need a custom `Handler` subclass to tag
prepended modules separately, which cuts against this project's stated
"no custom handler classes" integration principle (see "Architecture"
below) — not worth doing for this one line.

**The decision:** ship the honest, cheaper answer. `Loud` shows up under
the ordinary `**Includes:**` line on `Polygon`'s page — no `extends_line`-style
`prepends_line`/`**Prepends:**` counterpart, and no template code change was
needed at all for this item (the existing `includes_line` already renders a
`prepend`ed module correctly, since YARD hands it the same data either way).
The one thing metadata *can't* convey — that `Loud#describe` actually wins
over `Polygon`'s own `#describe` at call time, the opposite precedence from
`include` — is explained only in `Polygon`'s hand-written class docstring.
This means an agent reading just the `**Includes:**` line (without reading
the prose) cannot tell a `prepend`ed module from an `include`d one; that's a
real, permanent gap in the output format, not a TODO to close later.

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

### Compound-type cross-referencing

Extends the "Cross-referencing" decision above to a **compound** type string
— one with collection/union syntax around one or more names, e.g.
`Array<Point>` (`Geometry::Computations.centroid`'s `points` param). The
naive option — resolve the *whole* string as one name — never links these:
`Registry.resolve` doesn't understand `Array<Point>` as "an `Array` of
`Point`," so it comes back `nil` and the whole thing falls back to a single
unlinked backtick, even though `Point` itself is a real, resolvable,
in-example type.

Rejected: reparsing the type string with YARD's own `Tags::TypesExplainer`
(the parser behind the `yard types` CLI command and `Tag#explain_types`) to
extract the inner name(s). It builds a semantic tree (`CollectionType`,
`HashCollectionType`, etc.) meant for generating human-readable prose like
"an Array of (a Point)" — it doesn't preserve the original punctuation, so
there'd be no way to get back to `Array<Point>` with just `Point` linked;
we'd have to reinvent that rendering from the semantic tree instead of
reusing the original text.

Chosen instead: `type_ref` scans the type string with `StringScanner`,
token by token, reusing YARD's own token-matching building blocks
(`CodeObjects::NAMESPACEMATCH`, `ISEP`, `METHODNAMEMATCH` — the same regexes
`TypesExplainer`'s parser is built from) to recognize a "name" (a namespace
path, a duck-type method reference like `#to_s`, a string/symbol literal, or
a bare word like `nil`) — `templates/default/module/agentdocs/setup.rb`'s
`TYPE_TOKEN`. Only names that actually resolve get pulled out into their own
Markdown link; everything else — collection/union punctuation (`<`, `>`,
`{`, `}`, `,`) and names that don't resolve — accumulates into a plain-text
buffer that gets flushed as one backtick span the moment a resolved name
interrupts it (or at the end of the string). `Array<Point>` (with `Point`
resolving) renders as `` `Array<`[`Point`](Point.md)`>` ``; `Array<Foo>`
(nothing resolves) collapses to a single buffer flush, `` `Array<Foo>` `` —
byte-identical to the old whole-string behavior, so every already-covered
simple type (a lone name, resolved or not) renders exactly as before.

**Why not wrap every token (including punctuation) in its own backtick
span?** That was the first design tried, and it's broken: two backtick-
delimited code spans placed directly adjacent with nothing between them
(e.g. `` `Array` `` immediately followed by `` `<` ``) put two backtick
characters next to each other in the raw text, which CommonMark parses as
one longer opening delimiter rather than "close one span, open the next" —
silently mangling the output. Buffering — merging all not-just-resolved
content into a single span instead of one-per-token — sidesteps this
entirely, since a link (not another bare backtick span) is always what
separates two buffer flushes. It also means collection punctuation is never
left as bare, unescaped text: leaving `<`/`>` unwrapped was considered and
rejected too, even though tracing through CommonMark's raw-HTML-tag and
autolink grammars shows a bare `<` here would never actually be misread
(a link's own resolved-vs-unresolved rendering always makes the character
immediately following `<` either `` ` `` or `[`, neither of which can start
an HTML tag or autolink) — that safety argument is subtle and rests on
`type_ref`'s output shape never changing, whereas keeping every character
inside a backtick span is safe on its face, for any markdown consumer,
without relying on that argument.

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

#### Flat full-FQN index: classes/modules only, replacing the top-level list

`index.md`'s single `## Classes & modules` section now lists every documented
class/module (not just root-namespace ones) as one bullet each, sorted
alphabetically by full FQN with the same `[FQN](path) — summary` link format
as before. This replaces the prior `## Top-level namespaces` section rather
than supplementing it — the flat list is a strict superset (top-level
namespaces are still in it), so keeping both would just duplicate content in
the same file. An agent that knows a class/module's name but not its
namespace can now find it in one file read via `grep`, without walking the
tree from a root namespace.

Granularity stops at classes/modules — members are deliberately excluded.
Once an agent has the FQN's file open, member lookup is already solved via
headings + `grep -n '^### '` (see above), so indexing every method too would
duplicate that mechanism while bloating the index, working against the
"minimize tokens" goal for a lookup problem that doesn't exist once the file
is open.

Implementation-wise, this only touched `serialize_index`/`index.erb`
(`@top_level_objects` → `@indexed_objects`, filtered to `object.type` of
`:class`/`:module` and sorted by `object.path` instead of `object.namespace.root?`
and `object.name`) — no new `example/lib` fixtures were needed, since the
existing `Geometry::*` nesting already exercised a non-trivial FQN depth.

### Checklist pruning and prioritization (July 2026)

A consultant-style review pass tightened the coverage checklist. Recording
the removals/merges here so they don't get re-proposed later as gaps:

- **"Plain class with no superclass vs. explicit `< Object`"** — removed.
  `Stopwatch`/`Point` already cover the implicit case, and YARD records the
  `Object` superclass as an unresolved proxy either way, so the explicit
  variant would render byte-identically. Nothing left to decide or exercise.
- **`#to_s`/`#inspect` overrides** — removed. They're ordinary instance
  methods: no signature shape, tag, or rendering decision distinguishes
  them, and no special-casing is planned.
- **`@todo`/`@author`/`@version` as separate items** — collapsed into one
  free-form-tag policy item under "YARD tags"; the real decision is one
  policy, not three tags.
- **Duplicate `@overload` entry** — the YARD-tags copy removed; the item
  under "Methods — shapes & signatures" is the one canonical entry.
- **`@private` tag + `@api private`** — merged into one tag-based-privacy
  item under "Visibility"; both pose the same question (appear in output or
  not, flagged how).
- **Operator-method bullet split** — the previously checked bullet bundled
  `#[]`/`#[]=`/`#==`/`#<=>`/unary operators with infix `#+`, but only the
  infix-binary rendering is actually designed and exercised — by the
  checklist's own checking rules it was overchecked. Now split: `#+` stays
  checked as "infix binary operator"; the remaining operator forms are a
  new unchecked (design) item, since each has a distinct natural-call-syntax
  rendering.

The same pass added the missing-coverage items (inline `{...}` references,
markup dialect, exception class, compound-type variants, metacharacter
escaping, undocumented class/module, flat index), introduced the
(design)/(mech)/(stretch) priority markers, and added the dogfood milestone
— see "Prioritization and roadmap" under "Example coverage checklist".

### Docstring markup dialect: Markdown passes through, RDoc converts via `RDoc::Markup::ToMarkdown`

Settles the markup-dialect checklist item's *decision* ahead of its
implementation — unusually for this project, it was decided by inspecting
YARD's own source (yard 0.9.44, rdoc 8.0.0) rather than by iterating on
example fixtures, because the question is about matching ecosystem behavior,
not inventing format.

**Implemented** as `YARD::AgentDocs::Markdownify#markdownify`
(`lib/yard/agentdocs/markdownify.rb`), `include`d into
`module/agentdocs/setup.rb` alongside the other `lib/` mixins. Two points
left open above were settled during implementation:

- **Scope: full, not body-only.** `markdownify` wraps every prose string the
  templates render, not just the class/method/constant/attribute body
  docstring: `@param`/`@return` tag text (`method_entry.erb`) and every
  Member Summary one-line summary (`*_summary_line` in
  `module/agentdocs/setup.rb`, `attribute_docstring` in
  `lib/yard/agentdocs/attribute_info.rb`) also go through it. Matches real
  YARD, whose default HTML template likewise runs tag text through
  `htmlify_line` — an RDoc-authored `@param` description left unconverted
  would leak raw `+teletype+`/`*bold*` markers into a Params bullet under
  `--markup rdoc`.
- **Unsupported markup type: log and pass through, don't raise.**
  `log.error`s (YARD's own logging convention, matching
  `MarkupHelper#load_markup_provider`'s pattern) and returns the raw text
  unconverted, rather than raising and aborting generation. Softer than the
  original "fail loudly" leaning, chosen so one object with an exotic
  `--markup` setting doesn't take down an entire otherwise-fine generation
  run; the logged error still makes the gap visible.
- One thing probed but deliberately *not* exercised in the rdoc-dialect
  example fixture: an RDoc `=` heading. It converts correctly in isolation
  (verified by unit test), but embedding one in a class docstring collides
  with this format's own heading hierarchy — see the note added to
  "Markdown formatting in prose" under "Example coverage checklist".

**What YARD's default template does:** `HtmlHelper#htmlify` dispatches on
`options.markup` (the `--markup` flag) to a per-dialect
`html_markup_<type>` method (rdoc — YARD's default — markdown, textile,
org, asciidoc, plus literal types), each converting the docstring to
*HTML*, the template's own output format, via a pluggable provider
(`MarkupHelper::MARKUP_PROVIDERS`). The dialect question disappears at
conversion time; the template proper only ever sees its output format.
Notably, `{Foo#bar}` resolution (`resolve_links`) runs *after* markup
conversion, on the converted text — it's dialect-independent.

**The decision:** mirror that shape with a `markdownify` dispatch on
`options.markup`, converting prose to *our* output format (Markdown):

- **`:markdown` — passthrough.** What the template already does today, now
  correct by declaration rather than by accident.
- **`:rdoc` — convert with `RDoc::Markup::ToMarkdown`** (ships in the rdoc
  gem, `rdoc/markup/to_markdown`). YARD's own `RDocMarkup` provider wraps
  the same `RDoc::Markup` parser with the `ToHtml` formatter; this is the
  identical pattern pointed at a different formatter. Probe-verified
  against rdoc 8.0.0: `+other+` → `` `other` ``, `*this*` → `**this**`,
  `{label}[url]` → `[label](url)`, `=` headings → ATX `#` headings.
- **Any other markup type — out of scope.** Leaning: fail loudly (log an
  error) rather than silently emit textile/org source into `.md` files;
  finalize the exact unsupported-dialect behavior at implementation time.

**Implementation/testing guidance** for the session that builds it:

- Put the conversion in a `lib/yard/agentdocs/` mixin with focused unit
  tests, per "Extracting generic logic into `lib/` mixins".
- `ToMarkdown`'s exact output (4-space-indented code blocks rather than
  fenced, list/wrap details) is owned by the rdoc gem, so any rdoc-dialect
  fixture couples byte-for-byte to the installed rdoc version. Contain
  that: keep the main `example/` fixture set declared `--markup markdown`,
  and cover the rdoc path with unit tests plus at most one small dedicated
  rdoc-dialect fixture, so rdoc version drift breaks one localized,
  legible spot.
- Probe, don't assume, that a bare YARD-style `{Foo#bar}` inline reference
  (braces *not* followed by `[url]`, so not RDoc link syntax) passes
  through `ToMarkdown` unmangled — the inline-references checklist item
  resolves those *after* conversion, same as YARD's `resolve_links`.

**Rejected: a hybrid accept-both parser.** As of 0.9.44, YARD's default
provider for *both* `:rdoc` and `:markdown` is its built-in
`HybridMarkdown` — one tolerant parser accepting both dialects at once. It
isn't reusable here (it targets HTML), and the accept-both trick only
works when converting to a third format: for Markdown *output*,
passthrough-plus-conversion is the coherent split, since round-tripping
Markdown through a hybrid parser would reformat prose the author already
wrote in the output dialect.

### Inline cross-references in prose: rewrite to a Markdown link, reusing `Registry.resolve`

Settles the inline-`{Foo#bar}`-references checklist item. Implemented as
`CrossReferencing#resolve_references` (`lib/yard/agentdocs/cross_referencing.rb`),
called by `Markdownify#markdownify` as its final step — so every prose call
site gets this automatically, with no template changes needed beyond what
"Docstring markup dialect" already wired up. Confirmed via
`Registry.resolve(object, name, true, false)` (the same call `type_ref`/
`see_ref` already use) that relative forms like `#other_method` resolve
correctly regardless of whether `object` is the enclosing class/module or a
specific method within it — no new resolution logic was needed, only the
prose-scanning/rendering layer around it.

**Syntax supported**, deliberately narrower than YARD's own `resolve_links`/
`linkify`: a bare reference `{Name}`, a labeled reference
`{Name label text}`, and an escaped `\{...}` or `!{...}` (backslash or bang
— both are real YARD escape prefixes — stripped, left completely literal,
never resolved). `Name` is resolved with the same relative-path semantics
`@param`/`@return`/`@see` already use, so `{#sibling_method}`,
`{Other::Class#method}`, `{CONST}`, etc. all work. Explicitly **not**
supported: YARD's other `linkify` special forms (`include:`, `render:`,
`file:`, bare URLs, `<a href>` unwrapping) — those are separate YARD
features unrelated to object cross-referencing, out of scope for this item.

**Rendering, all decided as deliberate departures from mirroring YARD's
HTML behavior exactly, for consistency with this format's own established
conventions:**

- **Resolved, not self-referencing:** `{Name}` → `` [`Name`](path) ``
  (name as written, backticked, same convention as `type_ref`/`see_ref`);
  `{Name label text}` → `[label text](path)` (label shown as plain prose,
  no backticks — it's freeform text the author chose, not necessarily a
  code-like name).
- **Resolved, but a same-file self-reference** (per the existing
  "Cross-referencing" decision: a link to the file you're already in is
  useless) — `{Name}` → `` `Name` `` (backtick, no link, matching
  `see_ref`'s self-reference convention — `see_ref` was refactored to
  share the same `self_reference?` owner-comparison helper); `{Name label
  text}` → `label text` (plain prose, *no* backticks — the author wrote
  that label to read naturally in the sentence; showing it plain preserves
  that, at the cost of consistency with the no-label case, which was
  judged the better tradeoff).
- **Unresolved** (either form) — the entire original text, braces
  included, passes through completely untouched. A deliberate departure
  from real YARD, which strips the braces and shows the bare name/label as
  plain unlinked text even when unresolved (a known YARD footgun: an
  unescaped stray `{...}` in prose that was never meant as a reference
  silently loses characters). Matches this project's existing precedent
  instead — `type_ref`'s unresolved names and compound-type punctuation are
  always preserved verbatim, never partially rewritten.
- **Inside a backtick code span** (any length, so this also covers a
  fenced ` ``` ` block) — left completely alone, matching Markdown's own
  rule that nothing inside a code span is markup. Implemented as an outer
  `StringScanner` loop over backtick-delimited runs (opening run length
  *N*, closing at the next run of exactly length *N* — same rule
  CommonMark uses), so reference-resolution only ever runs on the
  non-code segments in between.

**Exercised** in both fixture sets: the main `example/` (Markdown dialect)
set gained a resolved unlabeled cross-file reference and a resolved
labeled cross-file reference (`Triangle`'s doc, referencing `Polygon` and
`Named`), an unresolved reference left untouched (`Point`'s doc,
referencing the not-yet-mixed-in `Comparable`), and a labeled self-reference
(`Stopwatch`'s doc, referencing its own `#reset`). The `example/rdoc`
fixture's pre-existing bare self-reference (`Greeter`'s doc, referencing
its own `#greet`) now actually resolves — previously it was deliberately
left unresolved pending this item, and its expected output/commentary was
updated accordingly. Escaping and the code-span/fenced-block exclusion are
covered by unit tests only (`test/test_cross_referencing.rb`), not the
example fixtures, per this project's existing precedent of keeping
narrative fixture prose natural rather than forcing in every edge case
(see the heading-collision note this same precedent left under "Markdown
formatting in prose").

### Block presentation: `&block` in the parens, implicit `yield` as a trailing block literal

Settles the "block-presentation decision" shared by the `&block`-captured,
implicit-block-usage, and `@yield`/`@yieldparam`/`@yieldreturn` checklist
items — all three landed together, since a block-taking method isn't fully
documented without also rendering what it yields. Exercised via
`Stopwatch#measure(&block)` (explicit capture, no yielded args), `` Geometry
::Polygon#each_side`` (implicit `yield`, one yielded arg named only via
`@yield`'s bracket), and `Geometry::Computations.each_point` (implicit
`yield`, one yielded arg named via `@yieldparam`).

**Signature line — matches how the method is actually called, not how it's
declared:**

- A method that captures the block as a named `&block` parameter shows it
  inline with the other params, same as any other param — `param_names`
  already handles this for free (YARD reports `&block` as a plain parameter
  name), no template code needed: `` stopwatch.measure(&block) → Object ``.
- A method that takes a block only implicitly (bare `yield`, no captured
  param — detected by `implicit_block?` in `method_signature.rb`: any of
  `@yield`/`@yieldparam`/`@yieldreturn` present, and no parameter name
  starts with `&`) instead gets a trailing block-literal fragment from
  `block_literal`, e.g. `` polygon.each_side { |side_number| ... } → Integer ``
  or `` Computations.each_point(*points) { |point| ... } → Integer `` — this
  is how you'd actually have to call it (Ruby's `{ ... }`/`do...end` block
  syntax), so it follows the same "natural call syntax over an invented
  schema" precedent as everything else in the signature line. The block's
  parameter names come from `block_param_names`: `@yieldparam` names in
  declaration order if present, else `@yield`'s own bracketed name list
  (`@yield [a, b] ...`), else empty (`{ ... }` with no `| |`). An empty
  ordinary-param list is dropped entirely when a block literal follows
  (`each_side` has no real params, so it renders as `polygon.each_side { ...
  }`, never `polygon.each_side() { ... }`) — parens still appear as normal
  when real params exist alongside the block (`each_point`'s `(*points)`).

**`@yield`/`@yieldparam`/`@yieldreturn` rendering**, inserted between
`**Params:**` and `**Returns:**` in `method_entry.erb`:

- `**Yields:**` — one line, from `@yield`. Critically, `@yield`'s bracketed
  part (`@yield [a, b] description`) holds *parameter names*, not types —
  confirmed against YARD's own tag library docs and dogfooded usage
  (`yard/tags/library.rb`, `@yield [a, b, c] Gives 3 random numbers to the
  block`) — so those names are rendered as plain backticked literal text
  (`` `side_number` — one call per side ``), **never** passed through
  `type_ref`, which is reserved for real type strings (`@return`,
  `@yieldreturn`, `@param`/`@yieldparam`'s type brackets). A bracket-less
  `@yield` (no yielded args, e.g. `Stopwatch#measure`) renders as just the
  description, no leading backtick/dash — matches common bracket-less
  `@yield` idiom seen throughout YARD's own source (e.g. `` @yield a block
  of arbitrary code to benchmark ``).
- `**Yield Params:**` — a bullet list from `@yieldparam`, structurally
  identical to `**Params:**` (`` `name` (`Type`) — description ``, `Type`
  through `type_ref` as usual — `@yieldparam` types are real types, unlike
  `@yield`'s bracket).
- `**Yield Returns:**` — one line from `@yieldreturn`, structurally
  identical to `**Returns:**`.

All three are independently optional (a method may have any subset), and a
method can legitimately use `@yield`'s bracket form *instead of*
`@yieldparam` for a simple single-purpose block (`each_side`) or
`@yieldparam` *instead of* a bracketed `@yield` for a more structured
breakdown (`each_point`) — both styles occur in real-world YARD usage, and
the fixtures deliberately exercise one of each rather than combining both
on the same method.

### Visibility policy: Ruby-scope privacy omitted, tag-based privacy shown-and-flagged

Settles the "visibility policy" shared by `private`/`protected` methods,
private class methods, `private_constant`, and tag-based privacy
(`@private`/`@api private`) — following "Design heuristic: agent reference
needs mirror human reference needs" above, which led to two *different*
resolutions rather than one:

- **Ruby-scope `private`/`protected`** (and `private_constant`): omitted
  entirely, exercised via `Stopwatch#current_time` (a private helper backing
  `#measure`), which doesn't appear anywhere in `Stopwatch.md`. This falls
  out of YARD's own CLI defaults (`visibilities = [:public]` in
  `YARD::CLI::Yardoc`) with **no template code** — the `agentdocs` templates
  never see these objects in the first place. Deliberately relies on the
  invoking `yardoc` command not passing `--private`/`--protected`, rather
  than defensively filtering by `object.visibility` in the template: that
  would block a legitimate use case (an agent doing internal maintenance on
  the gem itself, not just consuming its public API) for a problem
  (`.yardopts` inheriting unwanted flags from an unrelated human-doc setup)
  that's speculative, not observed. Revisit only if the dogfood milestone
  (see "Prioritization and roadmap") surfaces a real case.
- **`@private` tag / `@api private` tag** on an otherwise Ruby-public method:
  shown, not omitted — matching YARD's default HTML template, which also
  renders these (bare `yardoc` doesn't hide `@private`/`@api private` by
  default; `--no-private` is a flag for exactly this, off by default despite
  the name, and had to be **removed** from `test/test_agentdocs_template.rb`'s
  `generate`/`generate_rdoc` invocations, since it was already suppressing
  these objects entirely rather than flagging them). Exercised via
  `Stopwatch#raw_elapsed_s` (tagged `@private`; `@api private` resolves
  identically via the same `VisibilityInfo#private_api?` check, so wasn't
  separately exercised). Flagged with a `**Private API.**` bold line in
  `method_entry.erb`, inserted between the signature code block and the
  docstring, plus a `(private API)` parenthetical suffix on the Member
  Summary bullet — both structurally identical to the existing
  `attribute_annotation`/`attribute_annotation_short` (`**Read-only.**`
  /`(read-only)`) mechanism, now generalized as
  `YARD::AgentDocs::VisibilityInfo`. This is terser than YARD's own
  multi-line warning paragraph (`docstring/*/private.erb`), per the
  terseness half of the design heuristic above, and establishes the
  precedent the not-yet-tackled auxiliary-one-line-tags item
  (`@deprecated`/`@since`/`@note`) will likely want to follow.

### `@raise`: always-bulleted `**Raises:**` list

Settles the format for `@raise`, exercised via `Geometry::Computations.centroid`
(a single `@raise`, an unresolved `ArgumentError` when called with no points)
and `Geometry::Point.parse` (two `@raise` tags, `ArgumentError` for a malformed
string and `TypeError` for a non-`String` argument — mirroring how Ruby's own
`Integer()`/`Array()` conversions document more than one failure mode for one
method):

- Renders as a `**Raises:**` heading followed by a bulleted list — one
  `` - `ExceptionType` — description `` line per `@raise` tag — even when
  there's only one tag, rather than `**Returns:**`'s single-line form. A
  method can carry zero, one, or many `@raise` tags, the same shape as
  `@param`, so it follows `**Params:**`'s always-bulleted convention rather
  than `**Returns:**`'s (which YARD only ever surfaces one of via
  `method_return_tag`). This also matches YARD's own default HTML template,
  which wraps `@raise` in a `<ul>` regardless of tag count
  (`Tags::Library.define_tag "Raises", :raise, :with_types`, rendered via
  `templates/default/tags/html/tag.erb`).
- Positioned after `**Returns:**` and before `**See also:**`, matching YARD's
  own tag ordering (`Tags::Library.visible_tags`: `..., :return, :raise,
  :see, ...`).
- The exception type goes through the same `type_ref` cross-referencing as
  any other type token: both examples use unresolved stdlib exceptions, which
  render as a plain backtick, same policy as an unresolved `Array`/`Hash`
  element type. An in-example custom exception class isn't exercised here —
  deliberately deferred to the still-open "custom exception class" checklist
  item under "Module/class structure", which pairs with this one.
- A single `@raise` tag carrying more than one type (e.g. `@raise
  [ArgumentError, TypeError]`) isn't exercised; `Point.parse` uses two
  separate single-type tags instead, judged the more common real-world
  pattern. Revisit if the dogfood milestone turns up the multi-type-per-tag
  form in the wild.

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
  one's `setup.rb` isn't visible in the other's): `ErbWithTrimMode`,
  `CrossReferencing`, `MethodSignature`, `AttributeInfo`, and `Markdownify`,
  each `include`d where needed.
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

### Extracting generic logic into `lib/` mixins

Preference, going forward: once a `setup.rb` helper method is both (a)
generic enough that another template module could plausibly want it, and
(b) nontrivial enough to deserve isolated unit tests (branching logic,
regex/parsing, anything bug-prone), move it into its own
`lib/yard/agentdocs/*.rb` module — mirroring `ErbWithTrimMode` — and
`include` it from `setup.rb` rather than leaving it as a bare top-level
method there. `CrossReferencing` (`type_ref`/`see_ref`/`link_path`),
`MethodSignature` (`signature_text` and its supporting helpers), and
`AttributeInfo` (the `attribute_*` helpers) were split out of
`module/agentdocs/setup.rb` this way, cutting it from 267 to about 100 lines
of page-assembly glue.

Test each mixin with `YARD.parse_string` against a minimal stub class that
includes just the module under test (see `test/test_cross_referencing.rb`,
`test/test_method_signature.rb`, `test/test_attribute_info.rb`), not only
indirectly through the full `example/lib`/`example/doc` fixture — this
keeps failures localized to the one helper that broke, and lets edge cases
(e.g. compound-type cross-referencing) get direct coverage without needing
a matching `example/lib` scenario for every branch.

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
