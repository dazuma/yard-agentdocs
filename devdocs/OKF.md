# OKF and yard-agentdocs

Analysis of the **Open Knowledge Format (OKF)** draft spec and what it means
for this project. Written July 2026 against OKF **v0.1 (Draft)**.

- Spec: <https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md>
- Supporting material reviewed: the OKF `README.md` (motivation, reference
  producer/consumer agents), the three checked-in example bundles
  (`bundles/ga4`, `bundles/stackoverflow`, `bundles/crypto_bitcoin`), and the
  surrounding repo tooling (`toolbox/mdcode` metadata-as-code sync tool, the
  `samples/discovery` agent skill, the `reference_agent` producer and its
  `viz.html` graph-viewer consumer).

This document is analysis and brainstorm only. Nothing here is a decision;
adopting any of it goes through the normal design workflow (checklist item →
hand-authored `example/` changes → approval → tests/implementation), and the
one already-recorded decision it would touch ("No YAML front matter", under
"Output format: per-file Markdown template" in DESIGN.md) would need to be
explicitly revisited, not silently overridden.

## What OKF is

OKF represents *knowledge* — metadata, context, curated insight — as a
**bundle**: a directory tree of UTF-8 markdown files. Each non-reserved
`.md` file is a **concept** (unit of knowledge) whose **concept ID** is its
bundle-relative path minus `.md`. Structure:

- **Frontmatter (YAML)** on every concept: `type` is REQUIRED (free-form
  string, no central registry — e.g. `BigQuery Table`, `Playbook`,
  `Reference`); `title`, `description`, `resource` (canonical URI of the
  described asset), `tags`, `timestamp` are recommended; arbitrary extra
  keys are allowed and consumers must tolerate/preserve them.
- **Body**: free-form markdown, structural markdown preferred. No required
  sections; `# Schema`, `# Examples`, `# Citations` are *conventional*
  headings.
- **Reserved filenames** at any level: `index.md` (directory listing for
  progressive disclosure — sections of `* [Title](url) - description`
  bullets, no frontmatter except an optional `okf_version` block at the
  bundle root) and `log.md` (newest-first, date-grouped update history).
- **Cross-links**: plain markdown links; bundle-absolute form
  (`/tables/customers.md`) recommended over relative. Link semantics are
  untyped — the relationship kind lives in surrounding prose. Broken links
  are legal (not-yet-written knowledge).
- **Consumption is permissive by design**: consumers MUST NOT reject
  bundles for unknown types/keys, missing optional fields, broken links, or
  missing indexes.

Conformance (§9) reduces to three hard requirements:

1. Every non-reserved `.md` file has a parseable YAML frontmatter block.
2. Every frontmatter block has a non-empty `type`.
3. `index.md`/`log.md`, where present, follow the §6/§7 structures.

Notably, OKF's stated motivations overlap heavily with this project's:
human- and agent-readable without SDKs, cheap file reads over API round
trips, progressive disclosure via indexes, diffable/portable/git-native.
The two efforts arrived independently at almost the same substrate
(markdown tree + predictable paths + index files). The differences are that
OKF adds frontmatter and reserves index/log filenames, while we add a much
more prescriptive *body* grammar (heading sigils, signature blocks,
`**Params:**` bullets) that OKF deliberately leaves unspecified. They
compose: an agentdocs tree can be a valid OKF bundle without giving up any
of its body conventions.

## Part 1 — What conformance would take

Gap analysis of the current `example/doc` output against §9:

| Requirement | Current state | Gap |
|---|---|---|
| Frontmatter with `type` on every concept file | None — an explicit prior decision | **The** gap; every class/module file needs a block |
| Root `index.md` follows §6 | Nav preamble prose + a link-list section | Preamble is not §6 structure; needs relocation or a spec-side accommodation |
| Per-directory `index.md` | Absent (e.g. no `Geometry/index.md`) | None — indexes are optional; consumers may synthesize |
| `log.md` structure | Absent | None — optional |
| Cross-link form | Relative links | None for conformance (both forms legal); spec *recommends* bundle-absolute |

So conformance is two concrete changes:

### 1. Frontmatter on every class/module file

Minimal conforming block, using data the template already computes (the
title is the H1's content; the description is the same summary sentence the
index list already extracts):

```yaml
---
type: Ruby Class            # or "Ruby Module"
title: Geometry::Circle
description: A circle, defined by its radius.
---
```

Points worth settling deliberately when this is taken up:

- **`type` vocabulary.** Types are producer-defined; something
  self-explanatory like `Ruby Class` / `Ruby Module` matches the style of
  the spec's examples (`BigQuery Table`). Finer distinctions (exception
  classes, mixin modules) fit better as `tags` or extension keys than as
  type proliferation, since consumers route on `type`.
- **Token cost.** A 3-field block is roughly 5 lines / ~30 tokens per file
  read, against the "minimize tokens per lookup" goal. It is small but not
  free, and `title`/`description` duplicate information already present in
  the H1 and first prose sentence. The honest framing: those ~30 tokens buy
  compatibility with every OKF consumer; an agent reading the file directly
  loses almost nothing (frontmatter is self-explanatory and skimmable).
