# Code review — 2026-07-17

Comprehensive review of the implementation (`lib/`, `templates/`) and tests
(`test/`), excluding the `example/` fixtures. Requested with an eye toward a
future open-source release; focus areas were test coverage, encapsulation,
readability, and maintainability. Reviewed by Claude (Fable 5); implementation
of the work packages is being delegated to subagent sessions (see "Work
packages and status" at the bottom).

Baseline at review time: `toys test` green (94 runs, 134 assertions),
`toys rubocop` clean, working tree clean at commit `c3b92f1`.

**Overall assessment:** better shape than typical fully-agent-generated code.
The byte-for-byte fixture test is a strong regression net, comments are
unusually good at recording *why*, and the `lib/` module decomposition is
sensible. The two structural problems worth fixing before OSS release: (1) the
dependency inversion between `lib/` and the template `setup.rb` files, and
(2) unit-test coverage much thinner than the fixture test makes it look.

## Encapsulation

### Finding 1 — `lib/` modules depend on methods defined in template files

The dependency points the wrong way:

- `AuxiliaryTags` calls `indent_continuation`, defined in
  `templates/default/module/agentdocs/setup.rb:232`
  (lib/yard/agentdocs/auxiliary_tags.rb:111 and five other call sites).
- `MemberRoster` calls `constant_objects` / `attribute_objects` /
  `class_method_objects` / `instance_method_objects`, all defined in that same
  setup.rb (lib/yard/agentdocs/member_roster.rb:42-63).

The contracts are documented in comments ("Requires the including template to
expose…"), but structurally this means shipped library code cannot run — or be
unit-tested — without a template file that YARD's engine `include`s at render
time. It's also why five modules have no unit tests (Finding 5).

**Recommendation:** move `indent_continuation`, `summary_suffix`, and
`dash_join` into a lib module (pure text-layout logic), and move the four
member-listing query methods into a lib module too — the `class` template's
`class_method_objects` override (templates/default/class/agentdocs/setup.rb:5)
uses `super`, which works identically with module inclusion.

### Finding 2 — attribute hash contract is stringly-shaped, spread across four files

`{ name:, read:, write: }` is built in
templates/default/module/agentdocs/setup.rb:34, consumed by `AttributeInfo`
and `MemberRoster`, and rebuilt by hand in test/test_attribute_info.rb:27.
With a Ruby 3.4 floor, `Data.define(:name, :read, :write)` (with
`source_method` as an instance method, replacing
`attribute_source_method(attr)`) gives one construction point, a real type in
`@param` docs, and NoMethodError instead of silent `nil` on a typo'd key.

### Finding 3 — `MethodSignature` mixes explicit and implicit state inconsistently

Methods take `meth` as a parameter but silently read the host's `object` —
e.g. `receiver_name` (method_signature.rb:83) and, more subtly,
`overridden_method` (method_signature.rb:203), which walks the *rendered
object's* superclass chain rather than `meth.namespace`'s. Correct only under
the unstated invariant that `meth` belongs to `object`. Either derive from
`meth.namespace` or state the invariant once at the module level.

Related naming trap: `AuxiliaryTags` methods take a parameter named `object`,
shadowing the template's `object` method — forgetting to pass it would
silently use the wrong thing. A different parameter name removes the trap.

### Finding 4 — duplicated code-span scanner

`CrossReferencing#resolve_references` (cross_referencing.rb:117-130) and
`Markdownify#demote_headings` (markdownify.rb:68-81) contain the same
nontrivial backtick-run-skipping StringScanner loop, character for character.
Extract a shared helper (e.g. `transform_outside_code_spans(text) { |seg| … }`)
so the tricky part — the ``(?<!`)…(?!`)`` closing-run match — exists once.

## Test coverage

### Finding 5 — five lib modules have zero unit tests; `MethodSignature` half-covered

Untested modules: `AuxiliaryTags`, `ExampleTags`, `MemberRoster`,
`VisibilityInfo`, `ErbWithTrimMode`. Untested `MethodSignature` methods: the
alias trio (`alias_original`, `alias_own_prose` with its subtle
prefix-stripping, `also_known_as_line`), `overridden_method`/`overrides_line`,
the block-literal trio (`implicit_block?`, `block_param_names`,
`block_literal`), and `ordered_param_tags`. Everything untested at unit level
is covered only by the fixture test, which (a) exercises only the paths
`example/lib` happens to contain, and (b) reports failures as whole-file diffs
with poor locality. The holder pattern in test/test_method_signature.rb
extends naturally; highest logic-per-line spots first: `alias_own_prose`,
`ordered_param_tags`, `MemberRoster`'s set arithmetic.

### Finding 6 — template setup.rb helpers untestable in isolation

`indent_continuation` in particular encodes hard-won markdown-corruption rules
(its comment cites CommonMark-verified failure modes) and has no direct test.
Fixing Finding 1 fixes this for free.

### Finding 7 — test-file boilerplate quadruplicated

The anonymous holder class + `Registry.clear`/`parse_string`/`Registry.at`
dance appears in all four unit-test files with small variations. Extract a
shared builder into test/helper.rb (e.g.
`agentdocs_holder(*mixins, source:, at:, markup:)`) — also an on-ramp for
writing the Finding-5 tests.

### Finding 8 — small test weaknesses

- test/test_version.rb:7 asserts only `defined?` — assert a
  `/\A\d+\.\d+\.\d+\z/` match instead.
- test/test_markdownify.rb:112 is named "logs an error" but never asserts
  logging happened (and lets the error print into test output); capture `log`
  or drop the claim from the name.

## Readability / maintainability

### Finding 9 — `method_entry.erb` is the maintenance hot spot

159 lines. The ≥2-overloads branch and the else branch duplicate the
annotations/docstring/examples block verbatim (method_entry.erb:28-41 vs
67-80), and the shared tail after line 101 depends on `primary` — a local
defined only in the else branch — kept safe by re-testing
`overloads.size < 2` at line 127. That coupling is invisible until someone
reorders it. Extract the shared prose block into its own partial (or helper
methods returning strings), and pass `primary` explicitly.

### Finding 10 — `tag.types && tag.types.first` dug out inline eight-plus times

Across method_entry.erb and constant_entry.erb:3 (a triple dig there). A
single helper — `type_ref_for(tag)`, or letting `type_ref` accept a tag —
removes the repetition and gives one place to change when Finding 12 gets
tackled. Also inconsistent altitude: attributes get an `attribute_type`
helper while constants dig inline.

### Finding 11 — `fulldoc` `summary_suffix(object)` name-collides with module template's

fulldoc/agentdocs/setup.rb:25 vs module/agentdocs/setup.rb:184 — same name,
different parameter type and semantics, in sibling templates. Rename one.
Substantive difference hiding under the collision: the fulldoc version splices
the raw summary without `markdownify`, so an inline `{Name}` reference in a
class docstring's first sentence renders resolved on the class page but
literal in index.md.

## Correctness-adjacent — flagged only, gated by the TDD loop

These change rendered output, so they go through the human-gated coverage
workflow (checklist entries + `example/` fixtures first), **not** direct
implementation.

### Finding 12 — union-type fix not propagated everywhere

The "Multiple return types" decision (DESIGN.md) fixed Returns/Yield
Returns/signature arrow, but `@param`, `@option`, `@yieldparam`, and `@raise`
rendering still do `.types.first` (method_entry.erb:51,87,115,143;
module setup.rb:210), silently dropping `@param x [String, Symbol]` — very
common in real gems; will surface at the dogfood milestone. Most pointed:
`signature_return_type_for` (method_signature.rb:359) still does
`&.types&.first` for an overload's arrow while the non-overload path joins
all types — a direct internal inconsistency with the settled decision.

### Finding 13 — `ordered_param_tags` assumes `sort_by` is stable; Ruby's isn't

method_signature.rb:125. Tags matching real params get unique indices (fine),
but two tags naming *nonexistent* params (a typo'd `@param`) both key to
`real_names.length` and can reorder nondeterministically — which would make
the byte-for-byte fixture test flake if such a case ever lands. One-line fix:
`sort_by.with_index { |p, i| [real_names.index(…) || real_names.length, i] }`.
(Arguably a pure bug fix, but it has no fixture coverage, so it should enter
via the loop with a fixture exercising it.)

### Finding 14 — class-level attributes are invisible

`attribute_objects` reads only `attributes[:instance]` (module setup.rb:34),
and `MemberRoster` follows suit — `class << self; attr_accessor :config; end`
renders nothing. Not on the DESIGN.md checklist; add it as an item.

## Work packages and status

Findings 1–11 are behavior-preserving and delegable to subagent sessions (the
fixture test is the byte-for-byte oracle). Findings 12–14 are **not**
delegable — they're TDD-loop items (checklist + fixtures + human review
first).

- [x] **Package 1** — Findings 1 + 6 + 2: relocate text-layout helpers and
      member-listing queries into `lib/` with unit tests; `Data.define`
      attribute type. *(Implemented by a Sonnet 5 subagent 2026-07-17,
      reviewed and verified by Fable; uncommitted, awaiting human review.
      New files: `lib/yard/agentdocs/text_layout.rb`, `member_listing.rb`,
      `attribute.rb`, `test/test_text_layout.rb`. Residual nit for
      Package 2: `test/test_attribute_info.rb`'s helper is still named
      `attr_hash` though it now returns an `Attribute`.)*
- [x] **Package 2** — Findings 5 + 7 + 8: shared test holder-builder, fill
      unit-test gaps. *(Implemented by a Sonnet 5 subagent 2026-07-17,
      reviewed and verified by Fable; uncommitted, awaiting human review.
      `agentdocs_holder(*mixins, source:, at:, markup:)` added to
      test/helper.rb and adopted by all prior holder-based test files;
      new test files for AuxiliaryTags, ExampleTags, VisibilityInfo,
      MemberRoster, ErbWithTrimMode; MethodSignature gaps filled;
      `attr_hash` renamed to `attribute_for`. 173 runs / 226 assertions,
      up from 105/145. Residual nits surfaced, deferred: (a)
      lib/yard/agentdocs/erb_with_trim_mode.rb uses `::ERB` without
      `require "erb"` — works in real renders only because YARD's
      Template requires it first; add the require in a later package.
      (b) In tests where a holder and a parsed object are built by
      separate `agentdocs_holder` calls (test_auxiliary_tags.rb), the
      holder's later registry-clear empties the registry after the object
      was fetched, so tag text containing resolvable `{...}` references
      would silently not resolve — fine for current assertions, but a
      trap for future tests; consider a builder variant returning both
      holder and object from one registry.)*
- [x] **Package 3** — Findings 4 + 9 + 10 + 11: scanner dedup,
      `method_entry.erb` restructuring, `type_ref_for(tag)` helper,
      `summary_suffix` rename. *(Implemented by a Sonnet 5 subagent
      2026-07-17, reviewed and verified by Fable; uncommitted, awaiting
      human review. Scanner lives as private
      `CrossReferencing#transform_outside_code_spans`; the tag helper is
      `CrossReferencing#type_ref_first` (first-type-only behavior
      preserved, Finding 12 stays gated — the helper's docstring says so);
      shared prose block extracted to
      `templates/default/module/agentdocs/method_prose.erb` with `primary`
      hoisted above both branches; fulldoc rename to
      `index_summary_suffix`. Also closed Package 2's nit (a): `require
      "erb"` added to erb_with_trim_mode.rb. Fixture output byte-identical
      throughout.)*
- [x] **Package 4** — Finding 3: explicit-vs-implicit state cleanup in
      `MethodSignature`. *(Same subagent session as Package 3. Took option
      (a): `receiver_name`/`overridden_method`/`signature_return_type` now
      derive from `meth.namespace`; `MethodSignature` no longer reads the
      host's `object` at all and its docstring says so.
      `AuxiliaryTags`' `object` params renamed to `obj`. New residual nit,
      deferred: `VisibilityInfo` still uses the same shadowing
      `object`-parameter pattern `AuxiliaryTags` just dropped — rename for
      consistency in a later pass.)*
- [ ] Findings 12 + 13: add to DESIGN.md checklist (union types in
      `@param`/`@option`/`@yieldparam`/`@raise` and overload arrows;
      `ordered_param_tags` stability fixture).
- [ ] Finding 14: add class-level attributes to the DESIGN.md checklist.
