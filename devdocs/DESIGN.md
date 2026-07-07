# Design

This document describes the design of `yard-agents` — a [YARD](https://yardoc.org/)
plugin that renders Ruby API reference documentation in a format meant for coding
agents to look up efficiently, rather than for human browsing.

It is a living design document, and currently reflects a **pre-implementation**
state: nothing below is finalized. Decisions get logged here as we make them, and
open questions stay open (and listed) until they're resolved. This file is the
source of truth for design; keep it in sync as understanding improves.

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

## Open questions

Nothing here is decided yet. These are the questions the `example/doc` exercise
should help answer:

- **Output format** — likely Markdown, but exact structure (headers, sections,
  front matter, whether it's optimized for a human skim too or purely for
  machine/agent consumption) is undecided.
- **File granularity** — one file per class vs. one file per method (so an agent
  can load a single method's docs without pulling in the whole class). Method-
  level granularity is the leading idea but has tradeoffs: file count, how to
  present shared class-level context (e.g. class description, `@since`,
  ancestry) without duplicating it into every method file, and how cross-method
  references (overloads, related methods) work across file boundaries.
- **Indexing/lookup** — how an agent (or tooling around it) discovers which file
  corresponds to a given class/method: a top-level index file, a predictable
  path/naming convention derived from the fully-qualified name, or both.
- **YARD integration mechanics** — how the plugin hooks into YARD's
  template/handler system (custom template path vs. registered output format vs.
  standard `yard-*` plugin conventions), and how it's invoked (`yard doc -f
  agents`, a Toys task, a CLI wrapper, etc.).
- **Cross-referencing** — how method docs that reference other methods/classes
  (`@see`, param types, return types, mixins/inheritance) should link between
  generated files without forcing an agent to load unnecessary context to
  resolve them.

## Decisions

None yet — this section will be populated as open questions above are resolved
through the `example/doc` exercise.
