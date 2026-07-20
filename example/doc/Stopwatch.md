# class Stopwatch

- **Superclass:** `Object`
- **Defined in:** `example/lib/stopwatch.rb`

* **Note:** Not thread-safe: concurrent `#add`/`#measure` calls on the same
  stopwatch can lose updates.

A simple stopwatch that accumulates elapsed time, in seconds.

Defined at the top level (not nested inside any module), to exercise how
`yard-agentdocs` renders a class that isn't namespaced.

Call the reset method to start over.

* **Todo:** Support pausing/resuming instead of only accumulating.

  Would also need to decide whether a paused stopwatch's own `#describe`
  output should say so explicitly, or just look identical to a running
  one — a second paragraph purely to exercise a multi-paragraph tag
  (blank line and all) instead of a single wrapped one.

## Member Summary

**Constants**

- `DEFAULT_ELAPSED` — The elapsed time a newly created stopwatch starts at, and the default value `#reset` resets to.

**Class Attributes**

- `.verbose` — Whether class-level operations should log diagnostic output to `$stderr`.

**Class Methods**

- `.clock_resolution` — The clock's reported resolution, in seconds — how precise `#measure`'s timing can actually be.
- `.new` — Creates a stopwatch with no elapsed time yet recorded.

**Instance Methods**

- `#<=>` — Compares this stopwatch's elapsed time to another's, per Ruby's `<=>` convention.
- `#accrue` — **Alias for:** `#add`
- `#add` — Adds to the elapsed time.
- `#describe` — Builds a descriptive label for this stopwatch.
- `#measure` — Runs the given block and adds how long it took to this stopwatch's elapsed time.
- `#raw_elapsed_s` (private API) — Formats the elapsed time for internal diagnostic tooling.
- `#reset` — Resets the elapsed time.
- `#restart` — **Alias for:** `#reset`

## Constants

### DEFAULT_ELAPSED

- **Type:** `Float`
- **Value:** `0.0`

The elapsed time a newly created stopwatch starts at, and the default
value `#reset` resets to.

* **Defined in:** `example/lib/stopwatch.rb:28`

## Class Attributes

### .verbose

- **Type:** `Boolean`

Whether class-level operations should log diagnostic output to
`$stderr`. A `class << self`-defined attribute — should behave and
render the same as an instance-level `attr_accessor`, just at class
scope.

* **Defined in:** `example/lib/stopwatch.rb:54`

## Class Methods

### .clock_resolution

```ruby
Stopwatch.clock_resolution() → Float
```

The clock's reported resolution, in seconds — how precise
`#measure`'s timing can actually be. A `class << self`-defined
method — should render identically to `def self.foo`.

**Returns:**

- `Float`

* **Defined in:** `example/lib/stopwatch.rb:63`

### .new

*(Ruby's default constructor; documents `#initialize`.)*

```ruby
Stopwatch.new() → Stopwatch
```

Creates a stopwatch with no elapsed time yet recorded.

* **Defined in:** `example/lib/stopwatch.rb:41`

## Instance Methods

### #<=>

```ruby
stopwatch <=> other → Integer
```

Compares this stopwatch's elapsed time to another's, per Ruby's `<=>`
convention. Doesn't mix in `Comparable`, so this is the only comparison
operator available (no `<`, `>`, etc. — see [`Geometry::Point`](Geometry/Point.md), which
makes the same choice).

**Params:**

- `other` (`Stopwatch`) — the stopwatch to compare to

**Returns:**

- `Integer` — -1, 0, or 1

* **Defined in:** `example/lib/stopwatch.rb:170`

### #accrue

```ruby
stopwatch.accrue(seconds) → Float
```

* **Alias for:** `#add`

Older name for `#add`, from an earlier version of this API.

#### Migrating

Prefer `#add` in new code. `#accrue` is kept only so callers written
against the 1.x API keep working.

* **Defined in:** `example/lib/stopwatch.rb:88`

### #add

```ruby
stopwatch.add(seconds) → Float
```

* **Also known as:** `#accrue`

Adds to the elapsed time.

**Params:**

- `seconds` (`Float`) — the number of seconds to add

**Returns:**

- `Float` — the new total elapsed time

* **Defined in:** `example/lib/stopwatch.rb:76`

### #describe

```ruby
stopwatch.describe(name, precision = 1, *tags, unit:, separator: ", ", **metadata, &block) → String
```

Builds a descriptive label for this stopwatch. Combines every parameter
shape this format's signature line can render — a required positional
argument, an optional positional argument, a splat, a required keyword,
an optional keyword, a double-splat, and a block — in one signature,
purely to exercise how they assemble together; not a realistic
formatting API.

**Params:**

- `name` (`String`) — the stopwatch's label
- `precision` (`Integer`) — decimal places to round the elapsed time to
- `tags` (`Array<String>`) — extra tags to include
- `unit` (`String`) — the unit label, e.g. `"s"`
- `separator` (`String`) — the string used to join the tags
- `metadata` (`Hash{Symbol => Object}`) — arbitrary extra key/value pairs to include
- `block` (`Proc`) — a block to post-process the label, used instead of it if given

**Returns:**

- `String` — the assembled label

* **Defined in:** `example/lib/stopwatch.rb:142`

### #measure

```ruby
stopwatch.measure(&block) → Object
```

Runs the given block and adds how long it took to this stopwatch's
elapsed time.

**Yields:**

- the work to time

**Yield Returns:**

- `Object` — the block's own return value, passed through unchanged

**Returns:**

- `Object` — the block's return value

* **Defined in:** `example/lib/stopwatch.rb:118`

### #raw_elapsed_s

```ruby
stopwatch.raw_elapsed_s() → String
```

* **Private API.**

Formats the elapsed time for internal diagnostic tooling. Kept public so
other objects in this library can call it directly, but not meant to be
part of the stable public API.

**Returns:**

- `String` — the elapsed time, in seconds, as a plain string

* **Defined in:** `example/lib/stopwatch.rb:157`

### #reset

```ruby
stopwatch.reset(to = DEFAULT_ELAPSED) → Float
```

* **Also known as:** `#restart`

Resets the elapsed time.

**Params:**

- `to` (`Float`) — the elapsed time to reset to; defaults to
  `DEFAULT_ELAPSED`, which returns the stopwatch to its just-created,
  zeroed state

**Returns:**

- `Float` — the new elapsed time

* **Defined in:** `example/lib/stopwatch.rb:105`

### #restart

```ruby
stopwatch.restart(to = DEFAULT_ELAPSED) → Float
```

* **Alias for:** `#reset`

* **Defined in:** `example/lib/stopwatch.rb:108`
