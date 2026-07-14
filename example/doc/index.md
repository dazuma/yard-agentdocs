# yard-agentdocs example — API Reference

## Classes & modules

- [`Geometry`](Geometry.md) — A small toy geometry namespace, used as a worked example and test case for the `yard-agentdocs` output format.
- [`Geometry::Angles`](Geometry/Angles.md) — Angle-related helpers.
- [`Geometry::Circle`](Geometry/Circle.md) — A circle, defined by its radius.
- [`Geometry::Computations`](Geometry/Computations.md) — Utility computations on `Point` values.
- [`Geometry::Loud`](Geometry/Loud.md) — Prepended onto a class to upper-case whatever its own `#describe` method returns, without needing to know that method's implementation.
- [`Geometry::Named`](Geometry/Named.md) — Mixed into shape classes via `extend` (not `include`) to add a `.kind` class method, derived from the extending class's own name.
- [`Geometry::ParseError`](Geometry/ParseError.md) — Raised when a string can't be parsed as a point.
- [`Geometry::Point`](Geometry/Point.md) — A point in two-dimensional space.
- [`Geometry::Polygon`](Geometry/Polygon.md) — A polygon: a shape with a fixed number of straight sides.
- [`Geometry::Rounding`](Geometry/Rounding.md) — Rounding helpers.
- [`Geometry::Segment`](Geometry/Segment.md)
- [`Geometry::Shape`](Geometry/Shape.md) — A generic two-dimensional shape.
- [`Geometry::Taggable`](Geometry/Taggable.md) — Mixed into shape classes to add a short bracketed tag string, derived from whatever `#label` the including class defines.
- [`Geometry::Triangle`](Geometry/Triangle.md) — A triangle: a polygon with exactly three sides.
- [`Geometry::Vector`](Geometry/Vector.md) — An immutable 2D displacement vector.
- [`Stopwatch`](Stopwatch.md) — A simple stopwatch that accumulates elapsed time, in seconds.
