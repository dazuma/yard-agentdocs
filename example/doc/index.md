# yard-agentdocs example — API Reference

## How to navigate these docs

- **Path derivation:** a class/module's file path mirrors its fully-qualified
  name, with `::` becoming a directory separator — e.g. `Foo::Bar` is
  `Foo/Bar.md`, `Foo::Bar::Baz` is `Foo/Bar/Baz.md`. If you already know the
  FQN you're after, go straight to that path; the index below is only for
  discovering a name you don't have yet.
- **Member lookup:** every constant, attribute, and method is its own `### `
  heading inside its class/module's file — `` ### NAME `` for constants,
  `` ### #name `` for instance methods/attributes, `` ### .name `` for class
  methods. `grep -n '^### '` in one file lists every member there with its
  exact line number; e.g. `grep -rn '^### #each' .` finds the `#each` method
  across the whole tree without knowing which class it belongs to.
- **Inherited and mixed-in members aren't duplicated in full.** A
  class/module's file documents only members defined in its own source,
  plus a names-only **Inherited & Mixed-in Members** list in `## Member
  Summary` naming what its immediate superclass and directly-`include`d/
  `extend`ed modules each contribute — one hop only, not the full ancestry
  chain, and not anything from outside this project's own parsed source.
  For the actual docs behind any of those names, follow the
  `**Superclass:**`, `**Includes:**`, or `**Extends:**` link near the top
  of the file to that type's own file.
- **Trailing metadata uses `*`, not `-`.** A member's own content bullets
  (`**Params:**`, `**Returns:**`, `**Raises:**`, etc.) always use `- `.
  Deprecation/note/abstract flags, aliasing, and trailing `**Since:**`/
  `**Version:**`/`**Author:**`/`**Defined in:**` lines always use `* `
  instead, and stack with no blank line between them — a deliberate marker
  change so they never render as part of the preceding content list.

## Classes & modules

- [`Geometry`](Geometry.md) — A small toy geometry namespace, used as a worked example and test case for the `yard-agentdocs` output format.
- [`Geometry::Angles`](Geometry/Angles.md) — Angle-related helpers.
- [`Geometry::BoundingBox`](Geometry/BoundingBox.md) — An axis-aligned bounding box, whose four numeric edges are declared through a small class-level DSL (`.edge`) instead of individual `attr_reader`s.
- [`Geometry::Circle`](Geometry/Circle.md) — A circle, defined by its radius.
- [`Geometry::CompassRose`](Geometry/CompassRose.md) — Compass-bearing lookups, one instance method per cardinal direction.
- [`Geometry::Computations`](Geometry/Computations.md) — Utility computations on `Point` values.
- [`Geometry::Loud`](Geometry/Loud.md) — Prepended onto a class to upper-case whatever its own `#describe` method returns, without needing to know that method's implementation.
- [`Geometry::Named`](Geometry/Named.md) — Mixed into shape classes via `extend` (not `include`) to add a `.kind` class method, derived from the extending class's own name.
- [`Geometry::ParseError`](Geometry/ParseError.md) — Raised when a string can't be parsed as a point.
- [`Geometry::Path`](Geometry/Path.md) — An ordered sequence of points.
- [`Geometry::Point`](Geometry/Point.md) — A point in two-dimensional space.
- [`Geometry::Polygon`](Geometry/Polygon.md) — A polygon: a shape with a fixed number of straight sides.
- [`Geometry::Rectangle`](Geometry/Rectangle.md) — An axis-aligned rectangle, defined by its width and height.
- [`Geometry::Rounding`](Geometry/Rounding.md) — Rounding helpers.
- [`Geometry::Segment`](Geometry/Segment.md)
- [`Geometry::Shape`](Geometry/Shape.md) — A generic two-dimensional shape.
- [`Geometry::Taggable`](Geometry/Taggable.md) — Mixed into shape classes to add a short bracketed tag string, derived from whatever `#label` the including class defines.
- [`Geometry::ThreeD`](Geometry/ThreeD.md)
- [`Geometry::ThreeD::Point`](Geometry/ThreeD/Point.md) — A point in three-dimensional space.
- [`Geometry::Triangle`](Geometry/Triangle.md) — A triangle: a polygon with exactly three sides.
- [`Geometry::Vector`](Geometry/Vector.md) — An immutable 2D displacement vector.
- [`Geometry::Waypoint`](Geometry/Waypoint.md) — A labeled stop along a route, documented the way YARD supported before `attr_*` gained its own doc-comment convention: `@attr`/`@attr_reader`/ `@attr_writer` tags on the class docstring, rather than a comment above each reader/writer method.
- [`Stopwatch`](Stopwatch.md) — A simple stopwatch that accumulates elapsed time, in seconds.
