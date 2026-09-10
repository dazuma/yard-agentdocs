---
type: Ruby Module
title: Geometry::Rounding
description: "Rounding helpers."
---

# module Geometry::Rounding

- **Defined in:** `examples/geometry/lib/geometry/rounding.rb`

Rounding helpers.

Exercises the `module_function` pattern: each method becomes a public
singleton method (`Geometry::Rounding.to_precision(...)`) and, unlike
`extend self` (see `Angles`), a *private* instance method — so mixing
this module in elsewhere would not expose `#to_precision` publicly.

Also exercises `{include:...}`/`{render:...}` inline references: both
degrade to a plain link, identically to a bare `{Name}` reference —
[`Geometry::Angles`](Angles.md) and [`Geometry::Vector`](Vector.md).

Both forms also support a label, rendered as plain text with no
backticks: [the Angles module](Angles.md) and
[the Vector class](Vector.md).

A same-file self-reference degrades the same way a bare self-reference
does: `Rounding` renders as a plain backtick, and
this very module renders as plain label text — no
link either way.

## Member Summary

**Class Methods**

- `.to_precision` — Rounds a value to the given number of decimal places.

## Class Methods

### .to_precision

```ruby
Rounding.to_precision(value, precision) → Float
```

Rounds a value to the given number of decimal places.

**Params:**

- `value` (`Float`) — the value to round
- `precision` (`Integer`) — the number of decimal places

**Returns:**

- `Float` — the rounded value

* **Defined in:** `examples/geometry/lib/geometry/rounding.rb:35`
