# The generated Bundle is an OKF bundle, and adopts nothing optional without need

## Context

A Bundle is a directory tree of markdown files. That shape is also the
[Open Knowledge Format](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md)'s,
and the overlap is not a coincidence this project can ignore: `README.md`
advertises conformance as a feature, and `CONTEXT.md` takes **Bundle** and
**Concept** from OKF's vocabulary, with `description:` named as "OKF's key name,
fixed by interop".

The fit is unusually cheap because the two specify disjoint halves of a file.
OKF specifies YAML frontmatter and reserves two filenames, and deliberately
leaves the body unspecified. This format's entire contribution — heading sigils,
signature blocks, `**Params:**` bullets, a grep-able member grammar — is body.
Conformance therefore costs a handful of frontmatter keys and one surface form,
and constrains nothing this project actually cares about.

What makes a decision record necessary is the other direction. OKF v0.2 added
four optional frontmatter families aimed squarely at machine-authored corpora —
provenance, trust, lifecycle, attestation — and they read as though they were
designed for a generator like this one. Most of them are not: §1 frames the
problem as knowledge *extracted by an LLM*, and models neither the cost nor the
epistemics of content *derived deterministically from authoritative source*. The
resulting keys look free and are not, because every frontmatter key is tokens on
every read of every page, duplicating body content the format already carries.

## Decision

The tree satisfies OKF's three hard conformance conditions (v0.2 §11) and adopts
nothing beyond them without demonstrated consumer need:

1. Every non-reserved `.md` file carries a parseable YAML frontmatter block.
2. Every such block carries a non-empty `type`.
3. `index.md` and `log.md`, where present, follow §8 and §9.

Optional keys are held to the same bar as any other addition to the format: a
real consumer wanting the field, not the spec merely offering it.

## Consequences

Four sites implement this, which is why it is recorded here rather than in one
of them:

- **`templates/default/module/agentdocs/setup.rb`** — the `Frontmatter` group
  emits `type`/`title`/`description` on every class and module page.
- **`templates/default/fulldoc/agentdocs/setup.rb`** — `type: Guide` on extra
  files, and `generated: { by, at }` on `bundle.md`.
- **`templates/default/fulldoc/agentdocs/index.erb`** — declares `okf_version`,
  the one key §8 permits in a bundle-root `index.md`.
- **`templates/default/fulldoc/agentdocs/bundle.erb`** — `type: Bundle Info`.

Two of the resulting oddities are deliberate and will otherwise read as bugs:

- **`index.md` rows use `" - "` (spaced hyphen) where every other surface in the
  tree uses `" — "` (em dash).** §8 fixes the `* [Title](url) - description`
  surface form, and an index is a reserved file whose structure is one of the
  three hard conditions.
- **`generated.at` is build wall-clock, knowingly against §5.2's definition** of
  "the content's last meaningful change". A meaningful-change date cannot answer
  the staleness question at all, since regenerating unchanged source leaves it
  untouched and so reads as fresh. The reasoning is at `generated_at` in
  `fulldoc/agentdocs/setup.rb`; this is the only place the output deviates from
  the spec's stated semantics rather than simply omitting an optional key. Issue
  #17 tracks raising the missing vocabulary upstream.

Evaluated and deliberately not adopted, none of them a conformance gap:

- **Per-directory `index.md`** — optional under §8; the flat root index plus
  deterministic FQN-to-path derivation already covers discovery.
- **`log.md`** — optional under §9. An API changelog would need real diffing
  machinery and nothing has asked for one.
- **Bundle-absolute cross-links** — recommended by §6.1; relative links are
  equally legal.
- **`# Schema`/`# Examples`/`# Computation` body headings** — conventional H1s.
  This format reserves H1 for the page title, and restructuring bodies to chase
  them would trade away the grep grammar for nothing.
- **A `references/` directory (§6.3)** — a naming convention with no conformance
  force. A Ruby namespace named `References` would collide with it; cosmetic.
- **`tags`** — optional, and §3.1 specifies no aggregation format, so nothing is
  expected of a producer.

The tree was never exposed to either of v0.2's breaking changes (§13.1): it emits
no `timestamp` and no `# Citations` body list. **That was luck, not foresight.**
`timestamp` was omitted because it would churn every file on every regeneration
for no informational gain, and H1 was reserved for the page title for unrelated
reasons. Neither was a forward-compatibility judgment, and neither is evidence
that the same instincts will survive the next spec revision.

One consequence is about what the format must *not* grow. Conformance is what
lets curated knowledge — playbooks, gotchas, "which of these five methods you
actually want" — live in separate concept files that link into the generated
pages, rather than as annotations inside them. Ownership is per file, so
regeneration never clobbers curation, and links broken by API drift are legal
OKF. Hand-curation affordances inside generated pages would destroy that
property to solve a problem the bundle format already solves.

## Considered options

- **`status: deprecated` for a class carrying YARD's `@deprecated`.** The most
  convincing of the optional keys, and wrong. §5.4's values only cohere as
  properties of the *concept document* — `draft` is "not yet reviewed" in
  §5.2's `verified` sense, which a Ruby class cannot be — and every sibling key
  is document-scoped. The reference bundle confirms it: `acme_retail`'s only
  `status: deprecated` concept is a retired document superseded by another file
  in the same bundle, while the page documenting the *replacement* subject is
  `status: stable`. Emitting it for a deprecated class would tell a consumer the
  page it just read is superseded and a current version exists elsewhere in the
  bundle. Both false, and the failure is asymmetric — an agent hunts for a
  replacement page that does not exist — to put in frontmatter a fact the body
  already states as `* **Deprecated.** …`. Subject-level deprecation, if ever
  wanted, is `tags` or a producer extension key.
- **`verified: { by: process:… }` to escape the bottom trust tier.** §5.3 derives
  three tiers from `verified` alone, and a deterministic transformation of
  authoritative source has no honest place on that ladder: the generator
  *produced* the content, so it has confirmed nothing independently, which leaves
  this project in `unverified` alongside an unreviewed LLM guess. Claiming
  otherwise would be overclaiming. The right response is upstream feedback (issue
  #17), not a frontmatter change.
- **`stale_after`.** Declined outright rather than deferred: for a build tree
  over mutable source the truthful value is today, and for a gems bundle over an
  immutable installed release it is never. Neither is useful.
- **`type: Attested Computation` (§10).** The largest addition in v0.2 and
  entirely inapplicable — runtimes, executors and attesters exist so a consumer
  can confirm a *number* was computed the sanctioned way. Recorded only because
  its prominence in the spec invites the question.
- **Bespoke frontmatter, or none at all.** The alternative to conformance. It
  would save the `okf_version` declaration and the spaced-hyphen surface form,
  and cost every OKF-aware consumer — catalog UIs, traversal agents, the
  reference repo's cross-link graph viewer — the ability to ingest a generated
  tree without special-casing. That ecosystem is the entire reason the
  constraints above are worth accepting.
