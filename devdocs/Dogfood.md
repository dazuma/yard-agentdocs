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
| `rubocop` | Queued (2026-07-21) | Scale + macro-defined methods |
| `parser` | Queued (2026-07-21) | Racc-generated mega-classes |
| `toys` | Queued (2026-07-21) | Human-written docs, embedded `toys-core` copy, large `--files` guide, installed-gem generation |
| `google-cloud-secret_manager-v1` | Queued (2026-07-21) | Protobuf-generated client; `@example`/`@overload`/`@yield` at scale |

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

### `google-cloud-secret_manager-v1`

**Why this gem:** requested directly by the user (2026-07-21) as a
mechanically generated gem — automatically converted to Ruby from a
protobuf/gRPC service definition (Google's `gapic-generator-ruby`), unlike
every other queued/run candidate so far, all of which are hand-written.
Per [[user_google_api_client_background]] the user has direct hands-on
experience with this generated-docs style, so is well positioned to judge
whether the rendered output looks right. Local checkout confirmed at
`~/Documents/Development/oss/google-cloud-ruby/google-cloud-secret_manager-v1`
(not currently Bundler-vendored in this project; `google-cloud-secret_manager-v1`
`1.9.0` is published on rubygems.org, so either the local checkout or a
fresh install would work). The user named three specific axes to expect:

1. **`@example` usage at scale** — confirmed: 47 occurrences across `lib/`.
2. **`@overload`** — confirmed: present in 3 files (`secret_manager_service/paths.rb`,
   `secret_manager_service/client.rb`, `secret_manager_service/rest/client.rb`)
   — the generator emits both an RPC-request-object calling convention and a
   flattened-keyword-args convenience convention as alternate signatures on
   the same method, a shape none of the run/queued gems so far use.
3. **`@yield`** — confirmed: present in 3 files (the same `client.rb`/
   `rest/client.rb` plus `rest/service_stub.rb`) — generated RPC methods
   yield the raw response/operation for streaming or custom-call use.
4. **"Potentially awkward formatting because it was automatically
   converted"** — the user's framing, not yet independently verified by
   reading actual rendered output; that's exactly what this run needs to
   check (per the general procedure below) rather than something to
   pre-judge from source alone.

**Setup notes for the eventual run:** `.yardopts` specifies
`--markup markdown --markup-provider redcarpet` and points at
`./lib/**/*.rb` **and** `./proto_docs/**/*.rb`, with `--exclude _pb\.rb$`.
`lib/` is 15 files / ~348KB; `proto_docs/` (protobuf message-class doc
stubs, no real logic — likely almost pure docstrings) is a further 17
files / ~143KB — both trees need to be included to match how this gem
documents itself, unlike every prior candidate's single source tree.
Extra `--files`: `README.md` (154 lines), `AUTHENTICATION.md` (122 lines),
`LICENSE.md` (201 lines).

**Not yet run** — queued only.

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
