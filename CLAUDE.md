# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

The `agentdocs` YARD template is implemented and generates output matching `examples/geometry/doc` when run
against `examples/geometry/lib` (see `templates/default/{fulldoc,module,class}/agentdocs/`, registered via
`lib/yard-agentdocs.rb`), verified by `test/test_agentdocs_template.rb`. Scope is
intentionally narrow: the fixture is the record of what is covered, and open gaps are
tracked as GitHub issues.

The gem also ships user-facing Toys tools in `toys/` (included in the gemspec, so users get
them via `load_gem "yard-agentdocs"`): `agentdocs build` documents a project directory,
`agentdocs gems` documents installed gems into
`<XDG data home>/yard-agentdocs/gems/<name>-<version>`, `agentdocs gems clean` removes those
bundles again, `agentdocs lookup` answers one API lookup against a gems bundle,
`agentdocs path` prints a gems bundle's directory as one bare line for shell composition, and
`agentdocs install-skill` installs the agent skill below into a harness's skills directory
(`--claude`, or `--output DIR` for anywhere else). Each tool file holds only the Toys DSL and
prompting; the behavior lives in
`lib/yard/agentdocs/{builder,gem_builder,gem_cleaner,lookup,bundle_path,bundle_locator,bundle_reader,dependency_resolver,skill_installer}.rb`,
so it is unit-tested and documented independently. A decision about a tool is recorded in the
class that implements it, as ordinary YARD documentation — see "Recording decisions" below.

`agentdocs lookup` is the **Reader** in `CONTEXT.md`'s sense: it *implements* `bundle.md`'s
mechanics rather than restating them. It is an accelerator, never a gateway — grepping a bundle
directly stays first-class, and the format, not the Reader, is the contract. So do not move
format mechanics into it as behavior the format itself no longer describes.

`agentdocs path` is what makes that first-class grep cheap to enter, by printing a bundle's
directory as one bare line and keeping everything else — build progress, every failure — on
standard error. That inverts `lookup`'s "the body is primary, on standard output"
rule, deliberately: one line of prose on standard output and `$( )` yields a path that is not
a path. A line there means a bundle is at that location and means nothing else, so never print
a gem root or a checkout path on it. Both tools locate their bundle through `BundleLocator`,
which owns version resolution and exists so the invariant has one implementation rather than
one per tool. `BundlePath`'s own documentation records why, and why every recipe the gem
publishes gates its grep on `&&`.

The gem additionally ships an agent skill at `skills/yard-agentdocs/SKILL.md` (in the gemspec),
installed by `agentdocs install-skill`. It is scoped to *routing and judgment only* — when to
prefer a generated bundle over gem source or the web, which lookups are in scope, when to give
up. Format mechanics belong to the generated `bundle.md`, CLI mechanics to the Toys tools’ own
`long_desc`, and anything the skill could only restate rather than enforce — deriving a bundle's
path, resolving a version, obtaining a missing bundle — belongs to the Reader. This split is
deliberate anti-drift, so do not move content across it. See the `Lookup` class's own
documentation.

Two properties of that skill look like violations of the split and are not. It routes
lookups for **dependencies only**, never consulting an `agentdocs build` tree: for the
project an agent is editing, that source is open, mutable, and authoritative, so a bundle
over it can only produce a wrong answer about code the agent could simply read. And it
states the one mechanic its happy path needs — deriving a path from an FQN — rather than
sending the agent to `bundle.md` every time, because reading a ~2KB preamble per lookup is
a real cost in a project whose pitch is token economy. The preamble stays the single
authority; it is consulted when a lookup does not resolve, not recited up front.

## Purpose

