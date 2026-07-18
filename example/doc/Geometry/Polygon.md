# class Geometry::Polygon

- **Superclass:** [`Shape`](Shape.md)
- **Includes:** [`Loud`](Loud.md)
- **Defined in:** `example/lib/geometry/polygon.rb`

A polygon: a shape with a fixed number of straight sides.

Also prepends `Loud`, to exercise how `prepend` (as opposed to
`include`/`extend`) is presented: `#describe` is defined here, but
`Loud`'s own `#describe` actually wins when called, since a `prepend`ed
module sits above the class in the method resolution order. YARD's own
registry doesn't track which mixin style was used to bring a module in,
so `Loud` shows up below under the ordinary `**Includes:**` line,
indistinguishable there from a plain `include` — this paragraph is the
only place that calls out the actual override behavior.

`#label` is deliberately overridden here with no doc comment of its own,
to exercise the "subclass overrides a documented parent method without
redocumenting it" case: `Shape#label` has real docs, but YARD doesn't
copy them onto an undocumented override, so this class's own file needs
to point somewhere rather than rendering `#label` as if it were plain
undocumented.

## Member Summary

**Instance Attributes**

- `#sides` (read-only) — The number of sides the polygon has.

**Class Methods**

- `.new` — Creates a polygon with the given number of sides.

**Instance Methods**

- `#describe` — A short human-readable description of the polygon.
- `#each_side` — Calls the block once for each side of the polygon, in order.
- `#label` (overrides `Shape#label`)

**Inherited & Mixed-in Members**

- **Inherited from [`Shape`](Shape.md):** `#area`

## Instance Attributes

### #sides

- **Type:** `Integer`
- **Read-only.**

The number of sides the polygon has.

* **Defined in:** `example/lib/geometry/polygon.rb:40`

## Class Methods

### .new

*(Ruby's default constructor; documents `#initialize`.)*

```ruby
Polygon.new(sides) → Polygon
```

Creates a polygon with the given number of sides.

**Params:**

- `sides` (`Integer`) — the number of sides

* **Defined in:** `example/lib/geometry/polygon.rb:31`

## Instance Methods

### #describe

```ruby
polygon.describe() → String
```

A short human-readable description of the polygon.

**Returns:**

- `String` — the description, e.g. `"polygon"`

* **Defined in:** `example/lib/geometry/polygon.rb:47`

### #each_side

```ruby
polygon.each_side { |side_number| ... } → Integer
```

Calls the block once for each side of the polygon, in order.

**Yields:**

- `side_number` — one call per side

**Returns:**

- `Integer` — the number of sides yielded

* **Defined in:** `example/lib/geometry/polygon.rb:57`

### #label

```ruby
polygon.label()
```

* **Overrides:** [`Shape#label`](Shape.md)

* **Defined in:** `example/lib/geometry/polygon.rb:62`
