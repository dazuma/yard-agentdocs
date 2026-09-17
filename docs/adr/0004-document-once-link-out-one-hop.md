# Members are documented once, linked to, and followed for exactly one hop

## Context

A class's page could show every member callable on an instance of it —
its own, its superclass's, and every mixin's — so that one file read answers
every question about that class. For an agent paying per read, that is the
obvious shape, and it is roughly what a human-facing template does when it
renders inherited-method summaries.

It cannot be made to work uniformly. A Bundle documents the source it was
pointed at and nothing else, so an ancestor may simply not be in the registry:
`Comparable`, `Enumerable`, and `Object` are the everyday cases, and any gem
whose mixin comes from a dependency is the general one. A page that inlines
what it can reach and silently omits what it cannot makes "is this method
documented here, or do I need another read?" depend on where the mixin
happened to be defined — which is exactly the question the reader cannot
answer from the page in front of them.

## Decision

Each member's full documentation lives on exactly one page: the one for the
namespace that defines it. Other pages point at it rather than copying it.

Pointers are followed for **one reliable hop** — the immediate superclass, each
directly `include`d module, each directly `extend`ed module — and never
further. A page carries `**Superclass:**`/`**Includes:**`/`**Extends:**` links
to those, plus a names-only roster of the members they contribute that the page
does not already list itself. Reaching a grandparent's members means loading
the parent's page, which carries its own one-hop set.

## Consequences

The invariant has four implementations and no single home, which is why it is
recorded here:

- **`MemberListing`** enforces "documented once" by passing both
  `inherited: false` and `included: false` to `NamespaceObject#meths`. Both
  flags are required and independent — `:inherited` covers superclass methods
  and is `ClassObject`-only, `:included` covers mixins on every
  `NamespaceObject`. `included:` defaults to *true*, so omitting it leaks every
  mixin's methods into the listing; that was a real latent bug, invisible until
  a fixture first exercised a mixin.
- **`MemberRoster`** implements the one-hop set and the dedup against the
  page's own members.
- **`CrossReferencing`** renders the links, stopping at one hop for a second,
  independent reason: an unparsed ancestor is a `Proxy` with no ancestry or
  mixin data of its own, so walking further is not merely undesirable but
  unsupported.
- **`bundle.md`**'s "Inherited and mixed-in members aren't duplicated in full"
  bullet is what makes the gap honest rather than silent. Without it an agent
  reads an incomplete roster as an exhaustive one. It is not optional
  commentary on this decision; it is half of it.

The roster therefore can never reflect `Enumerable`, `Object`, or any other
unparsed ancestor. This is a permanent gap, and deliberately not a new *kind*
of gap: reading the raw source has the identical blind spot.

## Considered options

- **Inlining inherited and mixed-in member docs onto each class's page.** The
  uniformity problem above. Also multiplies corpus size by the depth of the
  ancestry chain, against a format whose premise is cheap reads.
- **Walking the full ancestry chain for links or the roster.** Produces a list
  that is silently incomplete rather than visibly one hop deep, and is not
  derivable anyway for the unparsed `Proxy` ancestors where it would matter
  most. One reliable hop beats a chain that stops without saying so.
- **Emitting an H3 stub per inherited member, pointing at the real entry.**
  Rejected for the roster: it doubles the page's member headings, which is the
  structure `grep '^### '` depends on, in exchange for information the
  names-only roster already carries.
