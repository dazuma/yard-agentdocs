# Geometry::Point

**Ancestors:** `Object` → `BasicObject`
**Includes:** `Kernel`
**Defined in:** `example/lib/geometry/point.rb`

A point in two-dimensional space.

## Member Summary

**Constants**

- `DIMENSIONS` — The number of coordinates a point has.
- `ORIGIN` — The point at the origin, `(0, 0)`.

**Attributes**

- `#x` (read-only) — The x-coordinate.
- `#y` (read-only) — The y-coordinate.

**Class Methods**

- `.new` — Creates a point from its coordinates.
- `.parse` — Parses a point from a string formatted as `"x,y"`.

**Instance Methods**

- `#+` — Adds this point to another, component-wise.
- `#distance_to` — Computes the Euclidean distance to another point.

## Constants

### DIMENSIONS

**Type:** `Integer`
**Value:** `2`

The number of coordinates a point has.

**Defined in:** `example/lib/geometry/point.rb:13`

### ORIGIN

**Type:** `Point`
**Value:** `Point.new(0, 0)`

The point at the origin, `(0, 0)`.

**Defined in:** `example/lib/geometry/point.rb:45`

## Attributes

### #x

**Type:** `Numeric`
**Read-only.**

The x-coordinate.

**Defined in:** `example/lib/geometry/point.rb:20`

### #y

**Type:** `Numeric`
**Read-only.**

The y-coordinate.

**Defined in:** `example/lib/geometry/point.rb:27`

## Class Methods

### .new

*(Ruby's default constructor; documents `#initialize`.)*

```ruby
Point.new(x, y) → Point
```

Creates a point from its coordinates.

**Params:**

- `x` (`Numeric`) — the x-coordinate
- `y` (`Numeric`) — the y-coordinate

**Defined in:** `example/lib/geometry/point.rb:35`

### .parse

```ruby
Point.parse(str) → Point
```

Parses a point from a string formatted as `"x,y"`.

**Params:**

- `str` (`String`) — a string such as `"3,4"`

**Returns:** `Point` — the parsed point

**Defined in:** `example/lib/geometry/point.rb:53`

## Instance Methods

### #+

```ruby
point + other → Point
```

Adds this point to another, component-wise.

**Params:**

- `other` (`Point`) — the point to add

**Returns:** `Point` — a new point whose coordinates are the sum of the two

**Defined in:** `example/lib/geometry/point.rb:64`

### #distance_to

```ruby
point.distance_to(other) → Float
```

Computes the Euclidean distance to another point.

**Params:**

- `other` (`Point`) — the point to measure distance to

**Returns:** `Float` — the distance between the two points

**Defined in:** `example/lib/geometry/point.rb:74`
