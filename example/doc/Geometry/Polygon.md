# Geometry::Polygon

**Superclass:** [`Shape`](Shape.md)
**Defined in:** `example/lib/geometry/polygon.rb`

A polygon: a shape with a fixed number of straight sides.

## Member Summary

**Attributes**

- `#sides` (read-only) — The number of sides the polygon has.

**Class Methods**

- `.new` — Creates a polygon with the given number of sides.

## Attributes

### #sides

**Type:** `Integer`
**Read-only.**

The number of sides the polygon has.

**Defined in:** `example/lib/geometry/polygon.rb:22`

## Class Methods

### .new

*(Ruby's default constructor; documents `#initialize`.)*

```ruby
Polygon.new(sides) → Polygon
```

Creates a polygon with the given number of sides.

**Params:**

- `sides` (`Integer`) — the number of sides

**Defined in:** `example/lib/geometry/polygon.rb:13`
