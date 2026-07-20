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
   target output for it) — for any multi-line tag/docstring text, mirror the
   source comment's exact line breaks, since the template preserves raw text
   verbatim rather than rewrapping it — asking clarifying questions along the
   way where the item raises a design choice not already settled in
   "Decisions".
3. **Human** reviews the proposed `example/lib`/`example/doc` changes; they
   iterate with Claude as needed until both are satisfied. Nothing outside
   `example/` (templates, `test/test_agentdocs_template.rb`) is touched during
   this step.
4. Once the human explicitly says the example changes are good, **Claude**
   implements: confirm `toys test` fails against the new fixture (both
   `example/lib` source files and `example/doc` output files are
   discovered automatically — no list to maintain in
   `test/test_agentdocs_template.rb`), then update the template
   implementation until it passes
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
pick the next item. Some also carry a **pre-dogfood** annotation, defined in
the same section.

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

Additionally, a **pre-dogfood** annotation (alongside the priority marker)
means the item was judged (2026-07-17 review; two more added by a
2026-07-20 re-review after the first pre-dogfood pass closed out) worth
completing *before* the dogfood milestone: the gap sits on a pattern real
gems certainly use, and today's behavior is a silent drop, a pervasive
rendering artifact, or — worst, for the `@param`-mismatch item —
nondeterministic output, so leaving it open would pollute the dogfood
diff-read with known noise (or, for the nondeterminism, undermine its
reproducibility). As the dogfood milestone approaches, prefer pre-dogfood
items over unannotated ones of the same marker; the `@param`-mismatch item
comes first among them since it protects the reproducibility of every run
after it. The 2026-07-20 additions (the lexical cross-reference resolution
cap and the explicit-assignment-method rendering gap) were found by
probing the intended dogfood target (YARD's own source) directly rather
than reasoning abstractly — see their checklist entries under "Methods —
shapes & signatures" and "Cross-referencing scenarios" for the measured
evidence — which is why the same technique (a disposable probe against the
real target, not just re-reading the checklist) is worth repeating in any
future pre-dogfood re-review.

Suggested ordering: prefer (design) items early — each one settled reduces
the risk of late format churn invalidating already-approved fixtures — and
use (mech) items as filler between them. Every item, regardless of marker,
still goes through the human-gated workflow above; the marker only
calibrates how much iteration to expect.

**Dogfood milestone:** once the checklist is substantially covered — in
particular, once the **pre-dogfood**-annotated items above are done (or
consciously waived) — run the
template against a real, mid-size gem (YARD itself is a fitting candidate)
and diff-read the output. The hand-written example drives format decisions
well, but it will systematically miss what real docstrings do — markup
dialects, inline references, odd whitespace, very large classes that would
trigger the deferred "escape valve" under "File granularity". Harvest
anything the run surfaces back into this checklist as new items rather than
fixing ad hoc. Also verify the token-economy claim directly: on the
hand-written example, `example/doc` is ~37% *larger* than `example/lib`
(38.9KB vs. 28.5KB — judged an artifact of toy method bodies under rich
docstrings; see "Agent-usefulness evaluation" under "Decisions"), so
"cheaper than reading source" needs confirming on a real gem, where
implementation bodies dominate, rather than assuming. Two further
measurements ride along from the per-entry `Defined in:` review (see
"Per-entry `Defined in:` retained at all levels" under "Decisions"):
re-measure the per-entry `**Defined in:**` overhead on a real gem (8.6%
of corpus bytes on the hand-written example), and watch for evidence of
whether agents actually exercise those pointers.

**First run complete (2026-07-20, YARD 0.9.44 self-run)** — findings,
measurements, and two new checklist items in "Dogfood milestone: first run"
under "Decisions"; full working notes in `devdocs/Dogfood.md`. Further gems
may follow; that doc tracks status across all of them.

### Module/class structure

- [x] Top-level class — `Stopwatch`
- [x] Top-level module (namespace only, no behavior) — `Geometry` itself,
      once its one method moved to `Geometry::Computations`
- [x] Nested namespacing (`Foo::Bar::Baz`), including a module that
      exists only to hold nested classes/modules — path derivation is
      settled; an undocumented namespace-only module now also has a settled
      rendering (see "Intentionally undocumented objects" under
      "Decisions"), so this is unblocked — `Geometry::ThreeD` (undocumented
      namespace-only module) → `Geometry::ThreeD::Point`; path derivation
      needed no template changes, but surfaced a `**Defined in:**`
      determinism bug for undocumented multi-file objects, see "Class/module
      reopened across files" under "Decisions"
- [x] A class reopened across two files/locations (docs should
      merge — how do multiple `**Defined in:**` locations render?) —
      `Geometry::Rectangle`, split across `rectangle.rb`/
      `rectangle_perimeter.rb`; see "Class/module reopened across files"
      under "Decisions"
- [x] A custom exception class (`class ParseError < StandardError`) —
      `Geometry::ParseError`, raised by `Point.parse` (replacing that
      method's plain `ArgumentError`) alongside its existing `TypeError`, so
      `Point.md`'s `**Raises:**` list shows one linked, in-example entry
      next to one plain unresolved one; also exercises an *unresolved*
      superclass that isn't `Object`/`Struct`/`Data` (`**Superclass:**
      `StandardError``). Escalated from (mech) to (design) on the spot, per
      "Prioritization and roadmap": `ParseError` is idiomatically empty (no
      methods/constants/attributes), which no existing example class was —
      see "Empty `## Member Summary` section: omitted entirely" under
      "Decisions"
- [x] Subclassing a class defined elsewhere in the example (inheritance chain
      of at least 3 levels, to test how ancestry is presented) — `Geometry::Shape`
      → `Polygon` → `Triangle`; also settled that `**Superclass:**` links to a
      resolved (in-example) superclass's own file, showing the name as written
      in source
- [x] A `Struct.new`-based class — `Geometry::Circle`
- [x] A `Data.define`-based class (Ruby 3.2+ value object, relevant given the
      gem's `>= 3.4` floor) — `Geometry::Vector`
- [x] (design) Names-only inherited/mixin member roster in `## Member
      Summary` — one line per ancestor/mixin listing member *names* only,
      no descriptions (e.g. ``**Inherited from `Polygon`:** `#describe`,
      `#each_side`, `#label`, `#sides` ``). Deliberately revisits the
      settled "link out, don't duplicate" family ("Subclass method content
      strategy" / "Mixin content strategy" under "Decisions"): those weighed
      full doc duplication against a bare metadata pointer, but never this
      names-only intermediate — which is what YARD's own HTML template
      renders ("Methods inherited from …"), so the mirror-human-docs
      heuristic favors it. Today `Triangle.md` shows only `.new`; assembling
      a Triangle's full API surface takes four further file reads
      (`Polygon`, `Shape`, `Taggable`, `Named`). Raised by the July 2026
      agent-usefulness evaluation (see "Decisions"). See "Names-only
      inherited/mixin member roster" under "Decisions" for the settled
      shape, scope, and dedup rule

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
- [x] A module meant purely to be mixed in (documented as such, e.g. via
      `@abstract` or prose) rather than instantiated — `@abstract`'s own
      rendering is its own item under "YARD tags". Already covered
      incidentally, not by a dedicated fixture: `Taggable`/`Named` are both
      already documented in prose as mix-in-only, and a module never gets a
      synthetic `.new` entry regardless (that's constructor-specific, see
      the `Struct`/`Data` decision) — there's no distinct rendering left for
      a new fixture to prove
- [x] `extend self` pattern (module usable both as namespace and as
      mixin) — `Geometry::Angles`; settled by generalizing `**Extends:**`
      (and `**Includes:**`) from class-only to modules too, applying the
      existing self-reference-is-unlinked convention to the metadata line —
      see "`extend self` / `module_function`" under "Decisions"
- [x] `module_function` (same decision as `extend self` above) —
      `Geometry::Rounding`; confirmed purely mechanical, zero template
      changes — the private instance-side twin is already dropped by the
      existing visibility policy, leaving an ordinary class-method entry
- [x] Mixing in a stdlib module (e.g. `Comparable` or `Enumerable`) to see
      how we handle methods whose docs live outside the example source
      entirely — `Geometry::Path` (`include Enumerable`, defining only
      `#each`); confirmed purely mechanical, zero template changes:
      `**Includes:** \`Enumerable\`` renders as a plain, unlinked backtick,
      the existing unresolved-`CodeObjects::Proxy` branch `mixin_line`
      already had, same as an unresolved superclass. Added as a new class
      rather than retrofitted onto `Stopwatch`/`Point`, both of which
      already have approved docstring text explicitly declining to mix in
      `Comparable`

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
- [x] Multiple overloads via `@overload` — `Geometry::Point.of` (two
      overloads dispatching on argument type, with different return types
      each) and `Geometry::Point#label` (one overload, the "friendlier
      signature over an awkward real one" idiom); settled both the
      single-overload and two-or-more-overload rendering shapes — see
      "`@overload`" under "Decisions"
- [x] (design) Settle prose-vs-signature ordering as one uniform rule — the
      2+-overload shape led with the shared docstring and `@example`s
      (`Point.of`'s two examples rendered before *any* signature), while
      every other entry kind led with its signature/type block. Landed
      shape: one leading fenced block listing every overload's
      natural-call-syntax line, then flags/prose/`@example`s (shared), then
      one bold-inline-code-labeled `**Params:**`/`**Returns:**` group per
      overload — see "Prose-vs-signature ordering" under "Decisions"
- [x] A method that returns early with multiple distinct return shapes
      (documented return type is a union, e.g. `String, nil`); also cover
      `@return [self]` (chainable methods — a type token that's neither
      resolvable nor an ordinary class name) and `@return [void]` here —
      `Geometry::Path#closest_to` (union), `#add`/`#transform!` (`self`),
      `#clear` (`void`); tackled together with multiple `@return`/
      `@yieldreturn` tags below since both turned out to be the same
      underlying gap — see "Multiple return types: union tags, multiple
      `@return`/`@yieldreturn` tags" under "Decisions"
- [x] Multiple `@return` tags on a single method, and correspondingly
      multiple `@yield`/`@yieldreturn` tags — YARD's own default HTML template
      already renders every tag instance generically as its own list item
      (`templates/default/tags/html/tag.erb`), confirming this is idiomatically
      expected, not a fringe case. The Returns/Yields/Yield Returns bullet-list
      shape (see "Output format") accommodates multiple items mechanically once
      the template iterates `object.tags(:return)` instead of `.tag(:return)`
      (ditto `@yield`/`@yieldreturn`) — but the open design question is what
      the *signature line*'s `→ Type` arrow shows when there's more than one
      `@return` type (a union of all of them? the first? omitted?), which the
      single-tag case never had to answer — `Geometry::Path#segment_at` (two
      `@return` tags), `#transform!` (two `@yieldreturn` tags); `@yield` tag
      multiplicity itself intentionally left unexercised — see "Multiple
      return types" under "Decisions"
- [x] (design) A method returning an `Enumerator` when called without a
      block, and yielding when called with one (tests combined
      `@yield`/`@return` docs) — `Geometry::Path#each_segment`; confirmed
      mechanical, zero template changes — settled that the signature line
      shows only the block-calling form, not a second no-block form — see
      "Enumerator-returning method: single block-form signature line, no
      overload-aware block detection" under "Decisions"
- [x] Infix binary operator method — `Point#+`, rendered infix
      (`point + other → Point`)
- [x] Remaining operator forms — `#[]` / `#[]=` (`point[i]`, `point[i] = v`),
      `#<=>` / `#==`, unary `-@` / `+@` (`-point`) — `Geometry::Point#[]`/
      `#[]=` (bracket form) and `Geometry::Vector#-@`/`#+@` (unary prefix
      form) and `#==` (infix, no new rendering needed); `Stopwatch#<=>`
      (already existing) confirmed the infix case already covered `<=>`.
      New `bracket_call?`/`prefix_call?` rendering branches added alongside
      the existing `infix_call?` — see "Remaining operator forms" under
      "Decisions"
- [x] Aliased method (`alias`/`alias_method`) — does the alias get its own
      entry or point back at the original? — `Stopwatch#restart`
      (`alias_method :restart, :reset`, no comment of its own); settled on a
      minimal pointer entry for the alias plus a reciprocal
      `**Also known as:**` note on the original — see "Aliased method" under
      "Decisions". Also covers an alias with its own attached comment —
      `Stopwatch#accrue` (aliasing `#add`) — whose extra prose renders as
      its own top-level Markdown paragraph(s), still run through
      `markdownify` (heading demotion included) — see "Aliased method with
      its own comment" under "Decisions"
- [ ] (design) Alias targeting a method outside the parsed corpus (external
      gem/stdlib, or otherwise not a plain `def` YARD's registry resolves) —
      `alias_original(meth)` returns `nil` in this case, and nothing
      downstream guards it: `member_heading(nil)` (called from both
      `method_summary_line` and `method_entry.erb`'s `**Alias for:**` line)
      raises `NoMethodError`, crashing the entire `yard doc` run. Not
      hypothetical — hit on the very first dogfood run, from two
      independent real cases in YARD's own source (`alias block last` where
      `last` is inherited `Array`-like behavior, never a plain `def`;
      `alias query params` where `params` comes from the external `rack`
      gem). Same shape as the already-settled "unresolved mixin/superclass
      renders as a plain, unlinked backtick" pattern (see "Mixin content
      strategy"/`superclass_line` under "Decisions"), but genuinely
      (design), not (mech): unlike an unresolved mixin/superclass, which is
      still a `Proxy` object with a real `.name`, `alias_original` returning
      `nil` loses even the original's *name* — recovering it means falling
      back to the raw `meth.namespace.aliases[meth]` symbol instead of a
      resolved object, a display case none of the existing unresolved-
      reference handling covers. Flagged by the 2026-07-20 YARD dogfood run
      (see devdocs/Dogfood.md)
- [x] Singleton/class method (`def self.foo`) alongside instance methods on the
      same class — `Point.parse`/`Point.new` alongside `Point#+`/`#distance_to`
- [x] (mech, pre-dogfood) Class methods defined via `class << self` — should render
      identically to `def self.foo`; also cover *attributes* defined on the
      singleton (`class << self; attr_reader :config; end`, the standard
      module-level configuration pattern), which exercise `AttributeInfo`
      down a different path than instance attributes — `Stopwatch.clock_resolution`
      (a `class << self`-defined method, renders identically to a `def self.foo`
      one) and `Stopwatch.verbose` (a `class << self`-defined `attr_accessor`);
      settled alongside the class-level-attributes design item below, since
      both were exercised by the same fixture — see "Class-level attributes"
      under "Decisions"
- [x] (mech) A private class method — `Geometry::Computations.average`
      (`private_class_method`-marked, backing `.centroid`'s x/y averaging);
      confirmed omitted with zero template changes, same policy as instance
      `private`/`protected`
- [ ] (mech) Argument forwarding and anonymous params — `def foo(...)` and
      `def foo(*, **, &)` (Ruby 3.0–3.2, well within the gem's `>= 3.4`
      floor and increasingly idiomatic): `param_names` renders whatever
      YARD's `parameters` reports for these, which nobody has inspected —
      the natural-call-syntax line might come out fine (`obj.foo(...)`) or
      mangled. Escalate to (design) if the raw report needs cleanup.
      Flagged by the July 2026 coverage review
- [ ] (mech) Endless method definition (`def area = width * height`) —
      almost certainly renders identically to the block form, but it's a
      distinct parse path in YARD and a one-line fixture proves it.
      Flagged by the July 2026 coverage review
- [x] (mech, pre-dogfood) Explicit assignment method (`def name=(value)`) not
      paired via `attr_*` — YARD treats it as a plain method named `name=`,
      not an attribute, so it takes the method-entry path; the
      assignment-form rendering settled for `#[]=` (natural `obj[i] = v`
      syntax, no `→` arrow — see "Remaining operator forms" under
      "Decisions") should extend to it, else it renders as the awkward
      `obj.name=(value)`. Originally flagged by the July 2026 coverage
      review; escalated to pre-dogfood by the 2026-07-20 review, which
      confirmed the bad rendering directly (`foo.label=(value) → String`,
      generated from a one-method probe fixture — invalid Ruby syntax, plus
      a meaningless `→` arrow on an assignment) and found the pattern
      genuinely common on the intended dogfood target: 36 occurrences in
      YARD's own source (e.g. `Verifier#expressions=`,
      `SourceParser.parser_type=`). Fixed exactly as scoped: a new
      `MethodSignature#assignment_call?`/`#assignment_call_text` pair,
      checked in `signature_text` alongside `bracket_call?`, matches any
      method whose name ends in `=` and isn't in `OPERATOR_METHOD_NAMES`
      (covers the comparison exclusions for free — `==`/`!=`/`<=`/`>=` are
      members so `end_with?("=")` never reaches them, and `=~` is excluded
      by `end_with?("=")` itself, since it ends in `~`). Deliberately not
      restricted to instance scope like `bracket_call?`/`prefix_call?` are —
      a class-level setter (`SourceParser.parser_type=`) is real and common,
      and `receiver_name` already renders the class receiver correctly for
      it. No arrow-suppression code added, matching `#[]=`'s own precedent
      (an unfixed, acknowledged gap — see "Remaining operator forms" under
      "Decisions"): the `example/` fixture's assignment methods simply carry
      no `@return` tag, and the existing "no tag → no arrow" behavior
      handles it for free. Exercised via `Stopwatch#tag=` (instance scope)
      and `Stopwatch.log_target=` (class scope, alongside a paired
      `.log_target` getter), both hand-written instead of `attr_writer`
      specifically to validate before storing — the realistic reason a gem
      author writes one of these by hand

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
- [x] (mech, pre-dogfood) `@api` with non-private values (`@api public`, `@api
      internal`) — `VisibilityInfo` only special-cases `text == "private"`,
      so any other value vanishes entirely today; and `@api` is one of
      YARD's two transitive tags (see the `@since` discussion under
      "Splitting the flag block" in "Decisions"), so a class-level tag
      covers every method. Confirmed mechanical, zero template changes:
      settled on dropping non-private values, matching YARD's own default
      template's behavior (only `@api private` ever renders) — see "`@api`
      with non-private values" under "Decisions". Originally flagged by the
      July 2026 coverage review
- [x] (mech, pre-dogfood) Class-level `@private` (or `@api private`) on a class/module —
      tag-based privacy was settled and exercised on methods only; whether
      a `@private`-tagged class gets a file, gets flagged on its own page,
      and gets flagged (or filtered) in `index.md` is unverified. Escalate
      to (design) if the index treatment isn't obvious. Confirmed: gets a
      file (nothing filters on tags, same as methods); own page already
      flagged with zero template changes (`page.erb` already calls the
      generic `annotation_lines(object)`). The two gaps that did need code
      — a parent's "Nested Classes & Modules" listing and `index.md`'s row,
      neither of which called the existing `private_api_annotation_short`
      helper — didn't need to escalate to (design): settled on flagging
      (not filtering), consistently with the already-decided policy, not a
      new decision. See "Class-level `@private`/`@api private`" under
      "Decisions". Originally flagged by the July 2026 coverage review

### Attributes & constants

- [x] `attr_reader`, `attr_writer`, `attr_accessor` with doc comments —
      `attr_reader` via `Point#x`/`#y`, `attr_accessor`/`attr_writer` via
      `Rectangle#width`/`#height`; zero template changes needed — see
      "`attr_accessor`/`attr_writer` with doc comments" under "Decisions",
      which also closes out the undocumented-attribute boilerplate revisit
      this item was carrying
- [ ] (design) Attribute `**Type:**` fallback for a plain, comment-less
      `attr_reader`/`attr_writer`/`attr_accessor` with no `@attr*` tag —
      reopens part of the boilerplate-revisit claim the item above closed.
      That claim ("YARD's `Struct`/`Data` handlers and `AttributeHandler`
      generate the same boilerplate text through the same `AttributeInfo`
      rendering path") holds for the docstring *text* half
      ("Returns the value of attribute `name`" — genuinely shared, both
      handlers populate the same generic docstring), but not the *type*
      half: `` **Type:** `Object` `` on `Circle#radius`/`Vector#dx` comes
      from a real `@return [Object]` tag YARD's `Struct.new`/`Data.define`
      handlers synthesize on the accessor — confirmed directly
      (`tag(:return).types == ["Object"]`) — which plain `AttributeHandler`
      (backing ordinary `attr_*`) never adds (`tag(:return) == nil`).
      `attribute_type` passes that `nil` through and `type_ref(nil)`
      returns `""`, so a plain `attr_*`'s `**Type:**` line renders visibly
      blank instead of falling back to `` `Object` ``, reading as a
      rendering bug rather than a terse-but-valid entry. Pervasive on real
      code: 245 occurrences across 89 of 286 classes/modules (~31%) in the
      2026-07-20 YARD dogfood run (see devdocs/Dogfood.md) — every
      undocumented plain `attr_accessor`. Needs an `example/lib` fixture
      with a bare, comment-less `attr_reader`/`writer`/`accessor` (not
      Struct/Data-based, which is already covered by `Circle`/`Vector`) to
      settle whether the fix is defaulting to `` `Object` `` to match the
      Struct/Data case, or something else
- [x] Manually-defined reader/writer pair documented via
      `@attr`/`@attr_reader`/`@attr_writer` tags instead of relying on
      `attr_*` — `Waypoint#label`/`#order`; escalated to (design), since
      the tag/method merge surfaced a real quirk — see "`@attr`/
      `@attr_reader`/`@attr_writer` tags on a manual reader/writer pair"
      under "Decisions"
- [x] (design, pre-dogfood) Class-level attributes (`class << self` +
      `attr_accessor`, the idiomatic gem-configuration pattern) —
      `MemberListing#attribute_objects` read only
      `attributes[:instance]`, so a class-level attribute was silently
      invisible: no entry, no Member Summary line, no roster
      mention (`MemberRoster` reused the same query). `Stopwatch.verbose`;
      settled that class-level attributes get their own `## Class
      Attributes`/`**Class Attributes**` section, split from instance-level
      ones the same way Class Methods/Instance Methods already split — see
      "Class-level attributes" under "Decisions". Related to (but distinct
      from) the `@!attribute` directive item under "YARD directives".
      Flagged by the 2026-07-17 code review
- [x] Simple constant (numeric/string literal) with a doc comment —
      `Point::DIMENSIONS`
- [x] (design) Structured constant (`Hash`, `Array`, `Regexp` literal) — a
      multiline literal forces a decision on how `**Value:**` renders when
      the raw source text doesn't fit one line — `Geometry::Angles::NAMED_ANGLES`
      (multiline `Hash`); settled that a multiline value escalates from the
      inline `` **Value:** `...` `` span to a `` ```ruby `` fence, mirroring
      `@example`'s own raw-code fence — see "Structured constant: multiline
      value escalates to a `` ```ruby `` fence" under "Decisions"
- [ ] (mech) Constant that references another documented class (e.g.
      `DEFAULT_HANDLER = SomeClass.new`) — `Point::ORIGIN = new(0, 0)` is close
      but is a *self*-reference (an instance of the class it's defined on, not
      another one), so it exercises the value/type machinery but not this case
- [x] (mech) Private constant (`private_constant`) — `Stopwatch::CLOCK`,
      backing `#current_time`; confirmed omitted with zero template changes,
      same policy as instance/class-method privacy
- [ ] (stretch) Class variables (`@@foo`) — YARD registers them as
      first-class code objects; the template has no section for them, so
      they're silently dropped today. Modern Ruby style avoids them, so
      deliberate omission is probably the right outcome — but that should
      be a recorded decision, not an accident. Flagged by the July 2026
      coverage review

### YARD tags

- [x] `@param` (including duck-type syntax, e.g. `@param [#to_s] x`) — duck
      typing itself not exercised, but the tag is otherwise thorough
- [x] `@return` (including `void` and multi-type unions) — `void`/unions not
      exercised, but the tag is otherwise thorough
- [x] (mech, pre-dogfood) Union types on the remaining first-type-only tag sites —
      `@param`/`@option`/`@yieldparam`/`@raise` (all via
      `Geometry::Angles.normalize`'s `degrees` param, `Point#translate`'s
      `:y` option, and `Computations.centroid`'s two-type `@raise`), a
      2+-`@overload` method's signature arrow (`Point.of`'s `(point, count)`
      overload), and the attribute `**Type:**` line (`Waypoint#label`).
      Confirmed mechanical as expected: `CrossReferencing#type_ref_first`
      now joins every type instead of taking `.first`, which fixes every
      bullet-list site (plus, as an unrequested but harmless side effect,
      the 2+-`@overload` branch's own per-overload Returns bullet and the
      constant `**Type:**` line, both of which happen to funnel through the
      same helper); `MethodSignature#signature_return_type_for` and
      `AttributeInfo#attribute_type` each got the identical one-line fix
      directly, since neither funnels through `type_ref_first`. See "Union
      types on the remaining first-type-only tag sites" under "Decisions"
- [x] (design) `@param` naming a nonexistent parameter (typo'd, or stale after
      a signature change — real gems have these) — settled on dropping the
      tag entirely rather than rendering it (which would also have sorted
      unmatched tags nondeterministically, since Ruby's `sort_by` isn't
      stable); `Stopwatch#reset`'s stale `seconds`/`millis` tags exercise
      it — see "`@param` naming a nonexistent parameter" under "Decisions".
      Originally flagged (as a determinism bug, not yet this design
      question) by the 2026-07-17 code review
- [x] (design) `@option` (documenting keys of an options hash/kwargs) —
      `Geometry::Point#translate`'s existing `deltas` param; settled a
      separate `**Options (`deltas`):**` block, one per documented hash
      param, default folded into the type parenthetical — see "`@option`"
      under "Decisions"
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
- [x] `@example` — both a bare example (`Point#distance_to`) and a titled
      example (`@example Some title` — `Geometry::Circle`, class-level), and
      a method with more than one `@example` (`Point.of`, reusing its
      2-overload pair); settled the `**Examples:**` header, placement right
      after the docstring, and italic-line title format — see "`@example`"
      under "Decisions"
- [x] Auxiliary one-line tags — `@deprecated` (with a replacement pointer,
      `Geometry::Computations.distance`; without one, `Geometry::Circle`),
      `@since` (`Geometry::Point::DIMENSIONS`, `Geometry::Vector`), `@note`
      (`Geometry::Point#round`, `Stopwatch`); settled placement, ordering,
      and format once for all three, each exercised on both a method and a
      non-method (class/module or constant) object — see "Auxiliary
      one-line tags" under "Decisions"
- [x] `@abstract` (on a class/module, and on a method meant to be
      overridden) — `Geometry::Shape` (class-level) and two method-level
      variants on it: `#label` (abstract but with a working default
      implementation, overridden by `Polygon`/inherited by `Triangle`) and
      `#area` (abstract with no working implementation, a bare `raise
      NotImplementedError` stub); settled that it folds into the existing
      flag-line mechanism with no extra prominence — see "`@abstract`"
      under "Decisions"
- [x] (design, one decision) Remaining free-form/low-value tags — `@todo`,
      `@author`, `@version`, and anything similar: a single policy (render
      generically or deliberately drop). These are rarely what an agent
      needs; per-tag treatment isn't worth it. — `Geometry::Vector`
      (`@version`, two `@author` tags, alongside its existing `@since`) and
      `Stopwatch` (`@todo`, alongside its existing `@note`); settled on
      generic rendering, reusing the existing flag-line/trailing-key-value
      machinery, rather than dropping — see "Remaining free-form tags:
      render generically via existing `@since`/`@note` machinery, don't
      drop" under "Decisions"
- [x] Reference tags — a docstring that is literally `(see #other)`, and the
      per-tag form `@param x (see #other)`: YARD's doc-copying syntax, used
      in real gems to avoid duplicating docs across overloads/aliases.
      Confirmed by direct probing (not just source-reading) that `Docstring`
      resolves both forms transparently before the template ever sees them
      — `Geometry::Point#[]=` (per-tag form, reusing `#[]`'s `@param
      index`/`@raise`) and `Geometry::Vector#eql?` (whole-docstring form,
      reusing `#==`'s docs entirely). Surfaced one genuine rendering bug
      along the way: a resolved reference tag always sorts after a method's
      own tags of the same name, which silently reordered `#[]=`'s
      `**Params:**` list away from signature order — see "Reference tags:
      transparent resolution, plus a `Params:`-ordering fix for mixed
      own/ref tags" under "Decisions"
- [ ] (stretch) Custom user-defined tags (`--tag foo:"Header"` in
      `.yardopts`) — the free-form-tag decision routed
      `@todo`/`@version`/`@author` through existing machinery, but a
      user-defined tag is likely dropped silently today. Wait for dogfood
      evidence that real gems' custom tags matter before designing
      anything. Flagged by the July 2026 coverage review

### YARD directives (for dynamically-defined methods/attrs)

- [x] (mech, pre-dogfood) `@!attribute` (documenting an attribute defined through
      metaprogramming rather than `attr_*`) — `Geometry::PointCloud#size`
      (`define_method`-defined, no `attr_reader`/`@attr` tags). Confirmed
      purely mechanical, zero template changes — see "`@!attribute`: zero
      template changes; same indentation subtlety as `@!method`/`@!macro`"
      under "Decisions"
- [x] (mech, pre-dogfood) `@!method` (documenting a method defined via `define_method` in
      a loop, or via a class-level DSL macro — common in real-world gems) —
      `Geometry::CompassRose` (loop variant, four bare `@!method` directives
      stacked above one shared `each_key` call site); the DSL-macro variant
      is `Geometry::BoundingBox` under `@!macro` just below. Confirmed
      purely mechanical, zero template changes — see "`@!method` (no
      macro): zero template changes; multiple stacked directives share one
      `Defined in:` line" under "Decisions"
- [ ] (stretch) `@!group` / `@!endgroup` (method grouping) — only include if
      we decide the output format should reflect YARD groups
- [x] (design, pre-dogfood) `@!macro` — attach-mode macros on class-level DSL methods
      are the workhorse of DSL-heavy and generated codebases, so the
      dogfood run will hit them. YARD expands macros at parse time, so
      rendering *may* be free — probe rather than assume. Flagged by the
      July 2026 coverage review. Confirmed free: `Geometry::BoundingBox`'s
      `.edge` DSL method, zero template changes — see "`@!macro` (attach
      mode): zero template changes; expands only at call sites, `Defined
      in:` follows the call" under "Decisions"
- [ ] (stretch) `@!parse` / `@!scope` / `@!visibility` — the remaining
      directives; mainly matter for C-extension gems documenting via stub
      files. Wait for real-usage evidence. Flagged by the July 2026
      coverage review

### Documentation content / prose patterns

- [x] Single-line summary only — e.g. `Point#x`'s "The x-coordinate."
- [x] Multi-paragraph description (summary + extended discussion) — the
      `Geometry` module doc
- [x] Markdown formatting in prose: code spans (already covered, e.g.
      `` `"x,y"` ``), a fenced code block, a list, and a link — `Geometry`'s
      module doc. Also settles the prose-embedded-heading wrinkle surfaced
      while building the `:rdoc` dialect path — see "Prose-embedded
      headings: demote below the structural range" under "Decisions".
- [x] Docstring markup dialect — dispatch on `options.markup`, `:markdown`
      passes through, `:rdoc` converts via `RDoc::Markup::ToMarkdown`
      (`YARD::AgentDocs::Markdownify#markdownify`). Covers docstring bodies,
      `@param`/`@return` tag text, and Member Summary one-line summaries —
      see "Docstring markup dialect" under "Decisions" for the full scope
      and unsupported-dialect behavior settled while implementing this.
- [x] Prose/summary containing Markdown metacharacters (backticks, `*`, `_`,
      `[`) — turned out not to need an escaping policy at all (CommonMark
      keeps a bare metacharacter's effects confined to its own line/bullet);
      the real risk was unescaped embedded newlines in tag text corrupting
      the file structure (verified severe with a real CommonMark parser: an
      unmatched fenced-code delimiter can swallow the rest of the document).
      Fixed by preserving structure and indenting as list-item continuation
      instead of flattening, once real-world evidence (google-cloud-ruby)
      showed genuine multi-paragraph/nested-list tag descriptions occur in
      practice — see "Prose/summary containing Markdown metacharacters"
      under "Decisions", including the `@return`/`@yield`/`@yieldreturn`
      rendering-shape change this required
- [x] A class-level doc comment (not just method-level) — both `Geometry` and
      `Geometry::Point`
- [x] Intentionally undocumented objects — a public method with no doc
      comment (`Geometry::Point#zero?`) and an entirely undocumented
      class/module (`Geometry::Segment`, including an undocumented
      `#initialize`); settled the no-flag, blank-render policy — see
      "Intentionally undocumented objects" under "Decisions"

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
- [x] (mech, pre-dogfood) Inline `{Class#method}` reference (and, since it
      shares the identical `Registry.resolve` call, `@see` targeting a
      method) more than one namespace hop away from a method target —
      `RegistryResolver#lookup_by_path` caps *lexical* (non-inheritance)
      method lookups at exactly one namespace hop up from the referencing
      object (`lib/yard/registry_resolver.rb`'s `lexical_lookup > 1 &&
      resolved.is_a?(CodeObjects::MethodObject)` check); a same-distance
      *class*-only reference resolves fine, since the cap is
      method-specific. Silently renders as unresolved (plain text with the
      braces stripped, same as any other unresolved reference — no crash,
      just a quietly wrong result) rather than erroring, so it's easy to
      miss in review — worse than ordinary "known noise," since there's
      nothing visibly different to spot in a diff-read. Surfaced by-product
      of the `Geometry::Cache` fixture (see "Class-level `@private`/`@api
      private`" under "Decisions"), worked around there rather than fixed.
      Escalated to pre-dogfood by the 2026-07-20 review, which measured the
      real impact on the intended dogfood target directly: a probe that
      parses YARD's own source and compares its capped resolution against
      an uncapped resolver found **30 of 555 real inline references (5.4%)**
      would silently degrade to plain unlinked text, e.g. `{Handlers::
      Base#push_state}` from `Handlers::Ruby::Legacy::Base`, `{Registry.
      root}` from `CodeObjects::Base`.

      **Correction (second 2026-07-20 pass):** the review's proposed fix —
      "retry once from the root namespace, but only when the given name
      contains `::`" — doesn't hold up under direct testing and rests on a
      claim ("every failing case found was a `::`-qualified reference")
      that a fresh probe against the same YARD checkout contradicts: of 29
      reproduced failures (555→548, 30→29, presumably from minor source
      drift since the first pass), only 15 (52%) are `::`-qualified;
      14 — including both cited examples, `{Registry.root}` and (on
      inspection) most of the rest — are bare/unqualified. Worse, the
      literal fix as written (a single `Registry.resolve(:root, name, ...)`
      jump) resolves only 1 of the 29, since these names are lexically
      *relative*, not root-qualified, so jumping straight to root and
      searching for the literal string almost always misses. The intended
      fix — actually run the resolve loop's *own* lexical climb further, no
      one-hop cap — dropped entirely because implementing it directly means
      subclassing `RegistryResolver` and overriding a private method, not
      something worth doing just to avoid a public-API retry loop.

      **Actual fix, verified against the same corpus:** no `::` gating at
      all. On a failed `Registry.resolve(object, name, true, false)`, retry
      with the *same* call but a different starting `namespace` — walking
      `object.namespace`, then `.namespace` again, up to the root — stopping
      at the first non-nil result. This needs no access to `RegistryResolver`
      internals: each retry is an ordinary public `Registry.resolve` call,
      and its own internal hop-count resets to zero relative to *its own*
      starting namespace, so a retry from close enough to the real target
      always lands within the original one-hop allowance on its own.
      Recovers **29 of 29** reproduced failures, with **zero** cases where it
      resolves something the fully-uncapped resolver wouldn't (checked
      against all 548 references, not just the 29 failures) — i.e. no
      measured false-positive cost to dropping the `::` gate.

      **Implementation:** `CrossReferencing#resolve_name`, a new private
      helper, replaces the three direct `Registry.resolve(object, name,
      true, false)` call sites (`type_ref`, `see_ref`, `render_reference`)
      — one shared retry loop rather than three copies. `test/
      test_cross_referencing.rb`'s "lexical cross-reference resolution cap"
      describe block proves the boundary directly: a one-hop reference
      resolves without the fallback ever running, a two-hop reference
      resolves only via it, and a genuinely-unresolvable name still returns
      nil after climbing all the way to root (no false positive, no
      infinite loop). `example/` appearance: `Geometry::Cache`'s docstring
      — previously a plain, unlinked `` `Stopwatch#raw_elapsed_s` `` code
      span, worked around exactly because of this gap (see "Class-level
      `@private`/`@api private`" under "Decisions") — now uses a real
      `{Stopwatch#raw_elapsed_s}` reference, two full namespace hops away,
      resolving correctly
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
- [x] A subclass method that overrides a documented parent method
      without redocumenting it (does output inherit/copy/link the parent
      doc?) — `Geometry::Polygon#label` (overrides `Shape#label`, no doc
      comment of its own); settled alongside the paired "inherited, not
      overridden at all" open question — see "Subclass method content
      strategy" under "Decisions"
- [x] A mixin method's docs as seen from an including class — confirmed with
      zero new fixture or template changes: `Geometry::Shape` `include`s
      `Taggable` without overriding `#tag`, and `Shape.md` already omits
      `#tag` entirely (only the `**Includes:**` line points to `Taggable.md`,
      where `#tag` gets its normal full entry) — the existing mixin
      content-strategy decision already covered this, this item just
      verified nothing about the module-page side was left undecided
- [x] `{file:...}` inline references to a `--files`/`--readme` guide — full
      support, not degradation: `{file:path}`/`{file:path label text}`
      resolve to a Markdown link to that guide's own rendered page. See
      "`{file:...}` guide references" under "Decisions"
- [x] `{include:...}`/`{render:...}` inline references — full support, not
      degradation, but not content-embedding either: both collapse to a
      plain link, the same as a bare `{Name}` reference (or `{file:...}`,
      for `{include:file:...}`). See "`{include:...}`/`{render:...}`:
      collapse to a plain link, never embed" under "Decisions"
- [x] `{url}`/`{mailto:...}` inline references — full support, the last of
      the four forms originally scoped out of the inline-reference decision
      (flagged by the July 2026 coverage review). See "`{url}`/
      `{mailto:...}` references" under "Decisions"

### Indexing & discovery

- [x] (design) Flat full-FQN index — see "Flat full-FQN index: classes/modules
      only, replacing the top-level list" under "Decisions".
- [x] (design) "How to navigate these docs" preamble — nothing in the
      output currently discloses the conventions an agent needs in order
      to exploit the format deliberately: the FQN→path derivation rule,
      the `### .method`/`### #method` heading grammar and its grep recipes
      (`grep -rn '^### #each' doc/` finds a member without knowing its
      class), and the fact that inherited/mixed-in members live in
      ancestor files reachable via the `**Superclass:**`/`**Includes:**`/
      `**Extends:**` lines. Decide where it lives (top of `index.md` vs. a
      linked conventions file) and what it covers. Raised by the July 2026
      agent-usefulness evaluation (see "Decisions") as its highest-value
      gap: mechanical navigation is the format's core strength, but only
      if disclosed. Division of labor vs. the accompanying-skill item just
      below is settled — the preamble owns the *how* (format mechanics),
      ships unconditionally, and is the self-describing floor for any
      agent regardless of harness; see "Navigation guidance: preamble plus
      skill" under "Decisions"
- [ ] (design) Accompanying agent skill for using/navigating the format —
      an installable skill (SKILL.md) scoped to what the in-band preamble
      structurally can't do: trigger *proactively* (steer an agent toward
      these docs before it starts grepping gem source or an HTML yardoc
      site), and carry workflow — how to generate docs for a dependency
      that lacks them, where per-gem trees live, when to fall back to
      source via the `**Defined in:**` pointers. Format mechanics stay out
      (defer to the preamble) so the two artifacts can't drift. **Gated on
      the dogfood milestone:** its core content is the generation/lookup
      workflow, which depends on integration decisions (how a consuming
      project invokes the template per-dependency, where output lands)
      that dogfooding will settle — writing it earlier means guessing.
      See "Navigation guidance: preamble plus skill" under "Decisions"
- [x] (design) README and extra files (guides) — scoped to the README only;
      arbitrary `--files` guides remain unaddressed. See "README rendering:
      own page via `options.readme`, no heading demotion" under "Decisions".
- [x] (mech) Arbitrary `--files` guides (beyond the README) — see "Arbitrary
      `--files` guides: generalize the README path, `options.files`
      ordering" under "Decisions".
- [x] (mech→design, pre-dogfood) `index.md`'s per-entry summary doesn't go
      through `markdownify` or inline-reference resolution —
      `Geometry::ThreeD::Point`'s summary now reads "...analogous to
      `{Geometry::Point}`.", exercised at three different nesting depths
      (its own page, `Geometry::ThreeD`'s nested-class listing, and
      `index.md`) so the three required relative paths can't coincide by
      accident. Escalated to (design) on the spot, per "Prioritization and
      roadmap": reusing `summary_suffix` verbatim conflates "resolution
      context" with "link path base", which happen to be the same object
      for every other template but diverge for `index.md`. See "`index.md`
      per-entry summaries: `summary_suffix`, plus a `current_dir` seam in
      `CrossReferencing`" under "Decisions". Originally flagged by the
      2026-07-17 code review

## Open questions

Output format, indexing/lookup, cross-referencing, and the core YARD
integration mechanics are now decided *and implemented* — see "Decisions" and
"Implementation" below. What's still open:

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

### Remaining operator forms: bracket and unary-prefix rendering, `#[]=` never shows an arrow

Settles the "Remaining operator forms" checklist item, extending the natural-
call-syntax convention the infix-binary decision (`point + other → Point`)
established, to the operator shapes that decision didn't cover. Exercised via
`Geometry::Point#[]`/`#[]=` (index `0`/`1` → `x`/`y`) and `Geometry::Vector#-@`/
`#+@`/`#==` (negation, unary-plus no-op, and an explicit override of `Data`'s
auto-generated `==` purely to attach docs to it). `#<=>` needed no new fixture:
`Stopwatch#<=>` (added earlier, for the tag-based-privacy/visibility work)
already exercises it, and — being an ordinary one-argument operator — was
already rendered correctly by the existing infix logic without any code
changes, confirming that half of the bundled checklist item was already done.

**The gap this closed:** before this change, `infix_call?` (any one-argument
operator method) already matched `#[]` (single index) and would have rendered
it as `point [] index` — wrong, not what natural Ruby call syntax looks like
— and unary `#-@`/`#+@` (zero arguments) fell through to the generic dotted-
call branch, rendering as `vector.-@()`. Both were real, silent bugs waiting
for a fixture to catch them, not just missing polish.

**The decision, in `lib/yard/agentdocs/method_signature.rb`:**

- Two new method-name sets alongside the existing `OPERATOR_METHOD_NAMES`:
  `BRACKET_METHOD_NAMES` (`[]`, `[]=`) and `UNARY_METHOD_NAMES` (`+@`, `-@`).
  `infix_call?` now explicitly excludes `BRACKET_METHOD_NAMES`, since `#[]`
  would otherwise still match its own one-argument rule.
- `bracket_call?`/`prefix_call?` are two new predicates, checked in
  `signature_text` before `infix_call?`: `#[]` renders `point[index]`; `#[]=`
  renders `point[index] = value` (every param but the last inside the
  brackets, the last as the assigned value — `bracket_call_text`); a unary
  operator renders as its bare symbol directly against the receiver, no dot,
  no parens, no space — `-vector`, `+vector` (`"#{name[0]}#{receiver_name(meth)}"`,
  stripping the trailing `@` by taking just the first character of `-@`/`+@`).
- **`#[]=` never gets a `→ Type` arrow, even if a future example gives it an
  `@return` tag.** Ruby's assignment-expression semantics guarantee `a[i] = v`
  always evaluates to `v`, regardless of what the method body actually
  returns, so an arrow would risk asserting something false. Rather than add
  a dedicated suppression rule, the `example/lib` fixture simply omits
  `#[]=`'s `@return` tag — the already-existing "no `@return` tag → no arrow"
  behavior (`signature_return_type` returning `nil`) handles it for free. This
  is a real gap, not just an unexercised case: a `#[]=` that *does* carry an
  `@return` tag will still render an (misleading) arrow today, matching this
  project's general "reflect what's actually parseable" stance (see the
  `Struct`/`Data` decision) rather than trying to special-case it pre-emptively.
- No changes were needed for `#==` or `#<=>` — both are ordinary one-argument
  instance operators, already handled correctly by the pre-existing
  `infix_call?` path.

**Why `#[]`/`#[]=` went on `Point` and `-@`/`+@`/`==` went on `Vector`, not
some other combination:** `Point`'s docstring already explicitly disclaims
`Comparable`/`<=>` ("Doesn't mix in `Comparable`, so points aren't directly
sortable or comparable with `<=>`"), so adding `#==` there would read as a
contradiction; `Vector` had no such disclaimer and (being `Data`-backed)
already has an implicit, undocumented `==`, making an explicit, documented
override a realistic thing to exercise. `Point#[]=` is also notable as the
first *mutating* method in an otherwise value-object-style API (every other
`Point` method returns a new instance) — called out explicitly in its own
docstring rather than left as a silent inconsistency for a reader to notice.

### Aliased method: minimal pointer entry, not full duplication or omission

Settles the "Aliased method" checklist item. Exercised via `Stopwatch#restart`
(`alias_method :restart, :reset`, added with no comment of its own — the
base case; an alias with its own additional comment is left as a follow-up
variant).

YARD's own `AliasHandler` (`yard/handlers/ruby/alias_handler.rb`) registers
an alias as a real, independent `MethodObject`, copying the original's
docstring onto it (concatenated with any comment on the alias statement
itself, if present) — but its own default HTML template hides aliases from
method listings (`ModuleHelper#prune_method_listing`) and instead adds an
`(Also known as: ...)` note to the *original* method's page. Three options
considered against that precedent and this project's existing "link out,
not duplicate" call for mixins (see "Mixin content strategy" below):

- **Full omission** (matching this project's Ruby-scope `private`/
  `protected` policy) — rejected: unlike a `private` method, an alias is
  genuinely public and callable, and Ruby gives no signal that it's hidden;
  disappearing it entirely would leave an agent that encounters the alias
  name in someone else's code with nothing to find.
- **Summary-bullet-only** (a Member Summary line plus an "Also known as"
  note on the original, no separate per-kind heading) — rejected. "Indexing/
  lookup" (see below) already commits to a single sanctioned member-lookup
  mechanism, headings plus `grep -n '^### '`, specifically *instead of*
  building any separate member index — Member Summary is documented
  elsewhere as "pure overhead... not a source of truth," not a lookup path.
  Making the alias findable only there would mean the one mechanism this
  project relies on for member lookup silently doesn't cover it.
- **Full duplicate entry** (mirroring the synthetic `.new`/`#initialize`
  pattern) — rejected: unlike `#initialize`, which never gets its own real
  entry anywhere, the original method here already has one. Duplicating its
  params/returns/prose onto the alias would just be redundant content the
  "link out, not duplicate" mixin decision already argues against, and
  would imply (falsely, since Ruby's alias semantics guarantee identical
  behavior) that the two might independently diverge.

**Settled on: the alias gets its own minimal H3 entry** — real signature
line, then `` **Alias for:** `#original` `` in place of prose, then
`**Defined in:**` — no `**Params:**`/`**Returns:**`/etc. blocks, since that
content lives solely on the original's entry. Bolded as a key-value line
(no trailing period), matching `**Also known as:**`/`**Type:**`/etc.
rather than the period-terminated `**Private API.**`/`**Deprecated.**`
state flags — it's a factual pointer, not a warning. This keeps the
`grep -n '^### '` contract intact (every real, public member name is
heading-discoverable) while keeping the actually expensive content
(descriptions, params, returns) in exactly one place. Member Summary gets
the matching one-liner (`` - `#restart` — **Alias for:** `#reset` ``), not
the alias's copied docstring summary, for the same reason. The original
method's entry gets a reciprocal `**Also known as:** `#restart`` line, in
the same
"flag line, right after the signature block, before prose" slot
`@deprecated`/`@note`/tag-based-privacy already occupy (see "Auxiliary
one-line tags" below) — not folded into the shared `annotation_lines`
helper itself (which stays tag-only, shared by both classes/modules and
methods), but composed alongside it at the template level in
`method_entry.erb`, since aliasing is method-only, structural metadata (via
YARD's own `MethodObject#aliases`/`#is_alias?`), not a docstring tag.

**Implementation, in `lib/yard/agentdocs/method_signature.rb`:**

- `alias_original(meth)` — `nil` unless `meth.is_alias?`; otherwise looks up
  `meth.namespace.aliases[meth]` (the original's name, per YARD's own
  bookkeeping) among `meth.namespace.meths(scope: meth.scope,
  included: false)` to find the actual original `MethodObject`. **Correction
  (2026-07-20 YARD dogfood run, see devdocs/Dogfood.md):** this description
  undersold the `nil` case — `alias_original` also returns `nil` when
  `meth.is_alias?` is true but the `.find` comes up empty (the original is
  outside the parsed corpus), and unlike this decision's own examples, no
  caller guards against it: `member_heading(alias_original(meth))` crashes
  the whole run. See the new "Alias targeting a method outside the parsed
  corpus" checklist item under "Methods — shapes & signatures" — not yet
  fixed.
- `also_known_as_line(meth)` — `nil` if `meth.aliases` (YARD's own reverse
  list) is empty, otherwise the `**Also known as:**` line, comma-joining
  every alias.
- **Latent bug fixed along the way:** `param_names` built the signature
  line's parameter list from `meth.parameters` directly, which is always
  empty for an alias — `alias`/`alias_method` never parses a real parameter
  list, unlike a `def`. Before this fix, `Stopwatch#restart`'s signature
  line rendered as `stopwatch.restart() → Float`, silently dropping the
  `to = DEFAULT_ELAPSED` parameter `#reset` actually takes (caught by the
  failing-fixture step of the TDD loop, not spotted by inspection). Fixed
  generally — `param_names` now sources from `overload || alias_original(meth)
  || meth` — so any alias's signature line reflects its original's real
  parameter list, not just `#restart`'s. `signature_return_type` needed no
  equivalent fix: it reads `meth.tags(:return)`, which YARD already
  populates correctly on the alias via the copied docstring.
- **Left deliberately unexercised:** `implicit_block?`/`block_param_names`
  (in the same file) also read `meth.parameters` directly and would
  misjudge a `&block`-capturing method's alias as taking an *implicit*
  block instead. No current fixture aliases a block-taking method, so this
  wasn't fixed pre-emptively — same "not yet exercised, left for a real
  case to justify" stance this file already takes with `@since` on a method
  or attribute (see "Auxiliary one-line tags" below).

### Aliased method with its own comment: isolate and render the extra prose, still markdownified

Follow-up to "Aliased method" above, covering an alias statement that
carries its own comment rather than relying entirely on the original's
copied docstring. Exercised via `Stopwatch#accrue` (`alias_method :accrue,
:add`, with its own comment including a level-2 Markdown heading
specifically to prove heading demotion applies on this path too).

Decided by probing YARD directly (`YARD.parse_string` against a minimal
stub, not by reading `AliasHandler` alone — its concatenation logic doesn't
say what the *re-parsed* result looks like): `AliasHandler` joins
`[original.docstring.to_raw, statement.comments].join("\n")` and re-parses
that as the alias's own docstring. Two things the probe confirmed that
aren't obvious from the source:

- The join point gets only a single `\n`, not a blank line, so the
  original's copied prose and the alias's own new text land in the *same*
  paragraph once re-parsed (`alias.docstring.to_s` for `#accrue` before any
  fix: `"Adds to the elapsed time.\nOlder name for..."`, no paragraph
  break) — rendering `@method.docstring` wholesale for an alias-with-comment
  would both duplicate the original's full prose (the "Aliased method"
  decision's whole reason for *not* doing that) and glue the new text onto
  it with no visual separation.
- Despite that, `alias.docstring.to_s` always starts with exactly
  `original.docstring.to_s` as a literal string prefix — tags land wherever
  they fall structurally, but the free-text (non-tag) portions concatenate
  in source-encounter order with the tags stripped out, so the original's
  contribution is always a clean, diffable prefix of the merged free-text.

**The decision:** `alias_own_prose(meth)`
(`lib/yard/agentdocs/method_signature.rb`) strips that shared prefix (and
the seam's leading newline) to isolate just the alias's own new text, or
returns `nil` if there isn't any (the common case — `Stopwatch#restart`,
with no comment of its own, is unaffected). `method_entry.erb`'s alias
branch renders it, when present, as its own paragraph between the
`**Alias for:**` line and `**Defined in:**` — genuine top-level Markdown,
not spliced into a bullet, so it goes through the plain `markdownify(text)`
call every other docstring body already uses (not `summary_suffix`/
`dash_join`'s `indent_continuation` bullet-escaping, which doesn't apply
here). That's what makes heading demotion and dialect conversion apply for
free: `#accrue`'s own `## Migrating` heading demotes to `#### Migrating`
via the same `demote_headings` pass "Prose-embedded headings" already
established, with zero special-casing for the alias path. Member
Summary's `#accrue` bullet is unaffected — still the fixed `**Alias for:**`
one-liner regardless of whether the alias has its own extra prose, keeping
every alias's Member Summary line the same predictable shape; the extra
commentary is only visible once the full entry is open.

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

Scoped to classes only at the time this was written (`extends_line`
returned `nil` unconditionally in `module/agentdocs/setup.rb`) — a module
extending another module wasn't yet exercised, matching `**Includes:**`'s
then-class-only scope. Both lines were later generalized to modules too,
once `extend self` (a module extending *itself*) gave a concrete case to
build against — see "`extend self` / `module_function`" below.

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

### Subclass method content strategy: link out via `**Superclass:**`; an undocumented override points back via `**Overrides:**`

Resolves plain superclass inheritance, the one case the "Mixin/inheritance
content strategy" family (`include`/`extend`/`prepend` above) left open —
covering both halves of the paired open question at once:

- **Inherited, not overridden at all** — turned out to already be settled
  behavior, just never written up as a deliberate decision.
  `instance_method_objects`/`class_method_objects` already pass
  `inherited: false` (predates this decision — see the "Latent bug fixed
  along the way" note under "Mixin content strategy" above, which caught the
  *mixin* half of the same flags but not this one), so a subclass's own file
  never duplicates a superclass method it doesn't redefine. The only pointer
  is the existing `**Superclass:**` metadata line — same "link out, don't
  duplicate" shape as `**Includes:**`/`**Extends:**`, just riding on
  metadata that already existed for an unrelated reason. Already exercised
  incidentally by `Triangle` (inherits `#label`/`#describe`/`#sides`/
  `#each_side` from `Shape`/`Polygon` without redefining any of them) before
  this decision made it deliberate.
- **Overridden without redocumenting** — genuinely unexercised until now.
  Probed directly against YARD (not assumed): an override with no doc
  comment of its own gets a completely empty `docstring` and `tags` —
  YARD never copies a superclass method's docs onto it, even when the
  superclass method is fully documented. Left alone, this would render
  exactly like a plain undocumented method (the "Intentionally undocumented
  objects" policy below), silently discarding the one-hop pointer to the
  ancestor's real docs that a human reader would get for free just by
  glancing at the class hierarchy.

Considered against the same three options "Aliased method" above weighed for
aliases — full omission (already ruled out generally: it's genuinely public,
unlike Ruby-scope `private`), full duplication (rejected there and here for
the same reason: it would assert, falsely, that the override's behavior
still matches the parent's contract, when overriding is usually done
*because* it doesn't), and a flag-line pointer. **Settled on the pointer**,
consistent with `include`/`extend`'s "link out, don't duplicate": a new
`**Overrides:**` bold key-value line (no trailing period — a factual
pointer, not a warning, matching `**Also known as:**`) in the same
"before prose" flag-line slot, immediately after `**Also known as:**`. Its
Member Summary counterpart is a parenthetical, `(overrides `Shape#label`)`,
same shape as `(private API)`/`(deprecated)`. Exercised via
`Geometry::Polygon#label` (overrides `Geometry::Shape#label`, no comment of
its own).

**Scope, deliberately narrow:** the line only appears when the override
itself has *zero* declared documentation (`docstring.empty? &&
tags.empty?`) — an override with even a bare `@return [Type]` and no prose
is left to render normally, on the theory that it's already conveying
something rather than nothing. Resolution walks the superclass chain
looking for the nearest ancestor's same-named, same-scope method that
*does* have a non-empty docstring (`MethodSignature#overridden_method`);
mixins aren't searched — that's the separate, still-open "mixin method's
docs as seen from an including class" checklist item, not folded in here.
No reciprocal note is added to the ancestor's own page (unlike aliases'
`**Also known as:**` back-reference) — `**Includes:**`/`**Extends:**`
already established that this metadata family points one direction only
(child → parent), and finding every overriding subclass would mean
scanning the whole registry for what's ultimately a minor convenience.

**Known gap, left deliberately unresolved:** YARD auto-synthesizes a
`@return [Boolean]` tag for a `?`-suffixed predicate method even with zero
doc comment (confirmed by probe, same as the `Sub2#zero?` case in this
section's investigation) — so an undocumented predicate-method override
has a non-empty `tags`, fails the scope check above, and renders with a
`**Returns:** Boolean` line but no `**Overrides:**` pointer. Not fixed
here: the page in that case isn't content-free the way `#label`'s would
be, so it's a smaller gap than the one this decision closes, and no current
fixture exercises a predicate-method override to judge whether it's worth
a special case.

### `extend self` / `module_function`

Resolves both checklist items in one decision, since they share the
"methods simultaneously class- and instance-level" question. Exercised via
`Geometry::Angles` (`extend self`, one instance method `#normalize`) and
`Geometry::Rounding` (`module_function`, one method `#to_precision`).

**`module_function` needed zero template changes.** Probing YARD's object
model (`object.meths(inherited: false, included: false)`) shows
`module_function` produces two distinct `MethodObject`s: a public
class-scope one (`Rounding.to_precision`) and a *private* instance-scope
one (`Rounding#to_precision`). The private twin is already dropped by the
existing Ruby-scope-privacy policy (see "Visibility policy" above), so the
class file renders exactly one ordinary Class Methods entry — the same
shape `def self.foo` already produced. No new case for the template to
handle at all.

**`extend self` is a real (if narrow) gap, closed by generalizing
`**Extends:**`/`**Includes:**` from class-only to modules too.** The same
probe shows `extend self` produces only *one* `MethodObject`
(`Foo#bar`, `scope: :instance`) under `included: false` — there's no
separate, well-formed class-scope object to render as a second entry.
Widening the query to `meths(scope: :class, included: true)` does surface
something, but it's a corrupted proxy: same `path` (`Foo#bar`, `#`-sep) as
the instance method, just with `scope: :class` — not something a signature
renderer should trust. Generating YARD's own default HTML template against
the same source confirms this isn't a gap unique to this project: YARD's
own template also renders only an "Instance Method" entry, plus a
self-referential "Extended by: Foo" metadata line — it doesn't fabricate a
second class-method listing either. Per the "agent reference needs mirror
human reference needs" heuristic, this project makes the same call:
`Angles#normalize` is documented once, as an instance method, and the
module's own self-extension is surfaced only as metadata.

That metadata line was previously unavailable for modules at all —
`superclass_line`/`includes_line`/`extends_line` were stubbed to `nil` in
`module/agentdocs/setup.rb`, real implementations living only in
`class/agentdocs/setup.rb` (see "Scoped to classes only for now" under the
`extend` content strategy decision above). `includes_line`/`extends_line`
have now moved to `module/agentdocs/setup.rb` as the shared implementation
(behind a new `mixin_line(label, mods)` helper), with `class/agentdocs/setup.rb`
keeping only `superclass_line` (classes only — modules have no superclass).
This also incidentally resolves that older "module extending another
module isn't yet exercised" scope note, not just the self-extension case.

**Self-reference rendering reuses an existing convention, not a new one.**
A module extending itself means `mixin_line`'s target *is* the object
currently being rendered — a case `includes_line`/`extends_line` never hit
before (no existing class subclasses/includes/extends itself). Rather than
inventing a policy, `mixin_line` reuses `CrossReferencing#self_reference?`,
the same same-file-reference check `@see`/type-refs/inline `{}` cross-refs
already use to render a same-file target as a plain, unlinked backtick
instead of a link to the file the agent is already reading (confirmed this
generalizes cleanly: `self_reference?` compares a resolved object's owning
namespace against `object`, with no assumption specific to prose). Result:
`` **Extends:** `Angles` `` on `Angles.md` — unlinked, since `Angles.md` is
the file the agent already has open — rather than a self-link
(`` [`Angles`](Angles.md) ``, which YARD's own HTML template does produce,
since HTML anchors don't carry the same "why link to the page you're on"
cost a Markdown file read does).

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

### Intentionally undocumented objects: render normally, no flag or stub

Settles the "Intentionally undocumented objects" checklist item. Exercised
via `Geometry::Point#zero?` (a public method with no doc comment, on an
otherwise well-documented class) and `Geometry::Segment` (a new class with
no doc comment anywhere — including its `#initialize` — added purely to
exercise this scenario).

**The decision:** an undocumented object renders exactly like a documented
one, just with blank prose where the docstring/tag description would go —
no `**Undocumented.**`-style flag, no stub placeholder text. This mirrors
YARD's own default HTML template (confirmed by inspecting yard 0.9.44's
`docstring/html/index.erb` and `module/html/item_summary.erb`: both emit
blank content for a missing docstring, no special-cased marker), per this
project's "agent reference needs mirror human reference needs" heuristic —
there's no goal-driven reason here to invent a bespoke agent-specific
policy. Combined with the project's existing "absence means empty"
convention (previously used only for empty Member Summary subgroups), the
concrete rule is: a missing docstring/tag-text contributes *no* blank
line, dash, or placeholder of its own — as if that line had simply been
deleted, not left blank.

**The bug this caught.** Probing the *unmodified* template against a
scratch undocumented class/method first (before touching anything) showed
this wasn't actually implemented anywhere: `markdownify(docstring)` was
interpolated unconditionally in both `page.erb` (class/module prose) and
`method_entry.erb` (method prose), unlike every other optional section
(Params/Returns/Raises/etc.), which already supply their *own* leading
blank line only when they render. An empty docstring therefore produced
extra blank lines (a class with no docstring got three consecutive blank
lines before `## Member Summary`) and a Member Summary bullet for an
undocumented member rendered as a dangling `` — `` with nothing after it.

**The fix, module/agentdocs:**

- `page.erb` / `method_entry.erb`: the docstring interpolation is now
  wrapped in `unless object.docstring.empty?` / `unless
  @method.docstring.empty?`, each owning its own leading blank line (same
  self-contained pattern the Params/Returns/etc. sections already used) —
  rather than relying on a blank line that rendered unconditionally
  regardless of what followed it. This required also moving the
  single-overload branch's private-API-annotation blank from *trailing*
  (separating it from whatever came after) to *leading* (owned by
  whichever section renders), since the fence-to-content gap it used to
  share with the docstring line was otherwise still unconditional. Verified
  against the one existing fixture combining a fence with both an
  annotation and a docstring (`Stopwatch#raw_elapsed_s`, `@api private`) to
  confirm the restructure doesn't change already-approved output.
- `setup.rb`'s four `*_summary_line` methods: a new `summary_suffix(text)`
  helper renders `" — #{markdownify(text)}"` only when non-blank, `""`
  otherwise, replacing an unconditional `" — #{...}"` in each. Reused
  as-is in `fulldoc/agentdocs` (a separate template module, per
  "Architecture" — doesn't inherit from `module/agentdocs`) for the flat
  FQN index's own summary bullets, which had the identical unconditional-
  dash bug.
- Left deliberately unfixed, as a narrow accepted gap rather than
  speculative robustness: the 2+-`@overload` branch's docstring-to-first-
  overload-fence gap can still double a blank line if such a method were
  *also* fully undocumented (no prose, no `@overload` description) — every
  currently-exercised 2+-overload method has prose, so this combination
  isn't proven. Revisit only if real usage (the dogfood milestone) hits it.

**A related surprise, generalized on the spot per "if a (mech) item
surfaces a surprise... treat it as (design)":** YARD auto-synthesizes a
`@return [Boolean]` tag for any `?`-suffixed predicate method that doesn't
declare its own `@return` — confirmed via `Point#zero?`, which has *zero*
doc comment yet still renders `point.zero?() → Boolean` and `` **Returns:**
`Boolean` `` (a present tag with real type info, but blank `.text`). This
exposed the same unconditional-dash bug one level down: `` — `` was
hard-coded between a tag's type and its text everywhere a tag is rendered
(`@param`, `@return`, `@raise`, `@yield`, `@yieldparam`, `@yieldreturn`),
not just in docstrings/summaries. Fixed generally, not just for `@return`:

- `summary_suffix(text)` (renamed conceptually to cover this reuse, not
  just Member Summary bullets) also covers `@param`/`@yieldparam` bullets,
  where the type sits in its own always-rendered parentheses (`` `Type` ``)
  and only the trailing `" — text"` needs the guard.
- A new `dash_join(prefix, text)` helper covers `@return`/`@yield`/
  `@yieldreturn`/`@raise`, where the "prefix" (a `type_ref` result, or
  `@yield`'s bracketed name list) can *itself* be legitimately blank (no
  bracketed type; no yielded names) — it joins whichever of `prefix`/
  `markdownify(text)` are non-blank with `" — "`, so it's correct whether
  neither, either, or both are present. This also incidentally fixes a
  latent, previously-unexercised gap where a tag with no bracketed type at
  all (e.g. `@return the result`, no `[Type]`) would have rendered a
  doubled-up `` —  — text `` once the type-side blank was involved; no
  fixture exercises that combination, but the general helper handles it
  correctly by construction rather than by luck.
- `@yield`'s existing bracketed-names-conditional dash was replaced by
  `dash_join` too, verified against both already-approved shapes:
  `Stopwatch#measure` (no bracketed names, has text — `` **Yields:** the
  work to time ``, no dash) and `Polygon#each_side` (bracketed name and
  text — `` **Yields:** `side_number` — one call per side ``).

**A YARD parsing quirk worth knowing for future undocumented-object
fixtures:** a comment block attaches to the declaration below it as its
docstring even across one intervening blank *source* line, but not two —
confirmed by probing (a comment directly above `class Foo`, one blank
line above `class Foo`, and two blank lines above `class Foo` all run
through the template; only the last left `docstring.empty?` true).
`Geometry::Segment` therefore has no comment anywhere near its
declarations at all, rather than an explanatory note "safely" separated by
a blank line — a single blank line isn't actually safe. If a future
checklist item needs another genuinely undocumented `example/lib` object,
don't rely on blank-line separation to keep a nearby comment from being
picked up as its docstring.

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
- One thing probed here, but resolved separately: an RDoc `=` heading
  converts correctly in isolation, but embedding one in a class docstring
  collides with this format's own heading hierarchy — see "Prose-embedded
  headings: demote below the structural range" under "Decisions".

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

### Prose-embedded headings: demote below the structural range

Settles the "Markdown formatting in prose" checklist item's heading wrinkle,
surfaced while building the `:rdoc` dialect path (see "Docstring markup
dialect" above): a docstring can contain its own ATX heading — written
directly as Markdown `#`/`##`/`###`, or converted from RDoc `=`/`==`/`===`
via `ToMarkdown` — and, left alone, it renders as a real heading at the same
level this format's own `## Member Summary`/`### #method` structural
headings use, which would corrupt the `grep '^## '`/`grep '^### '` lookup
mechanism "Output format" depends on (a false match, or a false section
boundary for a "read from this heading to the next" range fetch).

Same "reflow, don't escape" instinct as the list-item-continuation fix (see
"Prose/summary containing Markdown metacharacters"): a heading is still
useful to an agent as a heading, so demote its level rather than defuse the
`#` character.

**The decision:** clamp, not shift. Any heading shallower than level 4
(`#`, `##`, or `###`) is rewritten to exactly `####`; a heading already at
level 4 or deeper is left untouched. Applied uniformly inside `markdownify`
(`YARD::AgentDocs::Markdownify#demote_headings`, run on the already-converted
text before `resolve_references`), so it's dialect-independent — a
Markdown-authored heading and an RDoc `=` heading that converted to the same
level get the same treatment.

- **Why clamp instead of an additive shift** (e.g. always +3, capping at
  h6) that would preserve relative nesting between multiple prose headings:
  simpler rule, and level 4 is already the shallowest level this format's
  hierarchy doesn't reserve, so there's no shallower "safe" level to shift
  *into* — an additive shift would just be clamp's more complicated cousin
  for the common case (a single heading, or a docstring not deep enough for
  the distinction to matter) while still collapsing multiple originally
  distinct levels together once any of them is deep enough to clamp. Not
  revisited unless a real docstring turns up with genuinely multi-level
  prose headings where losing that relative nesting is a real cost.
- **Why leave level 4+ alone:** it already can't collide with `^## '`/`^### '`
  by construction, and repeatedly demoting an author's already-deep heading
  every time would be pure churn.
- **Fence-aware, reusing the existing scan.** A `#`-starting line inside a
  fenced ` ```ruby ` code sample (e.g. a Ruby comment) is not a heading and
  must not be touched. `demote_headings` walks the text with the same
  backtick-run-skipping `StringScanner` loop `CrossReferencing#resolve_references`
  already uses to protect `{Name}` references inside code spans — proven
  against a fixture with a `#`-led comment line inside `Geometry`'s example
  code block (`example/lib/geometry.rb`), verified independently against
  `commonmarker` to confirm the intended heading levels and an unmangled
  code block.
- **Column-0 only, matching the list-item-continuation fix's reasoning.** A
  heading indented by leading whitespace (inside a `- ` bullet's continuation,
  or just authored with leading spaces) is already invisible to the
  column-0-anchored grep this format's lookup depends on, so it's left alone
  regardless of level — no need to walk indentation the way the demotion
  logic walks backtick spans.

Exercised in both dialects: `Geometry`'s module doc (level-1 and level-3
Markdown headings, both landing at `####`, plus an untouched level-5 heading)
and the small dedicated `Greeter` rdoc fixture (a level-1 RDoc `=` heading,
same landing spot after `ToMarkdown` conversion) — see `example/lib/geometry.rb`
and `example/rdoc/lib/greeter.rb`. Direct unit coverage in `test/test_markdownify.rb`
covers the level-4+-untouched, fenced-code-block, and indented-heading cases
that aren't separately exercised end-to-end.

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

### `{file:...}` guide references: full support, matched only against registered `--files`/`--readme` entries

Settles the `{file:...}` portion of the "Graceful degradation for the inline
forms scoped out of the inline-reference decision" checklist item — upgraded
from degradation to full support once arbitrary `--files` guides (see
"Arbitrary `--files` guides" above) gave every such reference something real
to link to. `{include:...}`/`{render:...}` followed immediately after (see
"`{include:...}`/`{render:...}`: collapse to a plain link, never embed"
below); bare URLs remain the one form still tracked by the checklist item,
narrowed accordingly.

**Syntax**: reuses the existing `REFERENCE` scanner unchanged (a `{file:...}`
reference is just a `{Name}`/`{Name label text}` whose name happens to start
with `file:`) — `{file:path}` and `{file:path label text}`, plus the same
escaping (`\{...}`/`!{...}`) and code-span exclusion every other inline
reference already gets for free. No `#anchor` support (YARD's own
`{file:path#anchor}`): nothing currently needs it, and it's easy to add
later behind its own fixture — deferred rather than built speculatively.

**Matching policy — a deliberate departure from real YARD.** YARD's own
`file:` link (`BaseHelper#linkify`, `HtmlHelper#link_file`) treats `path` as
a literal disk path relative to the CLI's CWD and re-reads it fresh,
whether or not it was ever passed to `--files`/`--readme` — so it happily
emits a link to a page that was never serialized (a dead link in the
generated site). `render_file_reference`
(`CrossReferencing#render_file_reference`) instead matches `path` by exact
string equality against each entry in `options.files`' own `filename` — the
literal path given on the CLI, the same array `index.erb`'s `## Guides`
section already iterates (YARD's CLI unshifts `options.readme` onto the
front, so a README reference needs no special-casing). A `path` matching no
registered guide is left completely untouched, braces included — same
"never rewrite what doesn't resolve" policy already applied to an
unresolved `{Name}` (see "Inline cross-references in prose" above). This
guarantees the format can never emit a link to a page that doesn't exist,
at the cost of requiring the referenced path to exactly match how it was
passed on the CLI.

**Rendering**, mirroring the established `{Name}` conventions exactly:
unlabeled `{file:path}` → `` [`Title`](file.name.md) `` (the guide's own
`ExtraFileObject#title`, backticked — same shape as a resolved `{Name}` and
the `## Guides` list itself); labeled `{file:path label text}` →
`[label text](file.name.md)` (plain prose, no backticks, same as a labeled
`{Name label text}`). No self-reference suppression — a guide linking to
itself just renders a normal link; unlike an object cross-reference, there's
no established "you're already on this page" convention for guides to
preserve, and a redundant-but-correct link is harmless.

**Exercised**: `example/README.md` gains a resolved labeled reference to
the `docs/point_cloud.md` guide (`## Further reading`); the `PointCloud`
class docstring (`example/lib/geometry/point_cloud.rb`) gains a resolved
unlabeled reference back to that same guide, proving the cross-directory
relative path (`Geometry/PointCloud.md` → `../file.point_cloud.md`) as well
as root-level resolution (`file.README.md` → `file.point_cloud.md`, both at
the doc root). The unregistered-path (unresolved) case, and the
label/no-label rendering split in isolation, are covered by unit tests only
(`test/test_cross_referencing.rb`), per this project's existing precedent
of keeping narrative fixture prose natural rather than forcing in every
edge case.

### `{include:...}`/`{render:...}`: collapse to a plain link, never embed

Settles the `{include:...}`/`{render:...}` portion of the checklist item
`{file:...}` narrowed just above. Real YARD's two forms both embed content
inline — `{include:file:path}`/`{include:Name}` splice in a raw file's
contents or another object's docstring text (`BaseHelper#linkify`,
`HtmlHelper#link_include_file`/`#link_include_object`); `{render:Name}`
splices in that object's *entire rendered page*
(`CodeObjects::Base#format`, a full recursive template run). Considered and
rejected: building real support for either. The content-duplication use
case both exist for is already served better by `@!macro` (full support,
zero template changes, with correct per-call-site `Defined in:`
attribution — see "`@!macro`" above), and actually embedding either form
would need genuinely new machinery this template has never needed
before — splicing multi-line/multi-heading block content mid-`gsub` instead
of a single inline substitution, plus cycle detection for a mutual-include
(`{render:...}`'s whole-page form would also collide with the
`demote_headings` single-level heading scheme, which has no notion of
absorbing another page's own structural hierarchy).

**Landed shape: both degrade to a plain link — the same link a bare
`{Name}` reference (or `{file:...}`, for `{include:file:...}`) to the same
target would produce — rather than to literal unresolved text.** This is a
genuine third option, distinct from both "full support" and the
"presumably literal text" degradation the checklist item originally
assumed: an agent hitting `{include:Foo}` gets a working link to `Foo`'s
own page instead of either duplicated content or dead braces, at zero
marginal implementation cost over what `{file:...}` already built. Precedent:
this is the same call "README rendering" already made — link out to a
guide's own page rather than inlining its content into `index.md`, to keep
pages compact and addressable.

**Mechanics**, all in `CrossReferencing#render_reference`
(`lib/yard/agentdocs/cross_referencing.rb`): `{include:file:path}` is
checked ahead of `{file:path}` (a name starting with the former also starts
with the latter's `"include:"` half) and dispatches to the very same
`#render_file_reference` `{file:...}` uses — a pure syntax alias, nothing
new. `{include:Name}`/`{render:Name}` strip their prefix
(`OBJECT_REFERENCE_ALIAS_PREFIXES`) and fall through to the ordinary
bare-`{Name}` object-resolution branch — also a pure alias, including
label handling, self-reference (a plain backtick/label, no link), and the
unresolved case (left completely untouched, prefix and braces included).

**Resolution scope, unified rather than mirrored.** Real YARD resolves
`{include:Name}` from `object.namespace` and `{render:Name}` from `object`
itself — two different roots, neither matching how `{Name}` resolves in
this template (`object`, with `inheritance: true, proxy_fallback: false`).
Since these are no longer "real" includes/renders, only alternate spellings
of "link to this," all three were unified to resolve identically — deciding
otherwise would mean two visually-similar spellings silently resolving from
different scopes, an invisible landmine in the rendered output (nothing
about a produced link reveals which scope resolved it).

**No `#anchor` support** for `{include:file:path#anchor}`, same reasoning
as `{file:...}`: nothing needs it yet, and it's cheap to add later behind
its own fixture.

**Exercised**: `example/README.md` gains an `{include:file:...}` reference
to the same `docs/point_cloud.md` guide `{file:...}` already proved,
showing it resolves to the identical link. `Geometry::Rounding`'s module
docstring (`example/lib/geometry/rounding.rb`) gains three paragraphs
covering `{include:Name}`/`{render:Name}`: unlabeled resolved (linking to
`Angles`/`Vector`), labeled resolved (same targets, with label text), and
an unlabeled/labeled same-file self-reference pair (`{include:Rounding}` →
a plain backtick; `{render:Rounding this very module}` → plain label text).
The unresolved case is covered by unit tests only
(`test/test_cross_referencing.rb`), per this project's existing precedent
of keeping narrative fixture prose natural rather than forcing in every
edge case.

### `{url}`/`{mailto:...}` references: full support, destination always angle-bracketed

Settles the last of the four forms the original "graceful degradation"
checklist item bundled together — `{file:...}`, `{include:...}`/
`{render:...}`, and now bare URLs, all ended up with full support rather
than degradation, following the same "convert to a real Markdown link"
reasoning each time.

**Detection mirrors `BaseHelper#linkify`'s own dispatch exactly**: a
{REFERENCE} name containing `"://"` anywhere (`URL_REFERENCE_PATTERN`), or
starting with `"mailto:"` (`MAILTO_REFERENCE_PREFIX`). Unlike every other
form this template resolves, there's no lookup step — the URL text *is*
the target, so a match here always renders as a link; there's no
unresolved case to prove. Checked ahead of the `file:`/`include:`/
`render:` prefixes in `render_reference`, though the two families never
actually collide (nothing starting with `"file:"`/`"include:"`/`"render:"`
also contains `"://"` or starts with `"mailto:"` in practice).

**Rendering**, matching the established unlabeled/labeled split: unlabeled
`{url}` → `` [`url`](<url>) `` (backticked display text, same convention
every other unlabeled {REFERENCE} form uses — YARD's own `link_url`
defaults the visible text to the URL itself, same idea); labeled
`{url label text}` → `[label text](<url>)` (plain prose, no backticks,
same as every other labeled form).

**The destination is always wrapped in angle brackets** (`(<url>)`, not
`(url)`) — the one place this template emits a link whose destination is
arbitrary, unvetted text rather than a path it generated itself, so unlike
every other link this template produces, it can contain Markdown-hostile
characters. Verified against a real hazard, not a hypothetical one: a URL
with a single unescaped `(` (e.g. a Wikipedia disambiguation link,
`https://en.wikipedia.org/wiki/Ruby_(programming_language)`) breaks a bare
`[label](url)` — confirmed against six real parsers in a scratch dir (not
project dependencies) spanning three ecosystems and both CommonMark-strict
and pre-CommonMark lineages: `commonmarker` (cmark-gfm/GitHub),
`redcarpet`, `kramdown`, `markdown-it`, `marked`, and Python's `markdown`.
Each broke differently (kramdown/markdown-it/Python-Markdown: no link at
all; cmark-gfm: mangled partial-autolink fallback; marked: a link to the
wrong, truncated URL) — none produced the correct link. The angle-bracket
form (`[label](<url>)`) is standard Markdown, not a CommonMark-only
extension (present in Gruber's original 2004 syntax, for reference-link
definitions specifically), and all six parsers handled it identically and
correctly on the same inputs, including a plain URL with no parens at all.

**Exercised**: `example/README.md` gains two "Further reading" bullets — an
unlabeled `{https://www.ruby-lang.org/en/}` (the baseline case), and a
labeled `{https://en.wikipedia.org/wiki/Ruby_(programming_language) Ruby on
Wikipedia}` (the paren-escape case, using a real, naturally-occurring URL
rather than a contrived one). `mailto:` and the unlabeled/labeled rendering
split in isolation are covered by unit tests only
(`test/test_cross_referencing.rb`), per this project's existing precedent.

### Prose/summary containing Markdown metacharacters: indent as list-item continuation, don't escape

Settles the "Prose/summary containing Markdown metacharacters" checklist
item. The item's original framing (an escaping policy for stray backticks/
`*`/`_`/`[`) turned out to be the wrong shape for the real risk, discovered
by probing actual behavior with a real CommonMark parser (GitHub's
`cmark-gfm`, via the `commonmarker` gem, in a scratch dir — not a project
dependency) rather than reasoning from the spec alone:

- **Bare metacharacters don't need escaping.** CommonMark parses each
  block's inline content independently, so even an adversarial unmatched
  backtick run (including a bare ` ``` `) confined to one line/bullet stays
  literal and can't affect neighboring bullets — verified directly, not
  assumed.
- **The real bug is embedded newlines, and it's severe.** `YARD::Docstring
  #summary` (Member Summary bullets) already collapses to one line, but
  `Tags::Tag#text` (`@param`/`@return`/`@raise`/`@yield`/`@yieldparam`/
  `@yieldreturn`) does not — probed directly against YARD 0.9.44, a
  multi-line `@param` description retains its raw embedded newlines,
  including a blank-line paragraph break. Splicing that verbatim onto a
  single generated line can silently corrupt the whole rest of the file:
  probed a `@raise` description containing a raw `\n` immediately followed
  by an unmatched ` ``` `, and confirmed with `cmark-gfm` that it opens an
  unclosed fenced code block swallowing every subsequent heading and method
  entry to end of document, with no error.
- **Real-world evidence changed the fix from "flatten" to "preserve, then
  reflow."** The obvious fix — collapse all embedded whitespace to prevent
  any line ever starting mid-splice — closes the corruption risk, but
  google-cloud-ruby's generated API-client gems (confirmed via `gh api`
  against `google-cloud-speech-v2`, `lib/google/cloud/speech/v2/speech/
  client.rb` around line 2598: a `@!attribute` description with a genuine
  nested bulleted list of supported credential types) show real gems do
  write multi-paragraph, list-bearing tag descriptions — mostly ones
  generated from language-agnostic specs (protobufs) rather than
  hand-written idiomatic Ruby docs, but real nonetheless. Flattening would
  destroy that structure.

**The decision:** for every tag whose text is spliced onto a `- ` list-item
bullet (`@param`, `@yieldparam`, `@raise`, and — see the rendering-shape
change below — `@return`/`@yield`/`@yieldreturn`), preserve the full
`markdownify`-converted text (paragraphs, nested lists, inline markup and
all) and indent every line after the first by 2 spaces, matching the width
of the `- ` marker itself. Verified this only needs to match the *marker*
width, not the bullet's own longer visible prefix (`` [`ParseError`]
(ParseError.md) — ``), so a fixed 2-space indent is correct regardless of
prefix length — `cmark-gfm` correctly scopes the nested paragraphs/list to
that one list item, with sibling bullets and the trailing `**Defined in:**`
line unaffected. This also incidentally keeps this format's own
`grep '^## '`/`grep '^### '` lookup mechanism (see "Output format") safe
from a prose-embedded heading: an indented `## fake heading` still renders
as a real (if oddly nested) HTML heading, but it does **not** match a
column-0-anchored grep against the raw `.md` source, which is what this
format's indexing actually depends on. This is a different, narrower
problem than the still-open docstring-*body* heading collision (see
"Markdown formatting in prose" below), which remains unindented at column 0
and stays deliberately deferred.

Implemented as `indent_continuation` (`templates/default/module/agentdocs/
setup.rb`), called from both `summary_suffix` (Member Summary bullets —
already single-line via `Docstring#summary`, so a no-op there — and Params/
Yield Params bullets) and `dash_join` (Raises, and now Returns/Yields/Yield
Returns). No metacharacter escaping was added anywhere.

**Rendering-shape change, decided alongside this:** `@return`/`@yield`/
`@yieldreturn` moved from a single-line `**Label:** value` bold-key-value
line to the same `**Label:**` / blank line / `- ` bulleted-list shape
`@param`/`@raise` already used — required because a plain paragraph line
(no list marker) has no CommonMark-safe way to host nested block content
(a paragraph can be *interrupted* by a heading/fence/list-marker line even
without a blank line first, so the corruption risk applies to a bare
`**Returns:** value` line too, and there's no container block to indent
continuation lines under). This was verified against YARD's own default
HTML template (`templates/default/tags/html/tag.erb`, yard 0.9.44), which
generically renders *every* tag type — including `@return`/`@yield`/
`@yieldreturn` — as its own `<li>`, confirming multiple tag instances are
already an idiomatically-expected shape, not just a workaround invented
here. This changed nearly every existing `example/doc` fixture
mechanically (shape only, no content change) — see `git log` for the
full diff. One pre-existing fixture bug surfaced and got fixed as a
byproduct: `Geometry::Point#label`'s `@param separator` was already
wrapped across two comment lines in `example/lib`, and the *old*,
un-reflowed generator had been silently emitting the continuation at
column 0 (a real, unnoticed instance of the same corruption-shaped bug);
it now reflows correctly.

**Deliberately not solved here:** the template still renders only the
*first* `@return`/`@yield`/`@yieldreturn` tag, even though the rendering
shape now technically supports more. Genuinely supporting multiple tags of
these kinds — a real pattern per YARD's own generic template — is tracked
as a new checklist item under "Methods — shapes & signatures", separate
from this one, because it raises its own open question (what the signature
line's `→ Type` arrow shows for more than one `@return` type) that this
item didn't need to answer.

**Exercised** via two `example/lib` additions, chosen to cover both the
common case and the evidenced-richer case: `Stopwatch#reset`'s `@param to`
wraps across two comment lines (plain soft-wrap, no nested list — the
everyday case); `Geometry::Point.parse`'s `@raise [ParseError]` gained a
multi-paragraph description with a nested bulleted sub-list (mirroring the
google-cloud-ruby shape). Both tag families' shared helpers mean this
covers `@param`/`@raise`/`@yieldparam` and, via the rendering-shape change,
`@return`/`@yield`/`@yieldreturn` as well — no dedicated multi-line example
was added for the latter three, consistent with this project's existing
precedent of proving shared machinery once and leaning on unit tests (not
a forced fixture) for the remaining edge cases (see the code-span/
fenced-block precedent under "Inline cross-references in prose").

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
and `Geometry::Point.parse` (two `@raise` tags, `Geometry::ParseError` for a
malformed string and `TypeError` for a non-`String` argument — mirroring how
Ruby's own `Integer()`/`Array()` conversions document more than one failure
mode for one method):

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
  any other type token: `centroid`'s `ArgumentError` and `Point.parse`'s
  `TypeError` are unresolved stdlib exceptions, rendering as a plain
  backtick (same policy as an unresolved `Array`/`Hash` element type), while
  `Point.parse`'s other tag, `Geometry::ParseError`, is defined in-example
  and renders as a link — see "Custom exception class" below.
- A single `@raise` tag carrying more than one type (e.g. `@raise
  [ArgumentError, TypeError]`) isn't exercised; `Point.parse` uses two
  separate single-type tags instead, judged the more common real-world
  pattern. Revisit if the dogfood milestone turns up the multi-type-per-tag
  form in the wild.

### Custom exception class: no special handling; surfaced the empty-`## Member Summary` gap

`Geometry::ParseError < StandardError` needed no dedicated template code of
its own — it's rendered by the same class-page/superclass/`@raise`
cross-referencing machinery as everything else, exercising an *unresolved*
superclass (`**Superclass:** \`StandardError\``, not `Object`/`Struct`/`Data`)
and, via `Point.parse`'s `@raise [ParseError]`, a *resolved* one linking back
to `ParseError.md`.

What it did surface: `ParseError` is idiomatically empty (`class ParseError <
StandardError; end`) — no methods, constants, attributes, or nested classes —
a shape no existing example class had. `member_summary.erb` previously
unconditionally emitted a `## Member Summary` heading with nothing under it
for such a class. Escalated to a design decision on the spot (per
"Prioritization and roadmap"'s guidance for a (mech) item that surprises):

- The whole `## Member Summary` block (heading and all) is now omitted when
  an object has zero members in every category — no nested classes/modules,
  constants, attributes, class methods, or instance methods
  (`any_members?` in `templates/default/module/agentdocs/setup.rb`, gating
  the `erb(:member_summary)` call in `page.erb`). Chosen over keeping the
  heading with an empty-state placeholder (e.g. `*(No members.)*`), per the
  terseness half of "Design heuristic: agent reference needs mirror human
  reference needs" — dead-weight scaffolding costs an agent tokens for
  nothing, even though YARD's own HTML template does render an empty
  members box.
- This only changes output for a class/module with zero members overall;
  every previously-covered case (including `Geometry.md`, which has nested
  classes but no constants/methods of its own) still renders identically —
  `any_members?` is `nested_objects.any? || any_member_sections?`, a
  superset of the pre-existing `any_member_sections?` gate on the `##
  Constants`/`## Class Methods`/etc. sections below it.

### `@overload`: two idioms, both rendered from the tag data instead of the real signature

Settles the "Multiple overloads via `@overload`" checklist item, covering
both real-world idioms stock YARD itself distinguishes (single overload
tag vs. two or more), not just the literal "multiple" wording. Exercised
via `Geometry::Point.of` (two overloads, dispatching on argument type, with
genuinely different return types) and `Geometry::Point#label` (one
overload, giving a friendly keyword-style signature over an options-hash
implementation).

- **Single `@overload` tag** — the common idiom for a method whose real
  Ruby signature is awkward (`def label(opts = {})`) but is meant to be
  called one specific, friendlier way. Renders as an *ordinary-looking*
  entry: the fenced signature block, `**Params:**`, and `**Returns:**` all
  come from the overload tag's own data instead of the real method's —
  indistinguishable from a hand-written natural signature, which is the
  point of the idiom. The main docstring (prose) is always the real
  method's own, unconditionally — not switched to the overload's own
  (usually blank) docstring the way stock YARD's `docstring_text` does,
  since every case worth exercising here writes real prose on the method
  itself; revisit only if a case with a blank main docstring surfaces.
- **Two or more `@overload` tags** — the "one Ruby signature doesn't tell
  the full story" idiom. Renders as: one leading fenced signature block
  listing every overload's natural-call-syntax line, one per line; then the
  shared method docstring (prose) and `@example`s; then one repeated group
  per overload — a bold inline-code label (that overload's own
  natural-call-syntax line again) followed by its own `**Params:**` and
  `**Returns:**`, sourced entirely from that overload's own tag data.
  `**Yields:**`/`**Yield Params:**`/`**Yield Returns:**`/`**Raises:**`/
  `**See also:**` stay method-level and shared (rendered once, not per
  overload) — not exercised varying per overload by either fixture. See
  "Prose-vs-signature ordering" below for why this shape (not the original
  prose-first one) is current.
- **Implementation:** `MethodSignature#param_names`/`#signature_text`
  (`lib/yard/agentdocs/method_signature.rb`) both grew an `overload:`
  keyword (default `nil`, preserving every prior call site/test
  byte-for-byte): when given a `::YARD::Tags::OverloadTag`, params come
  from `overload.parameters` and the return type from
  `overload.tag(:return)` instead of `meth.parameters`/`meth.tag(:return)`.
  No new handler or parsing code was needed — `OverloadTag` already
  exposes `#parameters` (the same `[name, default]` shape as
  `MethodObject#parameters`) and forwards `#tag`/`#tags` to its own nested
  docstring, so every existing cross-referencing/`type_ref` helper works
  unchanged on overload-sourced tags. `templates/default/module/agentdocs/method_entry.erb`
  branches on `@method.tags(:overload).size` (0/1 share one code path —
  passing `overload: nil` — vs. 2+ its own repeated-group loop).
- **Not exercised, left for a real case to justify:** a method carrying
  both `@overload` tags *and* its own top-level `@param`/`@return` (assumed
  redundant/unusual — when overloads are present they're treated as the
  complete params/return story); per-overload `@yield`/`@raise`/`@see`; and
  an aliased/inherited method's overloads as seen from another class's
  page (not raised by either fixture).

### Prose-vs-signature ordering: one leading multi-line signature block, bold inline-code labels per overload group

Settles the "Settle prose-vs-signature ordering as one uniform rule"
checklist item — the 2+-overload shape was the one entry kind that led with
prose instead of a signature. The July 2026 agent-usefulness evaluation's
initial recommendation ("stack each overload's own signature/params/returns
block first, shared prose and examples after") put the shared docstring
*after* every overload's params/returns. Human review of the `Point.of`
fixture rejected that: description prose gives the context params/returns
need to be read *against* (same reason the non-overload entry order is
signature → prose → params/returns, not signature → params/returns →
prose), so burying it after every overload's specifics was worse, not
better, than the original problem.

Landed shape (matches every other entry's signature → flags → prose →
`@example`s → specifics order, generalized to N call shapes):

1. One fenced `` ```ruby `` block right after the heading, listing every
   overload's natural-call-syntax line, one per line — the multi-arity
   analogue of the single signature line every other entry leads with.
2. Flags (`@deprecated`/`@abstract`/`@note`, also-known-as, overrides) —
   same position as any other entry, right after the signature block. This
   incidentally resolves a question the original recommendation left open
   (where flags land when there's no single leading signature to hang them
   off of): with exactly one leading block regardless of overload count,
   there's exactly one answer.
3. The shared docstring (prose) and `@example`s.
4. One repeated group per overload: a bold inline-code label restating
   that overload's natural-call-syntax line, then its own `**Params:**`/
   `**Returns:**`.
5. Shared `**Yields:**`/etc., then trailing tags (`@since`/etc.), then
   `**Defined in:**` — unchanged from before.

**Considered and rejected: re-fencing each overload's signature a second
time** (i.e. a full ` ```ruby ` block per overload group in step 4, not
just a bold label) — the human's first sketch of this shape, explicitly
flagged as having a duplication cost worth solving rather than accepting.
Rejected in favor of the bold inline-code label because: it avoids
duplicating the full fenced block (cost scales with overload count); it
reuses an existing idiom instead of inventing one (`` **Options (`param`):**
`` already labels a nested block this way); and a heading (`` #### ``)
was considered and rejected for the same label, since `` #### ``/`` ##### ``
are already claimed by "demote user's own docstring headings below the
structural range" (below) — reusing them structurally here would make an
agent unable to tell a demoted docstring heading from a structural overload
marker.

**Implementation:** also fixed a latent bug the original recommendation's
shape had never surfaced: `trailing_annotation_lines` (`@since`/`@todo`/
`@version`/`@author`) was called once inside the 2+-overloads branch and
again in the shared tail after the branch, so a 2+-overload method with
e.g. `@since` would have rendered it twice. No fixture combined 2+
overloads with a trailing tag until this item added `@note`/`@since` to
`Point.of` specifically to catch it. Fixed by deleting the in-branch call;
the shared tail's call is now the only one, for both branches.

### Auxiliary one-line tags: `@deprecated`/`@note` as flag lines, `@since` as trailing metadata

Settles the "Auxiliary one-line tags" checklist item for all three
representative tags at once (single decision, per the checklist item's own
framing), on both a method and a non-method object for each. Exercised via
`Geometry::Computations.distance` (`@deprecated` with a `{Point#distance_to}`
replacement pointer, coexisting with its existing `@see`) and `Geometry::Circle`
(`@deprecated` with no pointer, phased out in favor of `Data.define`-based
value objects — a class-level example) for `@deprecated`; `Geometry::Point#round`
(`@note` about negative-precision rounding) and `Stopwatch` (`@note` about
thread-safety — a class-level example) for `@note`; `Geometry::Point::DIMENSIONS`
and `Geometry::Vector` (a class-level example) for `@since`.

- **`@deprecated`/`@note` render as bold flag lines** in the same
  "before prose" slot tag-based-privacy's `**Private API.**` line already
  occupies (see "Visibility policy" above) — for a method, right after the
  signature block; for a class/module, right after the metadata block
  (`metadata.erb`), before the docstring. When more than one flag applies to
  the same object, they stack with no blank line between them, in a fixed
  order — `**Private API.**`, then `**Deprecated.**`, then `**Note:**` —
  mirroring YARD's own default template's `private`/`deprecated`/`note`
  ordering (see `docstring/setup.rb` in the installed `yard` gem). Not
  exercised by any current fixture (no example object carries two flags at
  once), but the ordering is settled regardless, since it costs nothing to
  fix now and avoids an arbitrary array-order dependency later.
  - `**Deprecated.** text` (period, matching YARD's own "Deprecated. ...").
    A replacement pointer is just ordinary tag text — `@deprecated Use
    {Point#distance_to} instead.` needs no special-casing, since tag text
    already goes through `markdownify` (which resolves inline `{...}`
    references) the same as any other tag. No text at all renders as the
    bare flag, `**Deprecated.**`.
  - `**Note:** text` (colon, matching YARD's own "Note: ..."). Only a
    single `@note` tag is read (`object.tag(:note)`, not `.tags(:note)`) —
    same singular-tag treatment as `@deprecated`/`@private`/`@api`; multiple
    `@note` tags on one object aren't exercised and aren't handled.
  - Member Summary gets a `(deprecated)` suffix for a deprecated member,
    reusing the same bullet-suffix slot `(private API)` already uses
    (`method_summary_line` now joins `annotation_lines_short`'s entries with
    `", "` instead of rendering a single fixed annotation) — genuinely
    useful for "does this class have a working way to do X" scanning, the
    same reasoning "Visibility policy" gives for flagging private API there.
    `@note`/`@since` get no Member Summary suffix — informational content,
    not a state flag worth surfacing in a one-line discovery listing. A
    class/module's *own* deprecation doesn't propagate to bullets that
    merely *link* to it (a nested-class bullet in its parent's Member
    Summary, or the flat FQN index) — left unexercised and unimplemented;
    revisit if the dogfood milestone shows this matters.
  - **Superseded:** rendering shape later changed from a bare bold line to a
    `- **Label:**` bulleted list item, and `@todo` was pulled out of this
    group entirely — see "Bulleted-list rendering for metadata/flag lines"
    and "Splitting the flag block" below.
- **`@since` renders as a trailing `**Since:**` key-value line** instead — a
  version string isn't a flag to call out up front the way a deprecation or
  caveat is, so it goes wherever each object kind already puts its own
  trailing/metadata key-value lines instead of the shared flag block:
  - Constants: right before `**Defined in:**` (`constant_entry.erb`), after
    the docstring — the same slot a method's `**Returns:**`/`**See also:**`
    occupy relative to *its* `**Defined in:**`.
  - Classes/modules: **(superseded — see below)** originally folded into the
    metadata block itself (`metadata.erb`), right after `**Superclass:**`/
    `**Includes:**`/`**Extends:**` and before `**Defined in:**`; later moved
    out of `metadata.erb` entirely into its own trailing block after the
    docstring — see "Splitting the flag block" below.
  - No backticks around the version text (`**Since:** 1.0.0`, not `` **Since:**
    `1.0.0` ``) — unlike `**Superclass:**`/`**Value:**`, it isn't a type
    reference or Ruby literal, just a plain version token, matching how
    YARD's own default template renders it unadorned too.
  - **Superseded:** `@since` on a method is no longer un-exercised —
    `method_entry.erb` now calls `since_line` (via `trailing_annotation_lines`),
    which surfaced that `@since` is one of YARD's two transitive tags. See
    "Splitting the flag block" below for the full decision.
- **Implementation:** a new `YARD::AgentDocs::AuxiliaryTags` mixin
  (`lib/yard/agentdocs/auxiliary_tags.rb`, alongside `VisibilityInfo`) adds
  `annotation_lines`/`annotation_lines_short` (the flag-line array and its
  Member Summary-suffix counterpart, composing `VisibilityInfo`'s existing
  `private_api_annotation`/`private_api_annotation_short` together with the
  new `@deprecated`/`@note` handling) and `since_line`. Included from
  `module/agentdocs/setup.rb` alongside the other mixins, so `class/agentdocs`
  picks it up automatically via its existing `include T("default/module/agentdocs")`.
  `method_entry.erb`'s and `page.erb`'s previous direct
  `private_api_annotation` calls were both replaced with `annotation_lines`
  (now wrapping the private-API text in `**...**` itself, since it's no
  longer the ERB template's job once composed alongside the other two flag
  lines) — verified byte-for-byte unchanged against `Stopwatch#raw_elapsed_s`,
  the one pre-existing fixture with a private-API flag.

### `@abstract`: folded into the existing flag-line mechanism, no new prominence

Settles the "`@abstract`" checklist item. Exercised on `Geometry::Shape`
(class-level, "never instantiated directly") and two method-level cases on
that same class: `#label` (abstract, but with a real, working default
implementation that `Polygon` overrides and `Triangle` inherits) and `#area`
(abstract with no working implementation at all — a bare `raise
NotImplementedError` stub, deliberately left unoverridden by every subclass
in this example, since nothing else in the example needs an area
computation).

- **No extra prominence beyond the existing one-line flag mechanism.** The
  checklist item flagged this as an open question — YARD's own HTML template
  renders `@abstract` as a highlighted `<div class="note abstract">` box,
  visually heavier than a plain flag line — but a highlighted box is still,
  structurally, one info block ahead of the prose, the same slot
  `**Deprecated.**`/`**Private API.**` already occupy. Giving it a bigger
  Markdown treatment (its own heading, a blockquote) would cost terseness
  for no real gain: the bold flag is already unambiguous once read under its
  own `#`/`##`/`###` heading. `abstract_line` (`lib/yard/agentdocs/auxiliary_tags.rb`)
  renders `**Abstract.** text`, bare `**Abstract.**` with no text, exactly
  like `deprecated_line`.
- **Flag order becomes Private API, Deprecated, Abstract, Note** (`annotation_lines`) —
  matches YARD's own internal `docstring/setup.rb` section order (`private,
  deprecated, abstract, todo, note`), skipping `todo` since it isn't a
  supported tag here yet (see the still-open "remaining free-form tags"
  checklist item). Not exercised by any current fixture (no object here
  carries two flags at once), but settled regardless, same "costs nothing to
  fix now" reasoning as the original auxiliary-tags decision.
- **Member Summary gets an `(abstract)` suffix**, reusing the same bullet-suffix
  slot `(deprecated)`/`(private API)`/`(read-only)` already use
  (`annotation_lines_short`) — useful for the same "does this class have a
  working way to do X" scanning `(deprecated)` already serves; an agent
  scanning a class's members can tell at a glance which ones are
  extension points rather than opening the full entry.
- **No propagation to a bullet that merely links to an abstract class.**
  `Geometry.md`'s own `Shape` bullet is unchanged — same precedent already
  set for `@deprecated` ("a class/module's own deprecation doesn't propagate
  to bullets that merely link to it"); revisit both together if the dogfood
  milestone shows this matters.
- **A stub `raise NotImplementedError` body needs no special-casing** —
  confirmed by `#area`: the renderer only ever reads `object.tags`/`object.docstring`,
  never the method body, so an abstract method's implementation (a working
  default vs. a bare raise) is invisible to the template either way. The
  `@raise` tag on `#area` renders through the ordinary, already-settled
  `**Raises:**` list, no new logic.
- **Implementation:** `AuxiliaryTags#abstract_line` (private) and its wiring
  into `#annotation_lines`/`#annotation_lines_short`, mirroring
  `deprecated_line`/`note_line` exactly. No ERB template changes — `page.erb`
  and `method_entry.erb` already call `annotation_lines`/`annotation_lines_short`
  generically.

### `@example`: `**Examples:**` block right after the docstring, titles as italic lines

Settles the "`@example`" checklist item. Exercised on `Geometry::Circle`
(class-level, one titled example — also confirms ordering against its
existing `@deprecated`), `Geometry::Point#distance_to` (method, one bare
example), and `Geometry::Point.of` (method, two titled examples — reusing
its existing 2-overload `@overload` pair, which also settles where
`@example` sits relative to the per-overload signature/params/returns
breakdown).

- **Header is always `**Examples:**`** (plural), regardless of how many
  `@example` tags are present — mirrors YARD's own default HTML template,
  whose "Examples:" `h4` doesn't flex for count either, and matches this
  format's other headers (`**Params:**`, `**Raises:**`) not flexing for
  singular.
- **Placement: immediately after the object's docstring prose**, before
  `**Params:**`/the per-overload breakdown (methods) or `## Member Summary`
  (classes/modules) — matches `@example`'s position in YARD's own tag
  rendering order (`docstring/setup.rb` puts `example` right after the
  docstring text, ahead of `param`/`return`/`raise`/`see`).
- **A titled example's title renders as an italicized line** (`*Title*`)
  directly above its code fence, not a Markdown heading — avoids colliding
  with the `## `/`### ` structural heading hierarchy `grep '^## '` relies
  on. A bare example (no title) is just the fenced code block.
- **Code fence is always ` ```ruby `.**
- **`@example` text is never passed through `markdownify`** — confirmed via
  `YARD::Tags::Library` that `@example` uses the `:with_title_and_text`
  factory (raw code + title), unlike `@param`/`@return`/`@note`, which are
  RDoc/Markdown prose.
- **Implementation:** a new `YARD::AgentDocs::ExampleTags` mixin
  (`lib/yard/agentdocs/example_tags.rb`) adds `examples_block(object)`,
  returning the full block (or `nil` if untagged). Included from
  `module/agentdocs/setup.rb` alongside the other mixins, so it's shared
  by `page.erb` (class/module) and `method_entry.erb` (both the
  single-overload and `overloads.size >= 2` branches) without duplicating
  the rendering logic per object kind.

### Class/module reopened across files: comma-separated `**Defined in:**`, own-members-only

`Geometry::Rectangle` is split across `rectangle.rb` (docstring, `#initialize`,
`#area`) and `rectangle_perimeter.rb` (reopens the class, adds `#perimeter`
only — no second class-level docstring, keeping the fixture narrowly about
the `**Defined in:**` question rather than also raising which of two
docstrings should win).

- **Multiple locations render as one comma-separated line**, not a bulleted
  list: `` **Defined in:** `path/a.rb`, `path/b.rb` ``. Rejected the
  bulleted-list form used by `**Params:**`/`**Returns:**`/`**Raises:**`
  because those lists carry a per-entry description; a bare file path
  doesn't need one, and every other metadata-block line (`**Superclass:**`,
  `**Includes:**`) stays a single terse line — a list here would break that
  block's otherwise-uniform shape. The single-file case is unchanged
  (still one path, no comma).
- **Order matches YARD's own file-priority, not parse/glob order**: verified
  directly against `YARD::CodeObjects::Base#files` (parsing the two fixture
  files in both orders) that the file carrying the object's docstring always
  sorts first, regardless of which file YARD parses first. No extra sorting
  needed in the template — `object.files`' existing order is already right.
- **Surprised us mid-implementation, escalated per "Prioritization and
  roadmap"'s guidance for a surprising (mech-shaped) sub-step**: naively
  rendering every path in `object.files` blew up `Geometry.md`'s
  `**Defined in:**` line to all 17 `geometry/*.rb` files, because every file
  that nests a class/module inside `Geometry` (`module Geometry; class Foo;
  ...; end; end`) counts as "reopening" `Geometry` too, in YARD's own
  bookkeeping — the namespace-wrapping idiom every multi-file gem uses is
  indistinguishable, in `object.files`, from a "real" reopening that adds
  new content directly. Since the nested type already gets its own file and
  its own `**Defined in:**` line, repeating that path on the *namespace's*
  line would be pure noise.
  - Fixed by filtering to **own direct members only**: a file counts as a
    second "defined in" location only if it contributes one of the object's
    own constants, attributes, or methods — not a nested class/module.
    Always includes `object.file` (the docstring-bearing file) first,
    regardless of whether that file has any direct members beyond the
    docstring itself (true for `Geometry`, which is a pure namespace).
  - Implemented as `defined_in_line` in
    `templates/default/module/agentdocs/setup.rb`: `object.children.reject
    { |c| c.is_a?(CodeObjects::NamespaceObject) }.map(&:file)`, unioned with
    `object.file`, deduplicated. Replaces the old inline `` `<%=
    object.file %>` `` in `metadata.erb`.
  - Verified against both fixtures: `Geometry.md`'s line is unchanged
    (`geometry.rb` only — its 17 nested classes don't count), and
    `Rectangle.md`'s shows both `rectangle.rb` and `rectangle_perimeter.rb`
    (both contribute real methods).
- **Follow-up surprise from "Nested namespacing"'s `Geometry::ThreeD`
  (undocumented namespace-only module, reopened by `three_d/point.rb`
  nesting `Point` inside it): `object.file` isn't deterministic when the
  object has no docstring anywhere.** The "order matches YARD's own
  file-priority" bullet above only holds when *some* file has a docstring —
  `CodeObjects::Base#files` prioritizes that file via `unshift`, which is
  parse-order-independent (re-verified). But with no docstring on any
  reopening, nothing triggers that `unshift`, so `files.first` is just
  whichever file YARD's parser registered first — which for `ThreeD` meant
  whichever file `Dir.glob("example/lib/**/*.rb")` happened to visit first,
  and glob's directory-traversal order put the nested `three_d/point.rb`
  before the sibling `three_d.rb`, even though `three_d.rb` sorts first
  lexicographically. A silent dependency on glob traversal order isn't
  something this template should carry.
  - Fixed by making `defined_in_line`'s primary-file choice explicit rather
    than trusting `object.file` unconditionally: use `object.file` when
    `object.docstring` is non-empty (deterministic, as already verified),
    otherwise fall back to the lexicographically-smallest path among
    `object.files` (`object.files.map(&:first).min`) — deterministic
    regardless of parse/glob order either way.
  - Verified against all three fixtures: `Rectangle`/`Geometry` (both
    docstring-bearing) render identically to before, and `ThreeD.md` now
    shows `example/lib/geometry/three_d.rb`.

### Multiple return types: union tags, multiple `@return`/`@yieldreturn` tags

Tackled together (originally two separate checklist items) once tracing the
code showed they're the same underlying gap: `signature_return_type` and
`method_entry.erb`'s Returns/Yield Returns blocks all did `tag.types.first`
off a single `.tag(:return)`/`.tag(:yieldreturn)` call — so a union type in
one tag (`@return [Point, nil]`) silently dropped everything but the first
type, and a second `@return`/`@yieldreturn` tag was silently dropped
entirely. Both are just "more than one type token exists," so both get
fixed by the same change. Exercised via five new `Geometry::Path` methods:
`#add`/`#transform!` (`@return [self]`), `#clear` (`@return [void]`),
`#closest_to` (single tag, union type `[Point, nil]`), `#segment_at` (two
`@return` tags), `#transform!` (also two `@yieldreturn` tags).

- **The signature arrow joins every return type with `", "`, in source
  order — a union in one tag and multiple tags render identically.**
  `signature_return_type` now does `meth.tags(:return).flat_map { |t|
  t.types || [] }.join(", ")` instead of `meth.tag(:return)&.types&.first`:
  `path.closest_to(target) → Point, nil`, `path.segment_at(index) →
  Segment, nil`. Rejected showing only the first type (matches today's
  accidental behavior, but silently discards what the docstring author
  wrote) and rejected omitting the arrow entirely (throws away the
  signature line's whole value for exactly the methods where a reader most
  needs the at-a-glance shape). `self`/`void` needed no new handling —
  neither ever resolves via `Registry.resolve` (confirmed by probe), so
  they already rendered as plain unresolved tokens through the existing
  `type_ref`/arrow machinery; only the truncation-to-`.first` bug was new.
- **The `**Returns:**`/`**Yield Returns:**` blocks become bulleted lists,
  one bullet per tag, each tag showing its own (possibly still
  comma-joined, for a same-tag union) type** — `method_entry.erb` now
  iterates `method_return_tags(@method)` (renamed from the singular
  `method_return_tag`, now returning `meth.tags(:return)` filtered to `[]`
  for a constructor) and `@method.tags(:yieldreturn)`, each bullet's prefix
  now `type_ref(tag.types.join(", "))` instead of `type_ref(tag.types.first)`.
  Exactly the same iterate-and-bullet shape `**Params:**`/`**Raises:**`
  already used — no new rendering primitive, and the existing
  `type_ref`/"Compound-type cross-referencing" scanner already tokenizes a
  comma-joined union correctly (verified by probe: `"Point, nil"` from a
  different file renders `` [`Point`](Point.md)`, nil` ``, with `Point`
  linked and `nil` left a plain token), so a same-tag union bullet needed no
  new cross-referencing logic either.
- **`@yield` tag multiplicity itself (as opposed to `@yieldreturn`) is
  intentionally left unexercised and unimplemented.** Multiple *different*
  `@yield` signatures on one method (as opposed to multiple acceptable
  `@yieldreturn` values, which is a realistic "return X to replace, nil to
  skip" convention) is a genuinely rare, contrived pattern with no natural
  fixture — per the project's "don't build untested generality" stance,
  `yield_tag`/the `**Yields:**` block still use the singular `.tag(:yield)`
  and would silently drop a second `@yield` tag if one appeared. Revisit if
  real usage (the dogfood milestone) surfaces a genuine case.
- **Left deliberately unchanged, out of scope:** the 2+-`@overload` branch's
  per-overload Returns bullet (`ov.tag(:return)`) still takes only the
  first *tag* — no fixture combines `@overload` with multiple `@return`
  tags, so extending that would be unverified generality. (Its single
  tag's own union type did get fixed, but only as a side effect of the
  later "Union types on the remaining first-type-only tag sites" decision
  fixing `type_ref_first` generally, not by any change here.)

### Union types on the remaining first-type-only tag sites: extend the comma-join policy via `type_ref_first`, plus two direct fixes

Settles the "Union types on the remaining first-type-only tag sites"
checklist item under "YARD tags" — the follow-up the "Multiple return
types" decision above flagged but didn't do: `@param`, `@option`,
`@yieldparam`, `@raise`, a 2+-`@overload` method's signature arrow, and
the attribute `**Type:**` line all still rendered only a tag's first
declared type.

- **`CrossReferencing#type_ref_first` now joins every type instead of
  taking `.first`** (kept its name — misleading in isolation, but every
  call site still reads naturally, e.g. `type_ref_first(p)` for a param).
  Since every bullet-list site (`@param`, `@yieldparam`, `@raise`, and
  `@option` via `option_line`) already funneled through this one helper,
  fixing it there fixed all four simultaneously, with zero `.erb` changes
  — exactly the "should be mechanical" case the checklist predicted.
  Exercised via `Geometry::Angles.normalize`'s `degrees` param (`@param
  degrees [Float, Integer]`), `Point#translate`'s `:y` option (`@option
  deltas [Integer, Float] :y`), and `Computations.centroid`'s `@raise
  [ArgumentError, NoMethodError]` (a real, previously-undocumented failure
  mode: passing a non-`Point` element genuinely raises `NoMethodError`
  today, not just `ArgumentError` for an empty array) — deliberately *not*
  exercised via a dedicated `@yieldparam` fixture, since it's the exact
  same `type_ref_first(p)` call as `@param`, just a different tag array;
  a redundant fixture would prove nothing the `@param` one doesn't already.
- **Two side effects of fixing the shared helper, neither requested by the
  checklist item but both free and correct:** the 2+-`@overload` branch's
  own per-overload Returns bullet (`type_ref_first(ov_return)`) now also
  joins a same-tag union (though not multiple `@return` *tags* on one
  overload — see the amended note under "Multiple return types" above,
  still out of scope); and a constant's `**Type:**` line
  (`constant_entry.erb`'s `type_ref_first(@constant.tag(:return))`) now
  does too, though no fixture was added to prove it — no example
  constant declares a union `@return` type, and inventing one purely to
  exercise an incidental fix would be unverified generality the same way a
  dedicated `@yieldparam` fixture would have been.
- **`MethodSignature#signature_return_type_for` and
  `AttributeInfo#attribute_type` each needed their own one-line fix**,
  since neither funnels through `type_ref_first` (confirmed while tracing
  the code, matching what the checklist item already suspected): both now
  do `tag&.types&.join(", ")` instead of `&.first`. Exercised via
  `Point.of`'s `(point, count)` overload (`Point.of(point, count) →
  Array<Point>, Point`) and `Waypoint#label` (`**Type:** String, Symbol`).
- **`Point.of`'s fixture required a real behavior change, not just a doc
  edit**, to keep the union type honest: no existing overload branch
  naturally returned more than one type, so `(point, count)` now returns a
  bare `Point` (not a 1-element array) when `count` is `1`, documented as
  `@return [Array<Point>, Point]`. Chosen over a documentation-only union
  (which would have been fiction relative to the actual code) or
  inventing a new class purely to exercise this arrow.

### `@option`: a separate `**Options (`param`):**` bulleted block, one per documented hash param

Exercised via `Geometry::Point#translate(**deltas)`, adding
`@option deltas [Numeric] :x (0) the x offset to add` /
`@option deltas [Numeric] :y (0) the y offset to add` alongside its existing
`@param deltas [Hash{Symbol => Numeric}]` tag. Probed YARD's actual tag
model first (`OptionTag#name` is the parent param's name; `#pair` is a
`DefaultTag` holding the option key as `pair.name` — with its leading `:`
kept, e.g. `":x"` — plus `pair.types`, `pair.text`, and `pair.defaults`, an
array of raw default-value source text or `nil`).

- **A new top-level `**Options (`deltas`):**` heading, immediately after
  `**Params:**`, not a nested sub-list under the `deltas` bullet.** Every
  other tag family in `method_entry.erb` (Params, Yields, Yield Params,
  Yield Returns, Returns, Raises) is a flat, independent heading — even
  Yield Params, conceptually "inside" the yielded block, gets its own
  heading rather than nesting under Yields. Nesting would have introduced
  the template's first multi-level list and breaks down if a method ever
  has two separate hash params each with their own `@option`s; a
  `(`param`)`-qualified heading per param, matching YARD's own default HTML
  template's grouping, avoids both problems. `method_entry.erb` iterates
  `param_tags` (already computed for `**Params:**`) and, for each param,
  filters `@method.tags(:option)` down to the ones whose `name` matches
  that param — only emitting a heading when that filtered list is
  non-empty.
- **The default renders inside the type parenthetical** (`` `Numeric`,
  default `0` ``), **not appended after the dash text.** Unlike an ordinary
  optional param, an option key has no natural-syntax home in the method
  signature (`point.translate(**deltas) → Point` can't show it) — so,
  unlike "Optional param default rendering" above, the bullet is the *only*
  place left to put it. Bundled with the type as one structural
  parenthetical, keeping the dash-text free for the description only
  (`option_line` in `setup.rb`).
- **Only the primary (non-`@overload`) rendering branch handles
  `@option`.** The 2+-`@overload` branch's own Params block
  (`ov.tags(:param)`) has no fixture pairing `@overload` with `@option`, so
  it stays unchanged — same "don't build untested generality" call as the
  `@overload`/multi-return-type gap above.
- **Left deliberately unexercised: an `@option` key with no default.**
  Both `:x` and `:y` ended up with `(0)` defaults (matching
  `deltas.fetch(:x, 0)`/`deltas.fetch(:y, 0)`, and the docstring's "Any
  coordinate not given defaults to no change"), so `option_line`'s
  no-default branch (`type_part = ... : type`) is exercised only by
  inference from the identical, already-proven `@param`-with-no-default
  bullet shape, not by a byte-for-byte-asserted `@option` fixture of its
  own. Revisit if a real case (dogfood milestone) or a future checklist
  pass wants that branch directly covered.

### Structured constant: multiline value escalates to a ` ```ruby ` fence

Settles the "Structured constant" checklist item. `@constant.value` is
`Base#value`'s verbatim source text of the constant's right-hand side, not
markdownified prose — the same category of content `@example` already
renders as raw code, not the same category the `@param`/`@return`
list-item-continuation fix (see "Prose/summary containing Markdown
metacharacters") applies to.

- **The bug, proven against a real CommonMark parser first, not assumed:**
  the pre-existing single-line `` **Value:** `<value>` `` inline code span
  breaks the moment the value spans multiple lines *and* contains a blank
  line — a realistic style choice in a real hash/array literal (grouped
  entries separated for readability). CommonMark closes the paragraph at
  the blank line before inline parsing (code spans) ever runs, so the
  backtick pair never matches; the stray literal backticks and the value's
  own text spill across multiple broken paragraphs. This is the same
  corruption class the `@return`/`@yield` rendering-shape change already
  fixed for tag text, just not yet fixed for `**Value:**`, which had never
  been exercised past a single-line literal (`Point::DIMENSIONS`/`ORIGIN`).
- **The fix: escalate to a ` ```ruby ` fence when (and only when)
  `@constant.value` contains a newline**, leaving the existing single-line
  `` **Value:** `<value>` `` rendering untouched — verified this needs no
  metacharacter escaping or reflow logic of its own (unlike the tag-text
  fix): a fenced code block is a block-level container that correctly
  interrupts a preceding paragraph without a blank line first (verified
  with `commonmarker`), and YARD's `value` text already comes indented
  relative to the literal's own first line, not the source file's nesting
  depth, so it drops into the fence with no reformatting. Implemented as a
  `<%- if @constant.value.include?("\n") -%>` branch directly in
  `constant_entry.erb`, not a `setup.rb` helper — this is exactly the kind
  of optional block-shape branching "Template coding convention" reserves
  for the `.erb` file itself.
- **Reused `@example`'s established shape** (plain ` ```ruby ` fence, value
  never passed through `markdownify` — it's code, not prose) rather than
  inventing a new one, for the same reason `@example`'s own decision gives:
  a constant's raw value is source text, not RDoc/Markdown prose.
- **The `**Value:**` label gets its own line plus a blank line before the
  fence in the escalated case** (unlike the tight, no-blank-line
  `**Type:**`/`**Value:**` pairing the single-line case keeps), matching
  how `**Examples:**` already separates its header from its own fence —
  once `**Value:**` is fronting a block instead of a trailing inline value,
  it reads as a block header like the format's other block sections, not a
  second bare fact glued under `**Type:**`.
- **Known, deliberately deferred edge case:** a value containing a literal
  line starting with `` ``` `` (fence-delimiter collision) or with `## `/
  `### ` (this format's own raw-grep heading-index prefixes, e.g. from an
  inline double-hash Ruby comment) isn't specially handled. This risk
  already exists, unaddressed, for `@example`'s fenced code today — this
  change doesn't introduce a new gap, just doesn't close the pre-existing
  one. Revisit only if a real case surfaces (dogfood milestone).

Exercised via `Geometry::Angles::NAMED_ANGLES`, a multiline `Hash`
constant (compass-direction degree headings) added to `Geometry::Angles`
— chosen over a dedicated new fixture class since the design question
(single-line vs. multiline) doesn't depend on which structured literal
type (`Hash`/`Array`/`Regexp`) is involved, only on newline presence, so
one multiline `Hash` proves the mechanism for all three; unit-test-only
coverage for `Array`/`Regexp` shapes was not added, consistent with this
project's existing precedent of proving shared machinery once (see the
compound-type/code-span precedents elsewhere in this document).

### Enumerator-returning method: single block-form signature line, no overload-aware block detection

Settles the "A method returning an `Enumerator`..." checklist item.
Exercised via `Geometry::Path#each_segment` (`return enum_for(:each_segment)
unless block_given?`, `@yieldparam segment`, and two `@return` tags —
`Integer` when a block is given, `Enumerator` when not).

- **Confirmed mechanical: zero template changes.** Probed the real,
  already-implemented template against this fixture before touching
  `example/` at all. Multiple `@return` tags (see "Multiple return types"),
  `@yieldparam` rendering, and the implicit-block-literal signature line
  (see "Block presentation") are all independently-settled machinery that
  compose correctly with no new code: `path.each_segment { |segment| ... }
  → Integer, Enumerator`, with both `@return` tags listed in declaration
  order under `**Returns:**`.
- **The real design question: the signature line shows only the
  block-calling form**, never the no-block form (`path.each_segment →
  Enumerator`) that this exact method also supports. Considered making
  `@overload` show both forms separately (already-settled machinery for
  "multiple distinct call forms" in general) but rejected it: `block_literal`/
  `implicit_block?` in `method_signature.rb` inspect the *method's* own
  `@yield`/`@yieldparam` tags, not a specific `@overload` tag's, so every
  overload of a method currently gets identical block-literal treatment —
  giving each overload its own independently-detected block presence would
  be new, more invasive machinery, not a mechanical extension of what's
  already there.
  - **Accepted the single-signature-line simplification instead** — matches
    this project's own "natural call syntax over invented schema" precedent
    (prefer composing settled machinery over inventing a new rendering
    schema), and mirrors how Ruby's own core docs handle the identical
    idiom (e.g. `Array#each`: one signature line showing the block form,
    with the no-block/Enumerator behavior carried in prose/`@return` rather
    than a second signature line) — not a novel shortcut, a well-precedented
    one.
  - Not revisited unless a real case (dogfood milestone) makes the omission
    genuinely confusing in practice, at which point overload-aware block
    detection would need its own design pass.

### Remaining free-form tags: render generically via existing `@since`/`@note` machinery, don't drop

Settles the "Remaining free-form/low-value tags" checklist item. Scanned
`YARD::Tags::Library.labels` (the full set of tags YARD knows about) against
every tag this project's templates already reference by name, and confirmed
`@author`/`@todo`/`@version` were the *only* three with no handling
anywhere — silently dropped today purely because nothing names them, not by
any deliberate policy. So this one decision closes the whole gap; nothing
else needs covering under "and anything similar."

- **Initially proposed dropping them** (matching the pre-existing de facto
  behavior) on terseness grounds, but reconsidered after checking what
  YARD's own default HTML template actually does — per this project's
  "agent reference needs mirror human reference needs" heuristic, that's
  the reference point a divergence needs to justify itself against, not an
  assumption. YARD's default template renders all three: `@author`/
  `@version` generically via its catch-all tag-list section
  (`Tags::Library.visible_tags`), `@todo` specially as a highlighted
  callout. Human decision: render, matching that precedent, rather than
  diverge.
- **`@version` reuses `@since`'s exact rendering shape and scope** — a
  trailing `**Version:** 1.2.0` key-value line (`version_line` in
  `AuxiliaryTags`), originally wired into `metadata.erb` right after
  `since_line`. **Superseded:** `since_line`/`version_line`/`author_line` all
  moved out of `metadata.erb` into a separate trailing block, and
  `since_line`/`version_line`/`author_line` are now also wired into
  `method_entry.erb` — see "Splitting the flag block" below.
  `constant_entry.erb`/`attribute_entry.erb` still only wire in `since_line`
  (constants) or nothing at all (attributes); `@todo`/`@version`/`@author`
  remain unwired for both, same pre-existing "not exercised" gap as before.
- **`@author` supports multiple tags**, comma-joined under one `**Author:**`
  label (`Vector`'s `@author Ada Lovelace` / `@author Alan Turing` →
  `**Author:** Ada Lovelace, Alan Turing`) — same "one label, join the
  values" policy `defined_in_line` already uses for multiple file paths,
  chosen over flexing the label to `**Authors:**` for consistency with this
  format's established "labels don't flex for count" precedent (`@example`'s
  `**Examples:**` header, `@raise`'s always-bulleted `**Raises:**`).
- **`@todo` joins the existing flag-line family** (`deprecated_line`/
  `abstract_line`/`note_line` in `AuxiliaryTags`, via `annotation_lines`),
  appended last in the fixed Private API/Deprecated/Abstract/Note/Todo
  order — YARD's own template has no equivalent ordering to match (it
  renders `@todo` as a separate callout, not part of the same flag-line
  group), so "last" was picked arbitrarily as the lowest-priority
  annotation. **Superseded:** `@todo` was later pulled out of this group
  entirely into its own trailing block, after the prose rather than before
  it — see "Splitting the flag block" below. Deliberately not added to
  `annotation_lines_short` (Member Summary bullet annotations) — `@note`
  itself has no short form either, an existing precedent `@todo` just
  follows; this is unaffected by the later move.
- Exercised via `Stopwatch` (`@todo`, alongside its existing `@note`,
  proving the flag-line family holds more than two entries at once) and
  `Geometry::Vector` (`@since`/`@version`/`@author` stacked together,
  proving `metadata.erb`'s trailing block holds more than one optional line
  at once — previously only ever exercised with `@since` alone).

### Bulleted-list rendering for metadata/flag lines: CommonMark reflow and embedded-newline corruption

Prompted by re-reading the generated output as a human would (not just an
agent) and noticing `Stopwatch.md`'s `**Superclass:**`/`**Defined in:**`
lines, and its `**Note:**`/`**Todo:**` flag lines, were stacked with only a
single `\n` between them — no blank line. Verified two distinct problems
with a real CommonMark parser (`commonmarker`, GitHub's `cmark-gfm`, in a
scratch dir — not a project dependency), not by reasoning from the spec
alone:

- **Reflow.** Under strict CommonMark (no `hardbreaks`, which is how most
  non-GitHub renderers behave — Python-Markdown, pandoc, `marked` without
  options), consecutive bare `**Label:** value` lines land in one `<p>`, and
  the raw `\n` the parser emits between them gets collapsed by a browser
  into a single space — `Superclass: Object Defined in:
  example/lib/stopwatch.rb` reads as one flowing line. (`commonmarker`'s own
  default *does* insert `<br>` there, since its Ruby API defaults
  `render.hardbreaks` to `true` — confirmed directly — which isn't
  representative of a generic renderer, so the reflow probe was re-run with
  `hardbreaks: false` to see the strict-spec behavior instead.)
- **Embedded-newline corruption — the more serious finding.** `note_line`/
  `todo_line`/`deprecated_line`/`abstract_line`/`since_line`/`version_line`/
  `author_line` (`AuxiliaryTags`) all splice `markdownify(tag.text)` directly
  into a bare line — exactly the shape "Prose/summary containing Markdown
  metacharacters" (above) already fixed for `@param`/`@raise`/`@return`/
  `@yield` — but the fix (`indent_continuation`) was never applied here.
  Confirmed directly that `Tags::Tag#text` retains raw embedded newlines,
  including a blank-line paragraph break, for these tags too, and reproduced
  the exact severe failure mode already documented above: a multi-paragraph
  `@note` containing an unmatched fenced-code delimiter swallows every
  subsequent heading/entry to end of document, with no error.

**The decision:** every currently-bare `**Label:** value` line that either
(a) could be stacked adjacent to another such line with no blank line, or
(b) splices in raw tag text, becomes a `- **Label:** value` bulleted list
item, reusing `indent_continuation` for every value built from tag text
(`@note`/`@todo`/`@deprecated`/`@abstract`/`@since`/`@version`/`@author`).
Verified with `commonmarker` that this fixes both problems at once: list
items stay structurally distinct `<li>`s regardless of `hardbreaks`, and a
multi-paragraph value nests safely inside its own `<li>` instead of leaking
into the next block. For uniformity, *every* field line was converted this
way, even ones that were already isolated by blank lines and had no
adjacency risk (a method/constant/attribute's own trailing
`**Defined in:**`, the alias branch's `**Alias for:**`) — "a field is always
a bullet" is one simple rule to hold onto, rather than one that depends on
incidental adjacency. Not touched: `**See also:**` (a type/link list, not
raw prose, so no corruption risk, and already isolated), `**Params:**`/
`**Returns:**`/`**Raises:**`/`**Yields:**` (already bulleted), and the
multi-file comma-joined `**Defined in:**` line (already an established
single-line exception — see "Class/module reopened across files" above —
now `- **Defined in:** \`a.rb\`, \`b.rb\`` instead of a bare line, same
comma-joining).

- **Implementation:** `AuxiliaryTags#annotation_lines`, `#since_line`,
  `#version_line`, `#author_line` (and the private `#deprecated_line`/
  `#note_line`/`#abstract_line`/`#todo_line`) all prefix `- ` and wrap
  tag-text values in `indent_continuation`; `class/agentdocs/setup.rb#
  superclass_line`, `module/agentdocs/setup.rb#mixin_line`/`#defined_in_line`,
  `lib/yard/agentdocs/method_signature.rb#also_known_as_line`/
  `#overrides_line` gained the same `- ` prefix; `constant_entry.erb`/
  `attribute_entry.erb`/`method_entry.erb` got the same prefix spliced onto
  their remaining inline `**Type:**`/`**Value:**`/`**Defined in:**`/
  `**Alias for:**` lines.
- **Regression coverage:** extended `Stopwatch`'s `@todo` into a genuine
  multi-paragraph tag (a real blank line inside the tag text, not just a
  soft-wrapped single paragraph) — no fixture previously exercised a blank
  line inside `@note`/`@todo`/`@deprecated`/`@abstract`, so nothing would
  have caught a regression here otherwise. Verified end to end with
  `commonmarker` that the second paragraph nests correctly inside the
  `- **Todo:**` list item with no bleed into neighboring content, then
  regenerated every `example/doc`/`example/rdoc/doc` fixture from the actual
  template output (never hand-edited) and diffed to confirm only the
  intended lines changed.

### Splitting the flag block: `@todo`/`@since`/`@version`/`@author` move to a trailing block after the prose

Follow-up to "Auxiliary one-line tags" and "Remaining free-form tags" above,
prompted by looking at `Stopwatch.md` again and judging that
`**Note:**`/`**Todo:**` (grouped together, before the description) put too
much weight on `@todo`, which isn't really a caveat about *using* the object
the way `@note`/`@deprecated`/`@abstract` are.

- **Split by how actionable the tag is, not by tag "family."**
  `@deprecated`/`@abstract`/`@note` stay exactly where they were — the
  "before prose" flag slot — because they're genuine caveats that change how
  the rest of the entry should be read (a thread-safety warning, a
  deprecation notice), matching YARD's own default template's placement of
  these as callouts before the description. `@todo` (forward-looking, not a
  present caveat) and `@since`/`@version`/`@author` (provenance/bibliographic
  metadata, not usage-relevant) move to a new trailing block instead, placed
  after the docstring — burying lower-priority information below the actual
  content, rather than making a reader wade through it first, is the right
  trade-off here. `@note` was explicitly *not* moved, even though it was
  raised alongside `@todo` initially — `Geometry::Point#round`'s and
  `Stopwatch`'s own `@note` tags are exactly the kind of "read this before
  you use the method" caveat that belongs up front.
- **Where "trailing" means depends on the entry kind.** For a method, it's
  literally the bottom of the entry — right before the already-trailing
  `**Defined in:**` line (both the single-overload/primary branch and the
  `overloads.size >= 2` branch, the latter having no `**Defined in:**` line
  to anchor against at all — a pre-existing, unexercised gap this change
  doesn't fix, but the trailing block was still added at the end of that
  branch for symmetry). For a class/module, "just above `**Defined in:**`"
  doesn't work — classes put `**Defined in:**` at the *top* of the page (see
  "Output format" above), so the trailing block goes right after the
  docstring/`@example`s instead, before `## Member Summary`.
- **Surfaced a real YARD semantic while wiring `since_line` into
  `method_entry.erb` for the first time** (previously "not exercised," per
  "Remaining free-form tags" above): `@since` is one of only two tags YARD
  marks *transitive* (`@since` and `@api` — confirmed via
  `YARD::Tags::Library.transitive_tags`, *not* `@version`/`@author`). A
  transitive tag on a namespace applies to every child object that doesn't
  redeclare it, so `Geometry::Vector`'s class-level `@since 2.0.0` now also
  shows on all four of its methods. No bundled YARD template special-cases
  transitivity — the inheritance happens in `Docstring#tag` itself, not the
  template — so this is exactly how YARD's own default HTML template would
  render the same fixture. Decided, after presenting the trade-off, to leave
  it un-special-cased rather than filtering to only-directly-declared tags:
  it matches upstream semantics, and it's genuinely useful information for
  an agent looking at one method in isolation.
- **Implementation:** `AuxiliaryTags#annotation_lines` narrowed to Private
  API/Deprecated/Abstract/Note only; new `AuxiliaryTags#trailing_annotation_lines`
  added, returning Todo/Since/Version/Author in that order. `metadata.erb` no
  longer calls `since_line`/`version_line`/`author_line` (only
  `**Superclass:**`/`**Includes:**`/`**Extends:**`/`**Defined in:**` remain).
  `page.erb` calls `trailing_annotation_lines(object)` after the
  docstring/examples block, before `## Member Summary`. `method_entry.erb`
  calls `trailing_annotation_lines(@method)` in both overload branches,
  right before (or, for the `>= 2` branch, in place of) `**Defined in:**`.
  `constant_entry.erb`'s existing standalone `since_line(@constant)` call
  (already positioned correctly, after the docstring and before
  `**Defined in:**`) is untouched; `@todo`/`@version`/`@author` remain
  unwired for constants/attributes, same "not exercised" scope this item
  already had.
- Exercised via `Stopwatch` (`@todo`, now the sole occupant of the trailing
  block there, with its multi-paragraph text from the bulleted-list-rendering
  decision above) and `Geometry::Vector` (`@since`/`@version`/`@author`, now
  trailing instead of top-of-page, plus the newly-visible transitive
  `@since` on its methods).

### Trailing-bullet list merging: `*` for flag/trailing/per-entry-`Defined in:` lines, joined tight

Follow-up to "Bulleted-list rendering for metadata/flag lines" above — that
decision made every bare `**Label:** value` line a `- ` bullet to fix
reflow/embedded-newline corruption, but never checked what happens when one
of those bullets lands directly after an *unrelated* bulleted block with
only a blank line between them. Human review of the `Point.of` work
noticed `**Returns:**`'s list visually swallowing the `**Since:**`/
`**Defined in:**` lines after it. Verified with `commonmarker` (a real
CommonMark parser, not reasoning from the spec alone) that this is a
genuine, spec-conformant behavior — a blank line between two `- `-bulleted
blocks doesn't end the list, only makes it "loose"; ending a list requires
different block content (a paragraph, a heading, or a different bullet
character) — and then scripted the same check across every `example/doc`/
`example/rdoc/doc` file to find the real scope: nearly every file shipped
with at least one such merge (any content list — `**Returns:**`/
`**Raises:**`/`**Yields:**`/etc. — immediately followed by trailing
`**Since:**`/`**Defined in:**` bullets; also class-level `**Superclass:**`/
`**Includes:**`/`**Defined in:**` metadata merging with `**Deprecated.**`/
`**Abstract.**`/`**Note:**` flags right after it, since flags come before
prose with nothing but a blank line between).

**The fix:** every bullet that isn't part of the "content" of an entry —
`@deprecated`/`@abstract`/`@note`/private-API (`annotation_lines`),
also-known-as/overrides, `@todo`/`@since`/`@version`/`@author`
(`trailing_annotation_lines`), the alias branch's `**Alias for:**`, and
every *per-entry* `**Defined in:**` (method/attribute/constant) — switches
from `- ` to `* `. CommonMark treats a bullet-character change as starting
a new list, unconditionally, so this reliably splits these from whatever
`- `-bulleted content list precedes them, with no new visible syntax (a
human skimmer barely notices one character differs). Left as `-`: the
class-level metadata block itself (`**Superclass:**`/`**Includes:**`/
`**Extends:**`/`**Defined in:**`, only ever adjacent to each other, meant
to render as one block — same as before) and every content-shape list
(`**Params:**`/`**Options:**`/`**Returns:**`/`**Yields:**`/`**Yield
Params:**`/`**Yield Returns:**`/`**Raises:**`, plus attribute/constant
`**Type:**`/`**Value:**`/`**Read-only.**`). Two markers were enough because
the two families never both use `*` while directly touching each other
without an intervening paragraph/heading — verified by checking every
adjacency, not just the ones already failing.

**Considered and rejected:**
- **`<!-- -->` HTML-comment separator** — also verified with `commonmarker`
  to split the lists, but depends on the renderer supporting raw HTML
  blocks; under a renderer with HTML disabled/escaped it degrades to
  visible literal `<!-- -->` text, which is bad for a format that's meant
  to still be human-legible (see "Output format" above).
- **Thematic break (`---`)** — also verified to work (renders a real
  `<hr>`), but would add a visible divider line to nearly every entry in
  the corpus (any content list followed by `**Defined in:**`, i.e. almost
  all of them) — a much bigger visual footprint than a one-character marker
  swap.

**Implementation:** `AuxiliaryTags#annotation_lines`/`#trailing_annotation_lines`
(and their private `#deprecated_line`/`#note_line`/`#abstract_line`/
`#todo_line`/`#since_line`/`#version_line`/`#author_line`) switched their
leading `- ` to `* `; ditto `MethodSignature#also_known_as_line`/
`#overrides_line`; ditto the literal `**Alias for:**`/`**Defined in:**`
lines in `method_entry.erb`, `attribute_entry.erb`, and
`constant_entry.erb`. `setup.rb#defined_in_line`/`#mixin_line` and
`class/agentdocs/setup.rb#superclass_line` (the class-level metadata block)
were deliberately left untouched. Applied uniformly, not just where a
merge was empirically observed in the current fixtures — same "one simple
rule, not dependent on incidental adjacency" reasoning as the original
bulleted-list-rendering decision.

**Regression coverage:** since this is a purely mechanical rendering fix
(no content changes), every `example/doc`/`example/rdoc/doc` fixture was
regenerated directly from the updated template rather than hand-edited,
then diffed against the previous fixtures to confirm the *only* change on
every line was `- ` → `* ` (verified file-by-file before committing to the
regenerated set) — consistent with "prove format correctness" instead of
arguing the change was probably safe. Re-ran the `commonmarker` merge-scan
against the regenerated corpus afterward and confirmed zero remaining
blank-line-separated same-marker bullet adjacencies anywhere in either
fixture tree.

**Follow-up: join the trailing block to `**Defined in:**` tight, not
loose.** The marker swap alone still left a blank line between
`trailing_annotation_lines`'s output and the method's own
`**Defined in:**` — both `* `, so CommonMark keeps them one list, but the
blank line makes it a *loose* list (`<li><p>...</p></li>`, extra vertical
space per item), and it's just as easy to keep it tight. Verified with
`commonmarker` that a bullet-character change alone (no blank line needed
at all) reliably starts a new list even directly against a `- `-bulleted
block, and that a list also correctly interrupts a plain paragraph with no
blank line — so `method_entry.erb` now only inserts a blank line before
`**Defined in:**` when `trailing_annotation_lines` is empty (nothing
tight to join it to); when non-empty, `**Defined in:**` follows the
trailing lines' last line directly. Exercised by adding `@version` to
`Point.of` alongside its existing `@since`, specifically to prove multiple
trailing fields plus `**Defined in:**` stack tight as one list, not just a
single field.

**Spotted but deliberately not touched in this pass** (same underlying
"two `* ` bullets, blank line between" pattern, confirmed still present):
the alias branch's `**Alias for:**` directly followed by `**Defined in:**`
when the alias has no own prose (e.g. `Stopwatch#restart`), and a
constant's `since_line` directly followed by `**Defined in:**`
(`constant_entry.erb`). Flagging rather than folding in, since the
requested fix was scoped to the method-level trailing-tags case — worth a
deliberate follow-up rather than silently expanding this pass's scope.

### Agent-usefulness evaluation (July 2026)

A read-through evaluation of the full `example/doc` output from the
perspective of a coding agent needing to discover, search, and use the
library — including a comparison against reading `example/lib` source
directly. Not itself a format decision; logged here (like "Checklist
pruning and prioritization" above) so its findings, measurements, and
considered-and-rejected items don't get re-derived or re-proposed later.

**What works, no changes recommended:** known-FQN lookup is one cheap,
self-contained file read; the flat index plus the consistent
`### .method`/`### #method` heading grammar make both class discovery and
cross-corpus member search a single grep; the natural-call-syntax
signature lines (`point.round(precision: 0) → Point`) are the
highest-value single element; and the output surfaces semantics the
source hides — `Data.define`-synthesized members that exist as no `def`
in source (`Vector#dx`/`#dy`), reopened-class consolidation
(`Rectangle`), deprecation/abstract/override/alias flags, and
`**Defined in:**` file:line pointers as an escape hatch back to the
implementation. Private members being filtered out also shrinks the
surface an agent must read relative to source.

**Measurement worth keeping:** on this fixture the docs are ~37% *larger*
than the source (38.9KB vs. 28.5KB total; `Point.md` 7.2KB vs. `point.rb`
6.0KB), so per-class token cost currently favors reading source. Judged
an artifact of the fixture's toy method bodies under rich docstrings
rather than a real problem — real gems' implementation bodies should flip
the ratio — but this turns "cheaper than reading source" into an explicit
claim for the dogfood milestone to verify (a sentence to that effect was
added to the milestone's description).

**Recommendations, added as checklist items** (all human-gated per the
TDD loop, none acted on yet):

1. **"How to navigate these docs" preamble** — (design), under "Indexing
   & discovery". The format's mechanical conventions (path derivation,
   heading grammar, grep recipes, where inherited members live) are
   exploitable by an agent only if disclosed somewhere it will read
   first. Judged the evaluation's highest-value gap.
2. **Names-only inherited/mixin member roster in `## Member Summary`** —
   (design), under "Module/class structure". Deliberately challenges the
   settled "link out, don't duplicate" decisions: those weighed full doc
   duplication against a bare metadata pointer, but never the names-only
   intermediate that YARD's own HTML template renders. Motivating case:
   `Triangle.md` shows only `.new`, and assembling a Triangle's full API
   surface takes four further file reads.
3. **Prose-vs-signature ordering** — (design), under "Methods — shapes &
   signatures", replacing the former "Open questions" entry. The concrete
   new evidence is `Point.of`: its `@example`s render before any
   signature, so a top-down reader sees usage before learning the method
   has two arities. Recommendation: signature-first everywhere. Landed
   shape ended up refined from this recommendation after human review — see
   "Prose-vs-signature ordering" under "Decisions".
4. **Undocumented-attribute boilerplate** — already tracked by the
   existing `attr_*` item under "Attributes & constants"; that item's
   wording now records this evaluation's independent finding that the
   YARD fallback text renders as pseudo-documentation
   (`Circle#radius` — `` **Type:** `Object` ``, "Returns the value of
   attribute radius") indistinguishable from a legitimately terse
   docstring.

**Considered, explicitly no action** (recorded so they aren't
re-proposed):

- **Member Summary in tiny files** (`Taggable.md`, `Named.md`, `Loud.md`)
  is nearly half the file and pure duplication of the one or two entries
  below it. A member-count threshold below which the summary is omitted
  was considered and rejected: uniform, predictable structure is worth
  more than the handful of tokens.
- **Long `index.md` summary lines** (`Loud`/`Named` run ~150 characters).
  Fine at 21 entries; revisit at dogfood scale if the index bloats, rather
  than inventing a clamping rule now.
- **Member cross-links land on the target file, not the member**
  (`` [`Point#distance_to`](Point.md) `` — the reader greps the heading
  after arriving). Heading-anchor schemes were considered and rejected as
  fragile for operator names (`#[]=`, `#+`) and renderer-dependent; the
  navigation preamble (item 1 above) should document "grep the `### `
  heading" as the intended second hop instead.

### Navigation guidance: preamble plus skill, staged, with a strict division of labor

Follow-up to the agent-usefulness evaluation above, which recommended the
"how to navigate" preamble. Weighed against an alternative delivery
mechanism: an accompanying agent *skill* (SKILL.md) that teaches
using/navigating the format, either instead of or in addition to the
preamble. **Settled on both, staged, with a strict division of labor** —
each is tracked as its own checklist item under "Indexing & discovery".

The two mechanisms answer different questions, which is why neither
subsumes the other:

- **The preamble is in-band** — it travels inside the generated output, so
  it helps any agent that has already located the docs, on any harness,
  with zero installation, and it's version-locked to the tree it describes
  (emitted by the same template run). But it's purely reactive: it can't
  encode behavior ("when you need Ruby API info, look here first") or
  procedure ("if the docs don't exist, generate them like so"), because it
  has no way into an agent's context until the docs are already open.
- **The skill is out-of-band routing** — its description sits in the
  agent's context from session start, so it triggers *before* the agent
  starts spelunking through installed-gem source or an HTML yardoc site.
  That upstream discovery problem is the bigger one: the format's
  conventions are learnable from one file read (the preamble makes that
  reliable and instant rather than inferred), but no amount of in-band
  documentation can make an agent look in the docs directory in the first
  place. Costs: an installation/distribution burden the gem can't automate
  (its own chicken-and-egg discovery problem), benefit limited to
  harnesses that support skills, and a second artifact that can drift from
  the format version that generated any given tree.

Decisions embedded in the "both" outcome:

- **Skill-instead-of-preamble was explicitly rejected.** It would make the
  output format silently dependent on consumer-side configuration; an
  unconfigured agent — or a non-skill harness — would lose even the cheap
  win. Self-describing output is worth preserving as an invariant.
- **Anti-drift rule:** the preamble owns the *how* (format mechanics —
  path derivation, heading grammar, grep recipes); the skill owns the
  *when and why* (prefer these docs, generate missing ones) and defers to
  the preamble for mechanics rather than duplicating them. This is what
  keeps the two artifacts from diverging as the format evolves.
- **Staging:** preamble first — it's ~15 lines, universal, and the floor
  even the skill's own users benefit from. The skill is gated on the
  dogfood milestone, because its most valuable content is the
  generation/lookup workflow, which depends on integration decisions (how
  a consuming project invokes the template per-dependency, where output
  lands) that aren't settled until dogfooding; writing it earlier means
  guessing at the workflow.

### "How to navigate these docs" preamble: inline at the top of `index.md`

Implemented per the staging decision above. Settled placement: its own
`## How to navigate these docs` section, inline in `index.md` between the
title and `## Classes & modules` — not a separate linked conventions file
(the alternative the checklist item raised), since it's ~15 lines and an
agent that has just opened `index.md` shouldn't need a second file read to
get the mechanics.

Covers exactly the three things the checklist item named, one bullet each:
path derivation (`::` → directory separator), the `### NAME`/`### #name`/
`### .name` heading grammar with both grep recipes (single-file and
whole-tree), and that inherited/mixed-in members aren't duplicated —
follow `**Superclass:**`/`**Includes:**`/`**Extends:**` to their own file
instead.

**Generic placeholders, not fixture names.** The first draft illustrated
path derivation with the fixture's own classes (`Geometry::Point`,
`Geometry::ThreeD::Point`) and the grep recipe with a fixture-adjacent
`#each`. Caught before implementing: this text is static boilerplate
`index.erb` emits for *any* consuming gem, not content specific to this
repo's example — a real project's generated docs would carry a preamble
talking about `Geometry::Point`, which doesn't exist in their codebase.
Switched to metasyntactic placeholders (`Foo::Bar`, `Foo::Bar::Baz`) for
path derivation, and reworded the `#each` grep example with an explicit
"e.g." so it reads as an illustration of the recipe rather than a claim
that the gem being documented has that method.

**Reminder resolved:** the "not duplicated" bullet has been rewritten (see
"Names-only inherited/mixin member roster" below) now that the roster
itself has landed and changed what "not duplicated" means.

### Names-only inherited/mixin member roster: one hop, dedup by name, no H3 stubs

Settles the checklist item under "Module/class structure". A new `## Member
Summary` subgroup, **Inherited & Mixed-in Members**, appended after the
existing subgroups: one bullet per contributing ancestor/mixin, names-only
(no descriptions), the ancestor/mixin name linked the same way
`**Superclass:**`/`**Includes:**`/`**Extends:**` already link. Verb per
source: `` **Inherited from `Polygon`:** `` (superclass), `` **Included
from `Taggable`:** `` (`include`), `` **Extended from `Named`:** ``
(`extend`) — parallel to the metadata field names. Exercised via `Shape`
(`Included from Taggable: #tag`), `Polygon` (`Inherited from Shape:
#area`), and `Triangle` (`Inherited from Polygon: #describe, #each_side,
#label, #sides`; `Extended from Named: .kind`).

**Scope: one hop only**, mirroring `superclass_line`'s already-settled
reasoning — a more distant ancestor may live outside the parsed source, so
only the immediate superclass and each directly-`include`d/`extend`ed
module are queried, never walked further. An agent wanting `Shape`'s
`#area` from `Triangle` (two hops: `Triangle` → `Polygon` → `Shape`) hops
through `Polygon`'s own page, which carries its own bucket. This is a real,
permanent gap — the roster can never reflect `Enumerable`, `Object`, or any
other unparsed ancestor — but not a new *kind* of gap: reading the raw
source has the identical blind spot, and it's the same honesty policy
`**Superclass:**` already committed to (one reliable hop beats a chain
that's silently incomplete). The preamble's "not duplicated" bullet (see
above) now says so explicitly, so an agent doesn't over-trust the roster as
exhaustive.

**Dedup rule: exclude any name already present among the object's own
members**, regardless of whether it's a plain shadow or a
`**Overrides:**`-flagged override. This is what makes `Polygon`'s roster
render *nothing* for `Loud` even though `` **Includes:** [`Loud`](Loud.md)
`` is real metadata on that page: `Loud` prepends and contributes only
`#describe`, but `Polygon` already lists its own `#describe` (full
docs, own file) — without dedup the roster would repeat that name for zero
new information, right next to the exact prepend-precedence subtlety
`Polygon`'s prose already calls out. With dedup, `Loud`'s bucket has zero
surviving names and is omitted entirely (same "absence means empty"
convention used everywhere else in Member Summary) — this is also what
correctly skips `Polygon`'s own `.new` from `Triangle`'s "Inherited from
Polygon" bucket, with no ctor-specific special case needed.

**Sigil semantics differ by mixin kind, and matter for correctness, not
just style:**
- **Superclass** contributes constants/attributes/class methods/instance
  methods unchanged (a subclass truly inherits all of them, same calling
  form), so natural sigils throughout.
- **`include`** contributes constants (reachable via Ruby's constant
  lookup), attributes, and instance methods — but *not* the module's own
  class methods (`def self.foo` on a module stays solely on the module;
  `include` never brings those along).
- **`extend`** contributes attributes and instance methods only, sigil
  built as `.name` by hand rather than via
  {MethodSignature#member_heading} — reflecting `extends_line`'s
  already-established semantics that an extended module's instance methods
  "become singleton/class methods" on the extender. No constants (`extend`
  doesn't affect constant lookup) and no class methods (same reasoning as
  `include`).

**`extend self` is excluded from the roster, not just skipped for lack of
content — probed directly, not assumed.** Querying
`meths(scope: :class, included: true)` for an extend target (whether
self-extension or a normal cross-class `extend`) does *not* return a
distinct, trustworthy class-scope `MethodObject` — it returns the exact
same object as the plain instance-scope query (`equal?` true, confirmed via
scratch probe against `Geometry::Triangle`/`Geometry::Named` and
`Geometry::Angles`), with `#scope` only transiently reporting `:class` at
that call site. This generalizes the "`extend self` / `module_function`"
decision's "corrupted proxy... not something a signature renderer should
trust" finding beyond the self-extension case it was originally written
for. The roster implementation never hits this at all — it only ever calls
the ordinary `inherited: false, included: false` queries already used
everywhere else, and builds the `.name` sigil for `extend` by hand — but
`extend self` still needs an explicit `self_reference?` guard skipping it
outright (rather than relying on the querying to naturally come up empty),
matching the existing decision that `extend self` gets no fabricated
second listing anywhere, metadata-only.

**Considered and rejected: giving each roster name its own H3 stub entry**,
mirroring how an alias gets a minimal pointer entry (`**Alias for:**
#original`). The alias precedent doesn't transfer: an alias is a name with
no heading anywhere else in the corpus, so without one, the sanctioned
`grep -n '^### '` lookup mechanism genuinely fails for it. An
inherited/mixed-in method already has a real H3 heading — on the ancestor's
own page — findable today by the exact whole-tree grep recipe the
preamble itself documents (`grep -rn '^### #each' .`). There's no
lookup-mechanism gap to close. Stub entries would also reintroduce, per
subclass, the exact combinatorial duplication the whole "link out, don't
duplicate" family exists to prevent, for zero completeness gain beyond what
the one-hop bullet already gives (a stub would be one-hop too, to stay
honest about ancestry depth — same ceiling, much higher cost).

**Considered and rejected: a real docstring summary per roster name**, the
way own-member Member Summary bullets get one. Same reasoning already
established for aliases (`` `#restart` — **Alias for:** `#reset` ``, not a
copied summary): "keep the actually expensive content in exactly one
place." A summary here would mean copying the ancestor's own docstring onto
every subclass/includer — the same duplication cost the July 2026
evaluation already measured as making these docs 37% bigger than source on
this toy fixture, for a fixture that doesn't even exercise deep hierarchies
or widely-shared mixins yet.

**Implementation:** new `lib/yard/agentdocs/member_roster.rb`
(`MemberRoster` module, mixed into `module/agentdocs/setup.rb`, so it's
available to `class/agentdocs` too via that template's existing
`include T("default/module/agentdocs")`). `constant_objects`/
`attribute_objects`/`class_method_objects`/`instance_method_objects` (and
the class template's `class_method_objects` override, which adds the
synthetic `.new` entry) all gained an optional `namespace = object`
argument, so the roster reuses their exact filtering/visibility logic
(including `run_verifier`) against an ancestor's or mixin's own members
instead of duplicating it. `any_members?` now also checks
`member_roster_lines.any?`, so `## Member Summary` still renders for an
object with zero own members but a non-empty roster (not exercised by any
current fixture, but a real case once dogfooding hits a documentation-only
subclass).

### Per-entry `Defined in:` retained at all levels (July 2026 review)

Resolves the former open question "Should per-entry `Defined in:`
(method/attribute/constant) exist at all?", raised alongside the
trailing-bullet list-merging fix. That discussion questioned whether an
agent consuming a *dependency's* docs (the project's stated persona) would
ever want a per-entry source pointer — needing to open the gem's
implementation being close to the failure mode this project exists to
eliminate — and had informally converged on trimming to class-level only:
drop the trailing `* **Defined in:** path:line` line from every method,
attribute, and constant, keep the class/module metadata-block line, on
the reasoning that "given the class-level file(s), finding one method's
exact line is a single cheap `grep def method_name`." It was paused,
deliberately unimplemented, for a higher-level review. That review (July
2026, a stronger model re-examining the logged arguments fresh)
**rejected the trim — current behavior stands**: `**Defined in:**`
renders at class/module level and per-entry for every method, attribute,
and constant, exactly as before. No template or fixture change; this
entry logs the reasoning so the trim isn't re-proposed without new
evidence.

**Considerations the original discussion missed (both sides):**

- **The "mirror human reference needs" design heuristic already answers
  the default, and neither side cited it.** YARD's own HTML template
  renders per-method source location on every method (`# File
  'lib/x.rb', line 28` in the View Source toggle). The heuristic's
  terseness clause licenses compressing *presentation* ("prefer compact
  inline annotations over a human template's more elaborate treatment of
  the same information"), not dropping information the human template
  carries — and the one-line bullet already is the compact rendering.
  Trimming needed an explicit divergence case; the discussion never made
  one.
- **The trim side's grep-recovery claim fails exactly where these docs
  beat source: metaprogrammed members.** `grep "def perimeter"` works
  for plain defs, but finds nothing for attributes (`attr_reader
  :radius` — no `def radius` exists in source), `Data.define`/
  `Struct`-synthesized members (`Vector#dx`/`#dy` — which the
  agent-usefulness evaluation itself praised the format for surfacing as
  existing "as no `def` in source"), or `@!method`-directive/
  DSL-generated methods. Locating those definition sites requires
  already knowing which metaprogramming idiom produced the member —
  precisely the knowledge the docs exist to spare the agent — and in the
  real gems the dogfood milestone targets (generated API clients,
  DSL-heavy libraries), metaprogrammed members are common, not an edge
  case. The informal convergence extended the trim to attributes and
  constants "because the same reasoning applies"; attributes are in fact
  where the grep-recovery reasoning is weakest.
- **The fixture biases the debate toward "docs suffice."** `example/lib`
  is ~100% richly documented, making "when would an agent need source?"
  feel rare. Real gems invert this: for a member whose entire docstring
  is YARD's "Returns the value of attribute radius" boilerplate, the
  pointer is the entry's main payload, not an escape hatch. And the
  evaluation's own measurement (docs currently ~37% *larger* than
  source) means near-term consumers will plausibly interleave doc reads
  with source reads, raising, not lowering, pointer usage.
- **Neither side measured the cost.** Measured during this review: the
  per-entry lines are 66 lines / 3,543 bytes of the 41,422-byte
  `example/doc` corpus — **8.6%**, materially worse than the keep side's
  "isn't a meaningful contributor to verbosity" claim, and probably the
  format's largest uniform per-entry overhead. On real gems the fraction
  should shrink (real prose and method bodies dilute it) while
  individual lines grow (deeply nested `lib/...` paths). This is the
  trim side's strongest argument, and the reason this question gets a
  dogfood re-check (below) rather than being closed outright.
- **Line numbers are the brittle part, not the pointer itself.** Under
  docs/source version skew (stale vendored docs, docs generated from a
  different gem version), a `:line` suffix is silently, confidently
  wrong — worse than absent — while a bare file path degrades
  gracefully. Not acted on, since the intended deployment generates docs
  from the exact shipped source; logged so that if skewed deployments
  ever become real, the fix is dropping `:line`, not the pointer.

**Considered and rejected:**

- **Trim to class-level only** (the informal convergence) — rejected per
  the metaprogrammed-member and design-heuristic arguments above. The
  keep-side arguments it was originally weighed against remain valid
  too: the per-entry line is line-precise where class-level is
  file-only, and it resolves which file of a reopened class
  (`Geometry::Rectangle`) actually defines a given member.
- **Conditional rendering** — emit the per-entry line only where it adds
  information over class-level (multi-file classes, or metaprogrammed
  members). Kills most of the cost, but rejected on the project's own
  uniformity precedent (the Member Summary threshold rejection: "uniform,
  predictable structure is worth more than the handful of tokens"), and
  a sometimes-present field would break the navigation preamble's
  ability to state a simple invariant about where source locations live.
- **Drop `:line`, keep the path** — negligible token savings; loses the
  one-hop line precision; only worth revisiting as a staleness measure
  (see above), not a token measure.
- **Terser label** (e.g. `**Source:**` instead of `**Defined in:**`) —
  not worth format churn now; noted as the first, cheaper lever to pull
  if the dogfood measurement stays high.

**Disposition:** keep as-is. Two companion questions attached to the
dogfood milestone (see "Prioritization and roadmap"): re-measure the
per-entry overhead percentage on a real gem, and look for evidence of
whether agents actually exercise the pointers in practice. Revisit with
that data if the overhead stays high *and* the pointers go unused — not
before.

### Reference tags: transparent resolution, plus a `Params:`-ordering fix for mixed own/ref tags

Settles the "Reference tags" checklist item under "YARD tags". YARD's
`(see ...)` doc-copying syntax has two forms, both probed directly against a
running parser rather than inferred from source:

- **Whole-docstring form** (`(see #other)` as the *entire* docstring) is
  detected only when it's the very first content (`DocstringParser
  #detect_reference` anchors with `\A`); any prose before it silently
  defeats detection, leaving `(see #other)` as inert literal text — YARD's
  own contract, not something a template can rescue. Once detected, it's
  resolved lazily (`Docstring#resolve_reference`) the first time any normal
  accessor (`#summary`, `#tags`, `#to_s`) is called: the referenced object's
  full raw docstring is prepended and reparsed, merging its prose *and* its
  tags. Works across classes/namespaces, not just same-class. Exercised by
  `Geometry::Vector#eql?`, whose entire docstring is `(see #==)`.
- **Per-tag form** (`@tag name (see #other)`, e.g. `@param index (see
  #[])`) resolves via `Tags::RefTagList#tags`, matched by tag name and,
  when a name is given, by that name too — so `@raise (see #[])` (no name)
  pulls every `@raise` from `#[]`, while `@param index (see #[])` pulls
  only the `index` one. Exercised by `Geometry::Point#[]=`, whose `@param
  index` and `@raise` were already textually identical to `#[]`'s and are
  now sourced from it instead of duplicated.

Both forms are fully transparent to the template — `param_tags =
@method.tags(:param)` and friends already see fully-resolved, ordinary-
looking `Tags::Tag` objects, exactly like a plain `@param`. **Zero template
changes were needed to render resolved content.** An unresolvable target
(e.g. `(see #nonexistent)`) degrades silently: the whole-docstring form
leaves the docstring blank (same rendering as an undocumented object —
see "Intentionally undocumented objects"), and the per-tag form just drops
that one tag (same rendering as a param with no `@param` at all). Neither
needed new handling.

**The one real surprise, found only by generating output and diffing it,
not by reading source:** `Docstring#tags` builds its list as `@tags +
convert_ref_tags` (own tags first, resolved reference tags appended after),
then stable-sorts by tag name. So on a method mixing an *own* `@param` with
a *referenced* `@param`, the own one always sorts first regardless of which
was actually declared first — `Point#[]=`'s `**Params:**` came out as
`value, index` instead of `index, value`, breaking the signature-order
convention every other entry follows. Fixed with
`MethodSignature#ordered_param_tags`, which re-sorts a method's rendered
`@param` tags to match its real parameter order (`meth.parameters` — already
the signature line's own source of truth via `#param_names`), applied at
both `**Params:**` call sites in `method_entry.erb` (the `>= 2`-overload
loop and the single-signature case). Scoped to `@param` only: it's the only
tag family with a canonical declaration order to align with (`@raise` and
friends have no such order, and nothing here mixes own/ref tags for them)
— not extended speculatively.

### `@param` naming a nonexistent parameter: dropped, not rendered

Settles the "`@param` naming a nonexistent parameter" checklist item under
"YARD tags" (2026-07-17 review). A `@param` tag whose name doesn't match any
of the method's (or overload's) real parameters — typo'd, or stale after a
signature change, which real gems have — is now dropped from
`MethodSignature#ordered_param_tags` entirely, rather than rendered.

The original framing of this item, from the code review that flagged it, was
narrower: `ordered_param_tags` sorted every unmatched tag to a shared
tie-break key (`real_names.length`) via a bare `sort_by`, which Ruby doesn't
guarantee stable, so two-or-more unmatched tags could silently reorder
between runs — a latent byte-for-byte fixture flake. Investigating that
determinism bug raised the actual design question: *should* an unmatched
tag render at all?

Checked YARD's own default HTML template first (`templates/default/tags/
html/tag.erb` in the installed `yard` gem) rather than assuming: it renders
every `@param` tag in raw docstring order with no cross-check against
`object.parameters` at all — an unmatched name renders exactly like a
matched one. So there's no YARD precedent to mirror either way; a human
reader supplies the skepticism a generated doc can't.

Decided to diverge from that (render-everything) default and drop unmatched
tags, for reasons specific to this project's audience:

- `ordered_param_tags` already diverges from YARD's docstring-order default
  once, deliberately, to reorder tags into the method's *real* signature
  order (see "Reference tags" above) — established that signature accuracy
  beats docstring-verbatim fidelity when they conflict. An unmatched-name
  tag is a stronger case for the same principle, not a weaker one: it isn't
  merely out of order, it describes a parameter that doesn't exist at all.
- This format exists so an agent can trust a method's `**Params:**` list as
  its actual call surface from a single doc read, without cross-checking
  the source. Rendering a tag for a nonexistent parameter risks an agent
  passing an argument that isn't real, producing an `ArgumentError` — the
  exact failure mode the format exists to prevent.
- Distinguished from the "flag, don't drop" precedent set for `@api
  private`/`@private` methods (see "Visibility policy" above): those flag
  something *real* — a method that exists, with restricted visibility —
  where showing it with a caveat is informative. An unmatched `@param` tag
  describes something that isn't real; there's no accurate way to flag it
  that isn't just a longer-winded way of saying "ignore this."
- YARD itself already surfaces the mistake to the docstring's *author* at
  parse time (`[warn]: @param tag has unknown parameter name: ...`); the
  generated reference doc, read by an agent rather than the author, doesn't
  need to re-surface it.

Implementation: `real_names.include?(...)` filters `param_tags` before the
existing `sort_by`, both scoped to `real_names.index(...)` (now never `nil`
past the filter). This also fully resolves the original determinism
complaint — nothing sorts on a shared tie-break key anymore, since unmatched
tags never reach the sort. Exercised by `Stopwatch#reset`'s stale `seconds`/
`millis` tags (kept in the docstring, dropped from the rendered
`**Params:**`), simulating a `seconds`/`millis` pair collapsed into a single
`to` argument without cleaning up the old tags.

### `attr_accessor`/`attr_writer` with doc comments: zero template changes; undocumented-attribute boilerplate stays as-is

Settles the `attr_reader`/`attr_writer`/`attr_accessor` checklist item under
"Attributes & constants". `Point#x`/`#y` already exercised documented
`attr_reader`; added `Rectangle#width` (documented `attr_accessor`, the
first *documented* read-write attribute — `Circle#radius` was read-write but
undocumented) and `Rectangle#height` (documented `attr_writer`, write-only).

**Zero template changes were needed**, confirmed by tracing
`YARD::Handlers::Ruby::AttributeHandler` before writing the fixture: a
single `attr_accessor`/`attr_writer` statement registers its reader and/or
writer as separate `MethodObject`s, but both are built from the *same*
statement, so they share the exact same source line and — critically — the
handler attaches the *same* docstring/comment to both (`register_docstring`
is called with `statement.comments`, identical across the loop's read/write
iterations). `AttributeInfo`'s helpers (`attribute_type`,
`attribute_docstring`, `attribute_file`, `attribute_line`) all resolve via
`attribute_source_method`, which prefers the reader but falls back to the
writer when there's no reader (the write-only case) — already correct for
every `read`/`write`/`read-write` combination without modification.
`attribute_annotation`/`attribute_annotation_short` (the `**Write-only.**`
flag line and `(write-only)` Member Summary suffix) were likewise already
implemented, exercised for the first time by `Rectangle#height`.

**Undocumented-attribute boilerplate policy: reaffirmed as-is, no new
fixture.** This item was also flagged as the trigger to revisit the
`Struct`/`Data` decision's "kept as-is rather than filtered" call on YARD's
fallback attribute docstring (`` **Type:** `Object` ``, "Returns the value
of attribute `name`"). `Circle#radius` and `Vector#dx`/`#dy` already
exercise that exact fallback end-to-end — YARD's `Struct`/`Data` handlers
and `AttributeHandler` generate the same boilerplate text through the same
`AttributeInfo` rendering path, so a bare, comment-less plain `attr_reader`/
`writer`/`accessor` fixture would add no new coverage. No new evidence
surfaced against the original reasoning (filtering by matching YARD's exact
generated string is fragile and indistinguishable from a legitimately terse
human docstring), so the policy stands: render the boilerplate, don't
suppress it. Closes the revisit; not expected to be reopened without new
evidence.

**Reopened in part (2026-07-20 YARD dogfood run, see devdocs/Dogfood.md):**
new evidence did surface, against the middle claim above, not the policy
conclusion. "`Struct`/`Data` handlers and `AttributeHandler` generate the
same boilerplate text through the same `AttributeInfo` rendering path" is
true for the docstring *text* (`attribute_docstring`, genuinely shared) but
false for the *type*: `` **Type:** `Object` `` on `Circle#radius`/
`Vector#dx` comes from a real `@return [Object]` tag `Struct.new`/
`Data.define`'s handlers synthesize on the accessor
(`tag(:return).types == ["Object"]`, confirmed directly) — plain
`AttributeHandler` never adds one (`tag(:return) == nil`), so
`attribute_type` returns `nil` and `type_ref(nil)` returns `""`: a plain,
undocumented `attr_*`'s `**Type:**` line renders visibly blank, not
`` `Object` ``. Pervasive on real code — 245 occurrences across 89 of 286
classes/modules (~31%) on the dogfood run. The render-the-boilerplate
*policy* still stands (this doesn't reopen the filtering-is-fragile
reasoning), but the claim that `Circle#radius`/`Vector#dx` already exercise
the plain-`attr_*` case "end-to-end" was wrong — they only exercise the
Struct/Data path. See the new "Attribute `**Type:**` fallback for a plain…
`attr_*`" checklist item under "Attributes & constants" — not yet fixed.

### `@attr`/`@attr_reader`/`@attr_writer` tags on a manual reader/writer pair: accept YARD's own `Defined in:` quirk, no workaround

Settles the "Manually-defined reader/writer pair documented via `@attr`/
`@attr_reader`/`@attr_writer` tags" checklist item under "Attributes &
constants". Exercised by `Waypoint#label` (paired `@attr_reader`/
`@attr_writer` tags) and `Waypoint#order` (the combined `@attr` tag) —
real, hand-written `def label`/`def label=`/`def order`/`def order=`
methods, none with their own doc comment, documented entirely through
class-level tags instead.

**Probed directly against the parser (not inferred from source) before
writing the fixture, since the checklist item explicitly flagged "escalate
to (design) if YARD doesn't merge the pair into one attribute cleanly":**
`Handlers::Ruby::ClassHandler#process` calls `create_attributes` (from the
`@deprecated`-labeled `StructHandlerMethods`, originally written for
`Struct.new`) for *every* plain class, using whatever names
`members_from_tags` finds in `@attr`/`@attr_reader`/`@attr_writer` tags —
before the class body is parsed. This eagerly registers a synthetic
placeholder `MethodObject` per reader/writer. When the real `def label` is
parsed moments later, YARD's registry reuses that *same* object (methods
are memoized by path), so the pair does merge into one `namespace.attributes`
entry — the type/docstring end up correct, reflecting the real method's own
doc comment when it has one, and the class tag's text/type otherwise
(confirmed both paths directly). **`attribute_file`/`attribute_line` do
not merge correctly, though:** `CodeObjects::Base#add_file` only lets the
*first* registration carrying a non-blank comment claim the "primary"
file/line (`#file`/`#line`); since the class's own docstring (carrying the
tags) is non-blank, the synthetic pre-body registration wins that slot
permanently. The real `def`'s own file/line registration is appended, never
promoted — verified this holds even when the real method has its own doc
comment. Net effect: `Waypoint#label`/`#order` both render `` * **Defined
in:** `example/lib/geometry/waypoint.rb:21` `` — the `class Waypoint` line
— never their real lines (33/37/41/45).

**Decision: accept it, no template workaround.** This is a real case of
`**Defined in:**` being confidently *wrong* rather than merely absent — the
kind of outcome the "per-entry `Defined in:` retained at all levels" review
called worse than an absent pointer. A workaround was considered (e.g.
preferring `object.files.last` over `object.file`/`.line` when more than one
file-registration exists) and rejected: it leans on "synthetic registration
is always first, real one is always last, exactly two entries," which isn't
guaranteed (reopened classes, multiple `@attr` blocks) — exactly the kind of
speculative robustness this project defers until the dogfood milestone
shows it's actually needed. Both `@attr`-family tags are themselves
YARD-deprecated in favor of `@!attribute` (a separate, not-yet-built
checklist item, worth checking later whether it shares this flaw — the
mechanism is a directive, not a docstring tag, so likely not), which further
lowers the expected real-world prevalence of this exact gap. Not expected to
be reopened without dogfood evidence that this combination is common enough
to matter.

### Class-level attributes: split into `## Class Attributes`/`## Instance Attributes`, mirroring the Class/Instance Methods split

Settles the "Class methods defined via `class << self`" and "Class-level
attributes" checklist items under "Methods — visibility & special forms"
and "Attributes & constants" respectively (both `pre-dogfood`) — closed
together since one fixture exercises both: `Stopwatch` gained a `class <<
self` block defining `clock_resolution` (a plain method, proving it renders
identically to `def self.foo`) and `verbose` (an `attr_accessor`, the
gap this decision actually settles).

**The gap:** `MemberListing#attribute_objects` read only
`namespace.attributes[:instance]`, so a `class << self`-declared attribute
was invisible — no Member Summary line, no full entry, no roster mention.
The `.`/`#` sigil was also hardcoded wrong in every attribute rendering
site for when this got fixed (`attribute_summary_line`,
`attribute_entry.erb`'s heading, and three of `MemberRoster`'s four heading
builders all assumed `#`).

**Two ways to render it, once visible:** fold class- and instance-level
attributes into one `## Attributes` section using the `.`/`#` sigil to
distinguish them (the only precedent: `MemberRoster#extend_headings`'s
already-hand-built `.name` sigil for an extended module's attributes
surfacing as the extending class's class-level members); or split into
`## Class Attributes`/`## Instance Attributes`, mirroring this template's
existing `## Class Methods`/`## Instance Methods` split.

**Decided to split**, checking YARD's own default HTML template first (the
mirror-human-docs default — see "Navigation guidance" and elsewhere): it
splits attributes exactly the way it splits methods —
`templates/default/module/html/attribute_summary.erb` calls
`groups(attr_listing, "Attribute")`, producing "Class Attribute Summary"/
"Instance Attribute Summary" headers, and `attribute_details.erb` renders
`<h2><%= scope.to_s.capitalize %> Attribute Details</h2>`. Section order in
YARD's own `module/setup.rb` is `attribute_summary` before `method_summary`,
class before instance within each — carried over here as `## Constants` →
`## Class Attributes` → `## Instance Attributes` → `## Class Methods` →
`## Instance Methods`, both in `## Member Summary` and in the full-entry
sections. This precedent outweighs the one narrow roster-line sigil
precedent for folding. Each attribute entry keeps its `.`/`#` heading sigil
too (`AttributeInfo#attribute_heading`, mirroring
`MethodSignature#member_heading`), even though the section header alone
would disambiguate — consistent with the grep-based navigation convention
the preamble documents.

**A latent bug surfaced during implementation, unrelated to the format
decision itself:** `MemberListing#class_method_objects` never excluded
`is_attribute?` methods (unlike `instance_method_objects`, which always
has), so a class-level attribute's synthesized reader/writer
`MethodObject`s would have double-rendered — once under the new `## Class
Attributes`, once under `## Class Methods` — until now, no class-level
attribute existed anywhere in the example to expose it. Fixed alongside
this change; zero effect on any other existing fixture.

**Mechanical fallout:** every existing class with instance-level attributes
(`Rectangle`, `Vector`, `Point`, `Waypoint`, `Circle`, `Polygon`) had its
`Attributes` header renamed to `Instance Attributes`, since the split
applies even when a class has no class-level attributes of its own — no
content changes beyond the heading text.

`MemberRoster`'s four heading builders (`own_member_headings`,
`superclass_headings`, `include_headings`, `extend_headings`) were updated
to call `class_attribute_objects`/`instance_attribute_objects` instead of
the retired `attribute_objects`, each keeping the sigil its semantics
already implied: `include`/`extend` only ever bring across a mixin's
*instance*-scope members (documented reasoning predates this change and
still holds), so both stay `instance_attribute_objects`-only; `extend`'s
own-hand-built `.name` sigil is unchanged, now visibly correct rather than
coincidentally so.

### `@!macro` (attach mode): zero template changes; expands only at call sites, `Defined in:` follows the call

Settles the `@!macro` checklist item under "YARD directives" (`design`,
`pre-dogfood`). `Geometry::BoundingBox` declares a class-level DSL method,
`.edge`, carrying an attach-mode `@!macro [attach] edge` whose body is a
nested `@!method $1` directive; four `edge :name` calls (`:left`, `:top`,
`:right`, `:bottom`) each expand into their own real, documented instance
method (`#left`, `#top`, `#right`, `#bottom`).

**Zero template changes were needed**, confirmed by probing YARD's
macro/directive machinery (`YARD::CodeObjects::MacroObject`,
`YARD::Tags::Directives::MacroDirective`/`MethodDirective`) directly before
writing the fixture, per this item's own "probe rather than assume" note.
An attach-mode macro's `expand` returns `nil` at its own definition site
(`MacroDirective#expand`: `return if attach? && class_method?`), so
`.edge`'s own docstring carries no `@return` — the macro only expands at
each subsequent call site, where `MethodDirective#create_object` registers
a brand-new `MethodObject` with a synthesized docstring and attributes it
(via `handler.register_file_info`/`register_source`) to *that* call site's
line, not `.edge`'s definition line. The synthesized method renders through
the exact same attribute/param/return machinery every other method entry
already uses; nothing agentdocs-specific needed to change.

**One indentation subtlety surfaced while probing, not a template bug:**
nested tags on the interpolated method (e.g. `@return`) must be indented
*one level deeper* than the `@!method $1` line itself, so YARD's own
directive parser (`MethodDirective#use_indented_text`) picks them up as
part of the synthesized method's docstring rather than as stray tags on the
macro invocation's (nonexistent) target — a sibling-indented `@return` is
silently dropped. This is YARD's own parsing rule, not something agentdocs
renders differently; recorded here so a future macro fixture doesn't
rediscover it.

### `@!method` (no macro): zero template changes; multiple stacked directives share one `Defined in:` line

Settles the `@!method` checklist item under "YARD directives" (`mech`,
`pre-dogfood`). `Geometry::CompassRose` defines four instance methods
(`#north`/`#east`/`#south`/`#west`) via a single `.each_key` loop over
`Angles::NAMED_ANGLES`'s keys, documented by stacking one bare `@!method
NAME` directive per generated method directly above the loop — YARD's own
documented "attaching multiple methods to the same source" pattern, used
because there's no per-iteration call site (unlike the `@!macro` case
above) for a directive to attach to individually.

**Zero template changes were needed**, for the same reason as `@!macro`:
each `@!method` directive registers an ordinary `MethodObject` via
`MethodDirective#create_object`, indistinguishable at the template layer
from a `def`-declared method. The one distinguishing rendering trait,
confirmed end to end: all four methods share the exact same `**Defined
in:**` line, since every directive's comment block is attributed to the
same underlying statement (the `each_key` call) — proving the two
directive fixtures exercise genuinely different code paths (per-call-site
macro expansion vs. one-shared-site directive stacking) despite rendering
through identical template code.

**Side discovery, left open:** an early draft of `CompassRose`'s class
docstring put an inline `{Angles::NAMED_ANGLES}` cross-reference in its
first sentence, which reproduced the still-open "`index.md`'s per-entry
summary doesn't go through `markdownify`" checklist item live — resolved
correctly on `Geometry.md`'s nested summary, literal unresolved braces on
`index.md`. Reworded to keep this fixture scoped to `@!method` only; the
bug itself remains open for that item's own fixture.

### `@!attribute`: zero template changes; same indentation subtlety as `@!method`/`@!macro`

Settles the `@!attribute` checklist item under "YARD directives" (`mech`,
`pre-dogfood`). `Geometry::PointCloud#size` is defined via a bare
`define_method(:size) { @points.size }` — no `attr_reader`, no
`@attr`/`@attr_reader`/`@attr_writer` tags (contrast `Waypoint`'s
manual-pair fixture under the "`@attr`/`@attr_reader`/`@attr_writer` tags
on a manual reader/writer pair" decision, where the tags decorate a real
`def`) — documented via `@!attribute [r] size`.

**Zero template changes were needed**: `AttributeDirective#create_attribute_data`
registers the synthesized reader into `object.namespace.attributes[scope]`,
the exact same structure `attr_reader`/`attr_accessor`, `Struct.new`/
`Data.define`, and `class << self` attributes all populate — already
rendered correctly end to end since the "Class-level attributes" fix made
`MemberListing#attribute_objects` correct for both scopes. `#size` renders
with the same `**Type:**`/`**Read-only.**`/`**Defined in:**` shape as any
other read-only attribute, nothing agentdocs-specific to change.

**Same indentation subtlety as `@!method`/`@!macro`, rediscovered here:**
descriptive text has to be indented *under* the `@!attribute [r] size`
line to become the attribute's own docstring. An initial draft put it as a
sibling paragraph immediately *above* the directive (styled like an
ordinary doc comment); that text attaches to nothing — `#size`'s Member
Summary line and full entry both rendered with an empty description until
the text was re-indented as part of the directive's own block. Three for
three now across `@!macro`/`@!method`/`@!attribute`; worth remembering as
a single shared rule rather than a per-directive quirk.

### `index.md` per-entry summaries: `summary_suffix`, plus a `current_dir` seam in `CrossReferencing`

Settles the `index.md`-summary checklist item under "Indexing & discovery"
(`mech`, escalated to `design`, `pre-dogfood`). `fulldoc/agentdocs/
setup.rb`'s `index_summary_suffix(object)` spliced `object.docstring.summary`
raw, so a `{Name}` inline reference or RDoc markup in a class/module's first
sentence rendered resolved/converted on that class's own page (and in any
enclosing namespace's `nested_summary_line` listing) but literal in
`index.md` — the one place a fresh agent is most likely to read it.
`Geometry::ThreeD::Point`'s summary now demonstrates the fix at three
different relative-path distances from the same underlying docstring.

**The surprise:** the obvious fix — have `index_summary_suffix` call
`TextLayout#summary_suffix` like `nested_summary_line` already does — looked
purely mechanical, but `CrossReferencing#link_path` computes its relative
path from a single `object` accessor that, in every existing template, is
*both* "the object providing resolution context" (namespace-relative name
lookup, self-reference detection) *and* "the object whose page is being
rendered" (the path a link is relative from). Those two roles are the same
object everywhere else, but `index.md` is one page listing many different
objects' summaries: resolution context should still be each row's own
object (so a bare name in `Geometry::ThreeD::Point`'s summary resolves
preferentially within `Geometry::ThreeD`, and a self-mention stays
unlinked, same as everywhere else), while the link path must always be
relative to the doc root, since `index.md` never moves. Reusing `object`
for both would silently compute link paths relative to each row's own
(possibly deeply-nested) location instead of the root.

**The fix:** `CrossReferencing#link_path` now resolves its base directory
through a new private `#current_dir` method (`Pathname.new` of `object`'s
own file location — unchanged default behavior, so no `module`/`class`
template call site needed to change). `fulldoc/agentdocs/setup.rb` mixes in
`CrossReferencing`/`Markdownify`/`TextLayout`, overrides `current_dir` to
always return `Pathname.new(".")` (the doc root), and `index_summary_suffix`
sets `self.object = object` (`Template`'s own `Helpers::BaseHelper` accessor
— distinct from, but kept in sync with, `options.object`) before calling
`summary_suffix`, so resolution/self-reference still uses that row's own
object while the path comes out root-relative regardless of nesting depth.

### README rendering: own page via `options.readme`, no heading demotion

Settles the "README and extra files (guides)" checklist item under
"Indexing & discovery" — scoped to the README only; arbitrary `--files`
guides are tracked as a separate follow-up item, expected to mostly reuse
what's decided here. `fulldoc/agentdocs/setup.rb` never touched
`options.readme`/`options.files` before this; there was no prior
"Decisions" entry to extend.

**Separate page, not inlined into `index.md`.** YARD's own HTML template
mirrors README content *onto* the index page (replacing it, with the class
list living in a separate sidebar). `agentdocs` has no sidebar —
`index.md`'s `## Classes & modules` section is the only lookup table, kept
deliberately short and grep-able (same reasoning that capped the nav
preamble at ~15 lines). Inlining arbitrary README prose would dilute that.
This is the "structured search cost" divergence dimension from "Design
heuristic: agent reference needs mirror human reference needs" overriding
the mirror-human-docs default. Landed shape: a new `## Guides` section in
`index.md`, between the nav preamble and `## Classes & modules`, linking
out — `- [`README`](file.README.md)`, no summary suffix (extra files carry
no YARD docstring summary; same bare-link treatment already used for
summary-less classes like `Geometry::Segment`).

**Filename: `file.<name>.md`**, mirroring YARD's own HTML `file.<name>.html`
convention for extra files exactly (`file.README.md` here), rather than a
plain `README.md` at doc root — chosen over the plainer option so the same
convention generalizes cleanly once arbitrary `--files` guides land.

**Heading demotion must be skippable — reusing `markdownify` unmodified
was wrong.** `Markdownify#demote_headings` exists only because docstring
prose gets *embedded* into a page that already owns `##`/`###`
structurally (`## Member Summary`, `### #method`); demoting a
prose-embedded heading avoids collision. A README rendered onto its own
standalone page has no such competing structure — demoting its `#
Title`/`## Usage` hierarchy to a flat `####` would have flattened a real
README's own heading structure for a collision that can't happen on that
page. `markdownify` now takes a `demote_headings:` keyword (default
`true`, unchanged for every docstring/tag-text call site); the README path
calls `markdownify(file.contents, demote_headings: false)`. Dialect
conversion and inline `{Name}` reference resolution still apply
unchanged — both `example/README.md` (`:markdown` dialect) and
`example/rdoc/README.rdoc` (`:rdoc` dialect, added specifically to prove
this) exercise a heading staying undemoted, alongside a resolved
`{Name}` reference and RDoc inline formatting (`*bold*`, `+tt+`)
converting normally.

**No `**Defined in:**` line, no synthetic title wrapper.** Every
class/module page adds both (a title line, a source pointer), but a
README page's rendered content already *is* effectively its own source
(just dialect-converted and reference-resolved) — unlike a class page,
there's no implementation detail the docs omit that `**Defined in:**`
would usefully point back to, and the file's own top-level heading already
serves as the page title.

**Resolution context: pinned to `Registry.root`.** A README isn't "about"
any one class/module, so `serialize_readme` sets `self.object =
::YARD::Registry.root` before calling `markdownify` (same
`self.object = ` pattern `index_summary_suffix` already uses) — a `{Name}`
reference resolves as it would from top-level, and is never treated as a
self-reference. `current_dir` needed no separate override: `fulldoc/
agentdocs/setup.rb` already pins it to the doc root unconditionally for
the whole template (see "`index.md` per-entry summaries" above), which is
also correct for a page that, like `index.md`, always lives at the doc
root regardless of `object`.

**Test-fixture wrinkle: CWD-based README auto-detection had to be
defeated explicitly, twice.** `test_agentdocs_template.rb`'s `generate`/
`generate_rdoc` both `chdir` to the real project root without an explicit
`--readme` flag (needed for correct relative `**Defined in:**` paths, so
not changeable). YARD's CLI auto-detects any `README*` file in the CWD
when `--readme` isn't given, with no flag to suppress it — so once
`options.readme` started being honored, both fixture runs would otherwise
have silently picked up *this repo's own real* `README.md` instead of a
fixture-controlled file. Both `generate` and `generate_rdoc` now pass
`--readme` explicitly (`example/README.md`, `example/rdoc/README.rdoc`
respectively) to short-circuit the auto-detect (`options.readme ||= ...`
only fires when unset). This is why the `:rdoc`-dialect fixture — whose
whole point is staying minimal (see "Docstring markup dialect" above) —
ended up with its own small README fixture rather than staying
README-free: there was no available way to opt out once the mechanism
existed, and it doubled as the only coverage of `demote_headings: false`
under RDoc-to-Markdown conversion rather than Markdown passthrough.

### Arbitrary `--files` guides: generalize the README path, `options.files` ordering

Settles the "Arbitrary `--files` guides" follow-up checklist item — as
anticipated when it was split off, this was mechanical: every hard call
(own page, `file.<name>.md` naming, no heading demotion) was already made
by the README decision above and just needed generalizing from one file
to an array.

**The generalization.** `fulldoc/agentdocs/setup.rb`'s `serialize_readme`
became `serialize_extra_file`, called once per entry in `options.files`
instead of once for `options.readme`; `index.erb`'s `## Guides` section
loops the same array instead of special-casing the README. No new
decision needed here: YARD's CLI already unshifts `options.readme` onto
the front of `options.files` when both are given, so the README stays the
first `## Guides` entry automatically — this is also what settled the
one open question the split-off item flagged, **list ordering**: whatever
order `options.files` comes out in (README first, then `--files` entries
in the order passed on the command line), not a newly invented policy
like alphabetizing.

**`file.title`, not a raw filename, for link text — already true for the
README, now proven to generalize.** `example/docs/point_cloud.md` carries
a `# @title Working with point clouds` comment attribute (YARD's own
extra-file convention, parsed and stripped by `ExtraFileObject` before
`#contents` — needed no template code), so its `## Guides` entry reads
`` [`Working with point clouds`](file.point_cloud.md) `` rather than the
terser `point_cloud` its filename would otherwise default to (same
`.title` accessor the README entry already used, which happened to
default to "README" — its filename minus extension — since it declares no
`@title`).

**Directory dropped from the output filename, deliberately unaddressed
collision risk.** `example/docs/point_cloud.md` (a subdirectory, unlike
the root-level README) still renders to `file.point_cloud.md` at the doc
root — `ExtraFileObject#name` is `File.basename` minus extension, so two
guides in different directories sharing a basename would collide (last
one serialized wins, silently). Judged acceptable to leave unaddressed
for the same reason the original README item didn't invent a
collision-avoidance scheme: no existing mechanism in this format
addresses analogous collisions elsewhere, and inventing one
speculatively isn't warranted absent real evidence (e.g. from the
dogfood milestone) that it happens in practice.

### `@api` with non-private values: drop, matching YARD's own template and today's accidental behavior

Settles the "`@api` with non-private values" checklist item. Traced rather
than assumed: grepped the bundled `yard` gem's own default HTML template and
confirmed `@api private` is the *only* value it ever renders visibly
(`header.erb`/`item_summary.erb`'s "Private" badge, `docstring/setup.rb`'s
warning paragraph) — every other value (`public`, `internal`, anything else)
exists purely for CLI-level filtering (`--api`/`--hide-api`/`--query`) and
never reaches the rendered page. Cross-checked against real-world usage
(grepped installed gems): `@api private` (1091 occurrences) and `@api public`
(511) dominate; other values are vanishingly rare (`internal` × 1,
`semipublic` × 1). `@api public` on an already Ruby-public method is a
no-op for an agent's purposes — it doesn't convey anything `private`-vs-not
doesn't already say.

**Decision: drop, matching precedent.** `VisibilityInfo#private_api?` already
only special-cases `text == "private"`, so this needed zero template
changes — the checklist gap was that this was accidental (an untested
side effect), not a deliberate, proven choice. Confirmed via direct probing
(not just source-reading) that `@api` is transitive exactly like `@since`
(propagates from a class-level tag to every method that doesn't redeclare
it, including `class << self`-defined ones), and that a method's own
`@private` tag still flags it correctly even when it inherits an unrelated
`@api public` from its class — the two checks are independent `||` branches.

Exercised via `Stopwatch`, which now carries a class-level `@api public` tag
(proving the transitive, non-private case renders nothing, including on
`.verbose`/`.clock_resolution`, its `class << self`-defined members that
don't redeclare it) and `Stopwatch#add`, tagged `@api internal` (proving it's
not literally checking for the string `"public"` — any non-`"private"` value
drops the same way). `example/doc/Stopwatch.md` needed no content changes at
all, only `**Defined in:**` line-number bumps from the two added comment
lines — the whole point of the fixture.

### Class-level `@private`/`@api private`: flag consistently at every listing surface, don't filter

Settles the "Class-level `@private` (or `@api private`) on a class/module"
checklist item — the last pre-dogfood gap. Tag-based privacy was already
settled and exercised on methods only (see "Visibility policy" above); this
item verified the same policy actually reaches every place a class/module
can show up, not just its own page.

**Gets a file: confirmed, zero code change.** `fulldoc/agentdocs/setup.rb`'s
object enumeration doesn't filter on tags at all — only Ruby-scope
visibility does, and a class's visibility is always `:public` (Ruby has no
native "private class" concept). Consistent with the already-decided
"tag-based privacy is shown, not omitted" policy.

**Own page: confirmed, zero code change.** `page.erb` already calls
`annotation_lines(object)` generically for the class/module itself — the
exact mechanism `method_entry.erb` uses per-method — and `annotation_lines`
already includes the private-API check. The gap the checklist flagged was
untested, not actually missing.

**The two real gaps, both fixed the same way.** Neither a parent's "Nested
Classes & Modules" listing (`nested_summary_line`) nor `index.md`'s row
(`fulldoc/agentdocs/index.erb`) called the existing
`private_api_annotation_short` helper, unlike `method_summary_line`/
`attribute_summary_line`, which already do. **Decision: flag, don't
filter** — both now render the same `` (private API) `` parenthetical
suffix those two already use, right after the name/link and before the
summary. This didn't need to escalate to (design) as the checklist item
flagged as a possibility: the project already has a settled, general policy
(tag-based privacy is shown-and-flagged everywhere, never silently omitted
or filtered), and these were simply two listing surfaces that policy hadn't
been extended to yet — applying it is consistency, not a new choice. (For
what it's worth, YARD's own default HTML template isn't internally
consistent here either — its method-summary rows flag `@api private`, but
its "Defined Under Namespace" nested-class listing never flags anything at
all — so there's no clean upstream precedent to mirror either way; this
project's own convention wins.) Implementation: `nested_summary_line`
(`module/agentdocs/setup.rb`) now computes `private_api_annotation_short`
the same way `attribute_summary_line` already did; `fulldoc/agentdocs/
setup.rb` now mixes in `VisibilityInfo` (it didn't before) so `index.erb`
can call the same helper per row.

**A non-obvious wrinkle the fixture had to account for:** unlike `@since`/
`@api`, `@private` is *not* one of YARD's transitive tags (confirmed via
`Tags::Library.transitive_tags` and a direct parse probe) — a class-level
`@private` tag does not cascade to that class's own methods. `Geometry::Cache`
(the new fixture) has one ordinary method (`#fetch`) with no tag of its own,
specifically to prove it doesn't get flagged just because its containing
class is.

**An unrelated, genuine gap surfaced along the way, not fixed here:**
drafting `Cache`'s docstring to cross-reference `{Stopwatch#raw_elapsed_s}`
silently rendered as plain unresolved text — traced to a real YARD
limitation, not a bug in this project's cross-referencing code.
`RegistryResolver#lookup_by_path` caps *lexical* (non-inheritance) method
lookups at exactly one namespace hop up from the referencing object
(`lib/yard/registry_resolver.rb`'s `lexical_lookup > 1 && resolved.is_a?
(CodeObjects::MethodObject)` check) — a *class*-only reference the same
distance away resolves fine, since that cap only applies to
`MethodObject`s. `Geometry::Cache` is two hops from the top-level
`Stopwatch`, so the reference silently failed to resolve even though
`Registry.resolve` finds it perfectly well from one hop closer. Worked
around in the fixture by using a plain, unlinked `` `Stopwatch#raw_elapsed_s` ``
code span instead of a `{...}` inline reference — the sentence didn't
depend on a live link. Logged as a new checklist item under
"Cross-referencing scenarios" rather than fixed now, per this project's
usual practice of not bundling incidental fixes into an unrelated task.

### Dogfood milestone: first run (YARD 0.9.44 self-run, 2026-07-20)

The dogfood milestone described under "Prioritization and roadmap" — run
the template against a real, mid-size gem and diff-read the output — is
underway. Full working notes, the exact generation setup, and the raw
measurements live in `devdocs/Dogfood.md` (not shipped in the gem, kept
separate from this file so exploratory multi-gem material doesn't balloon
DESIGN.md); this entry records only the durable outcome of the first run,
matching how "Agent-usefulness evaluation (July 2026)" above logs its
findings. Further gems queued in `devdocs/Dogfood.md` may add more runs
here later.

**Target:** YARD itself (`yard-0.9.44`, already Bundler-vendored — named as
"a fitting candidate" in the roadmap section). Generated with
`--markup rdoc` (YARD's own docstrings use the `:rdoc` dialect, confirmed
by inspection — this was also the first real-scale exercise of that path,
previously only covered by the one-file `example/rdoc` fixture), excluding
`lib/yard/server/templates/` and `lib/yard/rubygems/` to mirror YARD's own
`.yardopts` `--exclude` entries (template-DSL source and a vendored
rubygems shim, neither part of the API surface a normal consumer would
generate docs for). Result: 287 output files (286 classes/modules + the
README guide) from 1,024,370 bytes of source across 200 files.

**Findings, escalated to new checklist items** (both detailed in their own
checklist entries — "Alias targeting a method outside the parsed corpus"
under "Methods — shapes & signatures", and "Attribute `**Type:**` fallback
for a plain… `attr_*`" under "Attributes & constants" — and as corrections
appended to "Aliased method: minimal pointer entry" and "`attr_accessor`/
`attr_writer` with doc comments" respectively):

1. **Crash:** an `alias`/`alias_method` targeting a method outside the
   parsed corpus (external gem, stdlib, or otherwise unresolvable) makes
   `alias_original` return `nil`, which nothing downstream guards against —
   `member_heading(nil)` raises and aborts the entire run. Hit immediately,
   from two independent real cases, not a contrived one.
2. **Pervasive gap:** a plain, comment-less `attr_reader`/`attr_writer`/
   `attr_accessor`'s `**Type:**` line renders blank rather than
   `` `Object` ``, because the `` `Object` `` fallback is actually
   synthesized by YARD's `Struct.new`/`Data.define` handlers specifically,
   not a general YARD behavior as an earlier decision ("`attr_accessor`/
   `attr_writer` with doc comments") had concluded. 245 occurrences across
   89 of 286 classes/modules (~31%).

**What works, no changes recommended** — confirms several existing
decisions/fixes hold up on real, independently-authored source, not just
the hand-crafted fixture that motivated them:

- **Token economy claim confirmed.** The July 2026 agent-usefulness
  evaluation flagged the toy fixture as ~37% *larger* than its source
  (38.9KB vs. 28.5KB) and made "cheaper than reading source" an explicit
  claim for this milestone to verify. On real code it flips as
  hypothesized: 771,369 bytes of docs vs. 1,024,370 bytes of source — docs
  are **~24.7% smaller**. The toy fixture's result was indeed an artifact
  of rich docstrings over toy method bodies, not a problem with the format.
- Cross-reference resolution at real scale/nesting depth works (`index.md`
  summaries correctly link deeply-nested real paths), and
  `indent_continuation` correctly keeps a hard-wrapped, multi-line
  docstring summary from breaking `index.md`'s Markdown list structure —
  both previously only exercised by short, single-line fixture text.
- The three most recent pre-dogfood fixes — assignment-method headings
  (`#[]=`/`#all=`), class-level `@private`/`@api private` flags, and
  `class << self` attributes — all render correctly on real source.
- YARD's own custom tags (`@yard.tag`/`@yard.signature`/`@yard.directive`,
  from `.yardopts` entries this run didn't load) are dropped with an
  `Unknown tag` warning and don't leak into rendered output — consistent
  with, and no new pressure on, the unchanged "Custom user-defined tags"
  `(stretch)` checklist item.
- No empty/broken output files. The one near-empty page produced
  (`YARD::Parser::C::CommentParser`, header + `Defined in:` only) is a
  module whose only methods are Ruby-`protected` — correctly filtered
  before any template code sees them, correctly rendering no `## Member
  Summary` at all, matching the existing "empty section omitted entirely"
  decision.

**Measurement: per-entry `Defined in:` overhead re-checked, went the
opposite direction from the stated expectation.** "Per-entry `Defined in:`
retained at all levels" gated its keep-as-is disposition partly on
re-measuring this on a real gem, speculating the fraction "should shrink…
(real prose and method bodies dilute it)". It grew instead: 8.6% on the toy
fixture (3,543B / 41,422B) vs. **~11.0%** here (84,454B / 771,369B). The
disposition doesn't automatically change on this alone — it was gated on
overhead staying high *and* the pointers going unused, and no measurement
of actual pointer usage was possible (that needs a live agent doing a real
lookup task, out of scope for a diff-read) — but the "should shrink"
expectation itself was wrong and shouldn't be relied on if this question
comes up again.

**Not yet revisited:** the two items the roadmap explicitly gates on this
milestone — the "no custom handler classes" integration principle, and the
"Accompanying agent skill" checklist item — since both benefit from seeing
more than one gem's worth of evidence first. Left for a later run or a
cross-run correlation pass in `devdocs/Dogfood.md`.

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
the fixtures) rather than absolute. Source files are discovered via
`Dir.glob("example/lib/**/*.rb")` (sorted for free on our Ruby >= 3.4
floor), so a new `example/lib` file needs no test-file edit to be
picked up. It asserts each generated file is exactly
equal to its `example/doc` counterpart — no normalization. A manual
end-to-end sanity check (`yard doc -f agentdocs -e ./lib/yard-agentdocs.rb
...` from the command line) is worth re-running after any template change,
since it's the only check that exercises the real CLI entry point rather than
`YARD::CLI::Yardoc.new.run` directly.
