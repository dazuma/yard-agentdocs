# class Stopwatch

**Superclass:** `Object`
**Defined in:** `example/lib/stopwatch.rb`

A simple stopwatch that accumulates elapsed time, in seconds.

Defined at the top level (not nested inside any module), to exercise how
`yard-agentdocs` renders a class that isn't namespaced.

## Member Summary

**Class Methods**

- `.new` — Creates a stopwatch with no elapsed time yet recorded.

**Instance Methods**

- `#add` — Adds to the elapsed time.

## Class Methods

### .new

*(Ruby's default constructor; documents `#initialize`.)*

```ruby
Stopwatch.new() → Stopwatch
```

Creates a stopwatch with no elapsed time yet recorded.

**Defined in:** `example/lib/stopwatch.rb:13`

## Instance Methods

### #add

```ruby
stopwatch.add(seconds) → Float
```

Adds to the elapsed time.

**Params:**

- `seconds` (`Float`) — the number of seconds to add

**Returns:** `Float` — the new total elapsed time

**Defined in:** `example/lib/stopwatch.rb:23`
