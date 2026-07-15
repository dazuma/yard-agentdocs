# class Geometry::Path

**Superclass:** `Object`
**Includes:** `Enumerable`
**Defined in:** `example/lib/geometry/path.rb`

An ordered sequence of points.

Includes the stdlib `Enumerable` module — defined outside this
example's own source — to exercise how a mixin whose docs live
entirely outside the parsed source renders: `Enumerable` methods like
`#map`/`#select`/`#first` are all available too, none of them
documented on this page.

## Member Summary

**Class Methods**

- `.new` — Creates a path visiting the given points in order.

**Instance Methods**

- `#add` — Appends a point to the end of the path.
- `#clear` — Removes every point from the path.
- `#closest_to` — Finds the point in the path closest to the given target.
- `#each` — Yields each point in the path, in order.
- `#each_segment` — Yields each segment connecting consecutive points in the path, in order.
- `#segment_at` — Builds the segment connecting the points at `index` and `index + 1`.
- `#transform!` — Replaces each point in the path with the block's result, in place.

## Class Methods

### .new

*(Ruby's default constructor; documents `#initialize`.)*

```ruby
Path.new(*points) → Path
```

Creates a path visiting the given points in order.

**Params:**

- `points` (`Array<`[`Point`](Point.md)`>`) — the points to visit, in order

**Defined in:** `example/lib/geometry/path.rb:21`

## Instance Methods

### #add

```ruby
path.add(point) → self
```

Appends a point to the end of the path.

**Params:**

- `point` ([`Point`](Point.md)) — the point to append

**Returns:**

- `self` — this path, for chaining

**Defined in:** `example/lib/geometry/path.rb:31`

### #clear

```ruby
path.clear() → void
```

Removes every point from the path.

**Returns:**

- `void`

**Defined in:** `example/lib/geometry/path.rb:41`

### #closest_to

```ruby
path.closest_to(target) → Point, nil
```

Finds the point in the path closest to the given target.

**Params:**

- `target` ([`Point`](Point.md)) — the point to measure distance from

**Returns:**

- [`Point`](Point.md)`, nil` — the closest point, or `nil` if the path has no points

**Defined in:** `example/lib/geometry/path.rb:51`

### #each

```ruby
path.each { |point| ... } → Integer
```

Yields each point in the path, in order.

**Yield Params:**

- `point` ([`Point`](Point.md)) — each point, in the order given

**Returns:**

- `Integer` — the number of points in the path

**Defined in:** `example/lib/geometry/path.rb:63`

### #each_segment

```ruby
path.each_segment { |segment| ... } → Integer, Enumerator
```

Yields each segment connecting consecutive points in the path, in
order. Returns an Enumerator instead if no block is given.

**Yield Params:**

- `segment` ([`Segment`](Segment.md)) — each segment, in order

**Returns:**

- `Integer` — the number of segments yielded, if a block is given
- `Enumerator` — an enumerator over the path's segments, if no
  block is given

**Defined in:** `example/lib/geometry/path.rb:90`

### #segment_at

```ruby
path.segment_at(index) → Segment, nil
```

Builds the segment connecting the points at `index` and `index + 1`.

**Params:**

- `index` (`Integer`) — the index of the first point in the segment

**Returns:**

- [`Segment`](Segment.md) — the segment between the two consecutive points
- `nil` — if `index` is out of range

**Defined in:** `example/lib/geometry/path.rb:75`

### #transform!

```ruby
path.transform! { |point| ... } → self
```

Replaces each point in the path with the block's result, in place.

**Yield Params:**

- `point` ([`Point`](Point.md)) — each point, in order

**Yield Returns:**

- [`Point`](Point.md) — the replacement for this point
- `nil` — to leave this point unchanged

**Returns:**

- `self` — this path, for chaining

**Defined in:** `example/lib/geometry/path.rb:105`
