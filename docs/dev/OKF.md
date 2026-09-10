# OKF and yard-agentdocs

Analysis of the **Open Knowledge Format (OKF)** spec and what it means for
this project. Rewritten 2026-08-03 against OKF **v0.2**, superseding the
July 2026 writeup against v0.1.

- Spec: <https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md>
- Supporting material reviewed for the original v0.1 pass: the OKF
  `README.md` (motivation, reference producer/consumer agents), the three
  checked-in example bundles (`bundles/ga4`, `bundles/stackoverflow`,
  `bundles/crypto_bitcoin`), and the surrounding repo tooling
  (`toolbox/mdcode` metadata-as-code sync tool, the `samples/discovery`
  agent skill, the `reference_agent` producer and its `viz.html` graph-viewer
  consumer). The v0.2 spec is self-contained (§1) and this pass reads it
  as such.

**What changed since the last revision of this document.** The July pass was
a gap analysis of a *nonconformant* tree: it proposed adding frontmatter,
relocating the index preamble, and declaring `okf_version`. All three were
adopted and implemented (see the three "OKF interop" entries under
"Decisions" in `DESIGN.md`), so `example/doc` and `example/rdoc/doc` have
been conformant bundles since July. This revision therefore does the
opposite job: it establishes that conformance *survives* the v0.2 bump, and
asks what the new spec makes newly *available*.

As before, this document is analysis and recommendation only. Nothing here
is a decision; anything adopted goes through the normal design workflow
(checklist item → hand-authored `example/` changes → approval →
tests/implementation).

## What OKF is (v0.2)

OKF represents *knowledge* — metadata, context, curated insight — as a
**bundle**: a directory tree of UTF-8 markdown files. Each non-reserved
`.md` file is a **concept** whose **concept ID** is its bundle-relative path
minus `.md`. The v0.1 substrate is unchanged:

- **Frontmatter (YAML)** on every concept: `type` is REQUIRED (free-form
  string, no central registry); `title`, `description`, `resource`, `tags`
  are recommended; arbitrary extra keys are allowed and consumers must
  tolerate and preserve them.
- **Body**: free-form markdown, structural markdown preferred. No required
  sections; `# Schema`, `# Examples`, and (new in v0.2) `# Computation` are
  *conventional* headings.
- **Reserved filenames** at any level: `index.md` (§8, directory listing for
  progressive disclosure — sections of `* [Title](url) - description`
  bullets) and `log.md` (§9, newest-first, date-grouped update history).
- **Cross-links**: plain markdown links; bundle-absolute (`/tables/customers.md`)
  recommended over relative. Link semantics are untyped. Broken links are
  legal.
- **Consumption is permissive**: consumers MUST NOT reject bundles for
  unknown types/keys, missing optional fields, broken links, or missing
  indexes.

What v0.2 adds is a stance on *machine-authored* corpora (§1): when most
concepts are agent-generated, a consumer needs to know where a concept came
from, how much to trust it, whether it is still true, and whether a number
was produced the sanctioned way. Four new optional frontmatter families and
one new concept type serve that:

- **Provenance** — `sources` (§5.1): a list of materials a concept derives
  from, each entry carrying a REQUIRED `resource` plus optional `id`,
  `title`, and the credibility signals `author`, `usage_count`,
  `last_modified`; `usage_window` is written once as a sibling. Per-claim
  attribution is a markdown footnote whose label is a `sources[].id`.
- **Trust** — `generated: { by, at }` and `verified: [{ by, at }, …]`
  (§5.2), with actors written in the `<producer>/<version>` /
  `human:<id>` / `process:<id>` convention (§7). Consumers derive a **trust
  tier** from `verified` alone (§5.3): absent ⇒ unverified, non-`human:`
  actors ⇒ machine-confirmed, a `human:` actor ⇒ human-reviewed.
- **Lifecycle** — `status: draft | stable | deprecated` (§5.4, absent ⇒
  `stable`), tracking the lifecycle of the *concept document* rather than
  that of whatever it describes (see Part 2 item 1), and
  `stale_after: YYYY-MM-DD` (§5.5, an absolute date so staleness is a
  plain date comparison).
- **Attestation** — `type: Attested Computation` (§10) plus `runtime`,
  `parameters`, `computation`, `executor`, `attester`: a sanctioned way to
  compute a value, so a consumer can confirm the blessed computation ran
  rather than agent-improvised SQL.

Also new: the `references/` directory convention (§6.3) for mirroring
external material, run instructions, or code as first-class concepts.

