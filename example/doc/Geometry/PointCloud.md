# class Geometry::PointCloud

- **Superclass:** `Object`
- **Defined in:** `example/lib/geometry/point_cloud.rb`

A fixed collection of points.

Exercises YARD's `@!attribute` directive: `#size` isn't declared via
`attr_reader` or any of the `@attr`/`@attr_reader`/`@attr_writer` tags
([`Waypoint`](Waypoint.md)'s manual-pair fixture) — it's a bare `define_method` call
with no source declaration of its own for a docstring to attach to, so
`@!attribute [r]` supplies one directly. As with `@!method`/`@!macro`
(see [`BoundingBox`](BoundingBox.md), [`CompassRose`](CompassRose.md)), descriptive text has to be indented
*under* the directive line to become the attribute's own docstring — a
sibling-indented paragraph above the directive attaches to nothing.

`#centroid` exercises a distinct case: its `@!attribute` directive has
no indented free-text paragraph of its own at all — the only
description anywhere is the text inside its `@return` tag, so the
attribute's own docstring is genuinely empty.

See [`Working with point clouds`](../file.point_cloud.md) for a worked example.

## Member Summary

**Instance Attributes**

- `#centroid` (read-only) — the average position of all points in the cloud.
- `#size` (read-only) — The number of points in the cloud.

**Class Methods**

- `.new` — Creates a point cloud from the given points.

## Instance Attributes

### #centroid

- **Type:** [`Point`](Point.md)
- **Read-only.**

the average position of all points in the cloud

* **Defined in:** `example/lib/geometry/point_cloud.rb:35`

### #size

- **Type:** `Integer`
- **Read-only.**

The number of points in the cloud.

* **Defined in:** `example/lib/geometry/point_cloud.rb:29`

## Class Methods

### .new

*(Ruby's default constructor; documents `#initialize`.)*

```ruby
PointCloud.new(points) → PointCloud
```

Creates a point cloud from the given points.

**Params:**

- `points` (`Array<`[`Point`](Point.md)`>`) — the points to collect

* **Defined in:** `example/lib/geometry/point_cloud.rb:44`
