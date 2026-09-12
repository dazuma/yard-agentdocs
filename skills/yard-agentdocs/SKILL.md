---
name: yard-agentdocs
description: Look up Ruby API reference details — classes, modules, methods, signatures, parameters, return values — for a gem the project depends on. Use whenever you need to know how to use a gem's API, before reading gem source or searching the web.
---

# Ruby gem API lookup

Installed gems can have agent-optimized reference docs: a tree of Markdown files you
read one at a time, instead of grepping the gem's source.

**Dependencies only.** For the project you are editing, read its own source — that is
authoritative and already in front of you.

## Before anything else

Run `toys --version`. If `toys` is missing or older than 0.24, run `gem install toys`
or `gem update toys`. If that fails for any reason, stop using this skill entirely and
read gem source instead; half-applying this procedure is worse than not starting it.

Run every command here outside `bundle exec`, which redirects the gem home.

## Looking something up

1. **Resolve the version.** From `Gemfile.lock` if the project has one
   (`grep -E '^    <name> \(' Gemfile.lock` — four spaces, to hit the resolved spec
   rather than a constraint), otherwise the newest in `gem list <name>`.
2. **Compute the path.** `$XDG_DATA_HOME/yard-agentdocs/gems/<name>-<version>`, where
   `$XDG_DATA_HOME` defaults to `~/.local/share`. Nothing inside a tree names its gem
   or version — that path is the only identity it has.
3. **Find the one file you need.** A class or module's file is its fully qualified
   name with `::` converted to directory separators: `Toys::Acceptor::Enum` is
   documented in `Toys/Acceptor/Enum.md`.
4. **Grep for the member.** Every constant, attribute, and method has its own `### `
   heading inside the file — `### NAME` for constants, `### #name` for instance
   methods/attributes, `### .name` for class methods. Grep for the individual member,
   or `grep -n '^### '` lists every member with its exact starting line number.

If the tree isn't there, build it (below) and continue.

**Never read `index.md`** — on a large gem it can be very long. Grep it instead:
`grep -i <term> index.md` for a name you can't quite recall, or
`grep -rn '^### #method_name' .` across the tree when you know only the member name.

Read `bundle.md` only when a lookup doesn't resolve the way you expected. It documents
the format's conventions in full, and is the authority on them.

## Building a tree that doesn't exist

```
toys do --gem=yard-agentdocs --on-missing-gem=install agentdocs gems <name>:<version>
```

Build exactly the version you resolved, and never `--all`. **Never read a different
version's tree** because it happens to exist — that is a plausible, silently wrong
answer.

Large gems take several minutes. Use a generous timeout, and if one expires, check
whether the tree exists now before retrying.

Trees never expire: `generated` in `bundle.md` is provenance, not freshness. A tree
documents one frozen gem release, so its age is never a reason to rebuild.

## When to stop and read source

Stop when the file for the name doesn't exist, or exists with no `### ` heading
matching the member — not because a tree looks thin. Then read the gem's own source.
`**Defined in:**` paths are relative to the gem root, which the tree does not record,
so get the root from `bundle show <name>`, or
`ruby -e 'puts Gem::Specification.find_by_name("<name>").gem_dir'`.

Skip all of the above and go straight to source for **Ruby's default gems** (`json`,
`set`, `logger` and friends — no trees are built for them) and for **git-, path-, or
vendored-source dependencies**, which have no computable tree path; `bundle show
<name>` gives you the checkout.

Prefer local source to documentation on the web. If you do consult the web, confirm it
describes the version this project actually uses.

## Example

*What arguments does `Toys::Acceptor::Enum.new` take?*

```
grep -E '^    toys \(' Gemfile.lock                     # → toys (0.24.0)
D=~/.local/share/yard-agentdocs/gems/toys-0.24.0        # exists
grep -n '^### \.new' -A 18 $D/Toys/Acceptor/Enum.md
```

One file, one read — no source, no web.
