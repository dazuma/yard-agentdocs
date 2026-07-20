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
- {file:example/docs/point_cloud.md the point cloud guide}, another
  `--files` guide beyond this README.
- {include:file:example/docs/point_cloud.md}, the same guide referenced
  again via `{include:file:...}`, an alias for `{file:...}`.
- {https://www.ruby-lang.org/en/}, exercising an unlabeled bracketed URL
  reference — a bare `{url}` resolves unconditionally to a plain link, no
  object/guide lookup involved.
- {https://en.wikipedia.org/wiki/Ruby_(programming_language) Ruby on Wikipedia},
  a labeled bracketed URL reference whose own URL contains unbalanced
  parentheses — exercising the angle-bracket destination escape
  (`(<url>)` instead of `(url)`) that keeps it from corrupting the
  surrounding Markdown link syntax.
