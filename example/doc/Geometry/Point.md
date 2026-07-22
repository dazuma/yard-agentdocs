---
type: Ruby Class
title: Geometry::Point
description: "A point in two-dimensional space."
---

# class Geometry::Point

- **Superclass:** `Object`
- **Defined in:** `example/lib/geometry/point.rb`

A point in two-dimensional space.

Doesn't mix in {Comparable}, so points aren't directly sortable or
comparable with `<=>`.

## Member Summary

**Constants**

- `DIMENSIONS` — The number of coordinates a point has.
- `ORIGIN` — The point at the origin, `(0, 0)`.

**Instance Attributes**

- `#x` (read-only) — The x-coordinate.
- `#y` (read-only) — The y-coordinate.

**Class Methods**

- `.from_polar` — Creates a point from polar coordinates.
- `.new` — Creates a point from its coordinates.
- `.of` — Builds a point from `x, y` coordinates, or several independent copies of an existing point at once.
- `.parse` — Parses a point from a string formatted as `"x,y"`.

**Instance Methods**

- `#+` — Adds this point to another, component-wise.
- `#[]` — Returns the coordinate at the given index: `0` for `#x`, `1` for `#y`.
- `#[]=` — Sets the coordinate at the given index: `0` for `#x`, `1` for `#y`.
- `#distance_to` — Computes the Euclidean distance to another point.
- `#label` — Returns a short label for this point, formatted `"x,y"` by default (the same format `.parse` understands).
- `#round` — Rounds this point's coordinates to the given decimal precision.
- `#to_a` — Returns this point's coordinates as a two-element array, `[x, y]`.
- `#translate` — Shifts this point by the given coordinate deltas.
- `#zero?`

## Constants

### DIMENSIONS

- **Type:** `Integer`
- **Value:** `2`

The number of coordinates a point has.

* **Since:** 1.0.0

* **Defined in:** `example/lib/geometry/point.rb:17`

### ORIGIN

- **Type:** `Point`
- **Value:** `new(0, 0)`

The point at the origin, `(0, 0)`.

* **Defined in:** `example/lib/geometry/point.rb:49`

## Instance Attributes

### #x

- **Type:** `Numeric`
- **Read-only.**

The x-coordinate.

* **Defined in:** `example/lib/geometry/point.rb:24`

### #y

- **Type:** `Numeric`
- **Read-only.**

The y-coordinate.

* **Defined in:** `example/lib/geometry/point.rb:31`

## Class Methods

### .from_polar

```ruby
Point.from_polar(radius:, angle:) → Point
```

Creates a point from polar coordinates.

**Params:**

- `radius` (`Numeric`) — the distance from the origin
- `angle` (`Numeric`) — the angle from the positive x-axis, in radians

**Returns:**

- `Point` — the point in Cartesian coordinates

* **Defined in:** `example/lib/geometry/point.rb:83`

### .new