- **Fields to omit.** `timestamp` (generation time) would churn every file
  on every regeneration for no informational gain — omit it, or derive it
  from source-control data if it ever earns its keep. `resource` is
  discussed in Part 2; it can be added later without a breaking change.
- **The reversal.** This reverses the recorded "No YAML front matter"
  decision. That decision predates knowing about OKF; the new fact is that
  frontmatter is the price of admission to an emerging interchange format
  whose goals align with ours. Still a user call.

### 2. Root `index.md` restructuring

Three sub-issues, in decreasing severity:

- **The navigation preamble.** §6 says an index body is "one or more
  sections, each grouping concepts under a heading" of link bullets, and
  §9(3) makes reserved-file structure a hard conformance condition. Our
  "How to navigate these docs" preamble is prose, not a concept listing.
  Options:
  - *(a)* Move the preamble to its own concept file (e.g.
    `navigating.md`, `type: Reference`), linked first from `index.md`.
    Cleanly conformant, and consistent with the preamble's own design
    intent (self-describing, in-band, one file read away) — the cost is
    that it's now one hop away instead of zero, and an agent that opens
    only `index.md` doesn't see the mechanics. That cost could be softened
    with a one-bullet pointer whose description carries the single most
    load-bearing rule (the FQN→path derivation).
  - *(b)* Keep the preamble in place and accept technical nonconformance,
    leaning on the permissive-consumer mandate (a consumer that chokes on
    extra prose in an index violates the spirit of §9's consumer rules).
    Pragmatic, but "conformant except where inconvenient" is a weak claim
    to print on the tin.
  - *(c)* Raise it upstream: the spec is a v0.1 draft, and "an index MAY
    open with introductory prose before its sections" is a tiny,
    compatible accommodation the OKF authors may well accept (their own
    README-style bundles would benefit). See Part 2.
  Recommendation: pursue *(c)* while doing *(a)* — *(a)* is correct under
  the spec as written today, and *(c)* may later let the pointer bullet
  grow back into a short preamble.
- **`okf_version` declaration.** Add the spec's optional frontmatter block
  to the root `index.md` only: `okf_version: "0.1"`. Cheap, and it is the
  one explicit self-identification hook the format offers.
- **List formatting.** The spec's examples use `* [Title](url) - desc`;
  we emit `- [Title](url) — desc`. §6 specifies structure, not bullet
  glyphs, and both are identical list markup under CommonMark, so this is
  almost certainly fine as-is. But since the interop payoff comes from
  naive consumers (some of which will regex rather than parse), matching
  the spec's exact surface form (`* ` and spaced hyphen) is nearly free —
  worth doing while touching the file anyway. Caveat: our em-dash
  separator was chosen deliberately for summary readability, and some
  summaries contain hyphens; switching to ` - ` needs a quick check
  against DESIGN.md's "Prose/summary containing Markdown metacharacters"
  decision before committing to it.

### Not required, but adjacent

- **Per-directory `index.md`** (`Geometry/index.md` listing the nested
  classes): optional under OKF, and our flat root index plus deterministic
  FQN→path derivation already covers discovery. Skip unless a real
  consumer shows the need (YAGNI).
- **Body heading conventions.** OKF's conventional `# Schema` /
  `# Examples` / `# Citations` sections are H1s; our body reserves H1 for
  the title and uses `**Examples:**` labels inside member entries. No
  conformance issue (conventions are SHOULD-when-applicable), and
  restructuring bodies to chase them would trade away our grep grammar for
  nothing — don't.
- **Bundle-absolute links** (`/Geometry/Point.md` instead of relative):
  recommended by §5.1 for move-stability. Our links are generated, so
  move-stability matters less, but absolute links are also what the OKF
  viewer and similar consumers rewire most reliably. Low-cost, low-urgency;
  reasonable to fold in if/when frontmatter lands.

### Verdict

Conformance is cheap: one small frontmatter block per file, a relocated
preamble, and an `okf_version` line. Nothing about the body format — the
part of this project that actually carries its value — needs to change.
Given the low cost, if conformance is adopted it should be unconditional
(the default and only mode), not an opt-in flag; a flag would mean two
output formats to test and document for ~30 tokens of savings.

## Part 2 — Interoperability ideas

Ordered roughly by leverage per effort. These are brainstorm items, not a
roadmap; each would become a checklist item only if/when picked up.

1. **Emit conformant bundles; get the OKF consumer ecosystem for free.**
   The direct payoff of Part 1: any OKF consumer — the reference repo's
   `viz.html` graph viewer, catalog UIs, consumption agents that already
   know how to traverse index files and frontmatter — can ingest a
   generated API-reference tree with zero special-casing. The graph viewer
   alone is a nontrivial freebie: it renders cross-links (superclass,
   mixins, `@see`, param types) as a navigable class-relationship graph,
   which is exactly the structure our output already encodes as links.

2. **Extension frontmatter keys as a machine-queryable spine.** OKF
   consumers preserve and tolerate arbitrary keys, so we can carry
   structured facts that today exist only as body prose: e.g. `gem`,
   `gem_version`, `constant` (the FQN), `superclass`, `includes`,
   `extends`. That lets a consumer filter/route ("all exception classes in
   gem X", "everything that includes Enumerable") by parsing five lines of
   YAML instead of our body grammar. Discipline required: every key added
   is tokens on every read and a duplication of body content, so each must
   earn its place — start with none beyond the Part 1 trio and add only
   against demonstrated consumer need (same YAGNI bar as everything else).

3. **`resource` as the identity bridge.** OKF's `resource` field is "a URI
   that uniquely identifies the underlying asset." For a class concept the
   natural candidates are a rubydoc.info URL, a source URL at the release
   tag, or a `rubygems.org` gem URL. This is what would let an aggregator
   deduplicate/merge knowledge about the same class arriving from
   different bundles (our generated reference vs. someone's hand-curated
   notes) — the same join key the OKF enrichment tooling uses to bind
   docs to BigQuery tables. Needs the dogfood milestone to settle what
   URI is actually derivable at generation time.

4. **Layered enrichment: generated reference as the base layer.** The OKF
   repo's whole toolchain (reference agent, `mdcode`, enrichment samples)
   is built around agents *enriching* a bundle over time. That suggests a
   powerful division for us: the generated tree is a regeneration-owned
   base layer, and curated knowledge — playbooks, recipes, gotchas,
   "which of these five methods you actually want" guidance — lives in
   *separate* concept files (e.g. `guides/`, `playbooks/`) that link into
   the generated pages via ordinary OKF cross-links. Regeneration never
   clobbers curation because ownership is per-file; broken links during
   API drift are legal OKF and detectable by a linter. This directly
   addresses the "no conceptual on-ramp" gap flagged by the July 2026
   evaluation (the README/guides checklist item) with an interop-standard
   answer rather than a bespoke one.

5. **`log.md` as an API changelog.** OKF's reserved log format (date
   headings, `**Update**`/`**Creation**`/`**Deprecation**` bullets) maps
   startlingly well onto "what changed in this gem's API between v1 and
   v2" — a question agents ask constantly during upgrades and one that
   diffing two doc trees answers poorly. A generator that compares the
   previous tree (or YARD registry) against the current one and emits
   log entries would make the bundle answer upgrade questions in one read.
   Likely post-dogfood; the diffing machinery is real work.

6. **Distribution: gems shipping their own knowledge bundle.** A bundle
   is "a subdirectory within a larger repository" per §3, so a gem could
   ship its generated tree in the packaged gem or repo (the metadata-as-
   code pattern `mdcode` promotes). An agent working in a project could
   then resolve "docs for gem X vX.Y" to a local directory via Bundler,
   with no network and no generation step. This is really a distribution
   question for the existing skill roadmap item (which already owns "where
   per-gem trees live, how to generate missing ones") — OKF's contribution
   is that the answer would use a public convention rather than a private
   one.

7. **Cross-domain linking in mixed bundles.** Because OKF is
   domain-agnostic, one organization's bundle can contain both data-catalog
   concepts (the spec's home turf) and API reference. A `BigQuery Table`
   concept's "how do I read this from Ruby" section could link straight to
   the client class's concept file in the same tree. We don't have to do
   anything to enable this beyond conformance — it's an argument for why
   conformance matters: it makes our output *composable into* knowledge
   corpora we don't control.

8. **Engage upstream while it's a draft.** OKF v0.1 is explicitly a draft
   in a repo soliciting contributions, and its examples are entirely
   data-catalog-shaped. An API-reference producer is exactly the kind of
   second domain that pressure-tests a "universal" format. Concretely
   worth raising: the index-preamble accommodation (Part 1's option *(c)*),
   and possibly a conventional `type` vocabulary note for code-reference
   concepts so independent producers (a Python/Sphinx analog, a TypeScript
   analog) converge on compatible types. Filing issues costs little and
   buys standing if the format gets traction.

9. **Skill + bundle pairing.** The OKF repo's `samples/discovery`
   demonstrates the same pattern our roadmap already contains: a SKILL.md
   that routes an agent into a knowledge bundle. When our skill item comes
   off its dogfood gate, "the tree is an OKF bundle" becomes part of the
   skill's pitch — an OKF-aware agent needs to be taught only *where* the
   bundle is, not *how* to traverse it, because index files, frontmatter,
   and link semantics are already shared convention. Shrinks the exact
   drift surface the preamble/skill division of labor was designed to
   manage.

## Suggested sequencing

If adopted, the natural order is: Part 1 conformance (frontmatter +
`okf_version` + preamble relocation) as one or two checklist items under a
new "OKF interop" or the existing "Indexing & discovery" section; upstream
engagement (#8) in parallel since it's free; everything else (resource
URIs, enrichment layering, log.md, distribution) explicitly gated on the
dogfood milestone, which is where their open inputs get settled anyway.
