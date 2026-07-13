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
- `.of` — Builds a point from `x, y` coordinates, or several independent copies of an existing point at once.
- `.parse` — Parses a point from a string formatted as `"x,y"`.

**Instance Methods**

- `#+` — Adds this point to another, component-wise.
- `#distance_to` — Computes the Euclidean distance to another point.
- `#label` — Returns a short label for this point, formatted `"x,y"` by default (the same format `.parse` understands).
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

### .of

Builds a point from `x, y` coordinates, or several independent copies
of an existing point at once.

```ruby
Point.of(x, y) → Point
```

**Params:**

- `x` (`Numeric`) — the x-coordinate
- `y` (`Numeric`) — the y-coordinate

**Returns:** `Point` — a single point built from the coordinates

```ruby
Point.of(point, count) → Array<Point>
```

**Params:**

- `point` (`Point`) — the point to copy
- `count` (`Integer`) — how many independent copies to build

**Returns:** `Array<Point>` — `count` copies of `point`

**Defined in:** `example/lib/geometry/point.rb:92`

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

**Defined in:** `example/lib/geometry/point.rb:105`

### #distance_to

```ruby
point.distance_to(other) → Float
```

Computes the Euclidean distance to another point.

**Params:**

- `other` (`Point`) — the point to measure distance to

**Returns:** `Float` — the distance between the two points

**Defined in:** `example/lib/geometry/point.rb:115`

### #label

```ruby
point.label(separator: ",") → String
```

Returns a short label for this point, formatted `"x,y"` by default
(the same format `.parse` understands).

**Params:**

- `separator` (`String`) — the string to place between the x and y
coordinates

**Returns:** `String` — the formatted label

**Defined in:** `example/lib/geometry/point.rb:128`

### #round

```ruby
point.round(precision: 0) → Point
```

Rounds this point's coordinates to the given decimal precision.

**Params:**

- `precision` (`Integer`) — the number of decimal places to round to

**Returns:** `Point` — a new point with rounded coordinates

**Defined in:** `example/lib/geometry/point.rb:139`

### #translate

```ruby
point.translate(**deltas) → Point
```

Shifts this point by the given coordinate deltas. Any coordinate not
given defaults to no change.

**Params:**

- `deltas` (`Hash{Symbol => Numeric}`) — `:x` and/or `:y` offsets to add

**Returns:** `Point` — a new point shifted by the given deltas

**Defined in:** `example/lib/geometry/point.rb:150`