The relationship to this project is unchanged and still unusually good. OKF
adds frontmatter and reserves index/log filenames; we add a much more
prescriptive *body* grammar (heading sigils, signature blocks, `**Params:**`
bullets) that OKF deliberately leaves unspecified. They compose.

## Part 1 — Conformance against v0.2

**The tree is already v0.2-conformant.** §11's three hard conditions are
verbatim v0.1 §9's:

1. Every non-reserved `.md` file has a parseable YAML frontmatter block.
2. Every frontmatter block has a non-empty `type`.
3. `index.md`/`log.md`, where present, follow §8/§9 (v0.1's §6/§7,
   renumbered but unchanged).

Current output satisfies all three: class/module pages carry
`type`/`title`/`description`, extra files carry `type: Guide`/`title`,
`bundle.md` carries `type: Bundle Info`/`title`/`generated`, and the root
`index.md` is a §8 concept listing in the spec's exact `* [Title](url) - desc` surface form with `okf_version` as
its only frontmatter.

Both of v0.2's **breaking** changes (§13.1) retire v0.1 features this
project deliberately never emitted:

| §13.1 breaking change | Our exposure |
|---|---|
| `timestamp` superseded by `generated: { by, at }` | None — `timestamp` was explicitly omitted, on churn grounds |
| Body `# Citations` list superseded by `sources` | None — no citations list is emitted; H1 is reserved for the page title |

The `timestamp` omission is worth calling out because it was decided for an
unrelated reason ("would churn every file on every regen for no
informational gain", under "Frontmatter on every class/module file") and
turned out to be forward-compatible by accident, not by foresight. Every
other v0.2 change is additive-optional (§13.2), so absence yields a plain,
valid concept.

### The one thing that was wrong — fixed

`okf_version: "0.1"` — in `templates/default/fulldoc/agentdocs/index.erb`
and both fixture trees' `index.md`. It was not a conformance failure (§12
makes the declaration optional entirely), but it actively misinformed: a
v0.2 consumer reading `"0.1"` would arm the §13.1 legacy fallbacks — look
for a `timestamp` when `generated` is absent, parse a `# Citations` body
list — that can never fire on our output. **Fixed 2026-09-09:** all three
sites now declare `"0.2"`, which required no other change to the tree. See
"`okf_version` bumped to `"0.2"`: a quoted string, and a standing
re-verification obligation" under "Decisions" in `DESIGN.md` — including why
the value stays a quoted string, and why dropping the key instead was
rejected.

Note the obligation this creates for the *next* revision of this document:
the tree now asserts a specific spec version, so a future OKF release makes
the declaration stale again until re-verified here.

### Not required, still not required

- **Per-directory `index.md`** (`Geometry/index.md`): optional under §8, and
  the flat root index plus deterministic FQN→path derivation already covers
  discovery. Unchanged from the v0.1 assessment; still YAGNI.
- **`log.md`**: optional. See Part 3 for the API-changelog idea it enables.
- **Body heading conventions**: `# Schema`/`# Examples`/`# Computation` are
  H1s; our body reserves H1 for the title and uses `**Examples:**` labels
  inside member entries. No conformance issue, and restructuring bodies to
  chase them would trade away the grep grammar for nothing.
- **Bundle-absolute links**: recommended by §6.1, ours are relative. Both
  legal. Low-cost, low-urgency, unchanged.

## Part 2 — What v0.2 newly offers

Ordered by cost/benefit for this project, best first — as assessed on
2026-08-03. Item 1 has since been **evaluated and rejected** (2026-09-09);
it is kept in place, rewritten, so the reasoning is not re-derived.

### 1. `status: deprecated` — evaluated and rejected

§5.4's `status` is a three-value lifecycle field, absent ⇒ `stable`. This
section previously called it "the clear win" and read a class-level YARD
`@deprecated` as mapping onto `status: deprecated` exactly. **That mapping
was wrong, and the item was rejected on 2026-09-09** — full reasoning in
"`status: deprecated` rejected: OKF `status` is document lifecycle, not
subject lifecycle" under "Decisions" in `DESIGN.md`; the essentials:

- §5.4's values only cohere as properties of the *concept document*.
  `draft` is "not yet reviewed; possibly incomplete" — §5.2–5.3's `verified`
  sense of reviewed, which a Ruby class cannot be — and `stable` is "ready
  for consumption". §5's framing makes the families answer "is it still
  current" *about the file*, and every sibling key (`sources`, `generated`,
  `verified`, `stale_after`) is document-scoped.
