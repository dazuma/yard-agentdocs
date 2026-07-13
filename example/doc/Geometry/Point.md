# class Geometry::Point

**Superclass:** `Object`
**Defined in:** `example/lib/geometry/point.rb`

A point in two-dimensional space.

Doesn't mix in {Comparable}, so points aren't directly sortable or
comparable with `<=>`.

## Member Summary

**Constants**

- `DIMENSIONS` — The number of coordinates a point has.
- `ORIGIN` — The point at the origin, `(0, 0)`.

**Attributes**

- `#x` (read-only) — The x-coordinate.
- `#y` (read-only) — The y-coordinate.

**Class Methods**

- `.from_polar` — Creates a point from polar coordinates.
- `.new` — Creates a point from its coordinates.
- `.parse` — Parses a point from a string formatted as `"x,y"`.

**Instance Methods**

- `#+` — Adds this point to another, component-wise.
- `#distance_to` — Computes the Euclidean distance to another point.
- `#round` — Rounds this point's coordinates to the given decimal precision.
- `#translate` — Shifts this point by the given coordinate deltas.

## Constants

### DIMENSIONS

**Type:** `Integer`
**Value:** `2`

The number of coordinates a point has.

**Defined in:** `example/lib/geometry/point.rb:16`

### ORIGIN

**Type:** `Point`
**Value:** `new(0, 0)`

The point at the origin, `(0, 0)`.

**Defined in:** `example/lib/geometry/point.rb:48`

## Attributes

### #x

**Type:** `Numeric`
**Read-only.**

The x-coordinate.

**Defined in:** `example/lib/geometry/point.rb:23`

### #y

**Type:** `Numeric`
**Read-only.**

The y-coordinate.

**Defined in:** `example/lib/geometry/point.rb:30`

## Class Methods

### .from_polar

```ruby
Point.from_polar(radius:, angle:) → Point
```

Creates a point from polar coordinates.

**Params:**

- `radius` (`Numeric`) — the distance from the origin
- `angle` (`Numeric`) — the angle from the positive x-axis, in radians

**Returns:** `Point` — the point in Cartesian coordinates

**Defined in:** `example/lib/geometry/point.rb:75`

### .new

*(Ruby's default constructor; documents `#initialize`.)*

```ruby
Point.new(x, y) → Point
```

Creates a point from its coordinates.

**Params:**

- `x` (`Numeric`) — the x-coordinate
- `y` (`Numeric`) — the y-coordinate

**Defined in:** `example/lib/geometry/point.rb:38`

### .parse

```ruby
Point.parse(str) → Point
```

Parses a point from a string formatted as `"x,y"`.

**Params:**

- `str` (`String`) — a string such as `"3,4"`

**Returns:** `Point` — the parsed point

**Raises:**

- [`ParseError`](ParseError.md) — if `str` isn't formatted as `"x,y"`
- `TypeError` — if `str` is not a `String`

**Defined in:** `example/lib/geometry/point.rb:58`

## Instance Methods

### #+

```ruby
point + other → Point
```

Adds this point to another, component-wise.

**Params:**

- `other` (`Point`) — the point to add

**Returns:** `Point` — a new point whose coordinates are the sum of the two

**Defined in:** `example/lib/geometry/point.rb:85`

### #distance_to

```ruby
point.distance_to(other) → Float
```

Computes the Euclidean distance to another point.

**Params:**

- `other` (`Point`) — the point to measure distance to

**Returns:** `Float` — the distance between the two points

**Defined in:** `example/lib/geometry/point.rb:95`

### #round

```ruby
point.round(precision: 0) → Point
```

Rounds this point's coordinates to the given decimal precision.

**Params:**

- `precision` (`Integer`) — the number of decimal places to round to

**Returns:** `Point` — a new point with rounded coordinates

**Defined in:** `example/lib/geometry/point.rb:105`

### #translate

```ruby
point.translate(**deltas) → Point
```

Shifts this point by the given coordinate deltas. Any coordinate not
given defaults to no change.

**Params:**

- `deltas` (`Hash{Symbol => Numeric}`) — `:x` and/or `:y` offsets to add

**Returns:** `Point` — a new point shifted by the given deltas

**Defined in:** `example/lib/geometry/point.rb:116`
