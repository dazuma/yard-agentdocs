---
type: Ruby Module
title: Geometry::Named
description: "Mixed into shape classes via `extend` (not `include`) to add a `.kind` class method, derived from the extending class's own name."
---

# module Geometry::Named

- **Defined in:** `examples/geometry/lib/geometry/named.rb`

Mixed into shape classes via `extend` (not `include`) to add a `.kind`
class method, derived from the extending class's own name.

Exercises `extend` of a module defining singleton methods: the extending
class's own file shows an `**Extends:**` line pointing back here, rather
than duplicating `#kind`'s docs inline — same link-out convention as
`include`/`**Includes:**` (see `Taggable`).

## Member Summary

**Instance Methods**

- `#kind` — The shape's kind, derived from the extending class's own name.

## Instance Methods

### #kind

```ruby
named.kind() → Symbol
```

The shape's kind, derived from the extending class's own name.

**Returns:**

- `Symbol` — the class's short name, downcased — e.g. `:triangle`

* **Defined in:** `examples/geometry/lib/geometry/named.rb:19`
