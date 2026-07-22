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
| `hermes-client` | Done (2026-07-21) — 2 checklist items promoted to DESIGN.md | 2 findings, no crash |
| `rubocop` | Done (2026-07-21) — 0 checklist items promoted to DESIGN.md (1 crash, confirmed pre-existing YARD-core bug) | Scale + macro-defined methods |
| `parser` | Done (2026-07-21) — 1 checklist item promoted to DESIGN.md | Racc-generated mega-classes |
| `toys` | Queued (2026-07-21) | Human-written docs, embedded `toys-core` copy, large `--files` guide, installed-gem generation |
| `google-cloud-secret_manager-v1` | Done (2026-07-21) — 3 checklist items promoted to DESIGN.md | 3 findings, no crash |

## Queued candidates

`rubocop`/`parser` recommended 2026-07-21 (asked in a separate future
session, not run yet); `toys` added 2026-07-21 after the `hermes-client` run
completed (see "Runs" below), replacing it in the queue. Each targets an
axis DESIGN.md's dogfood milestone flagged but the YARD run didn't cover.
Order not prescribed — pick whichever's most convenient to start; each
stands alone.

### `toys`

**Why this gem:** the user's own gem (reasons below given directly by the
user, verified against the local checkout at
`~/Documents/Development/oss/toys/toys` and the installed `toys-0.22.0`
gem before queuing):

1. Familiar territory — the user's own gem, like `hermes-client`.
2. **Documentation is human-written**, unlike `hermes-client`'s
   almost-entirely-agent-written docstrings — a useful contrast on the same
   axis (own-gem familiarity) but the opposite authorship source, which may
   surface different prose habits (verified: `hermes-client`'s docstrings
   were confirmed agent-authored during that run's write-up; `toys`'
   predate this project's agent-assisted workflow).
3. **Large `--files` entries exercising links/size/prose at scale.**
   Confirmed via `toys/.yardopts`: extra files are `README.md` (381 lines),
   `LICENSE.md` (21 lines), `CHANGELOG.md` (725 lines), and
   `docs/guide.md` — **4,748 lines**, by far the largest guide file this
   template has ever rendered (dwarfing the toy fixture's one-file
   `example/docs/point_cloud.md`), a real stress test of the "arbitrary
   `--files` guides" checklist item's inline-reference/size handling at a
   scale nothing has hit yet.
4. **Embeds another gem's source purely for documentation.** `.yardopts`
   points at `./core-docs/toys/**/*.rb` and `./core-docs/toys-core.rb` —
   a vendored copy of `toys-core`'s `lib/` (51 files, 584KB, confirmed
   present verbatim, each file headed by a `**_Defined in the toys-core
   gem_**` note) kept alongside `toys`' own `lib/toys/**/*.rb` (12 files,
   140KB) purely so `toys`' own generated docs include `toys-core`'s API
   without a cross-gem multi-run setup. Untested shape: two source trees
   for two different gems, parsed into one shared registry/output corpus,
   with `toys-core`'s own classes/modules appearing under their own
   namespace but attributed to a different gem's source paths.

**Generate from the installed gem, not the local checkout** — this is the
point of running `toys` at all, per the user: confirms the whole
`--files`/embedded-source/`.yardopts` setup survives being generated from
a real end-user install, not just the dev repo. Verified this is meaningful
to test, not redundant with the local checkout: the gemspec's `spec.files`
deliberately packages `core-docs/**/*.rb`, `docs/*.md`, and `.yardopts`
into the shipped gem (confirmed present in the installed `toys-0.22.0` at
`~/.local/share/mise/installs/ruby/4.0.5/lib/ruby/gems/4.0.0/gems/toys-0.22.0`:
`core-docs/` — 51 files, `docs/guide.md`, `.yardopts`, `lib/toys/` — 12
files — all match the local checkout's counts), specifically so an
installed `toys` gem can regenerate its own docs standalone — this run is
the first time anything here would exercise that path rather than assuming
it works. Total installed gem size ~1.0MB.

**Not yet run** — queued only, per the user's explicit instruction not to
start it in this session.

### `rubocop`

**Why this gem:** already Bundler-vendored (`rubocop-1.88.1`, 919 files /
~3.2MB — roughly 3x YARD's corpus), so no extra fetch/pin is needed and the
version is pinned by `Gemfile.lock`. Two things worth checking: whether
cops' `def_node_matcher`/`NodePattern` macros (which define methods via
metaprogramming rather than a plain `def`) are silently invisible to
YARD's static parser — a different flavor of silent gap than the
already-found unresolved-alias crash — and whether real-scale, heavy
`@example` usage (bad/good code fences in nearly every cop) renders well.
Also a more meaningful stress test of the file-count/size concern the
"File granularity" decision flagged (the deferred "escape valve") than
YARD's own run was.

### `parser`

**Why this gem:** already Bundler-vendored (`parser-3.3.11.1`), no
fetch/pin needed. Its racc-generated lexer/grammar files (`ruby34.rb`,
`lexer-F1.rb`, etc.) are 12–15K lines each — essentially single classes
with huge method counts. This is exactly the "very large class" scenario
the file-granularity "escape valve" was deferred against without ever
being exercised; a good forcing function to see whether deferring it is
still fine or whether real generated code hits it.

**Also considered:** `minitest` (already vendored, 24 files) — smaller
than the "mid-size" bar the other three clear, but interesting for a
different, so-far-untested reason: it leans on RDoc's `:nodoc:`/
`:stopdoc:`/`:startdoc:` visibility directives, which nothing has
exercised at all. Kept as a reserve pick rather than a fourth queued run.

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

### 2. `hermes-client`

**Status:** run complete (2026-07-21); the two checklist action items below
promoted to DESIGN.md 2026-07-21. The "what works"/measurement findings stay
here only, per the procedure's step 5 split (only durable, actionable items
graduate to DESIGN.md; confirmations and measurements are analysis, not
decisions).

**Why this gem:** see "Queued candidates" above — the user's own gem, real
Markdown-dialect docstrings throughout (`--markup=markdown` in its own
`.yardopts`), and structurally unlike YARD (a thin, layered API client
rather than a parser/generator), so likely to exercise different rendering
paths.

**Setup:** generated with `--markup markdown` against the 25 `.rb` files
under `~/Documents/Development/oss/hermes-client/lib/` (`lib/hermes_agent/**/*.rb`
plus `lib/hermes-client.rb`, mirroring the gem's own `.yardopts` file list),
run from within the gem's own directory (so `**Defined in:**` paths came out
relative to it), with its `README.md` as the readme and `LICENSE.md`/
`CHANGELOG.md` as extra `--files`. Disposable script:
`/private/tmp/.../scratchpad/dogfood_hermes.rb` (not committed). Result: 63
output files (58 classes/modules + 3 guide pages + `index.md`) from
144,347 bytes of source across 25 files. No crash — the run completed
cleanly on the first try, unlike the YARD run.

**Findings:**