- The reference bundle confirms the operative meaning: `acme_retail`'s only
  `status: deprecated` concept is `metrics/gross-margin-legacy.md`, a
  retired document superseded by `metrics/gross-margin.md`, and its `log.md`
  records the move. Meanwhile `gross-margin.md` is `status: stable` while
  documenting a subject whose predecessor was retired.
- Emitting it on a page like `Geometry::Circle` would therefore tell a
  consumer the documentation it just read is superseded and a current
  version exists elsewhere in the bundle. Both false, and the failure is
  asymmetric — an agent hunts for a replacement page that does not exist —
  all to put in frontmatter a fact the body already states as
  `* **Deprecated.** …`.

The key would be correct for one case this producer does not generate: a
page kept for link stability after its class was removed from the gem.
Subject-level deprecation, if it is ever wanted in frontmatter, belongs in
`tags` (where the reference bundle also puts it) or an extension key — see
Part 3 item 2, which is where this idea now lives.

### 2. Freshness vocabulary — and where it can't go

**Resolved 2026-09-09: option *(a)*, extended.** `bundle.md` ships at the
bundle root carrying `type: Bundle Info` and `generated: { by, at }`, and it
also subsumes the former `navigating.md` — the reading conventions are its
body. `generated.at` is **build wall-clock**, RFC 3339 UTC to the second,
which is a deliberate deviation from §5.2 (see the new Part 4 note below):
"last meaningful change" cannot answer the staleness question, because
regenerating unchanged source leaves it untouched and so reads as fresh.
`stale_after` was declined outright — for a mutable-input tree the truthful
value is today, for a `gems` bundle it is never, and neither is useful. Full
reasoning, including the type/filename choices and what a consumer compares
`at` against, is under "Bundle-level `bundle.md`" in `DESIGN.md`. The rest
of this section is the analysis that led there, kept for the vocabulary
survey and the location argument.

The then-open `(design)` checklist item
"Staleness of a bundle built over mutable source" asked whether a bundle
should record "a source fingerprint, a git SHA, a max source mtime", and
constrains any such signal to "the root `index.md` alone, or in a new
reserved file." v0.2 answers the *vocabulary* half and closes off the
location the item assumed.

The vocabulary now exists and fits:

- `generated: { by, at }` (§5.2) — `by` is REQUIRED within the block and
  would be `yard-agentdocs/<version>` under the §7 actor convention; `at` is
  optional and defined as "the content's last **meaningful change**".
- `stale_after: YYYY-MM-DD` (§5.5) — an absolute date, deliberately not a
  relative TTL.
- `sources[].last_modified` (§5.1) — "when the source itself last changed",
  explicitly distinguished from `generated.at`.

The location problem: §8 says index files contain no frontmatter "with one
exception: a bundle-root `index.md` MAY carry an `okf_version` key", and §12
repeats that this is "the only place frontmatter is permitted in an
`index.md`". Read together, the exception is scoped to that one key — and
§11(3) makes reserved-file structure one of the three hard conformance
conditions. So putting `generated`/`stale_after` in the root `index.md`
trades away conformance for them, which is the wrong trade for a project
whose whole reason to care about OKF is interop. Three ways out:

- **(a) A bundle-level concept file** — e.g. `bundle.md`, with a `type` of
  its own, carrying `generated`, `stale_after`, `resource`, and `sources`
  for the tree as a whole, and linked from `index.md`'s existing `##
  Guides` section the way `navigating.md` already is (in the event, it
absorbed `navigating.md` and took a `## Bundle info` section of its own).
Fully conformant (it
  is an ordinary non-reserved concept, so frontmatter is unrestricted), one
  extra file, one extra read, zero per-page churn — and it gives the
  deferred `resource` identity bridge somewhere to land in the same move.
  This is the strongest option the staleness item did not have in July.
- **(b) Per-page `generated`** — worth *re-examining* rather than citing as
  settled, because v0.2 changed the semantics that killed `timestamp`.
  `generated.at` is "last meaningful change", not generation time; derived
  from source (a git commit date, or a max mtime over `object.files`) it
  would be stable across regenerations, so the churn objection does not
  automatically transfer. Against it: mtime is meaningless in a fresh clone,
  git dates require a git repo and a per-object blame-ish query, and "which
  files define this class" is already a multi-file answer. Real work for a
  signal option (a) delivers in one file.
