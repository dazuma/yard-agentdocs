---
type: Ruby Class
title: Geometry::PointCloud
description: "A fixed collection of points."
---

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

`#average_point` exercises `@!attribute`-documented tags beyond a plain
description/`@return`: two stacked `@note` tags (also the only fixture
with more than one `@note` on the same object), plus `@deprecated`,
`@since`, and `@example`.

See [`Working with point clouds`](../file.point_cloud.md) for a worked example.

## Member Summary

**Instance Attributes**

- `#average_point` (read-only, deprecated) — The mean position of every point in the cloud — the original name for `#centroid`.
- `#centroid` (read-only) — the average position of all points in the cloud.
- `#size` (read-only) — The number of points in the cloud.

**Class Methods**

- `.new` — Creates a point cloud from the given points.

## Instance Attributes

### #average_point

- **Type:** [`Point`](Point.md)
- **Read-only.**

* **Deprecated.** Use `#centroid` instead; kept only for source compatibility, will be removed in 2.0.0.
* **Note:** Recomputes the average from every point on each call, just like `#centroid` — no memoization of its own.
* **Note:** Reads the point array with no synchronization; do not call while another thread mutates the cloud.

The mean position of every point in the cloud — the original name for `#centroid`.

**Examples:**

```ruby
cloud = PointCloud.new([Point.new(0, 0), Point.new(2, 0)])
cloud.average_point.x
#=> 1.0
```

* **Since:** 1.0.0
* **Defined in:** `example/lib/geometry/point_cloud.rb:57`

### #centroid

- **Type:** [`Point`](Point.md)
- **Read-only.**

the average position of all points in the cloud

* **Defined in:** `example/lib/geometry/point_cloud.rb:40`

### #size

- **Type:** `Integer`
- **Read-only.**

The number of points in the cloud.

* **Defined in:** `example/lib/geometry/point_cloud.rb:34`

## Class Methods

### .new

*(Ruby's default constructor; documents `#initialize`.)*

```ruby
PointCloud.new(points) → PointCloud
```

Creates a point cloud from the given points.

**Params:**

- `points` (`Array<`[`Point`](Point.md)`>`) — the points to collect

* **Defined in:** `example/lib/geometry/point_cloud.rb:66`
