---
type: Ruby Module
title: WrappedProse
description: "Exercises rdoc-dialect prose whose summary sentence runs on past a single source line, as most real-world RDoc summaries eventually do."
---

# module WrappedProse

- **Defined in:** `examples/rdoc/lib/wrapped_prose.rb`

Exercises rdoc-dialect prose whose summary sentence runs on past a single source line, as most real-world RDoc summaries eventually do.

RDoc joins a paragraph's source lines into one before converting it, so the line breaks in this comment are the author's, not part of the text. The converter must emit each paragraph on one line rather than re-wrap it at a fixed width of its own choosing.

## Member Summary

**Nested Classes & Modules**

- [`Member`](WrappedProse/Member.md) — Stands in for a nested member whose summary is long enough to have wrapped in its parent's Member Summary bullet.
