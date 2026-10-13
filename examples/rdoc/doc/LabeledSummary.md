---
type: Ruby Module
title: LabeledSummary
description: "EXPERIMENTAL: Exercises summaries that open with an RDoc label-list item."
---

# module LabeledSummary

- **Defined in:** `examples/rdoc/lib/labeled_summary.rb`

-   **EXPERIMENTAL:** Exercises summaries that open with an RDoc label-list item.

RDoc reads a leading bracketed label, or a leading label followed by a double colon, as a label list. Converted as a list, a summary would span two lines, so the summary surfaces render each item inline as "label: text" instead.

## Member Summary

**Nested Classes & Modules**

- [`Header`](LabeledSummary/Header.md) — Author: Jane Doe Copyright: Copyright (c) 2026 Example Corp.

**Constants**

- `LEGACY` — NOTE: Retained for compatibility with 1.x, in a label ending in a colon.
- `SUPPORTED` — Supported versions: 2.0 and later, in the double-colon form.

**Class Methods**

- `.fetch` — MAINTENANCE MODE: Fetches `key` from the legacy store.

## Constants

### LEGACY

- **Type:** `Object`
- **Value:** `true`

-   **NOTE:** Retained for compatibility with 1.x, in a label ending in a colon.

* **Defined in:** `examples/rdoc/lib/labeled_summary.rb:15`

### SUPPORTED

- **Type:** `Object`
- **Value:** `">= 2.0"`

-   **Supported versions:** 2.0 and later, in the double-colon form.

* **Defined in:** `examples/rdoc/lib/labeled_summary.rb:20`

## Class Methods

### .fetch

```ruby
LabeledSummary.fetch(key) → String, nil
```

-   **MAINTENANCE MODE:** Fetches `key` from the legacy store.

**Params:**

- `key` (`String`) — the key to look up

**Returns:**

- `String, nil` — the stored value, if any

* **Defined in:** `examples/rdoc/lib/labeled_summary.rb:35`
