---
okf_version: "0.2"
---

# yard-agentdocs rdoc-dialect fixture — API Reference

## Bundle info

* [`About this bundle`](bundle.md) - When this bundle was generated and by what, and how to look up Ruby classes, modules, methods, and other members in it. Read this first.

## Guides

* [`README`](file.README.md)
* [`A Markdown guide under --markup rdoc`](file.markdown_guide.md)
* [`Shebang-declared Markdown`](file.shebang_guide.md)

## Classes & modules

* [`AliasedMixin`](AliasedMixin.md) - Exercises a constant alias that a signature file redeclares as a module.
* [`AliasedMixin::Filtering`](AliasedMixin/Filtering.md) - Removes secrets from text.
* [`AliasedMixin::Host`](AliasedMixin/Host.md) - Includes and extends the aliased mixin.
* [`BlockMarkup`](BlockMarkup.md) - Exercises the block constructs RDoc's own markup gives no meaning to.
* [`Greeter`](Greeter.md) - Builds a greeting string.
* [`Provenance`](Provenance.md) - Exercises RBS provenance-marker stripping.
* [`TagConversion`](TagConversion.md) - Exercises RDoc::Markup::ToMarkdown's raw-HTML-leak bug.
* [`WrappedProse`](WrappedProse.md) - Exercises rdoc-dialect prose whose summary sentence runs on past a single source line, as most real-world RDoc summaries eventually do.
* [`WrappedProse::Member`](WrappedProse/Member.md) - Stands in for a nested member whose summary is long enough to have wrapped in its parent's Member Summary bullet.
