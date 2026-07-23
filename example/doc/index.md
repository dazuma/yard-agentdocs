---
okf_version: "0.1"
---

# yard-agentdocs example — API Reference

## Guides

* [`Navigating these docs`](navigating.md) - How to look up Ruby classes, modules, methods, and other members, and how to interpret entries in this knowledge bundle.
* [`README`](file.README.md)
* [`Working with point clouds`](file.point_cloud.md)

## Classes & modules

* [`Geometry`](Geometry.md) - A small toy geometry namespace, used as a worked example and test case for the `yard-agentdocs` output format.
* [`Geometry::Angles`](Geometry/Angles.md) - Angle-related helpers.
* [`Geometry::BoundingBox`](Geometry/BoundingBox.md) - An axis-aligned bounding box, whose four numeric edges are declared through a small class-level DSL (`.edge`) instead of individual `attr_reader`s.
* [`Geometry::Cache`](Geometry/Cache.md) (private API) - An internal memoization cache used by a few computation-heavy methods elsewhere in this namespace.
* [`Geometry::Circle`](Geometry/Circle.md) - A circle, defined by its radius.
* [`Geometry::CompassRose`](Geometry/CompassRose.md) - Compass-bearing lookups, one instance method per cardinal direction.
* [`Geometry::Computations`](Geometry/Computations.md) - Utility computations on `Point` values.
* [`Geometry::Loud`](Geometry/Loud.md) - Prepended onto a class to upper-case whatever its own `#describe` method returns, without needing to know that method's implementation.
* [`Geometry::Named`](Geometry/Named.md) - Mixed into shape classes via `extend` (not `include`) to add a `.kind` class method, derived from the extending class's own name.
* [`Geometry::ParseError`](Geometry/ParseError.md) - Raised when a string can't be parsed as a point.
* [`Geometry::Path`](Geometry/Path.md) - An ordered sequence of points.
* [`Geometry::Point`](Geometry/Point.md) - A point in two-dimensional space.
* [`Geometry::PointCloud`](Geometry/PointCloud.md) - A fixed collection of points.
* [`Geometry::Polygon`](Geometry/Polygon.md) - A polygon: a shape with a fixed number of straight sides.
* [`Geometry::Rectangle`](Geometry/Rectangle.md) - An axis-aligned rectangle, defined by its width and height.
* [`Geometry::Rounding`](Geometry/Rounding.md) - Rounding helpers.
* [`Geometry::Segment`](Geometry/Segment.md)
* [`Geometry::Shape`](Geometry/Shape.md) - A generic two-dimensional shape.
* [`Geometry::Taggable`](Geometry/Taggable.md) - Mixed into shape classes to add a short bracketed tag string, derived from whatever `#label` the including class defines.
* [`Geometry::ThreeD`](Geometry/ThreeD.md)
* [`Geometry::ThreeD::Point`](Geometry/ThreeD/Point.md) - A point in three-dimensional space, analogous to [`Geometry::Point`](Geometry/Point.md).
* [`Geometry::Triangle`](Geometry/Triangle.md) - A triangle: a polygon with exactly three sides.
* [`Geometry::Vector`](Geometry/Vector.md) - An immutable 2D displacement vector.
* [`Geometry::Waypoint`](Geometry/Waypoint.md) - A labeled stop along a route, documented the way YARD supported before `attr_*` gained its own doc-comment convention: `@attr`/`@attr_reader`/ `@attr_writer` tags on the class docstring, rather than a comment above each reader/writer method.
* [`Stopwatch`](Stopwatch.md) - A simple stopwatch that accumulates elapsed time, in seconds.