*(Ruby's default constructor; documents `#initialize`.)*

```ruby
Point.new(x, y) → Point
```

Creates a point from its coordinates.

**Params:**

- `x` (`Numeric`) — the x-coordinate
- `y` (`Numeric`) — the y-coordinate

* **Defined in:** `example/lib/geometry/point.rb:39`

### .of

```ruby
Point.of(x, y) → Point
Point.of(point, count) → Array<Point>, Point
```

* **Note:** The two call shapes are disambiguated only by argument count and
  type — passing a `Point` as the first argument always selects the
  copying form, never the coordinate form.

Builds a point from `x, y` coordinates, or several independent copies
of an existing point at once.

**Examples:**

*Building from coordinates*

```ruby
Point.of(3, 4).x
#=> 3
```

*Copying a point multiple times*

```ruby
original = Point.new(1, 1)
copies = Point.of(original, 3)
copies.size
#=> 3
```

**`Point.of(x, y) → Point`**

**Params:**

- `x` (`Numeric`) — the x-coordinate
- `y` (`Numeric`) — the y-coordinate

**Returns:**

- `Point` — a single point built from the coordinates

**`Point.of(point, count) → Array<Point>, Point`**

**Params:**

- `point` (`Point`) — the point to copy
- `count` (`Integer`) — how many independent copies to build

**Returns:**

- `Array<Point>, Point` — `count` copies of `point`, or a single copy when `count` is `1`

* **Since:** 1.1.0
* **Version:** 1.2.0
* **Defined in:** `example/lib/geometry/point.rb:113`

### .parse

```ruby
Point.parse(str) → Point
```

Parses a point from a string formatted as `"x,y"`.

**Params:**

- `str` (`String`) — a string such as `"3,4"`

**Returns:**

- `Point` — the parsed point

**Raises:**

- [`ParseError`](ParseError.md) — if `str` isn't formatted as `"x,y"`, or if
  either half can't be parsed as an integer.

  Currently, this parsing method supports parsing integers only,
  not floating-point numbers. It supports the following:
  * Negative numbers, e.g. `-123`
  * Zero
  * Arbitrary range (e.g. *no* 32- or 64-bit limit)
- `TypeError` — if `str` is not a `String`

* **Defined in:** `example/lib/geometry/point.rb:66`

## Instance Methods

### #+

```ruby
point + other → Point
```

Adds this point to another, component-wise.

**Params:**

- `other` (`Point`) — the point to add

**Returns:**

- `Point` — a new point whose coordinates are the sum of the two

* **Defined in:** `example/lib/geometry/point.rb:130`

### #[]

```ruby
point[index] → Numeric
```

Returns the coordinate at the given index: `0` for `#x`, `1` for `#y`.

**Params:**

- `index` (`Integer`) — `0` or `1`

**Returns:**

- `Numeric` — the corresponding coordinate

**Raises:**

- `ArgumentError` — if `index` isn't `0` or `1`

* **Defined in:** `example/lib/geometry/point.rb:194`

### #[]=

```ruby
point[index] = value
```

Sets the coordinate at the given index: `0` for `#x`, `1` for `#y`.

Unlike this class's other methods, which return a new `Point` rather
than modify the receiver, `#[]=` mutates this point in place.

**Params:**

- `index` (`Integer`) — `0` or `1`
- `value` (`Numeric`) — the new coordinate value

**Raises:**

- `ArgumentError` — if `index` isn't `0` or `1`

**See also:**

- `#[]` — the corresponding getter

* **Defined in:** `example/lib/geometry/point.rb:213`

### #distance_to

```ruby
point.distance_to(other) → Float
```

Computes the Euclidean distance to another point.

**Examples:**

```ruby
Point.new(0, 0).distance_to(Point.new(3, 4))
#=> 5.0
```

**Params:**

- `other` (`Point`) — the point to measure distance to

**Returns:**

- `Float` — the distance between the two points

* **Defined in:** `example/lib/geometry/point.rb:143`

### #label

```ruby
point.label(separator: ",") → String
```

Returns a short label for this point, formatted `"x,y"` by default
(the same format `.parse` understands).

**Params:**

- `separator` (`String`) — the string to place between the x and y
  coordinates

**Returns:**

- `String` — the formatted label

* **Defined in:** `example/lib/geometry/point.rb:156`

### #round

```ruby
point.round(precision: 0) → Point
```

* **Note:** A negative `precision` rounds to the left of the decimal
  point, matching Ruby's `Float#round` semantics — e.g.
  `precision: -1` rounds to the nearest 10.

Rounds this point's coordinates to the given decimal precision.

**Params:**

- `precision` (`Integer`) — the number of decimal places to round to

**Returns:**

- `Point` — a new point with rounded coordinates

* **Defined in:** `example/lib/geometry/point.rb:170`

### #to_a

```ruby
point.to_a() → Array(Numeric, Numeric)
```

Returns this point's coordinates as a two-element array, `[x, y]`.
Exercises YARD's parenthesized fixed-length-array type syntax.

**Returns:**

- `Array(Numeric, Numeric)` — the coordinates

* **Defined in:** `example/lib/geometry/point.rb:231`

### #translate

```ruby
point.translate(**deltas) → Point
```

Shifts this point by the given coordinate deltas. Any coordinate not
given defaults to no change.

**Params:**

- `deltas` (`Hash{Symbol => Numeric}`) — `:x` and/or `:y` offsets to add

**Options (`deltas`):**

- `:x` (`Numeric`, default `0`) — the x offset to add
- `:y` (`Integer, Float`, default `0`) — the y offset to add

**Returns:**

- `Point` — a new point shifted by the given deltas

* **Defined in:** `example/lib/geometry/point.rb:183`

### #zero?

```ruby
point.zero?() → Boolean
```

**Returns:**

- `Boolean`

* **Defined in:** `example/lib/geometry/point.rb:221`
