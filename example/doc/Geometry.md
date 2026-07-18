# module Geometry

- **Defined in:** `example/lib/geometry.rb`

A small toy geometry namespace, used as a worked example and test case for
the `yard-agentdocs` output format.

Exists purely to group its nested classes and modules; it defines no
behavior of its own. Not part of the shipped gem.

#### Usage

Construct two points and measure the distance between them:

```ruby
# build two points and measure the distance between them
a = Geometry::Point.new(1, 2)
b = Geometry::Point.new(4, 6)
Geometry::Segment.new(a, b).length
```

#### Further reading

- The [CommonMark spec](https://spec.commonmark.org/), which this output
  format's Markdown is meant to conform to.
- The [YARD documentation](https://yardoc.org/) for the docstring markup
  this namespace's own comments are written in.

##### Caveat

This heading is already below the level this format's own hierarchy
reserves, so it renders unchanged.

## Member Summary

**Nested Classes & Modules**

- [`Angles`](Geometry/Angles.md) — Angle-related helpers.
- [`BoundingBox`](Geometry/BoundingBox.md) — An axis-aligned bounding box, whose four numeric edges are declared through a small class-level DSL (`.edge`) instead of individual `attr_reader`s.
- [`Circle`](Geometry/Circle.md) — A circle, defined by its radius.
- [`CompassRose`](Geometry/CompassRose.md) — Compass-bearing lookups, one instance method per cardinal direction.
- [`Computations`](Geometry/Computations.md) — Utility computations on `Point` values.
- [`Loud`](Geometry/Loud.md) — Prepended onto a class to upper-case whatever its own `#describe` method returns, without needing to know that method's implementation.
- [`Named`](Geometry/Named.md) — Mixed into shape classes via `extend` (not `include`) to add a `.kind` class method, derived from the extending class's own name.
- [`ParseError`](Geometry/ParseError.md) — Raised when a string can't be parsed as a point.
- [`Path`](Geometry/Path.md) — An ordered sequence of points.
- [`Point`](Geometry/Point.md) — A point in two-dimensional space.
- [`PointCloud`](Geometry/PointCloud.md) — A fixed collection of points.
- [`Polygon`](Geometry/Polygon.md) — A polygon: a shape with a fixed number of straight sides.
- [`Rectangle`](Geometry/Rectangle.md) — An axis-aligned rectangle, defined by its width and height.
- [`Rounding`](Geometry/Rounding.md) — Rounding helpers.
- [`Segment`](Geometry/Segment.md)
- [`Shape`](Geometry/Shape.md) — A generic two-dimensional shape.
- [`Taggable`](Geometry/Taggable.md) — Mixed into shape classes to add a short bracketed tag string, derived from whatever `#label` the including class defines.
- [`ThreeD`](Geometry/ThreeD.md)
- [`Triangle`](Geometry/Triangle.md) — A triangle: a polygon with exactly three sides.
- [`Vector`](Geometry/Vector.md) — An immutable 2D displacement vector.
- [`Waypoint`](Geometry/Waypoint.md) — A labeled stop along a route, documented the way YARD supported before `attr_*` gained its own doc-comment convention: `@attr`/`@attr_reader`/ `@attr_writer` tags on the class docstring, rather than a comment above each reader/writer method.
