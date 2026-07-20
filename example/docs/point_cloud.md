# @title Working with point clouds

# Working with point clouds

A short guide beyond the top-level README, exercising a `--files` guide
that isn't the README itself — including one that lives in a
subdirectory, to prove a guide's rendered name is derived from its own
basename, not its path.

## Building a cloud

{Geometry::PointCloud} wraps a fixed set of {Geometry::Point} values:

```ruby
cloud = Geometry::PointCloud.new([
  Geometry::Point.new(0, 0),
  Geometry::Point.new(1, 1),
])
cloud.size
```
