---
type: Ruby Class
title: WrappedProse::Member
description: "Stands in for a nested member whose summary is long enough to have wrapped in its parent's Member Summary bullet."
---

# class WrappedProse::Member

- **Superclass:** `Object`
- **Defined in:** `examples/rdoc/lib/wrapped_prose.rb`

Stands in for a nested member whose summary is long enough to have wrapped in its parent's Member Summary bullet.

## Member Summary

**Constants**

- `DIRECTIVES` — Directive letters, one per line: %w - a word %s - the separator.

**Instance Methods**

- `#join` — Joins `words` with `separator`, in a summary sentence long enough to have been split across lines by a 78-column re-wrap.

## Constants

### DIRECTIVES

- **Type:** `Object`
- **Value:** `%w[w s].freeze`

Directive letters, one per line:  
 %w - a word  
 %s - the separator

Each `<br>` is a hard break, which the summary surfaces render as a space.

* **Defined in:** `examples/rdoc/lib/wrapped_prose.rb:26`

## Instance Methods

### #join

```ruby
member.join(words, separator = " ") → String
```

Joins `words` with `separator`, in a summary sentence long enough to have been split across lines by a 78-column re-wrap.

A body paragraph past 78 columns, whose source lines are joined into one and must then stay that way in the output, with no break inserted.

*   A list item whose text also runs past 78 columns, so a re-wrap would have pushed its tail onto an indented continuation line.
*   A short item.

**Params:**

- `words` (`Array<String>`) — the words to join, in a description long enough that a 78-column re-wrap would have split it across two lines
- `separator` (`String`) — the separator

**Returns:**

- `String` — the joined words

* **Defined in:** `examples/rdoc/lib/wrapped_prose.rb:44`