1. **Pervasive gap, newly quantified: `Docstring#summary`'s "e.g."/"i.e."
   mid-sentence truncation is common in real code, not just a
   fixture-writing hazard.** [[project_yard_summary_abbreviation_truncation]]
   already flagged this as a YARD quirk to avoid when hand-authoring
   `example/lib` fixture prose — but this run is the first real-scale
   evidence of how often idiomatic Ruby docstrings trip it. Confirmed by
   direct probe against `YARD::Docstring#summary`
   (`yard-0.9.44/lib/yard/docstring.rb:173`): it scans for the first `.`
   followed by whitespace/end-of-string with **no abbreviation
   exclusion at all** — `"e.g."`'s period ends the "sentence" exactly like a
   real one would. **43 occurrences across 22 of the 63 rendered files
   (~35%)** — e.g. `Entities::Job#deliver`'s Member Summary bullet reads
   `` - `#deliver` — The delivery target, e.g. `` with nothing after "e.g."
   (full text: `` The delivery target, e.g. `"local"`, `"origin"`,
   `"telegram"`, or `"platform:chat_id"`. Defaults to `"local"`. ``, correctly
   shown in full further down in `#deliver`'s own `## Instance Methods`
   entry). Only `.summary`-based one-liners are affected —
   `index.md`'s per-entry bullets and every `## Member Summary` line — the
   full-entry text lower in the same file always has the complete sentence,
   so no information is truly lost, just made hard to find from the cheap
   summary view. This reads as **worse than merely terse**: a summary
   bullet trailing off at a dangling "e.g." with zero examples after it
   looks broken to an agent scanning the Member Summary, not just
   abbreviated. Given the idiom's ubiquity (`"$FIELD, e.g. \`val1\`, \`val2\`."`
   is a common one-line docstring shape for enum-like string fields — 9 of
   the 22 affected files hit it exactly once, the rest 2–4 times each, up to
   4 in `HealthDetails`/`RunEvent`/`Features`), this is a stronger case for
   template-side mitigation (e.g. a smarter
   first-sentence extractor that doesn't split on known abbreviations) than
   the original fixture-avoidance framing implied, though whether/how to fix
   it is a (design) question for its own review — YARD's own default
   template has the identical bug (confirmed: `Docstring#summary` is used
   unconditionally, dialect-independent), so this isn't an agentdocs-
   specific regression, just newly load-bearing here since this format's
   whole pitch is a cheap-summary-first read.

2. **New, confirmed bug: an attribute documented via `@!attribute` whose
   description lives entirely inside its `@return [Type] Description` tag
   (not as separate free-text prose) renders the type correctly but drops
   the description silently, in both `## Member Summary` and the full
   entry.** Found on `Transport::Result` (`lib/hermes_agent/client/transport.rb:44`),
   a `Data.define(:body, :headers)` documented via:
   ```
   # @!attribute [r] body
   #   @return [Hash, Enumerator] The parsed JSON body, or the chunk
   #       enumerator for a streaming request.
   ```
   Rendered output: `` ### #body `` / `` - **Type:** `Hash, Enumerator` `` /
   `` - **Read-only.** `` then **two blank lines where the description
   should be** — same gap on `#headers`. Root cause, confirmed by direct
   probe (not inferred): the reader method's own `docstring` is empty
   (`""`) — the description text lives only in `tag(:return).text`
   (confirmed present: `"The parsed JSON body, or the chunk\nenumerator for
   a streaming request."`). `AttributeInfo#attribute_type`
   (`lib/yard/agentdocs/attribute_info.rb`) already falls back to
   `tag(:return)&.types` when there's no separate type info — that's the
   existing, already-shipped fix for the sibling "plain `attr_*`" gap the
   YARD run found. But `attribute_docstring`/`attribute_docstring_summary`
   in the same file read `attr.source_method.docstring` directly, with
   **no equivalent fallback to `tag(:return)&.text`** — so when a
   `@!attribute` directive's entire description lives in the `@return`
   tag's text (a natural way to write one, and the only way YARD's own
   `AttributeDirective` docs suggest), the description vanishes from both
   the summary line and the full entry, while the type survives. This is a
   different case from the already-tracked "Attribute `**Type:**` fallback
   for a plain… `attr_*`" item (that one has *no* `@return` tag at all,
   here one exists with real content) — a distinct, newly-discovered gap.
   Only 2 occurrences in this gem (the one `@!attribute`-using file), but
   the shape (any attribute whose docstring is blank while its `@return`
   tag carries text) isn't hermes-client-specific.

**What works, no changes recommended** (confirms existing decisions/probes
hold up on a second, structurally different real gem):

- **Duck-type `@param [#each]` resolving as a same-scope cross-reference
  link is expected, not a bug** — closes the previously-unexercised half of
  the "`@param` including duck-type syntax" checklist item. `Stream.new`'s
  `chunks [#each]` param (genuine duck
  typing: "anything responding to `#each`") renders as
  `` [`#each`](Stream.md) `` — a real link to `Stream#each`, since `Stream`
  itself happens to define an `#each` method in scope. Verified this is
  **not** an agentdocs-specific mis-resolution: generated the same file
  through YARD's own stock `-f`/`-t default` (HTML) template side by side —
  it produces the identical ambiguous link
  (`<a href="#each-instance_method" title="HermesAgent::Client::Stream#each (method)">each</a>`).
  `type_ref`/`resolve_name` (`lib/yard/agentdocs/cross_referencing.rb`)
  make no distinction between a `#name` duck-type token and a real method
  reference — matching YARD's own behavior exactly, which is the
  established bar (no custom handler classes / don't diverge from stock
  resolution).
