# class Geometry::BoundingBox

- **Superclass:** `Object`
- **Defined in:** `example/lib/geometry/bounding_box.rb`

An axis-aligned bounding box, whose four numeric edges are declared
through a small class-level DSL (`.edge`) instead of individual
`attr_reader`s.

Exercises YARD's attach-mode `@!macro` directive, the workhorse of
DSL-heavy and generated codebases: `.edge`'s own doc comment carries no
`@return`, since an attach-mode macro doesn't expand at its own
definition site, only at each *call site*. Every `edge :name` call below
is annotated with nothing more than `@!macro edge` in source; YARD
expands that into a synthetic `@!method $1` there, substituting the edge
name for `$1`, which in turn defines a real, individually-documented
instance method (`#left`, `#top`, etc.) attributed to its own call
site's line, not `.edge`'s.

## Member Summary

**Class Methods**

- `.edge` — Declares a coercing numeric edge attribute.
- `.enclosing` — Creates the smallest bounding box that encloses the given points.
- `.new` — Creates a bounding box from its four edges.

**Instance Methods**

- `#bottom` — Returns the box's `bottom` edge, coerced to a `Float`.
- `#left` — Returns the box's `left` edge, coerced to a `Float`.
- `#right` — Returns the box's `right` edge, coerced to a `Float`.
- `#top` — Returns the box's `top` edge, coerced to a `Float`.

## Class Methods

### .edge

```ruby
BoundingBox.edge(name)
```

Declares a coercing numeric edge attribute.

* **Defined in:** `example/lib/geometry/bounding_box.rb:28`

### .enclosing

```ruby
BoundingBox.enclosing(*points) → BoundingBox
BoundingBox.enclosing(path) → BoundingBox
```

Creates the smallest bounding box that encloses the given points.

Exercises a 2+-`@overload` method whose `@return` (and `@raise`) are
declared once, at the method level, rather than per overload: the two
calling conventions vary only in how the points are supplied.

**`BoundingBox.enclosing(*points) → BoundingBox`**

**Params:**

- `points` (`Array<`[`Point`](Point.md)`>`) — the points to enclose

**`BoundingBox.enclosing(path) → BoundingBox`**

**Params:**

- `path` ([`Path`](Path.md)) — a path whose points to enclose

**Returns (every overload):**

- `BoundingBox` — the smallest box containing every point

**Raises (every overload):**

- `ArgumentError` — if there are no points to enclose

* **Defined in:** `example/lib/geometry/bounding_box.rb:66`

### .new

*(Ruby's default constructor; documents `#initialize`.)*

```ruby
BoundingBox.new(left:, top:, right:, bottom:) → BoundingBox
```

Creates a bounding box from its four edges.

**Params:**

- `left` (`Numeric`) — the left edge
- `top` (`Numeric`) — the top edge
- `right` (`Numeric`) — the right edge
- `bottom` (`Numeric`) — the bottom edge

* **Defined in:** `example/lib/geometry/bounding_box.rb:40`

## Instance Methods

### #bottom

```ruby
boundingbox.bottom() → Float
```

Returns the box's `bottom` edge, coerced to a `Float`.

**Returns:**

- `Float` — the edge's value

* **Defined in:** `example/lib/geometry/bounding_box.rb:50`

### #left

```ruby
boundingbox.left() → Float
```

Returns the box's `left` edge, coerced to a `Float`.

**Returns:**

- `Float` — the edge's value

* **Defined in:** `example/lib/geometry/bounding_box.rb:47`

### #right

```ruby
boundingbox.right() → Float
```

Returns the box's `right` edge, coerced to a `Float`.

**Returns:**

- `Float` — the edge's value

* **Defined in:** `example/lib/geometry/bounding_box.rb:49`

### #top

```ruby
boundingbox.top() → Float
```

Returns the box's `top` edge, coerced to a `Float`.

**Returns:**

- `Float` — the edge's value

* **Defined in:** `example/lib/geometry/bounding_box.rb:48`