`yard-agentdocs` will be a Ruby gem implementing a [YARD](https://yardoc.org/) plugin. It provides a YARD
template that renders an "agent-friendly" yardoc output format: reference documentation structured for
consumption by coding agents (e.g. LLM-based tools) rather than for human browsing in a web browser.

The core problem being solved: agents that need to look up Ruby API details (method signatures, params,
return values, usage) currently have to search through source files or a human-oriented HTML yardoc site,
which burns a lot of input tokens and requires multi-step exploration. This gem should let an agent fetch
exactly the reference info it needs (e.g. one method's docs) with a single, cheap file read.

## Design

The output format is designed example-first. `examples/geometry/lib` holds hand-written
Ruby source exercising the YARD features the format cares about, and
`examples/geometry/doc` the hand-authored target output; `examples/rdoc` is the same
pair for the `--markup rdoc` path and for non-`.rb` input. Each pair is both the design
medium and the test fixture, asserted byte for byte.

`docs/dev/` is not shipped in the gem. Each tool's `long_desc` is the authoritative user
documentation for that tool.

### Coverage workflow

New format coverage is built test-first, and the loop is collaborative and human-gated —
the example files encode real design decisions, so they get reviewed before any
implementation code is touched.

1. The user picks what to tackle next.
2. Claude proposes the `examples/<tree>/lib` source exercising it and the
   `examples/<tree>/doc` output it should produce, asking about any design choice not
   already settled. For multi-line tag or docstring text, mirror the source comment's
   exact line breaks — the template preserves raw text verbatim rather than rewrapping.
3. The user reviews and iterates on those `examples/` changes. Nothing outside
   `examples/` is touched yet.
4. Once the user explicitly approves, Claude implements: confirm `toys test` fails
   against the new fixture, then change the template until it passes byte for byte. Fix
   the generator; never loosen the assertion.
5. Run `toys test` and `toys rubocop`.

Wait for the step-3 approval before implementing, even when the example changes look
finished — the review is the point of working test-first. Within a tree, source and
output files are discovered automatically; only a new file *extension* needs the glob in
`test/test_agentdocs_template.rb` edited.

### Recording decisions

Architecture decision records live in [`docs/adr/`](docs/adr/), numbered sequentially.
The bar is deliberately high, and all three of these must hold: the decision is hard to
reverse, it is surprising without context, and it was a real trade-off with genuine
alternatives. Most decisions in this repository do not clear it, which is intended.

Everything else is recorded where the code it governs is:

- **A decision local to one class** belongs in that class's own YARD documentation, where
  anyone modifying the code will encounter it. Only an invariant spanning several classes,
  with no single home, is a candidate for an ADR.
- **A rendering decision** is recorded by the `examples/*/doc` fixture, which the test suite
  asserts byte for byte. Do not also restate it in prose. What a fixture cannot record — a
  rejected alternative someone would otherwise re-propose, a trap the tests do not catch —
  goes in a comment at the code that would break.
- **CLI mechanics** belong in the tool's `long_desc`, which cannot drift from the tool.
- **YARD's own quirks** are not decisions at all and are not ADR material. Ones with no
  code home go in [`docs/dev/YARD-notes.md`](docs/dev/YARD-notes.md).

Do not write a decision log. A second one alongside `docs/adr/` is a drift surface, which is
the reason `docs/dev/Tooling.md` and `docs/dev/DESIGN.md` were both removed.

## Architecture

A YARD plugin, with the layout that implies. `lib/yard-agentdocs.rb` calling
`Templates::Engine.register_template_path` is the entire integration point — no custom
output format, no handler classes ([ADR-0003](docs/adr/0003-no-custom-handler-classes.md)).

Generation entrypoints, worth reading in this order — each `setup.rb` starts with a
comment explaining what that directory is responsible for:

- `templates/default/fulldoc/agentdocs/setup.rb` — the driver.
- `templates/default/module/agentdocs/setup.rb` — the shared rendering logic. Its header
  also holds the two conventions governing template and mixin code; read it before
  editing any `.erb`.
- `templates/default/class/agentdocs/setup.rb` — what only classes have.

`lib/yard/agentdocs/` holds two unrelated things: mixins `include`d by those `setup.rb`
files, and the implementation classes behind the `toys/` tools.

- [`docs/dev/YARD-notes.md`](docs/dev/YARD-notes.md) — traps in YARD itself. Read before
  debugging surprising template behavior; each one costs a session to rediscover.
- [`docs/adr/`](docs/adr/) — invariants spanning several classes.

## Commands

Tooling is driven by [Toys](https://dazuma.github.io/toys) (`gem install toys`), not Rake. Bundler is
wired into each tool, so none of these need `bundle exec`.

- `toys ci` — run the full CI suite (bundle, rubocop, tests, yardoc, gem build).
- `toys ci --only --test` — run a single CI job (any of `--bundle`, `--rubocop`, `--test`, `--yard`, `--build`).
- `toys test` — run the unit tests.
- `toys test test/test_version.rb` — run a single test file.
- `toys rubocop` — run the linter/style checker.
- `toys yardoc` — build docs. Fails on warnings and on any undocumented object, so every public
  class/module/method needs YARD comments.
- `toys build` / `toys install` — build (and install) the gem.

Run `toys test` and `toys rubocop` before committing.

## Conventions

- **Namespacing:** the gem is `yard-agentdocs`; code lives under `YARD::AgentDocs` (require path
  `yard/agentdocs`), reopening the `YARD` module from the `yard` gem since this is a plugin for it. The
  entry point `lib/yard-agentdocs.rb` just requires `yard/agentdocs`. Note this deliberately departs from
  the mechanical gem-name-to-module convention (`yard-agentdocs` would mechanically map to
  `YARD::Agentdocs`) for readability — same manual override RuboCop makes (`rubocop` → `RuboCop`, not
  `Rubocop`).
- **Tests:** Minitest, spec-style (`describe`/`it` blocks with `assert_*` assertions, not `must`/`wont`
  expectations). Test files follow `test_*.rb`. `minitest-focus` is available — add `focus` above a test
  to run only that one.
- **Ruby support:** `required_ruby_version >= 3.4`. All files use `# frozen_string_literal: true`.
- **Docs as a gate:** `toys yardoc` fails on undocumented objects, so document public API as you add it.
- **Changelog:** `CHANGELOG.md` is updated automatically by the release process. Never edit it as part
  of a task, and don't propose editing it.
- **Top-level constant references:** prefix references to Ruby core/stdlib and external-gem constants with
  a leading `::` (e.g. `::File`, `::Gem::Version`, `::YARD`), to avoid ambiguous resolution within nested
  namespaces. Do not prefix relative constants defined within the current namespace, and do not prefix
  Kernel method calls that look like constants (`Array(x)`, never `::Array(x)`).
- **License:** MIT.

## Agent skills

### Issue tracker

Issues live in this repo's GitHub Issues (`dazuma/yard-agentdocs`), via the `gh` CLI.
See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage roles, each label string equal to its name.
See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` plus `docs/adr/` at the repo root.
See `docs/agents/domain.md`.