- **(c) Decline, and have the skill state a conservative rule** (rebuild a
  project-local tree before trusting it). Still viable; v0.2 does not weaken
  it. Note the asymmetry that makes this defensible: a `gems` bundle
  documents an immutable installed release and is never stale, so declining
  only costs something for `agentdocs build` trees.

Note also that `generated.by` is usable *without* `at` — a stable,
non-churning `generated: { by: yard-agentdocs/<version> }` on every page
would identify the producer and its version and nothing else. Cheap and
honest, but it answers a question nobody has asked; it belongs in the
same-evidence-required bucket as everything else in Part 3.

### 3. `sources` — real fit, but gated

Every member and page already carries `**Defined in:** \`path/to/file.rb\``.
§5.1's `sources` is the standard frontmatter home for exactly that, and it
would make provenance machine-queryable instead of body prose. With an
absolute `resource` (a source URL at the release tag) it doubles as the
identity bridge that `resource` was deferred for. And `sources[].last_modified`
is the spec-blessed shape for per-concept recency — a consumer could tell
*which pages* went stale rather than only that the tree did.

Two honest caveats before this looks better than it is: `last_modified` is
day-granular, so it cannot see a file edited minutes ago (the exact failure
the staleness item is about), and the field otherwise duplicates content the
body already carries. Same YAGNI bar as the rest of Part 3 — gated on
dogfood evidence that a consumer actually wants it.

### 4. Trust tiers don't model what we produce

