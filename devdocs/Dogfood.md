# Dogfood testing

Working document for the dogfood milestone described in DESIGN.md's
"Prioritization and roadmap" (search "Dogfood milestone"): running the
`agentdocs` template against real, mid-size gems and diff-reading the
output, rather than just the hand-written `example/lib`/`example/doc`
fixture. Expected to cover several gems over time, each potentially
producing a fair amount of read-through notes and measurements — kept here
rather than in DESIGN.md so that document doesn't balloon with exploratory
material.

**This document is analysis and tracking only.** Nothing here is a decision
on its own. Findings get correlated and written up per run below; once a
run (or a cross-run pattern) produces something durable — a new/updated
checklist item, a resolved open question, a logged Decision — that gets
written into DESIGN.md, self-contained (no dependence on this doc), through
the normal human-gated workflow. This doc is transient in the sense of
[[feedback_transient_tracking_docs]]: keep the status below current, and if
it's ever retired, migrate every pending item to a durable DESIGN.md home
first.

## Status

| Gem | Status | Notes |
|---|---|---|
| YARD (self-run) | Done — findings promoted to DESIGN.md | 2 findings (1 crash) |

## Procedure (applies to every run)

Settled 2026-07-20, alongside the YARD run below. Repeat for each gem:

1. **Generate.** Reuse the exact CLI invocation
   `test/test_agentdocs_template.rb`'s `generate` helper already uses
   (`YARD::CLI::Yardoc.new.run(..., "-t", "default", "-f", "agentdocs",
   ...)`), pointed at the target gem's own source files, with `--markup`
   set to whatever dialect that gem's docstrings actually use (check before
   assuming Markdown). Output goes to a scratch directory, not committed —
   a disposable one-off script per run, matching the convention already
   used for the pre-dogfood probes (2026-07-20 DESIGN.md review), not a
   permanently maintained toys task.
2. **Diff-read.** No fixture to byte-diff against, so this is a structured
   read, not `assert_matches_fixture`: skim `index.md` and the navigation
   preamble at real scale; spot-check constructs already known to be
   common/tricky in the target source; then open a handful of the
   gnarliest/most metaprogrammed files and read them as if answering a real
   API question, watching for silent drops or awkward rendering.
