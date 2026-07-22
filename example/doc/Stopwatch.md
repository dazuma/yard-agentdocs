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

**Instance Attributes**

- `#clock_bias` — Advanced only. A manual offset, in seconds, added to every `#measure` reading to compensate for known clock drift.
- `#display_precision` — Optional. The number of decimal places to include when formatting elapsed time as a string.
- `#label_style` — The formatting style applied when rendering `#tag` for display — `"plain"`, `"bold"`, `"colored"`, etc.
- `#legacy_tag` — Deprecated.
- `#log_level` — The severity level to log at, e.g. `"debug"`, `"info"`, or `"warn"`.
- `#rounding_mode` — Which way to round elapsed time when display precision truncates a fractional second, i.e. `:up` or `:down`.

**Class Methods**

- `.clock_resolution` — The clock's reported resolution, in seconds — how precise `#measure`'s timing can actually be.
- `.configure` — Configures `.verbose` and `.log_target` together in one call.
- `.log_target` — Where `.verbose` diagnostic output is written.
- `.log_target=` — Sets `.log_target`.
- `.new` — Creates a stopwatch with no elapsed time yet recorded.

**Instance Methods**

- `#<=>` — Compares this stopwatch's elapsed time to another's, per Ruby's `<=>` convention.
- `#accrue` — **Alias for:** `#add`
- `#add` — Adds to the elapsed time.
- `#add_forwarded` — Forwards every argument (and any block) it's called with to `#add`, using Ruby's `...` argument-forwarding shorthand.
- `#add_forwarded_anon` — Forwards its arguments and block to `#add`, the same as `#add_forwarded`, but spelled with Ruby's fully anonymous splat/double-splat/block parameters (`*, **, &`) instead of `...`.
- `#describe` — Builds a descriptive label for this stopwatch.
- `#introspect` — **Alias for:** `#inspect`
- `#measure` — Runs the given block and adds how long it took to this stopwatch's elapsed time.
- `#raw_elapsed_s` (private API) — Formats the elapsed time for internal diagnostic tooling.
- `#reset` — Resets the elapsed time.
- `#restart` — **Alias for:** `#reset`
- `#stringify` — **Alias for:** `#to_s`
- `#tag` — A short identifier for this stopwatch, useful for grouping related log entries.
- `#tag=` — Sets `#tag`.

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

* **Defined in:** `example/lib/stopwatch.rb:69`

## Instance Attributes

### #clock_bias

- **Type:** `Float`

Advanced only. A manual offset, in seconds, added to every `#measure`
reading to compensate for known clock drift. Defaults to `0.0`.

Same merge as `#display_precision`, but proves the heuristic also
accepts a two-word leading sentence, not just a one-word one.

* **Defined in:** `example/lib/stopwatch.rb:360`

### #display_precision

- **Type:** `Integer`

Optional. The number of decimal places to include when formatting
elapsed time as a string. Defaults to `3`.

Exercises the low-information leading-sentence merge: a naive
first-sentence scan would otherwise summarize this attribute as just
`"Optional."`, with the actually useful content invisible until the
full entry below the Member Summary.

* **Defined in:** `example/lib/stopwatch.rb:349`

### #label_style

- **Type:** `String`

The formatting style applied when rendering `#tag` for display —
`"plain"`, `"bold"`, `"colored"`, etc. Additional styles may be
added later.

Unlike `#log_level`/`#rounding_mode`, `"etc."` is deliberately not
on the skip-list — it can legitimately end a sentence, so this
summary should still stop right after it.

* **Defined in:** `example/lib/stopwatch.rb:336`

### #legacy_tag

- **Type:** `String, nil`

Deprecated.

Use `#tag` instead; new code should not read or write this directly.

Proves the merge does *not* cross a paragraph break: even though
`"Deprecated."` is short enough to qualify, the explanation above is a
separate paragraph, so the summary must stay just `"Deprecated."`.

* **Defined in:** `example/lib/stopwatch.rb:373`

### #log_level

- **Type:** `String`

The severity level to log at, e.g. `"debug"`, `"info"`, or `"warn"`.
Defaults to `"info"`.

Exercises `Docstring#summary`'s abbreviation skip-list: a naive scan
would otherwise treat "e.g."'s period as the sentence's end.

* **Defined in:** `example/lib/stopwatch.rb:312`

### #rounding_mode

- **Type:** `Symbol`

Which way to round elapsed time when display precision truncates a
fractional second, i.e. `:up` or `:down`. Defaults to `:up`.

Same skip-list as `#log_level`, but for `"i.e."` instead of `"e.g."` —
proves the fix applies to every abbreviation on the list.

* **Defined in:** `example/lib/stopwatch.rb:323`

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

* **Defined in:** `example/lib/stopwatch.rb:78`

### .configure

```ruby
Stopwatch.configure(opts = {}) → void
Stopwatch.configure(verbose: false, log_target: $stderr) → void
```

Configures `.verbose` and `.log_target` together in one call.

