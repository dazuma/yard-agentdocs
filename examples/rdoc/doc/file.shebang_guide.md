---
type: Guide
title: "Shebang-declared Markdown"
---

# Shebang-declared Markdown

This file's extension says RDoc, but its `#!markdown` shebang — YARD's own
per-file dialect declaration, read by `ExtraFileObject` — wins over the
extension, so the fence below survives:

```text
not reflowed
```