---
type: Ruby Class
title: Geometry::ThreeD::Point
description: "A point in three-dimensional space, analogous to [`Geometry::Point`](../Point.md)."
---

# class Geometry::ThreeD::Point

- **Superclass:** `Object`
- **Defined in:** `examples/geometry/lib/geometry/three_d/point.rb`

A point in three-dimensional space, analogous to [`Geometry::Point`](../Point.md).

## Member Summary

**Class Methods**

- `.new` — Creates a point from its coordinates.

**Instance Methods**

- `#magnitude` — Computes the distance from the origin.

## Class Methods

### .new

*(Ruby's default constructor; documents `#initialize`.)*

```ruby
Point.new(x, y, z) → Point
```

Creates a point from its coordinates.

**Params:**

- `x` (`Numeric`) — the x-coordinate
- `y` (`Numeric`) — the y-coordinate
- `z` (`Numeric`) — the z-coordinate

* **Defined in:** `examples/geometry/lib/geometry/three_d/point.rb:16`

## Instance Methods

### #magnitude

```ruby
point.magnitude() → Float
```

Computes the distance from the origin.

**Returns:**

- `Float` — the distance

* **Defined in:** `examples/geometry/lib/geometry/three_d/point.rb:27`