3. **Measure.** Three measurements DESIGN.md's roadmap commits to
   confirming on real usage:
   - Token economy: total generated doc corpus size vs. total source size
     (the "cheaper than reading source" claim — currently 37% *larger* on
     the toy `example/` fixture; expected to flip once real method bodies
     dominate over docstrings).
   - Per-entry `**Defined in:**` overhead: what fraction of output bytes
     those lines contribute (8.6% on the toy fixture — see "Per-entry
     `Defined in:` retained at all levels" in DESIGN.md).
   - Qualitative read on whether those `Defined in:` pointers look
     load-bearing in practice (no live agent to instrument, so this stays a
     judgment call from the diff-read, not a hard number).
4. **Harvest, don't fix ad hoc.** Anything found becomes a new/updated
   DESIGN.md checklist item, each still going through the full human-gated
   TDD loop (hand-authored `example/` fixture → review → implementation)
   afterward. Nothing gets fixed directly from a dogfood finding.
5. **Log.** Write up the run below (this doc), then once findings are
   correlated, promote the durable parts into DESIGN.md: a dated evaluation
   subsection under "Decisions" (same shape as the July 2026
   agent-usefulness evaluation — what works / measurements /
   recommendations→checklist items / considered-and-rejected), plus the
   harvested checklist items themselves.
6. Also revisit, with real evidence in hand, the two items DESIGN.md
   already gates on this milestone: the "no custom handler classes"
   integration principle (did stock YARD handlers drop more data than just
   the known `prepend` case?), and the "Accompanying agent skill" checklist
   item (now that a real per-dependency invocation has been exercised).

## Runs

### 1. YARD (self-run)

**Status:** run complete (2026-07-20); findings promoted into DESIGN.md
(2026-07-20) — see "Dogfood milestone: first run" under "Decisions", plus
the two new checklist items ("Alias targeting a method outside the parsed
corpus" under "Methods — shapes & signatures"; "Attribute `**Type:**`
fallback for a plain… `attr_*`" under "Attributes & constants") and the
correction notes appended to "Aliased method: minimal pointer entry" and
"`attr_accessor`/`attr_writer` with doc comments". Kept here in full for
the raw measurement/setup detail DESIGN.md's summary doesn't repeat.

**Why this gem:** named as "a fitting candidate" in DESIGN.md's roadmap
section. Already vendored via Bundler (`yard-0.9.44`, 207 files, ~30K
lines / ~1MB source — a good mid-size fit), so no extra fetch/pin is
needed and the version is pinned by `Gemfile.lock`. Self-referential in a
useful way: the two 2026-07-20 pre-dogfood escalations (explicit
assignment methods, xref hop cap) were already found by probing YARD's own
source directly, so this continues that precedent at full scale rather
than switching targets. It also uses the `:rdoc` markup dialect for its
own docstrings (confirmed by grep — no `@markup` overrides, RDoc-style
markup throughout), which today is only exercised by a one-file
`example/rdoc/lib/greeter.rb` fixture — so this run doubles as the first
real-scale stress test of the `:rdoc` path, not just the primary Markdown
path.

**Setup:** generated with `--markup rdoc` against the Bundler-resolved
`yard-0.9.44` gem's `lib/**/*.rb`, run from within the gem's own directory
(so `**Defined in:**` paths came out relative to it, e.g.
`lib/yard/docstring.rb`). Excluded `lib/yard/server/templates/` and
`lib/yard/rubygems/`, mirroring the two `--exclude` entries in YARD's own
`.yardopts` — the former holds `setup.rb` files written in YARD's own
template DSL (`include T('default/layout/html')`), not ordinary library
Ruby, so parsing them as plain source produced a spurious "Undocumentable
mixin" warning; the latter is a vendored rubygems backport shim. Neither is
part of the API surface a normal consumer would generate docs for, and
excluding them made the size/overhead measurements below more
representative. Result: 287 output files (286 classes/modules + the README
guide) from 1,024,370 bytes of source across 200 files.

**Findings:**

1. **Crash: `alias_original` returns `nil` for an alias whose target is
   outside the parsed corpus, and nothing downstream guards against it.**
   `member_heading(nil)` — called from both `method_summary_line`
   (`## Member Summary`) and `method_entry.erb`'s `**Alias for:**` line —
   raises `NoMethodError: undefined method 'constructor?' for nil`,
   aborting the entire `yard doc` run. This isn't a hypothetical: it fired
   on the very first full-corpus run, from two independent real cases —
   - `YARD::Parser::Ruby::MethodDefinitionNode#block` (`alias block last`
     at `lib/yard/parser/ruby/ast_node.rb:507`) — `last` is never a plain
     `def` in the parsed source (inherited from `AstNode`'s `Array`-like
     behavior).
   - `Rack::Request#query` (`alias query params` at
     `lib/yard/server/rack_adapter.rb:95`) — `params` is defined by the
     external `rack` gem, never parsed.
   Both are ordinary `alias`/`alias_method` statements aliasing a method
   YARD's registry has no entry for — exactly the same shape as the
   already-accepted "unresolved mixin renders as a plain, unlinked
   backtick" case (`Enumerable`, `**Includes:**`), just missing the
   equivalent guard for aliases. The probe run only completed by patching
   `alias_original`/`member_heading` in the disposable script itself (not
   the real template) to fall back to a placeholder string and log every
   occurrence — see `/private/tmp/.../dogfood_yard.rb`'s "SURVIVAL PATCH"
   comment (not committed; script is disposable per the procedure above).
   Real fix direction: `alias_original` returning `nil` needs an explicit
   fallback everywhere `member_heading`/`member_name` consumes it — most
   likely render the alias's original name as plain, unlinked text (the
   established pattern for "known name, unresolved target") instead of
   crashing.

2. **Pervasive gap: attribute `**Type:**` renders blank, not `` `Object` ``,
   for a plain `attr_reader`/`attr_writer`/`attr_accessor` with no `@return`
   tag.** 245 occurrences across 89 of the 286 rendered classes/modules
   (~31%) — e.g. `Rack::Request#version_supplied` renders `- **Type:** `
   with nothing after the colon. Root cause, confirmed by direct
   probe (not inferred): YARD's `Struct.new` handler synthesizes a real
   `@return [Object]` tag on each generated accessor (`tag(:return).types
   == ["Object"]`), but a hand-written `attr_reader`/`attr_writer`/
   `attr_accessor` gets no `@return` tag at all (`tag(:return) == nil`).
   `attribute_type` (`lib/yard/agentdocs/attribute_info.rb`) returns that
   `nil` straight through, and `type_ref(nil)` (`cross_referencing.rb`)
   returns `""`. This **contradicts** the existing DESIGN.md decision
   "Attribute type/text default to `` `Object` ``/'Returns the value of
   attribute `name`'... confirmed this is a general YARD fallback for
   *any* undocumented attribute" (under "`Struct.new`-based class"/"the
   `Struct`/`Data.define` decisions) — that claim holds for the boilerplate
   *text* half (both cases render "Returns the value of attribute X"), but
   not the *type* half: the `` `Object` `` fallback is Struct/Data-handler-
   synthesized, not a general YARD behavior, and a plain `attr_*` gets a
   visibly blank field instead. Given the prevalence (idiomatic
   `attr_accessor`-based classes are extremely common in real Ruby), this
   reads as a rendering bug to an agent, not a terse-but-valid entry.

