# class Geometry::Path

**Superclass:** `Object`
**Includes:** `Enumerable`
**Defined in:** `example/lib/geometry/path.rb`

An ordered sequence of points.

Includes the stdlib `Enumerable` module — defined outside this
example's own source — to exercise how a mixin whose docs live
entirely outside the parsed source renders: `#each` is the only method
actually defined here, but `Enumerable` methods like `#map`/`#select`/
`#first` are all available too, none of them documented on this page.

## Member Summary

**Class Methods**

- `.new` — Creates a path visiting the given points in order.

**Instance Methods**

- `#each` — Yields each point in the path, in order.

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

### #each

```ruby
path.each { |point| ... } → Integer
```

Yields each point in the path, in order.

**Yield Params:**

- `point` ([`Point`](Point.md)) — each point, in the order given

**Returns:**

- `Integer` — the number of points in the path

**Defined in:** `example/lib/geometry/path.rb:31`
