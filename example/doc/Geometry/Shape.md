# class Geometry::Shape

- **Superclass:** `Object`
- **Includes:** [`Taggable`](Taggable.md)
- **Defined in:** `example/lib/geometry/shape.rb`

* **Abstract.** Never instantiated directly; subclass and override `#label`
  (see `Polygon`/`Triangle`).

A generic two-dimensional shape.

The base of a three-level example hierarchy (see `Polygon` and
`Triangle`), used to exercise how `yard-agentdocs` presents a
`Superclass:` chain that resolves entirely within the example, rather
than terminating at an unparsed core class like `Object`.

Also includes `Taggable`, to exercise how a directly-`include`d module
is presented (an `**Includes:**` line here, full docs in `Taggable`'s
own file).

## Member Summary

**Instance Methods**

- `#area` (abstract) — The shape's area.
- `#label` (abstract) — A short label identifying the kind of shape.

**Inherited & Mixed-in Members**

- **Included from [`Taggable`](Taggable.md):** `#tag`

## Instance Methods

### #area

```ruby
shape.area() → Float
```

* **Abstract.** Every concrete subclass must implement this; unlike
  `#label`, no subclass in this example actually overrides it —
  this method exists purely to exercise the no-real-implementation
  case.

The shape's area.

**Returns:**

- `Float` — the area

**Raises:**

- `NotImplementedError` — always, since this base
  implementation is never meant to run

* **Defined in:** `example/lib/geometry/shape.rb:44`

### #label

```ruby
shape.label() → String
```

* **Abstract.** Overridden by every concrete subclass — `Polygon#label`
  returns `"polygon"`, and `Triangle` inherits that override.

A short label identifying the kind of shape.

**Returns:**

- `String` — the shape's label

* **Defined in:** `example/lib/geometry/shape.rb:29`
