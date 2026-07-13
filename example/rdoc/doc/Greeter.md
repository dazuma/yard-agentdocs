# class Greeter

**Superclass:** `Object`
**Defined in:** `example/rdoc/lib/greeter.rb`

Builds a greeting string. Written in **RDoc** markup instead of Markdown, to
exercise the `rdoc` dialect of the "Docstring markup dialect" decision. See
the [RDoc markup reference](https://ruby.github.io/rdoc/RDoc/Markup.html) for
the full grammar, and note this paragraph's bare {Greeter#greet} reference is
left unresolved for now (a separate, not-yet-built checklist item).

## Member Summary

**Instance Methods**

- `#greet` — Greets `name`, wrapping it in *emphasis*.

## Instance Methods

### #greet

```ruby
greeter.greet(name) → String
```

Greets `name`, wrapping it in *emphasis*.

**Params:**

- `name` (`String`) — the `name` to greet

**Returns:** `String` — the greeting, with `name` emphasized

**Defined in:** `example/rdoc/lib/greeter.rb:18`
