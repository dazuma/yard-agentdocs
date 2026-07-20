# yard-agentdocs example

A tiny toy library of geometric primitives and a stopwatch utility. It
exists purely as a worked example and test fixture for the
`yard-agentdocs` output format — it is not a real, published gem, and
this file is not meant to be read outside this project.

## Usage

Construct two points and measure the distance between them:

```ruby
a = Geometry::Point.new(1, 2)
b = Geometry::Point.new(4, 6)
Geometry::Segment.new(a, b).length
```

See {Geometry::Point} for the full point API, or {Stopwatch} for basic
elapsed-time tracking.

## Further reading

- The [CommonMark spec](https://spec.commonmark.org/), which this
  format's Markdown is meant to conform to.
