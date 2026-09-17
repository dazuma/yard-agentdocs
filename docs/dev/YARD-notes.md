# YARD notes

Traps and non-obvious behavior in YARD itself, collected while building this
plugin. None of these are decisions — they are facts about the tool, kept here
because each one costs a session to rediscover and none has a single place in
this repository's code where a comment would be encountered in time.

Anything that *does* have such a place is documented there instead, not here.

## Template mechanics

**The directory is `fulldoc`, not `fulldocs`.** `Engine.generate` dispatches
through `template(options.template, :fulldoc, options.format)` — mechanically
singular. The typo is easy and silently means "no such template" at runtime,
with no error naming the directory it looked for.

**`T()` decorates its argument at runtime but not at `setup.rb` top level.**
Called from an instance method (inside `fulldoc`'s `init`, say), `T(:module)`
prepends `options.template` and appends `options.format`, resolving to
`default/module/agentdocs`. Called in class-method context at the top of a
`setup.rb` — `include T(...)` — it does no such decoration and needs the full
literal path, exactly as upstream's own `class/setup.rb` writes
`include T('default/module')`.

**`bundle exec yard doc -f agentdocs` alone will not find the template.**
Bundler activates a path-based gem dependency but never `require`s it. Either
pass `-e ./lib/yard-agentdocs.rb` so the file registers its template path, or
install the gem for real and let YARD's `yard-*` plugin autoload find it.

## Registry and parsing

**`Object`, `BasicObject`, and `Kernel` are never in the Registry** unless
their source was actually parsed. They appear only as unresolved `Proxy`
stand-ins carrying no ancestry or mixin data, so nothing about their own
superclass or includes can be derived from the registry. Any unparsed ancestor
behaves the same way.

**`Docstring#all` reconstructs the entire original comment, tags included.**
For a method with `@param`/`@return`/`@see`, `.all` returns the prose *plus*
the raw `@param ...` / `@return ...` lines. Prose-only rendering wants the
plain `Docstring` (`object.docstring`) instead — reaching for `.all` because
it sounds like "the whole docstring" is the trap.

**Method line numbers are the `def` line itself**, not a preceding comment or
blank line. Worth knowing when hand-authoring a fixture: adding or removing a
single comment line shifts every `def` below it, and every `**Defined in:**`
line that records one.

**Constant values are raw source text, implicit receivers included.**
`Point::ORIGIN = new(0, 0)`, written inside `class Point`, records verbatim as
`"new(0, 0)"` — not `"Point.new(0, 0)"`. The registry does no expansion and
neither does this template.

## Harmless noise

**Three "method redefined" warnings on first parse.** The first time anything
calls `YARD.parse` in a process, YARD's own `parser/ruby/ruby_parser.rb`
prints `on_hshptn`, `on_aryptn`, and `on_fndptn` warnings. It is intentional
upstream — a per-event codegen pass defines a default handler for every Ripper
event, and hand-written pattern-matching-aware versions later in the same file
redefine those three. Nothing to fix here; it is lazily triggered, which is
why it only appears once something actually drives the parser.