Exercises per-overload `@option`, `@deprecated`, and `@note` — a
legacy hash-options call form migrating to a keyword-args one, kept
side by side during a deprecation window, the way many gems handled
the Ruby 2.7/3.0 keyword-argument separation. No real-world precedent
for any of these nested inside a specific `@overload` was found in the
gems reviewed so far; included anyway by explicit human decision (see
DESIGN.md's per-overload checklist item).

**`Stopwatch.configure(opts = {}) → void`**

* **Deprecated.** Use the keyword form instead.

The original, hash-based calling form, kept for backward
compatibility.

**Params:**

- `opts` (`Hash`) — the settings to apply

**Options (`opts`):**

- `:verbose` (`Boolean`, default `false`) — whether to log diagnostic output
- `:log_target` (`IO`, default `$stderr`) — where to write it

**Returns:**

- `void`

**`Stopwatch.configure(verbose: false, log_target: $stderr) → void`**

* **Note:** Unlike the hash form, an unrecognized keyword raises
  immediately instead of being silently ignored.

The current, keyword-based calling form.

**Params:**

- `verbose` (`Boolean`) — whether to log diagnostic output
- `log_target` (`IO`) — where to write it

**Returns:**

- `void`

* **Defined in:** `example/lib/stopwatch.rb:112`

### .log_target

```ruby
Stopwatch.log_target() → IO
```

Where `.verbose` diagnostic output is written. `$stderr` until
changed.

**Returns:**

- `IO`

* **Defined in:** `example/lib/stopwatch.rb:127`

### .log_target=

```ruby
Stopwatch.log_target = value
```

Sets `.log_target`. Hand-written instead of `attr_writer` so it can
validate — an explicit `def name=(value)` not registered via
`attr_*`, exercising a plain assignment method's rendering at class
scope (as opposed to `.verbose=`, generated by `attr_accessor` above).

**Params:**

- `value` (`IO`) — the stream to write diagnostic output to

**Raises:**

- `TypeError` — if `value` doesn't respond to `#puts`

* **Defined in:** `example/lib/stopwatch.rb:140`

### .new

*(Ruby's default constructor; documents `#initialize`.)*

```ruby
Stopwatch.new() → Stopwatch
```

Creates a stopwatch with no elapsed time yet recorded.

* **Defined in:** `example/lib/stopwatch.rb:52`

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

* **Defined in:** `example/lib/stopwatch.rb:276`

### #accrue

```ruby
stopwatch.accrue(seconds) → Float
```

* **Alias for:** `#add`

Older name for `#add`, from an earlier version of this API.

#### Migrating

Prefer `#add` in new code. `#accrue` is kept only so callers written
against the 1.x API keep working.

* **Defined in:** `example/lib/stopwatch.rb:166`

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

* **Defined in:** `example/lib/stopwatch.rb:154`

### #add_forwarded

```ruby
stopwatch.add_forwarded(...) → Float
```

Forwards every argument (and any block) it's called with to `#add`,
using Ruby's `...` argument-forwarding shorthand.

**Returns:**

- `Float` — see `#add`

* **Defined in:** `example/lib/stopwatch.rb:174`

### #add_forwarded_anon

```ruby
stopwatch.add_forwarded_anon(*, **, &) → Float
```

Forwards its arguments and block to `#add`, the same as
`#add_forwarded`, but spelled with Ruby's fully anonymous
splat/double-splat/block parameters (`*, **, &`) instead of `...`.

**Returns:**

- `Float` — see `#add`

* **Defined in:** `example/lib/stopwatch.rb:185`

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

* **Defined in:** `example/lib/stopwatch.rb:248`

### #introspect

```ruby
stopwatch.introspect()
```

* **Alias for:** `#inspect`

Older name for `#inspect`, from an earlier diagnostics helper. Prefer
`#inspect` in new code.

* **Defined in:** `example/lib/stopwatch.rb:214`

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

* **Defined in:** `example/lib/stopwatch.rb:224`

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

* **Defined in:** `example/lib/stopwatch.rb:263`

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

* **Defined in:** `example/lib/stopwatch.rb:204`

### #restart

```ruby
stopwatch.restart(to = DEFAULT_ELAPSED) → Float
```

* **Alias for:** `#reset`

* **Defined in:** `example/lib/stopwatch.rb:207`

### #stringify

```ruby
stopwatch.stringify()
```

* **Alias for:** `#to_s`

* **Defined in:** `example/lib/stopwatch.rb:208`

### #tag

```ruby
stopwatch.tag() → String, nil
```

A short identifier for this stopwatch, useful for grouping related log
entries. `nil` until explicitly set.

**Returns:**

- `String, nil`

* **Defined in:** `example/lib/stopwatch.rb:286`

### #tag=

```ruby
stopwatch.tag = value
```

Sets `#tag`. Hand-written instead of `attr_writer` so it can
validate — an explicit `def name=(value)` not registered via
`attr_*`, exercising a plain assignment method's rendering.

**Params:**

- `value` (`String`) — the new tag; must not be empty

**Raises:**

- `ArgumentError` — if `value` is empty

* **Defined in:** `example/lib/stopwatch.rb:298`
