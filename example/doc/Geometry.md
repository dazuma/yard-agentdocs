# Geometry

**Defined in:** `example/lib/geometry.rb`

A small toy geometry namespace, used as a worked example for the
`yard-agentdocs` output format. Not part of the shipped gem.

## Member Summary

**Nested Classes & Modules**

- [`Point`](Geometry/Point.md) — A point in two-dimensional space.

**Class Methods**

- `.distance` — Computes the distance between two points.

## Class Methods

### .distance

```ruby
Geometry.distance(a, b) → Float
```

Computes the distance between two points.

**Params:**

- `a` ([`Point`](Geometry/Point.md)) — the first point
- `b` ([`Point`](Geometry/Point.md)) — the second point

**Returns:** `Float` — the distance between the two points

**See also:** [`Point#distance_to`](Geometry/Point.md)

**Defined in:** `example/lib/geometry.rb:17`
