# class Geometry::Polygon

**Superclass:** [`Shape`](Shape.md)
**Includes:** [`Loud`](Loud.md)
**Defined in:** `example/lib/geometry/polygon.rb`

A polygon: a shape with a fixed number of straight sides.

Also prepends `Loud`, to exercise how `prepend` (as opposed to
`include`/`extend`) is presented: `#describe` is defined here, but
`Loud`'s own `#describe` actually wins when called, since a `prepend`ed
module sits above the class in the method resolution order. YARD's own
registry doesn't track which mixin style was used to bring a module in,
so `Loud` shows up below under the ordinary `**Includes:**` line,
indistinguishable there from a plain `include` — this paragraph is the
only place that calls out the actual override behavior.

## Member Summary

**Attributes**

- `#sides` (read-only) — The number of sides the polygon has.

**Class Methods**

- `.new` — Creates a polygon with the given number of sides.

**Instance Methods**

- `#describe` — A short human-readable description of the polygon.

## Attributes

### #sides

**Type:** `Integer`
**Read-only.**

The number of sides the polygon has.

**Defined in:** `example/lib/geometry/polygon.rb:33`

## Class Methods

### .new

*(Ruby's default constructor; documents `#initialize`.)*

```ruby
Polygon.new(sides) → Polygon
```

Creates a polygon with the given number of sides.

**Params:**

- `sides` (`Integer`) — the number of sides

**Defined in:** `example/lib/geometry/polygon.rb:24`

## Instance Methods

### #describe

```ruby
polygon.describe() → String
```

A short human-readable description of the polygon.

**Returns:** `String` — the description, e.g. `"polygon"`

**Defined in:** `example/lib/geometry/polygon.rb:40`