**What works, no changes recommended** (confirms existing decisions/fixes
hold up on real, independently-authored source):

- Token economy flips as expected: the real corpus is 771,369 bytes vs.
  1,024,370 bytes of source — docs are **~24.7% *smaller*** than source,
  reversing the toy fixture's "37% larger" finding, confirming that was an
  artifact of the fixture's rich-docstrings-over-toy-bodies shape and not a
  problem with the format.
- Cross-reference resolution at real scale and real nesting depth works —
  `index.md` summary bullets correctly link deeply-nested paths (e.g.
  `` [`Registry`](YARD/Registry.md) ``), and `indent_continuation` (already
  built for this) correctly handles a docstring's hard-wrapped multi-line
  first sentence inside a single index bullet without breaking the Markdown
  list.
- The three 2026-07-17/07-20 pre-dogfood fixes (assignment-method headings
  like `#[]=`/`#all=`, class-level `@private`/`@api private` flags shown as
  `(private API)` in `index.md`/Member Summary, class-level attributes via
  `class << self`) all render correctly on real, independently-written
  source — not just the hand-crafted fixture that motivated them.
- YARD's own custom tags (`@yard.tag`, `@yard.signature`, `@yard.directive`,
  defined via its own `--tag`/`--type-name-tag` `.yardopts` entries we
  didn't load) are dropped with an `Unknown tag` warning and don't leak
  into rendered output — matches the already-accepted, unchanged "Custom
  user-defined tags" `(stretch)` checklist item.
- No empty/broken output files; the one near-empty page
  (`YARD::Parser::C::CommentParser`, header + `Defined in:` only) is a
  module whose only methods are `protected` — correctly filtered before
  any template code sees them, and correctly renders no `## Member
  Summary` at all, matching the existing "empty section omitted entirely"
  decision.

**Measurements:**

| Measurement | Toy fixture (`example/`) | YARD dogfood run |
|---|---|---|
| Doc corpus vs. source size | 38.9KB / 28.5KB = **+37%** (docs larger) | 771,369B / 1,024,370B = **‑24.7%** (docs smaller) |
| Per-entry `**Defined in:**` overhead | 3,543B / 41,422B = **8.6%** | 84,454B / 771,369B = **~11.0%** |
| Blank `**Type:**` from unresolved `alias_original` | crash (n/a — never completed) | run only finished via probe-only patch; both flagged in Findings above |

The `Defined in:` overhead measurement went the *opposite* direction from
DESIGN.md's stated expectation ("the fraction should shrink on real gems… while
individual lines grow" — see "Per-entry `Defined in:` retained at all
levels"): it grew from 8.6% to ~11.0% here. Worth recording as a correction
to that expectation when this gets promoted — though the *disposition*
(keep as-is) doesn't automatically change, since it was already gated on
overhead staying high **and** the pointers going unused, and this run can't
measure the second half (no live agent to instrument). No measurement was
taken of whether the pointers themselves get exercised — that requires a
live agent doing a real lookup task, which is out of scope for a diff-read.

**Checklist items harvested — added to DESIGN.md 2026-07-20:**

1. **(design)** Guard `alias_original`'s `nil` case wherever
   `member_heading`/`member_name` consume it — an alias targeting a method
   outside the parsed corpus currently crashes the whole run rather than
   rendering unresolved-but-present, like the existing unresolved-mixin/
   superclass pattern already does. Marked (design), not (mech): unlike an
   unresolved mixin/superclass (still a `Proxy` with a real `.name`),
   `alias_original` returning `nil` loses the original's name too, so the
   fallback display needs its own call. Added as "Alias targeting a method
   outside the parsed corpus" under "Methods — shapes & signatures". Needs
   an `example/lib` fixture exercising `alias`/`alias_method` to an
   external/undocumented method.
2. **(design)** Attribute `**Type:**` fallback when there's no `@return`
   tag and no Struct/Data-synthesized one either — currently blank; likely
   direction is defaulting to `` `Object` `` to match the Struct/Data case
   (Ruby's actual duck-typed reality) rather than leaving the field looking
   broken, but this revisits/corrects the existing "Attribute type/text
   default to `Object`" decision's scope, so needs its own review rather
   than a silent fix. Added as "Attribute `**Type:**` fallback for a
   plain… `attr_*`" under "Attributes & constants". Needs an `example/lib`
   fixture with a plain, undocumented `attr_reader`/`attr_writer`/
   `attr_accessor` (not Struct/Data-based).
