# module Geometry

**Defined in:** `example/lib/geometry.rb`

A small toy geometry namespace, used as a worked example and test case for
the `yard-agentdocs` output format.

Exists purely to group its nested classes and modules; it defines no
behavior of its own. Not part of the shipped gem.

## Member Summary

**Nested Classes & Modules**

- [`Circle`](Geometry/Circle.md) — A circle, defined by its radius.
- [`Computations`](Geometry/Computations.md) — Utility computations on `Point` values.
- [`Loud`](Geometry/Loud.md) — Prepended onto a class to upper-case whatever its own `#describe` method returns, without needing to know that method's implementation.
- [`Named`](Geometry/Named.md) — Mixed into shape classes via `extend` (not `include`) to add a `.kind` class method, derived from the extending class's own name.
- [`ParseError`](Geometry/ParseError.md) — Raised when a string can't be parsed as a point.
- [`Point`](Geometry/Point.md) — A point in two-dimensional space.
- [`Polygon`](Geometry/Polygon.md) — A polygon: a shape with a fixed number of straight sides.
- [`Segment`](Geometry/Segment.md)
- [`Shape`](Geometry/Shape.md) — A generic two-dimensional shape.
- [`Taggable`](Geometry/Taggable.md) — Mixed into shape classes to add a short bracketed tag string, derived from whatever `#label` the including class defines.
- [`Triangle`](Geometry/Triangle.md) — A triangle: a polygon with exactly three sides.
- [`Vector`](Geometry/Vector.md) — An immutable 2D displacement vector.
