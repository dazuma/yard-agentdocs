---
type: Ruby Class
title: Geometry::CompassRose
description: "Compass-bearing lookups, one instance method per cardinal direction."
---

# class Geometry::CompassRose

- **Superclass:** `Object`
- **Defined in:** `example/lib/geometry/compass_rose.rb`

Compass-bearing lookups, one instance method per cardinal direction.

Reuses the direction names from [`Angles::NAMED_ANGLES`](Angles.md) rather than a
fresh literal, and exercises YARD's `@!method` directive without an
accompanying `@!macro` — the idiomatic way to document methods defined
by looping over runtime data, where there's no per-iteration call site
for a macro to expand at (contrast [`BoundingBox`](BoundingBox.md), where each generated
method comes from its own `edge :name` call). Stacking one `@!method`
directive per generated method above the single `each` call that
defines them all — YARD's own documented "Attaching multiple methods to
the same source" pattern — is the fix: all four methods below end up
individually documented, but share one `**Defined in:**` line, since
they're all attributed to that same call site.

## Member Summary

**Instance Methods**

- `#east` — Returns east's bearing, in degrees.
- `#north` — Returns north's bearing, in degrees.
- `#south` — Returns south's bearing, in degrees.
- `#west` — Returns west's bearing, in degrees.

## Instance Methods

### #east

```ruby
compassrose.east() → Float
```

Returns east's bearing, in degrees.

**Returns:**

- `Float` — the bearing

* **Defined in:** `example/lib/geometry/compass_rose.rb:32`

### #north

```ruby
compassrose.north() → Float
```

Returns north's bearing, in degrees.

**Returns:**

- `Float` — the bearing

* **Defined in:** `example/lib/geometry/compass_rose.rb:32`

### #south

```ruby
compassrose.south() → Float
```

Returns south's bearing, in degrees.

**Returns:**

- `Float` — the bearing

* **Defined in:** `example/lib/geometry/compass_rose.rb:32`

### #west

```ruby
compassrose.west() → Float
```

Returns west's bearing, in degrees.

**Returns:**

- `Float` — the bearing

* **Defined in:** `example/lib/geometry/compass_rose.rb:32`
