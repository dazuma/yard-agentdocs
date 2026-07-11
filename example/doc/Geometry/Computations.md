# module Geometry::Computations

**Defined in:** `example/lib/geometry/computations.rb`

Utility computations on `Point` values.

## Member Summary

**Class Methods**

- `.centroid` — Computes the centroid (average position) of one or more points.
- `.distance` — Computes the distance between two points.

## Class Methods

### .centroid

```ruby
Computations.centroid(*points) → Point
```

Computes the centroid (average position) of one or more points.

**Params:**

- `points` (`Array<`[`Point`](Point.md)`>`) — the points to average

**Returns:** [`Point`](Point.md) — the centroid of the given points

**Defined in:** `example/lib/geometry/computations.rb:26`

### .distance

```ruby
Computations.distance(a, b) → Float
```

Computes the distance between two points.

**Params:**

- `a` ([`Point`](Point.md)) — the first point
- `b` ([`Point`](Point.md)) — the second point

**Returns:** `Float` — the distance between the two points

**See also:** [`Point#distance_to`](Point.md)

**Defined in:** `example/lib/geometry/computations.rb:16`