§5.3 derives three tiers from `verified` alone: unverified, machine-confirmed,
human-reviewed. A deterministically generated API reference has no honest
place on that ladder. We cannot claim `verified` — the generator *produced*
the content, so it has not independently confirmed it against anything —
which leaves us in **unverified**, the same tier as an unreviewed LLM guess,
despite being a mechanical transformation of authoritative source. §1's
motivation ("when most concepts are machine-generated… how much should I
trust it?") assumes extraction-by-LLM and doesn't model
derivation-by-compiler.

Emitting `verified: { by: process:… }` to escape the bottom tier would be
overclaiming, and this project should not do it. The right response is
upstream feedback (Part 4), not a frontmatter change.

### 5. Attested computations — not our domain

§10 is the largest addition in v0.2 and is entirely irrelevant here.
Runtimes, executors, receipts, and attesters exist so a consumer can confirm
a *number* was computed the sanctioned way; nothing in Ruby API reference is
a sanctioned computation over a warehouse. Recorded explicitly as
inapplicable so a future session doesn't re-derive the question from the
spec's prominence.

### 6. Incidental, no action

- **`references/` (§6.3)** is a naming convention with no conformance force.
  A Ruby namespace named `References` would produce a colliding root
  `references/` directory — cosmetic, not a violation.
- **Footnote attribution (§5.1)** introduces `[^label]` as meaningful
  syntax. We emit no footnotes; a docstring that happens to contain `[^…]`
  is the pre-existing Markdown-metacharacter concern already settled under
  "Prose/summary containing Markdown metacharacters", not a new one.
- **`tags`** stays optional and unemitted. §3.1 clarifies that OKF specifies
  no tag-aggregation file format, so nothing is expected of a producer here.

## Part 3 — Interoperability ideas

Carried forward from the v0.1 writeup, minus the items conformance already
delivered, updated where v0.2 changes the picture. These are brainstorm
items, not a roadmap.

1. **The OKF consumer ecosystem, already earned.** Conformance is done, so
   any OKF consumer — the reference repo's `viz.html` graph viewer, catalog
   UIs, consumption agents that traverse index files and frontmatter — can
   ingest a generated tree with no special-casing. The graph viewer renders
   cross-links (superclass, mixins, `@see`, param types) as a navigable
   class-relationship graph, which is exactly what our output already
   encodes as links. Nothing to do; worth remembering as the reason the
   remaining items are worth anything.

2. **Extension frontmatter keys as a machine-queryable spine.** Consumers
   preserve and tolerate arbitrary keys, so structured facts that today live
   only in body prose (`gem`, `gem_version`, `constant`, `superclass`,
   `includes`, `extends`) could be filtered on by parsing five lines of YAML.
   Discipline unchanged: every key is tokens on every read and a duplication
   of body content. Deprecation belongs on this list, not off it: v0.2 looked
   like it promoted the fact to a *standard* key, but `status` turned out to
   describe the document rather than the class (Part 2 item 1), so a
   subject-level signal would still be `tags: [deprecated]` or a producer
   extension, at the same evidence bar as the rest of this item.

3. **`resource` as the identity bridge.** Unchanged from v0.1: a URI that
   uniquely identifies the underlying asset (rubydoc.info URL, source URL at
   the release tag, rubygems.org gem URL) is what lets an aggregator merge
   knowledge about the same class arriving from different bundles. Still
   needs the dogfood milestone to settle what is actually derivable at
   generation time. v0.2 adds a natural home for a bundle-level one (Part 2
   option (a)) alongside the per-page one.

4. **Layered enrichment: generated reference as the base layer.** The
   generated tree is a regeneration-owned base layer; curated knowledge —
   playbooks, recipes, gotchas, "which of these five methods you actually
   want" — lives in *separate* concept files linking into the generated
   pages via ordinary cross-links. Regeneration never clobbers curation
   because ownership is per-file, and broken links during API drift are legal
   OKF. v0.2 strengthens this: `status: draft`, `verified`, and `sources` are
   exactly the fields a hand-curated or agent-curated overlay layer wants,
   and they now mean something standard rather than bespoke.

5. **`log.md` as an API changelog.** §9's date-grouped
   `**Update**`/`**Creation**`/`**Deprecation**` format still maps well onto
   "what changed in this gem's API between v1 and v2". The diffing machinery
   is real work; post-dogfood at the earliest.

6. **Distribution: gems shipping their own knowledge bundle.** A bundle may
   be "a subdirectory within a larger repository" (§3), so a gem could ship
   its generated tree. Partly overtaken by events — `agentdocs gems` already
   gives a computable local path for installed releases — but shipping
   in-gem would remove the generation step entirely.

7. **Cross-domain linking in mixed bundles.** A `BigQuery Table` concept's
   "how do I read this from Ruby" section linking straight to a client
   class's page in the same tree. Needs nothing from us beyond the
   conformance we have; it is the argument for *why* conformance matters.

8. **Skill + bundle pairing.** When the skill item comes off its block, "the
   tree is an OKF bundle" is part of its pitch: an OKF-aware agent needs to
   be told only *where* the bundle is, not *how* to traverse it. Shrinks the
   drift surface the preamble/skill division of labor manages.

## Part 4 — Upstream engagement

Three things worth raising with the OKF authors, all cheap and all
strengthened by having a working non-data-catalog producer to point at:

- **The index preamble accommodation** (v0.1 writeup's option *(c)*, still
  not taken). §8 admits only concept-listing sections, which is why our
  navigation guidance had to move out of `index.md` (first to
  `navigating.md`, now `bundle.md`). "An index MAY open with introductory
  prose before its sections" is a tiny, backward-compatible addition.
- **No field means "confirmed against source at T"** (Part 2 item 2). §5.2
  defines `generated.at` as the content's last *meaningful change*, which
  suits an author or an extracting agent but not a deterministic
  regenerator: for a producer that rebuilds its whole corpus from
  authoritative source, the useful assertion is that the content *matched
  that source* at a given moment, and no §5 key expresses it. A
  meaningful-change date actively misleads here — it survives a rebuild
  unchanged, so a tree whose source has since moved on still reads as
  current. We emit build wall-clock in `generated.at` as the closest honest
  fit and deviate from the stated definition to do it; a sibling key, or a
  sentence permitting generation time where the producer is deterministic,
  would close the gap.
- **A trust tier for deterministic derivation** (Part 2 item 4). The tier
  ladder collapses "mechanically transformed from authoritative source" into
  "unverified", alongside unreviewed LLM output. This is concrete,
  well-evidenced feedback from a second domain, and v0.2's §1 makes clear the
  spec authors want the machine-authored case modeled well — they just
  modeled the LLM-extraction half of it.

A third, softer note if the first two land: a conventional `type` vocabulary
for code-reference concepts, so independent producers (a Python/Sphinx
analog, a TypeScript analog) converge on compatible values rather than each
inventing their own.

## Suggested sequencing

The `okf_version` bump was mechanical and independent; it is **done**
(2026-09-09). `status: deprecated`, this document's pick for the one
substantive item that stood on its own merits, was **rejected** on
2026-09-09 (Part 2 item 1). The staleness item those freshness fields fed
is also **settled** (2026-09-09, Part 2 item 2): `bundle.md` now carries
`generated`. That leaves nothing here ready to act on — what remains is
gated on dogfood evidence (`sources`, `resource`, extension keys), exactly
as it was under v0.1. Upstream engagement (Part 4) is free and parallel,
and now has a third, concrete note to carry.
