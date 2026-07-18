# module Geometry::Computations

- **Defined in:** `example/lib/geometry/computations.rb`

Utility computations on `Point` values.

## Member Summary

**Class Methods**

- `.centroid` — Computes the centroid (average position) of one or more points.
- `.distance` (deprecated) — Computes the distance between two points.
- `.each_point` — Yields each of the given points in turn.

## Class Methods

### .centroid

```ruby
Computations.centroid(*points) → Point
```

Computes the centroid (average position) of one or more points.

**Params:**

- `points` (`Array<`[`Point`](Point.md)`>`) — the points to average

**Returns:**

- [`Point`](Point.md) — the centroid of the given points

**Raises:**

- `ArgumentError, NoMethodError` — if `points` is empty, or if an
  element doesn't respond to `#x`/`#y`

* **Defined in:** `example/lib/geometry/computations.rb:29`

### .distance

```ruby
Computations.distance(a, b) → Float
```

* **Deprecated.** Use [`Point#distance_to`](Point.md) instead.

Computes the distance between two points.

**Params:**

- `a` ([`Point`](Point.md)) — the first point
- `b` ([`Point`](Point.md)) — the second point

**Returns:**

- `Float` — the distance between the two points

**See also:** [`Point#distance_to`](Point.md)

* **Defined in:** `example/lib/geometry/computations.rb:17`

### .each_point

```ruby
Computations.each_point(*points) { |point| ... } → Integer
```

Yields each of the given points in turn.

**Params:**

- `points` (`Array<`[`Point`](Point.md)`>`) — the points to iterate over

**Yield Params:**

- `point` ([`Point`](Point.md)) — each point, in the order given

**Returns:**

- `Integer` — the number of points yielded

* **Defined in:** `example/lib/geometry/computations.rb:42`