- **Markdown dialect passthrough at real scale, beyond `@example`/code
  fences (neither actually used in this gem, contrary to the queued
  candidate's guess):** `Conversation`'s class docstring uses a bare
  4-space-indented usage example (not an `@example` tag) followed by a
  Markdown bullet list with inline `**bold**` and `` `code` `` spans —
  both render correctly untouched (`:markdown` is passthrough, per the
  "Docstring markup dialect" decision), including the list surviving
  adjacent to plain prose paragraphs above and below it.
  `stream.rb`/`job.rb` also use plain markdown bullet lists in prose
  (`- **id-tracking mode**...`, `- \`"once"\` — a one-shot run...`) with the
  same clean result.
- **Default values that are namespaced constant references** —
  `Client.new`'s keyword defaults `Configuration::DEFAULT_BASE_URL` and
  `Configuration::DEFAULT_KEEP_ALIVE_TIMEOUT` (not bare constants like the
  existing `Stopwatch#reset(to = DEFAULT_ELAPSED)` fixture) — render
  correctly in the signature line via the same raw-source-text passthrough
  the "Optional param default rendering" decision already established; no
  new template logic needed.
- **No new stock-handler gaps.** This gem has none of the metaprogramming
  shapes (`prepend`, `refine`, `define_method`, `method_missing`,
  `class_eval`) that would exercise the "no custom handler classes"
  principle differently from the YARD run — grepped and confirmed absent.
  Not new evidence either way; just nothing to report here (`rubocop`'s
  `def_node_matcher` macros remain the next real test of that principle).
- **No empty/broken output files**, no crash, and no unresolved-alias
  crash (this gem's aliasing is all real `def` pairs, e.g. `Entity#eql?`
  delegating to `#==` — nothing hitting the YARD run's `alias_original`
  gap).

**Measurements:**

| Measurement | Toy fixture (`example/`) | YARD dogfood run | `hermes-client` dogfood run |
|---|---|---|---|
| Doc corpus vs. source size | 38.9KB / 28.5KB = **+37%** | 771,369B / 1,024,370B = **‑24.7%** | 193,909B / 144,347B = **+34.3%** |
| Per-entry `**Defined in:**` overhead | 3,543B / 41,422B = **8.6%** | 84,454B / 771,369B = **~11.0%** | 22,756B / 193,909B = **~11.7%** |
| `Docstring#summary` "e.g."/"i.e." truncation | not probed | not probed (would need a re-check) | **43 occurrences / 22 of 63 files (~35%)** |

**Correction to the emerging "docs shrink on real gems" narrative:** the
YARD run's ‑24.7% looked like it confirmed DESIGN.md's expectation that the
toy fixture's +37% was a fixture artifact that would flip on real code. This
run's **+34.3%** — nearly matching the toy fixture's ratio, on a genuinely
real, independently-authored gem — shows that was the wrong generalization.
Token economy tracks a codebase's **docs-to-code density**, not
toy-vs.-real: YARD is a parser/generator with meaty method bodies relative
to its comments; `hermes-client` (like the toy fixture) is a thin
API-client wrapper — mostly one-line field readers and thin delegating
methods — with deliberately thorough per-method prose. Whether generated
docs are cheaper than source is a property of the *target codebase's
writing style*, not something this format can promise in general. The
`**Defined in:**` overhead measurement, by contrast, replicates cleanly a
second time (~11.0% → ~11.7%, both up from the toy fixture's 8.6%),
reinforcing the YARD run's correction to DESIGN.md's stated expectation
that the fraction would shrink on real gems.

**Checklist items harvested — added to DESIGN.md 2026-07-21:**

1. **(design)** `Docstring#summary`'s abbreviation-blind truncation, now
   that real-scale evidence shows it's common (not a rare fixture hazard)
   and actively misleading (dangling "e.g." with nothing after) rather than
   merely terse. Added under "Documentation content / prose patterns". Needs
   a fixture (a class/method docstring whose first sentence contains a
   mid-sentence "e.g."/"i.e." followed by concrete examples) and a design
   review of whether/how to mitigate (custom first-sentence extraction vs.
   accepting it as an inherited YARD limitation, same as the duck-typing
   ambiguity this run confirmed is unchanged from stock YARD).
2. **(design)** `AttributeInfo#attribute_docstring`/
   `#attribute_docstring_summary` fallback to `tag(:return)&.text` when
   `source_method.docstring` is empty but a `@return` tag carries
   descriptive text — mirroring `attribute_type`'s existing
   `tag(:return)&.types` fallback. Added under "Attributes & constants",
   right after the sibling "Attribute `**Type:**` fallback" item. Needs an
   `example/lib` fixture: an attribute (via `@!attribute` or a bare
   `Struct.new`/`Data.define` accessor) whose only description lives inside
   `@return [Type] Description`, no separate free-text docstring.

### 3. `google-cloud-secret_manager-v1`

**Status:** run complete (2026-07-21); the three checklist items below
promoted to DESIGN.md 2026-07-21. Measurements/confirmations stay here only,
per the procedure's step 5 split.

**Why this gem:** requested directly by the user as a mechanically
generated gem — automatically converted to Ruby from a protobuf/gRPC
service definition (`gapic-generator-ruby`), unlike every prior run
(all hand-written). Per [[user_google_api_client_background]] the user has
direct hands-on experience with this generated-docs style. Three axes named
in advance and confirmed present before running: `@example` at scale (47
occurrences), `@overload` (3 files — a request-object calling convention
alongside a flattened-keyword-args one, per RPC method), and `@yield` (3
files — RPC methods yield the raw response/operation). A fourth, "awkward
formatting from automatic conversion," was explicitly left unverified until
the actual diff-read (see Findings below).

**Setup:** generated from the local checkout
(`~/Documents/Development/oss/google-cloud-ruby/google-cloud-secret_manager-v1`,
not Bundler-vendored in this project) with `--markup markdown
--markup-provider redcarpet` (matching its own `.yardopts`), against
**both** `lib/**/*.rb` (15 files) and `proto_docs/**/*.rb` (17 files,
protobuf message-class doc stubs), excluding the 3 `_pb.rb` gRPC-stub files
per its own `--exclude _pb\.rb$` — the first run needing two separate
source trees to match how a gem documents itself. `proto_docs/` pulls in
several files (`google/api/*`, `google/iam/v1/*`, `google/protobuf/*`,
`google/rpc/status.rb`, `google/type/expr.rb`) that are shared
infrastructure across every `google-cloud-*-v1` gem, not Secret-Manager-
specific — a corpus-composition wrinkle unique to this run so far. Extra
`--files`: `README.md`, `AUTHENTICATION.md`, `LICENSE.md`. Disposable
script: `/private/tmp/.../scratchpad/dogfood_secret_manager.rb` (not
committed). Result: 120 output files (117 classes/modules + 3 guide pages
+ `index.md`) from 470,267 bytes of source across 29 files (excluding the
`_pb.rb` files). No crash, no warnings on stderr — clean on the first try.

**Findings:**

1. **Confirmed bug, high prevalence: a 2+-`@overload` method's own
   method-level `@return` is silently dropped whenever neither overload
   declares its own.** The existing "`@overload`" decision explicitly
   flagged this combination as "not exercised, left for a real case to
   justify," assuming it was "redundant/unusual — when overloads are
   present they're treated as the complete params/return story." This gem
   is exactly that real case, and the assumption is wrong for it: every RPC
   client method (e.g. `SecretManagerService::Client#access_secret_version`)
   declares two `@overload`s — one for the request-object calling
   convention, one for flattened keyword args — each documenting only its
   own `@param`s, while `@yield`/`@yieldparam`/`@return`/`@raise` sit once,
   at the method level, shared across both conventions (the return
   value/exceptions don't depend on which calling convention was used).
   `@raise`/`@yield` already render correctly (method-level tags are
   rendered unconditionally, regardless of overload branch), but
   `method_entry.erb`'s 2+-overload branch sets
   `return_tags = overloads.size < 2 ? ... : []` — unconditionally empty
   for 2+ overloads, with no fallback to the method's own `@return` when
   neither overload declares one. Confirmed on real code: 17 of 21 methods
   in `SecretManagerService::Client.md`, 17 of 21 in
   `SecretManagerService::Rest::Client.md`, and 2 of 5 in
   `SecretManagerService::Paths.md` (`#secret_path`/`#secret_version_path`,
   each with 2 keyword-shaped overloads for a nested vs. flat resource
   path) lose `**Returns:**` entirely — 36 methods across 3 files. The only
   methods keeping `**Returns:**` are the ones with 0–1 `@overload` tags.

2. **Confirmed bug, low prevalence here but a full unhandled category:
   attribute entries never render `@note`/`@example`/`@deprecated`/
   `@abstract`/`@since`/`@version`/`@author`/`@todo` — only the plain
   docstring (or its `@return`-text fallback) and type.**
   `attribute_entry.erb` calls only `attribute_type`/`attribute_docstring`;
   unlike `method_entry.erb`, it never calls `annotation_lines`,
   `examples_block`, or `trailing_annotation_lines`. DESIGN.md's "Remaining
   free-form tags" decision already flagged `@todo`/`@version`/`@author` as
   unwired for attributes ("same pre-existing 'not exercised' gap as
   before"), but the gap is broader than that note captured: `@note`,
   `@deprecated`, and `@example` — the "before prose" caveat family "Auxiliary
   one-line tags" settled as high-priority, must-see-before-using-the-object
   content — are silently dropped for attributes too, even though that
   decision's own checklist item claimed to exercise `@deprecated`/`@since`/
   `@note` "on both a method and a non-method (class/module or constant)
   object" — attributes were never actually in that set. Confirmed real,
   concrete loss on this gem: `SecretManagerService::Client::Configuration
   #credentials` (and its `Rest::Client` twin) is documented via
   `@!attribute` with **two** separate `@note` tags (one a real security
   warning: "Passing a `String`... is deprecated. Providing an unvalidated
   credential configuration to Google APIs can compromise the security of
   your systems and data.") plus a worked `@example` — all silently
   dropped from both `Client.md`/`Rest/Client.md`, leaving only the plain
   description and bullet list. `Google::Api::CommonLanguageSettings
   #reference_docs_uri`'s `@deprecated` flag is dropped the same way. Only
   3–4 real hits in this gem (low prevalence), but the category itself
   (any `@!attribute`-documented attribute carrying one of these tags) is
   completely unhandled, and `@note`/`@deprecated` in particular are
   exactly the kind of caveat this format's own stated priority order says
   should never be silently lost. Side note for whoever fixes this: the
   existing `note_line` (`AuxiliaryTags`) already has its own known,
   separate limitation — it reads `object.tag(:note)` (singular, first tag
   only), "multiple `@note` tags on one object aren't exercised and aren't
   handled" per the original "Auxiliary one-line tags" decision — and
   `credentials`' two `@note` tags are a real instance of exactly that,
   currently masked only because attributes don't reach `note_line` at
   all. Fixing the attribute-wiring gap without also fixing the
   singular-tag read would just relocate this bug rather than closing it.

3. **New, distinct-root-cause instance of the "cheap summary is
   uninformative" problem, at high prevalence.** Real protobuf/gapic
   docstrings conventionally open with a one-word field-behavior sentence
   — `"Optional."`, `"Required."`, `"Output only."`, `"Input only."` —
   before the actual description, e.g. `Secret#annotations`: "Optional.
   Custom metadata about the secret. Annotations are distinct from...".
   `Docstring#summary`'s first-sentence extraction correctly identifies
   `"Optional."` as a complete sentence (real period, real word boundary —
   unlike the already-fixed "e.g."/"i.e." abbreviation case, no misparse is
   involved here at all), so the Member Summary bullet/`index.md` entry for
   nearly every such attribute renders as just `` — Optional. `` or
   `` — Required. `` with zero real content — arguably worse than the
   abbreviation case, which at least left a recognizable fragment. Measured:
   77 occurrences (`"Optional."` ×35, `"Required."` ×23, `"Output only."`
   ×17, `"Input only."` ×2) across 32 of the 120 rendered files. The full
   description is never actually lost (the full entry below the Member
   Summary always has it in full, same "worse than terse, not
   information-losing" framing as the hermes-client "e.g." finding) — just
   unreachable from the cheap-summary view this format's whole pitch
   depends on. Since the already-fixed abbreviation-aware
   `DocstringSummary#smart_summary` reimplementation has no seam for "skip a
   real, complete, but low-information leading sentence," this needs its
   own design treatment, not a trivial extension of that fix.

**What works, no changes recommended** (confirms existing decisions/fixes
hold up on a third, structurally different real gem — the first
mechanically-generated one):

- **No crash, clean generation on the first try** — unlike the YARD run's
  immediate `alias_original` crash.
- **`config_attr`-based metaprogrammed attributes render correctly,
  reconfirming the "no custom handler classes" principle.** `Configuration`
  classes (e.g. `SecretManagerService::Client::Configuration`) define every
  attribute via `Gapic::Config`'s `config_attr` macro — invisible to YARD's
  static parser on its own — but the gem's own source explicitly documents
  each one via a stacked `@!attribute` directive on the class docstring
  (the same mechanism already covered by the `@!attribute`-description
  fallback fix), so every `config_attr`-defined attribute renders with a
  correct type and full description with zero template changes. This is
  the second real-world "invisible macro-defined method" case (after
  `hermes-client`'s clean "no such shapes present" non-finding) to confirm
  the principle holds *because the gem author compensated with real YARD
  directives*, not because YARD's stock handlers understood the macro —
  worth remembering distinctly if `rubocop`'s `def_node_matcher` (which is
  *not* accompanied by `@!attribute`-style compensating docs, per a quick
  check) turns out differently. Grepped for `prepend`/`refine`/
  `define_method`/`method_missing`/`class_eval`/`instance_eval` — none
  present, so this run adds no further evidence beyond `config_attr`.
- **A `{Full::Path#method_name label}`-style inline reference whose label
  isn't the real Ruby identifier (`{...#access_secret_version
  SecretManagerService.AccessSecretVersion}`) resolves correctly** — the
  same "link to the containing file, not a per-member anchor" behavior
  every other cross-reference already has (`CrossReferencing#link_path`
  always resolves to the target's namespace file), not a new gap; the
  differently-shaped display label doesn't change resolution at all.
- **The `@note` tag whose continuation lines are indented at the same
  level as the tag directive itself (rather than deeper, matching where
  its text starts) gets its continuation split off into a disconnected,
  mid-sentence paragraph** — a real, slightly jarring artifact in the
  `credentials` attribute's rendered text (see Finding 2's example) caused
  by inconsistent indentation in the gem's own auto-generated comments.
  Verified **not** an agentdocs-specific regression: generated the same
  file through YARD's own stock `-f`/`-t default` (HTML) template side by
  side — it produces the identical split (the tag captures only "Warning:
  If you accept a credential configuration (JSON file or Hash) from an",
  and the orphaned remainder appears as a disconnected paragraph in the
  main docstring body). A genuine instance of the "awkward formatting from
  automatic conversion" the user predicted, but the root cause is a
  pre-existing YARD-core `Docstring`/tag-continuation parsing behavior
  reacting to messy generated-comment indentation, not something this
  project's template introduces or could fix without diverging from stock
  YARD's own tag-continuation rules.
- **Token economy and `Defined in:` overhead both land in the
  already-established ranges, no new pattern.** 370,749 output bytes vs.
  470,267 source bytes = **‑21.2%** (docs smaller) — consistent with the
  YARD run's "heavy method bodies dilute docs" theory (this gem's RPC
  methods have substantial bodies: retries, coercion, gRPC/REST calls),
  unlike `hermes-client`'s thin-wrapper +34.3%. `Defined in:` overhead:
  38,403B / 370,749B = **~10.4%**, in the same band as the prior two real
  runs (~11.0%, ~11.7%), all still above the toy fixture's 8.6%.
- **No empty/broken output files.** The smallest files are all genuine
  namespace-only container modules (`Google.md`, `Google::Cloud.md`) or a
  real one-line-docstring thin subclass (`SecretManagerService
  ::Credentials`, which really does have no other content) — none are
  accidentally-empty renders of something that should have content.

**Measurements:**

| Measurement | Toy fixture | YARD run | `hermes-client` run | `google-cloud-secret_manager-v1` run |
|---|---|---|---|---|
| Doc corpus vs. source size | **+37%** | **‑24.7%** | **+34.3%** | **‑21.2%** (370,749B / 470,267B) |
| Per-entry `**Defined in:**` overhead | **8.6%** | **~11.0%** | **~11.7%** | **~10.4%** (38,403B / 370,749B) |
| One-word/abbreviation-truncated summary | crash / not probed | not probed | 43 / 22 of 63 files (~35%), "e.g."/"i.e." | 77 / 32 of 120 files (~27%), "Optional."/"Required."/"Output only."/"Input only." |

**Not yet formally revisited: the "no custom handler classes" open
question and the "Accompanying agent skill" checklist item.** This run adds
a third data point (after YARD's `prepend` gap and `hermes-client`'s clean
non-finding) confirming the principle holds so far — real metaprogramming
this run hit (`config_attr`) was fully covered by the gem's own compensating
`@!attribute` directives, not by any gap in YARD's stock handlers. Still
leaving the actual re-evaluation for a deliberate cross-run pass once more
of the queue (`toys`, `rubocop`, `parser`) has run, per the YARD run's own
"benefit from seeing more than one gem's worth of evidence first" call —
`rubocop`'s `def_node_matcher` macros (not accompanied by compensating YARD
directives, unlike `config_attr` here) are likely to be a more decisive
test than a fourth confirmation would be.

**Checklist items harvested — added to DESIGN.md 2026-07-21:**

1. **(design)** A 2+-`@overload` method's own top-level `@return`, shared
   across every overload rather than redundant with each overload's own —
   reopens the "`@overload`" decision's "not exercised, left for a real
   case to justify" bullet. Added under "Methods — shapes & signatures".
   Needs an `example/lib` fixture: a method with 2+ `@overload` tags, each
   declaring only its own `@param`s, plus a shared method-level `@return`
   (and ideally `@yield`/`@raise` alongside it, to keep exercising that
   those already work).
2. **(design)** Attribute entries never render `@note`/`@example`/
   `@deprecated`/`@abstract`/`@since`/`@version`/`@author`/`@todo` tags.
   Added under "Attributes & constants"; also corrects "Auxiliary one-line
   tags"' checklist claim of exercising `@deprecated`/`@since`/`@note` on
   "a non-method (class/module or constant) object" — attributes were
   never actually covered. Needs an `example/lib` fixture: an
   `@!attribute`-documented attribute carrying at least one of `@note`/
   `@deprecated`/`@example`, ideally two `@note` tags on the same attribute
   to also finally exercise `note_line`'s existing "first tag only"
   limitation in the same pass.
3. **(design)** `Docstring#summary` extracting a real, complete, but
   zero-information first sentence (a one-word field-behavior annotation
   like `"Optional."`/`"Required."`) as the entire Member Summary bullet —
   a distinct root cause from the already-fixed abbreviation-blind
   truncation (no sentence-boundary misparse here at all). Added under
   "Documentation content / prose patterns". Needs an `example/lib`
   fixture: a docstring whose first sentence is a short, low-information
   annotation word followed by the real description as a second sentence,
   and a design review of whether/how to mitigate (skip-listing specific
   one-word leading sentences vs. accepting it as an inherited YARD
   limitation, same disposition as the duck-typing/`@note`-split cases this
   run confirmed are unchanged from stock YARD).

### 4. `rubocop`

**Status:** run complete (2026-07-21); no new checklist items promoted to
DESIGN.md — every finding either replicates an already-fixed/already-accepted
disposition or turned out to be a pre-existing YARD-core bug outside this
project's control. New evidence gathered for the "no custom handler classes"
open question (see below) and folded into DESIGN.md's open-question note,
per the procedure's step 6 — not resolved.

**Why this gem:** see "Queued candidates" above — already Bundler-vendored
(`rubocop-1.88.1`, no extra fetch/pin needed), the largest corpus run yet
(919 source files, ~3x YARD's), and specifically queued to test whether
cops' `def_node_matcher`/`NodePattern` macro-defined methods are silently
invisible to YARD's static parser — a different metaprogramming flavor than
any prior run's `prepend`/`config_attr` cases.

**Setup:** generated with `--markup markdown` (no `.yardopts` ships in the
installed gem — confirmed by absence, then confirmed empirically: grepped
`lib/**/*.rb` for markdown-only syntax or rdoc-only syntax and found
Markdown-dialect tells — `**bold**` in 16 files, `[text](url)` links in 2 —
and zero rdoc-only tells, e.g. no `rdoc-ref`), against the Bundler-resolved
`rubocop-1.88.1` gem's `lib/**/*.rb` (919 files), run from within the gem's
own directory (so `**Defined in:**` paths came out relative to it, e.g.
`lib/rubocop/cop/style/redundant_sort.rb`). No `--exclude` needed — unlike
YARD's own run, nothing under `lib/` is template-DSL or vendored-shim source.
Extra `--files`: `LICENSE.txt`; `README.md` as the readme. Disposable
script: `/private/tmp/.../scratchpad/dogfood_rubocop.rb` (not committed).
Result: 1,035 output files (1,032 classes/modules + 2 guide pages +
`index.md`) from 3,247,460 bytes of source across 919 files. Generation
completed successfully (not aborted) despite one handler-level crash logged
to stderr — see Finding 1.

**Findings:**

1. **Crash logged to stderr, but non-fatal and confirmed to be a
   pre-existing YARD-core bug, not agentdocs-specific.**
   `YARD::Handlers::Ruby::MixinHandler` raises
   `NoMethodError: undefined method 'mixins' for an instance of
   YARD::CodeObjects::ConstantObject` while processing
   `lib/rubocop/ext/processed_source.rb:20`'s
   `RuboCop::ProcessedSource.include RuboCop::Ext::ProcessedSource`. Root
   cause, confirmed by direct read: `lib/rubocop/ast_aliases.rb:6` defines
   `RuboCop::ProcessedSource` as a plain constant assignment
   (`ProcessedSource = AST::ProcessedSource`, aliasing a class from the
   external `rubocop-ast` gem, never parsed as part of this corpus) — YARD's
   `ConstantHandler` registers this as a `ConstantObject`, not a class
   `Proxy`, so when the later `.include` statement's `MixinHandler` looks up
   `RuboCop::ProcessedSource` and calls `.mixins` on whatever it finds, it
   gets the `ConstantObject` and crashes (`ConstantObject` has no `.mixins`
   method) instead of resolving to (or gracefully failing on) a class.
   **Confirmed non-fatal and non-agentdocs-specific:** unlike the YARD run's
   `alias_original` crash (which aborted the *entire* run because it fired
   during *template rendering*), this fires during YARD's *parse-time
   handler* phase, which YARD's own CLI already wraps in a per-statement
   rescue — generation continued and completed normally, 1,035 files
   produced. Reproduced the identical crash generating the same two files
   through YARD's own stock `-f`/`-t default` (HTML) template
   side-by-side — confirming this is a pre-existing YARD-core parser bug
   (a gap in `MixinHandler`'s constant-vs-class assumption), not something
   this project's template introduces or could fix without patching YARD
   itself, which is out of scope. **No information actually lost:**
   `RuboCop::ProcessedSource` still renders correctly as a constant entry
   (`- **Value:** \`AST::ProcessedSource\``, confirmed in `RuboCop.md`), and
   `RuboCop::Ext::ProcessedSource` still renders fully as its own file with
   its own methods — the only thing missing is the (invisible-anyway, since
   `AST::ProcessedSource` isn't in-corpus) mixin relationship itself. Only 1
   occurrence in the whole corpus.

2. **`def_node_matcher`/`def_node_search`-defined methods render correctly
   at real scale — because rubocop's own maintainers enforce compensating
   `@!method` documentation via their own custom cop, not because YARD
   understands the macro.** 534 `def_node_matcher`/`def_node_search` call
   sites found; **521 (97.6%) are immediately preceded by a `# @!method
   name(params)` YARD directive** (confirmed by a direct scan: each
   call site's preceding 3 source lines checked for `@!method`). Verified
   one end-to-end: `Style::RedundantSort`'s `def_node_matcher
   :redundant_sort?, ...` (preceded by `# @!method
   redundant_sort?(node)`) renders `### #redundant_sort?` with the correct
   `(node)` signature in both `## Member Summary` and its own entry in
   `RedundantSort.md` — no gap. This convention isn't just author diligence:
   `lib/rubocop/cop/internal_affairs/node_matcher_directive.rb` is rubocop's
   own custom lint cop (`InternalAffairs/NodeMatcherDirective`) that flags
   any `def_node_matcher`/`def_node_search` call missing a preceding
   `@!method` comment — the compensating documentation is *enforced by
   RuboCop linting itself*, not incidental. The remaining 13 (2.4%)
   "uncompensated" hits are not real gaps on inspection: several are
   `@!method`-directive example text or `RESTRICT_ON_SEND` arrays (not real
   calls), and the two genuine call sites
   (`lib/rubocop/cop/lint/useless_access_modifier.rb:283,310`) construct the
   matcher's *name* from a user-configurable string at runtime
   (`matcher_name = :"#{m}_method?"`) — a fully dynamic name with no single
   static call site any static tool (YARD or otherwise) could statically
   document, the same category as already-accepted "genuinely dynamic,
   nothing to fix" gaps.

3. **A second, structurally different metaprogramming macro,
   `ExcludeLimit#exclude_limit`, defines a real instance method
   (`define_method`) with a genuinely static, single-call-site name — but
   gets no compensating `@!method` directive, and is completely invisible
   in the output.** `lib/rubocop/cop/exclude_limit.rb:35-44`'s
   `exclude_limit(parameter_name, method_name: transform(parameter_name))`
   macro (`define_method(:"#{method_name}=") { |value| ... }`) is called at
   class-body scope with a literal string argument at each of 8 call sites
   (e.g. `lib/rubocop/cop/metrics/block_nesting.rb:40`'s `exclude_limit
   'Max'`, which defines `#max=`) — unlike Finding 2's dynamic case, the
   resulting method name *is* statically determinable from the source (a
   `@!method max=(value)` directive could be hand-written, exactly as
   `def_node_matcher` calls already are), but none of the 8 call sites has
   one. Confirmed completely absent from rendered output: `#max=` does not
   appear anywhere in `BlockNesting.md` — not in `## Member Summary`, not in
   `## Instance Methods`, not in `**Inherited & Mixed-in Members**` (checked
   the full file). Affects 11 cop classes total (5 direct call sites +
   `Metrics::MethodLength`/`ClassLength`/`ModuleLength`/`BlockLength` via the
   shared `CodeLength` mixin + `Metrics::CyclomaticComplexity`/`AbcSize` via
   the shared `MethodComplexity` mixin), 12 missing setter methods overall
   (`ParameterLists` has 2: `#max=`/`#max_optional_parameters=`) — low
   prevalence (12 of several thousand rendered methods across the corpus)
   but a complete, silent loss for each, and the first case this project's
   dogfood runs have found where the "no custom handler classes" principle's
   optimistic half — "gem authors compensate with real YARD directives" —
   doesn't hold. See "What works" below for why this isn't itemized as a new
   checklist item.

**What works, no changes recommended** (confirms existing decisions/fixes
hold up on a fourth, much-larger-scale real gem, and replicates two
already-fixed template bugs staying fixed):

- **`@example` at real, heavy scale renders cleanly.** Nearly every cop
  docstring includes one or more `@example` blocks (often several, each with
  its own `*Title*` when `EnforcedStyle`-dependent, e.g.
  `Style::ConditionalAssignment`'s two titled examples for
  `assign_to_condition`/`assign_inside_condition`) mixing bad/good
  bare-indented code — all render as clean, correctly-delimited ` ```ruby `
  fences in the expected order, titles included, at a scale (roughly one
  `@example` per class across ~1,032 classes/modules) far beyond any prior
  run.
- **The `@safety` custom tag (rubocop's own convention, not a YARD builtin)
  drops cleanly with zero leaks at real scale.** 136 of 919 files use it
  (`Unknown tag @safety` warning each time); grepped the full output corpus
  for `@safety`-block prose fragments (e.g. "This cop is unsafe...") and
  found zero genuine leaks — the one substring hit
  (`RuboCop::Cop::Security::YAMLLoad.md`) is a Ruby comment *inside* an
  `@example` code fence ("Psych 3 is unsafe by default"), not a leaked tag.
  Confirms "Custom user-defined tags" `(stretch)` holds at 10x+ the prior
  runs' scale.
  - Also observed one real, malformed-tag typo in rubocop's own source
    (`lib/rubocop/cop/team.rb:83-84`: `@deprecated.` with a stray trailing
    period, and `@return Array<offenses>` missing its `[...]` brackets) —
    both degrade gracefully (dropped/misparsed without crashing or leaking
    raw tag syntax into output), not a template issue, just evidence
    malformed real-world tags don't break anything.
- **`Docstring#summary`'s two already-fixed prose-truncation bugs
  (abbreviation-blind "e.g."/"i.e." truncation, and low-information
  one-word leading sentences) replicate as fixed, not regressed.** Grepped
  the whole corpus for dangling `e.g.`/`i.e.` at end-of-line (the
  pre-fix failure shape) — the string `e.g.` appears 53 times across the
  corpus, always mid-sentence with real content after it (e.g.
  `RuboCop::Cop::Style::MutableConstant`'s Member Summary bullet: "Checks
  whether some constant value isn't a mutable literal (e.g. array or
  hash)."), zero truncated. Also checked for the low-information
  one-word-sentence pattern (`"Optional."`/`"Required."`-shaped bullets) —
  zero hits; rubocop's own docstring style doesn't happen to use that idiom
  (a negative replication result, not a gap — the fix has no reason to
  regress on a gem that doesn't exercise the pattern).
- **No empty/broken output files** across 1,035 files; smallest files are
  all genuine minimal exception classes (e.g. `RuboCop::IncorrectCopNameError`,
  a bare `< StandardError` with no methods) or genuine private-API markers
  (`RuboCop::Server::ServerStopRequest` — superclass + `**Private API.**`
  only), matching the established "correctly minimal, not accidentally
  empty" pattern.
- **File-count/size scale confirmed manageable.** 919 source files → 1,035
  output files generated in one run with no resource issues — the largest
  corpus yet, more than 3x YARD's 287 files and 8x secret_manager's 120 —
  but no individual class approached the "100+ methods" scale the
  file-granularity "escape valve" was deferred against (largest source file
  is `lib/rubocop.rb` at 756 lines, mostly autoloads; largest real cop file
  is `lib/rubocop/cop/style/conditional_assignment.rb` at 671 lines). That
  specific stress test remains open for `parser`'s racc-generated
  12–15K-line files, still queued.

**Measurements:**

| Measurement | Toy fixture | YARD run | `hermes-client` run | `google-cloud-secret_manager-v1` run | `rubocop` run |
|---|---|---|---|---|---|
| Doc corpus vs. source size | **+37%** | **‑24.7%** | **+34.3%** | **‑21.2%** | **‑9.7%** (2,932,989B / 3,247,460B) |
| Per-entry `**Defined in:**` overhead | **8.6%** | **~11.0%** | **~11.7%** | **~10.4%** | **~13.0%** (380,177B / 2,932,989B) — highest yet |
| Abbreviation/low-info summary truncation | crash / not probed | not probed | 43/22 of 63 files, "e.g."/"i.e." (bug, since fixed) | 77/32 of 120 files, "Optional."/etc. (bug, since fixed) | **0 — both fixes confirmed holding**; "e.g." pattern present (53 hits, all intact), low-info pattern absent from this gem's style |

The `Defined in:` overhead measurement continues the trend both prior real
runs established (growing from the toy fixture's 8.6%, not shrinking as
DESIGN.md originally expected) and sets a new high at ~13.0% — consistent
with rubocop's shape (many short, focused cop classes, each paying the full
per-file `**Defined in:**` line cost relative to its own modest content).
Token economy (‑9.7%) lands between the two "thin wrapper" runs
(`hermes-client` +34.3%, toy fixture +37%) and the two "heavy method body"
runs (YARD ‑24.7%, secret_manager ‑21.2%) — cop classes have real logic
(AST traversal, autocorrection) but each is individually small, and the
docstrings (full prose + often several `@example` blocks per cop) are
unusually dense per class, landing this gem in between rather than
confirming either extreme.

**Evidence for the "no custom handler classes" open question (not
resolved, per the procedure's step 6 — logged here, folded into DESIGN.md's
existing open-question note as new evidence only):** this is the fourth
data point, and the first genuinely mixed one. `def_node_matcher`/
`def_node_search` (Finding 2) replicates the `google-cloud-secret_manager-v1`
run's `config_attr` result — real metaprogramming, fully covered by the
gem's own compensating `@!method` directives, this time shown to be
*enforced by the gem's own internal linting* rather than just author
diligence, which is a stronger form of the same "authors compensate"
pattern. But `exclude_limit` (Finding 3) is the first case across all four
runs where a statically-nameable, macro-defined method has **no**
compensating directive and is silently, completely invisible — the
"authors compensate" half of the principle's optimism doesn't hold
universally. Not itemized as a new DESIGN.md checklist item: like the
already-accepted `prepend` gap ("`prepend` content strategy" under
"Decisions"), closing it would require a custom `Handler` subclass to
understand the `ExcludeLimit#exclude_limit` macro's semantics specifically
— exactly the "no custom handler classes" principle already declines to do,
so this is new evidence *for* the open question (whether to revisit the
principle), not a template bug to fix under it. Left for the same
deliberate, dedicated cross-run revisit both the procedure's step 6 and
DESIGN.md's open-question note already call for, now with one clear
"authors don't always compensate" data point (`exclude_limit`) in hand
alongside two "they do" ones (`config_attr`, `def_node_matcher`). `prepend`
is a related but distinct third category, not really an "authors don't
compensate" case: it predates this run's framing entirely, since no
`@!method`-equivalent directive exists at all for distinguishing `prepend`
from `include` — there's no compensating annotation a `prepend`-using
author *could* write, whereas `exclude_limit`'s missing `@!method` is a
directive that could exist (exactly like `def_node_matcher`'s) and simply
wasn't written.

**Checklist items harvested:** none. Every finding above either (a) confirms
an already-implemented fix holds (Finding on `Docstring#summary`, both
patterns), (b) confirms an already-accepted permanent limitation
(`exclude_limit`, same disposition as `prepend`), or (c) is a pre-existing
YARD-core bug outside this project's fixable surface (the `MixinHandler`
crash). No `example/lib` fixture work follows from this run.

### 5. `parser`

**Status:** run complete (2026-07-21); one new checklist item promoted to
DESIGN.md (a third distinct `Docstring#summary`/`smart_summary`
punctuation bug). New evidence gathered for both open questions this
milestone gates on — "no custom handler classes" (folded into the existing
open-question note) and the file-granularity "escape valve" (this run's
central purpose; its own dedicated recommendation is below) — neither
resolved, per the procedure's step 6.

**Why this gem:** see "Queued candidates" above — already Bundler-vendored
(`parser-3.3.11.1`, no extra fetch/pin needed), specifically queued to test
how the template handles the racc-generated grammar/lexer files (reported
as 12–15K source lines each, essentially single classes with huge method
counts) — the first real exercise of the "very large class" scenario the
file-granularity escape valve was deferred against without ever being
tested on real code.

**Setup:** the installed gem ships no `.yardopts`; markup dialect inferred
empirically the same way the `rubocop` run did — grepped `lib/**/*.rb` for
Markdown-only tells (`**bold**`, `[text](url)`) vs. RDoc-only tells
(`rdoc-ref:`, `<tt>`); found 16 Markdown tells, zero RDoc tells, so
`--markup markdown`. Generated against the Bundler-resolved
`parser-3.3.11.1` gem's `lib/**/*.rb` (76 files), run from within the gem's
own directory (so `**Defined in:**` paths came out relative to it, e.g.
`lib/parser/context.rb`). No `--exclude` needed. The installed gem ships no
`README.md` (confirmed: gemspec's `spec.files` packages only
`bin/*`/`lib/**/*.rb`/`parser.gemspec`/`LICENSE.txt` — no `--readme` flag
used); extra `--files`: `LICENSE.txt`. Disposable script:
`/private/tmp/.../scratchpad/dogfood_parser.rb` (not committed). Result: 79
output files (76 classes/modules + 1 guide page + `index.md`) from
10,380,592 bytes of source across 76 files — by far the largest *source*
corpus yet (3.2x `rubocop`'s), despite the smallest file count of any real
run. Generation completed in ~85 seconds with no crash — 9 stderr warnings
total (5 unknown `@param` names, 2 unknown `@returns` tags, 1 malformed
`@see` wrapping, 1 "Undocumentable FLAGS" — see Finding 2), all graceful.

**Findings:**

1. **New, distinct-root-cause bug: `Docstring#summary`/`smart_summary`
   blindly appends a trailing `.` even when the extracted text isn't a real
   truncated sentence at all — producing a visibly malformed summary, not
   just a terse or misleading one.** Two trigger shapes, same root cause
   (confirmed by direct algorithm trace through both YARD-core
   `Docstring#summary` and this project's ported `DocstringSummary
   #smart_summary` — both unconditionally `+= "."` whenever the extracted
   text is non-empty, with no check for what character it already ends in):
   - **A docstring whose first paragraph ends in `:` before a bulleted
     list** — the paragraph-break branch of the scan treats the blank line
     before the list as a sentence boundary (matching this format's
     existing "paragraph break = sentence end" fallback), but then appends
     `.` onto text already ending in `:`, yielding `"Initializes
     attributes:."` (`Builders::Default#initialize`,
     `lib/parser/builders/default.rb:239-243`: docstring is "Initializes
     attributes:" followed by a blank line and a bulleted list) and
     "Actions are arranged in a tree and get combined so that:."
     (`TreeRewriter::Action`, `lib/parser/source/tree_rewriter/action.rb:8`,
     same shape). The list itself — the actual content — never reaches the
     summary, same "worse than terse" framing as the two already-fixed
     patterns, but here the visible artifact (`:.`) reads as broken, not
     merely abbreviated.
   - **A docstring whose entire text is a single short token with no
     terminal punctuation at all** — the scan's `text.length - 1` fallback
     (no `.` or paragraph break ever found) takes the whole string, then
     still appends `.`, yielding `` `:nodoc:.` `` for three methods
     (`Source::Buffer#freeze`/`#inspect`, `Source::TreeRewriter#inspect`)
     documented with nothing but `# :nodoc:` — RDoc's "suppress this from
     docs" directive. **Confirmed as two separate gaps layered together,**
     not one: (a) YARD never implements `:nodoc:`/`:stopdoc:`/`:startdoc:`
     under any markup dialect (grepped YARD-0.9.44's own `lib/` — no
     handler processes it as a directive anywhere, and it uses the same
     `# :nodoc:` idiom in its own source); reproduced the identical
     `:nodoc:.` text via stock `-f`/`-t default` (HTML) generation
     side-by-side, confirming this half is a pre-existing YARD-core gap,
     out of scope here — and it's the first real (if incomplete — RDoc's
     `:stopdoc:`/`:startdoc:` weren't exercised, only `:nodoc:`) data point
     on the exact axis the "Also considered: `minitest`" aside under
     "Queued candidates" flagged as untested. (b) Given that YARD hands
     this format a bare `":nodoc:"` string as the "real" docstring text
     regardless, the summary machinery's blind period-append is what turns
     it into the actively-malformed `:nodoc:.` — that half **is** this
     project's own code and is what the new checklist item targets.
   Prevalence confirmed via a direct `smart_summary` probe against the full
   registry (not grep, which would miss/over-match on Markdown escaping):
   **5 occurrences** across the 76-class corpus — low in absolute count
   (this gem's docstrings are terse and code-comment-like throughout, not
   prose-heavy like `hermes-client`/`secret_manager`), but a clean, credible
   third data point in the "cheap summary is uninformative-or-worse" family,
   with its own distinct trigger and its own credible fix direction (skip
   the appended `.` when the extracted text already ends in non-alphanumeric
   punctuation, or — matching the low-information-sentence fix's precedent —
   extend to include what follows instead of truncating at all).

2. **`attr_accessor(*FLAGS)` — an `attr_accessor` call splatting a constant
   array, rather than a literal argument list — is completely invisible in
   the output, with no compensating YARD directive anywhere.**
   `Parser::Context` (`lib/parser/context.rb:19-45`) defines 8 boolean flag
   attributes (`in_defined`, `in_kwarg`, `in_argdef`, `in_def`, `in_class`,
   `in_block`, `in_lambda`, `cant_return`) via `FLAGS = %i[...]` followed by
   `attr_accessor(*FLAGS)`. YARD's stock `AttributeHandler` can't statically
   resolve the splatted variable to concrete names (logged at generation
   time: `[warn]: in YARD::Handlers::Ruby::AttributeHandler: Undocumentable
   FLAGS`) and silently drops all 8 attributes — confirmed completely absent
   from `Context.md`: not in `## Member Summary`, not as `## Instance
   Attributes`, nowhere; only the two real `def`s (`#in_dynamic_block?`,
   `#reset`) render. 16 accessor methods lost (8 readers + 8 writers). This
   is the same shape and disposition as the `rubocop` run's
   `ExcludeLimit#exclude_limit` finding — a genuinely static, real
   metaprogrammed method set with **no** compensating `@!attribute`
   directive anywhere near the call site — folded into DESIGN.md's "no
   custom handler classes" open-question note as a second "authors don't
   compensate" data point, not a new checklist item of its own (same
   reasoning as `exclude_limit`: closing it needs either a smarter stock
   `AttributeHandler` or a custom one, both out of scope for this
   principle).

**What works, no changes recommended** (confirms existing decisions hold up
on a fifth real gem, and the first one dominated by machine-generated
rather than hand-written source):

- **Token economy hits a new extreme, confirming the "docs shrink when
  source is generated/data-heavy" pattern rather than breaking it.** Total
  corpus: 1,386,744 output bytes vs. 10,380,592 source bytes = **‑86.6%** —
  by far the largest reduction of any run (previous best: YARD's ‑24.7%).
  Consistent with this gem's shape taken to its logical extreme: racc's
  generated files are almost entirely literal state-transition-table data
  with near-zero docstrings, so the format strips nearly all of that dead
  weight down to bare method signatures.
- **A blank-line-separated leading comment still attaches as the following
  method's docstring, confirmed as correct YARD-core behavior, not a
  mis-render.** Racc emits `# reduce N omitted\n\ndef _reduce_M(...)` (one
  blank line between comment and `def`) for reduce rules with no distinct
  action; `Docstring#summary`'s already-known one-blank-line tolerance
  attaches it anyway, and it renders identically and correctly in both `##
  Member Summary` (`` - `#_reduce_1` — reduce 0 omitted. ``) and the full
  entry (confirmed same text, same file, no divergence) — a real, if minor,
  YARD-core parsing nuance worth having on record since it wasn't
  previously exercised, but not a gap.
- **A 5,333-byte, 391-line constant value (`Racc_token_to_s_table`, a flat
  string-literal array) escalates to a full ` ```ruby ` fence and renders
  intact** — the "Structured constant" decision's largest real exercise yet
  (prior largest: the toy fixture's hand-sized `NAMED_ANGLES` hash), with no
  sign of the decision's own documented "deferred edge case" (a value
  containing a literal fence-delimiter or `##`/`###`-prefixed line) — this
  gem's racc-generated literals don't happen to contain either.
- **No new evidence for "no custom handler classes" beyond Finding 2** —
  grepped for `define_method`/`method_missing`/`class_eval`/`instance_eval`/
  `prepend`/`.prepend(` outside the racc-generated files; none found. This
  run's central axis was file granularity, not metaprogramming, and beyond
  the one real `attr_accessor(*FLAGS)` case, that holds.
- **No empty/broken output files** across all 79; the smallest
  (`Parser/Builders.md` at 174 bytes, `Parser/AST.md` at 269 bytes) are
  genuine empty namespace-container modules, matching the established
  pattern.
- **Malformed real-world tags degrade gracefully, replicating the
  `rubocop` run's finding at a different scale.** 5 `@param`s naming things
  that aren't parameter names (e.g. `content`, `Endpoint(s)`,
  `crossing_deletions:,`), 2 unknown `@returns` (plural, not a real tag),
  and one `@see` wrapped in `{}` that YARD itself warns "should not be
  wrapped in {} (causes rendering issues)" — all logged as warnings and
  dropped/degraded without crashing or leaking raw tag syntax.

**Measurements:**

| Measurement | Toy fixture | YARD run | `hermes-client` run | `secret_manager` run | `rubocop` run | `parser` run |
|---|---|---|---|---|---|---|
| Doc corpus vs. source size | **+37%** | **‑24.7%** | **+34.3%** | **‑21.2%** | **‑9.7%** | **‑86.6%** (1,386,744B / 10,380,592B) |
| Per-entry `**Defined in:**` overhead | **8.6%** | **~11.0%** | **~11.7%** | **~10.4%** | **~13.0%** | **~29.2%** (404,293B / 1,386,744B) — new high by a wide margin |
| Abbreviation/low-info summary truncation | crash / not probed | not probed | 43/22 of 63 files (bug, fixed) | 77/32 of 120 files (bug, fixed) | 0 — fixes holding | 0 — fixes holding; new distinct bug found instead (Finding 1, 5 occurrences) |

The `Defined in:` overhead measurement sets a dramatic new high — nearly
3x the previous record (`rubocop`'s ~13.0%) — driven entirely by the
racc-generated mega-classes: hundreds of `_reduce_N` methods per class carry
almost no other content (most have no docstring, params, or return value at
all — just a one-line call signature), so their `**Defined in:**` line is
often the majority of the entry's bytes. This is the clearest evidence yet
that the overhead scales with *method count relative to per-method content
density*, not gem size — exactly the mechanism DESIGN.md's "Per-entry
`Defined in:` retained at all levels" decision reasoned about in the
abstract, now measured at its real extreme.

**File-granularity "escape valve" — this run's central question, with a
recommendation:** `Parser::Ruby31` (552 instance methods) renders as an
82,835-byte, 5,524-line `Ruby31.md` — the largest single output file any
dogfood run has produced, and not a one-off: 17 of the ~77 rendered classes
here have 300+ methods (the next four largest: `Ruby32` 551, `Ruby34`/
`Ruby33` 546, `Ruby30` 537). This is the first real evidence the "100+
methods" scenario DESIGN.md's escape valve was deferred against actually
occurs in a real, commonly-depended-on gem — at more than 5x the threshold,
not just past it. **Recommendation: keep the escape valve deferred, not
implement it now.** Reasoning, not a decision — see "File granularity:
one file per class/module, members as sections" under "Decisions" for the
full writeup now added there:
- Even `Ruby31.md` at 552 methods is **86.7% smaller** than its own
  622,770-byte source file (`lib/parser/ruby31.rb`) — the format's core
  size-reduction promise holds even at this extreme; reading the doc file
  is still dramatically cheaper than reading the source, which was always
  the actual bar, not an absolute size cap.
- An agent after one specific method never needs to read the whole file at
  all — the existing greppable-heading mechanism (`### #_reduce_250`)
  resolves directly regardless of file size or the Member Summary's
  alphabetical ordering, which is the precision mechanism this decision
  already built specifically to avoid needing a full-file read.
- The measurable cost is real but narrower than originally framed: only a
  "cheap overview of an entire mega-class" read is degraded (a 552-entry,
  string-sorted `_reduce_1`/`_reduce_10`/`_reduce_100`-ordered list is
  genuinely hard to browse, but nothing about sequential `_reduce_N` names
  benefits from numeric adjacency in the first place, so this reads as a
  minor cosmetic cost, not a functional one), and the `**Defined in:**`
  overhead cost (Finding above) scales with method count regardless of
  whether the file gets split.
- This shape (racc-generated grammar tables) is a narrow, code-generation-
  specific extreme, not representative of the mid-size hand-written gems
  this milestone otherwise targets — `rubocop`'s 919-file run, by direct
  contrast, had no class approaching 100 methods.

**Evidence for the "no custom handler classes" open question:** see
Finding 2 above (`attr_accessor(*FLAGS)`) — folded into DESIGN.md's
existing open-question note as a second "authors don't compensate" data
point alongside `rubocop`'s `exclude_limit`, not resolved.

**Checklist items harvested — added to DESIGN.md 2026-07-21:**

1. **(design)** `Docstring#summary`/`smart_summary`'s blind trailing-`.`
   append when the extracted text already ends in different punctuation (a
   colon before a list) or is a bare directive-like token with no sentence
   structure — a third, distinct root cause in the summary-punctuation
   family, producing a visibly malformed result rather than a plausible
   truncation. Added under "Documentation content / prose patterns". Needs
   an `example/lib` fixture: a docstring whose first paragraph ends in `:`
   immediately before a bulleted/numbered list, and a design review of the
   fix direction (skip the appended period when the text already ends in
   non-alphanumeric punctuation, vs. extending the summary to include what
   follows, matching the low-information-sentence fix's precedent).
