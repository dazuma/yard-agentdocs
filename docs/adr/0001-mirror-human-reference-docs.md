# Agent reference docs mirror human reference docs

## Context

`yard-agentdocs` renders Ruby API reference documentation for coding agents to look
up cheaply, rather than for humans to browse. The goal is that an agent can answer
"what are the params and return type of `Foo#bar`?" with a single, cheap file read,
spending as few input tokens and round trips as possible.

That framing invites a bespoke format — inventing an agent-specific policy for every
rendering question from first principles, on the theory that an agent is a different
kind of reader. Hundreds of such questions come up (how to show a default value,
whether to duplicate a mixin's members, what to do with an alias), and answering each
from scratch is both slow and a source of inconsistency between answers settled
months apart.

## Decision

When a format or policy decision is not dictated by the goals above, default to
matching how a gem would already present that information to a human reader in its
own reference docs. YARD's default HTML template is the concrete reference point. An
agent looking up how to use a dependency is doing essentially the same task a human
engineer would.

Diverge only along two named dimensions:

- **Terseness and formatting.** Visual affordances that help a human scan — CSS,
  layout, verbose multi-line warning paragraphs — are dead weight for an agent
  parsing text. Prefer compact inline annotations over a human template's more
  elaborate treatment of the same information.
- **Structured search and cross-reference cost.** Favor forms that let an automation
  find, parse, and cross-reference elements cheaply — consistent headings,
  predictable file paths, minimal tokens — over forms optimized for visual browsing.

Where neither dimension is in play, do not reinvent a policy a human-facing template
has already settled.

## Consequences

- The default is to *render* what YARD's own template renders, not to *drop it for
  terseness*. Dropping requires an argument from one of the two dimensions above.
- Two scope boundaries follow. This plugin adds an output format; it does not change
  or replace YARD's HTML output for human browsing. And it is not a general-purpose
  YARD template framework — the format may be opinionated and narrow, tuned for one
  consumer.
- The heuristic is generative: it settles most individual rendering questions without
  needing a decision record of their own. That is why so few decisions in this
  repository rise to an ADR — the majority are applications of this one, and their
  record is the `examples/*/doc` fixture the test suite asserts byte for byte.
