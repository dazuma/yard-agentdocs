---
type: Ruby Class
title: Formatter
description: "Formats values as plain text."
---

# class Formatter

- **Superclass:** `Object`
- **Defined in:** `examples/text/lib/formatter.rb`

```text
Formats values as plain text. This docstring is written under
--markup text, so its line breaks are kept and *stars* stay literal.

# A top-of-line hash, not a heading

    A 4-space indent, not a code block
```

## Member Summary

**Instance Methods**

- `#format` — Formats one value, keeping this line break.

## Instance Methods

### #format

```ruby
formatter.format(value) → String
```

```text
Formats one value, keeping
this line break.
```

**Params:**

- `value` (`Object`) — the value to format, described over two lines of text

**Returns:**

- `String` — the value as *text*

**See also:**

- `Formatter` — the class this method belongs to

* **Since:** 1.0
* **Defined in:** `examples/text/lib/formatter.rb:22`
