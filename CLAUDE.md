# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

The `agentdocs` YARD template is implemented and generates output matching `examples/geometry/doc` when run
against `examples/geometry/lib` (see `templates/default/{fulldoc,module,class}/agentdocs/`, registered via
`lib/yard-agentdocs.rb`), verified by `test/test_agentdocs_template.rb`. Scope is intentionally narrow —
see `docs/dev/DESIGN.md`'s "Example coverage checklist" for what's covered vs. still open. See "Design"
below for the full rationale and implementation notes.

Remaining checklist coverage is built test-first and human-gated, per
`docs/dev/DESIGN.md`'s "Coverage workflow (TDD loop)": the user picks the next
checklist item(s), Claude proposes `examples/geometry/lib`/`examples/geometry/doc` changes for
review/iteration, and only once the user explicitly approves those does
Claude touch `test/test_agentdocs_template.rb` or the template implementation.
Do not jump ahead to implementation on your own initiative. Unchecked
checklist items carry (design)/(mech)/(stretch) priority markers — see
DESIGN.md's "Prioritization and roadmap" for what they mean and how the next
item gets picked.

The gem also ships user-facing Toys tools in `toys/` (included in the gemspec, so users get
them via `load_gem "yard-agentdocs"`): `agentdocs build` documents a project directory,
`agentdocs gems` documents installed gems into
`<XDG data home>/yard-agentdocs/gems/<name>-<version>`, `agentdocs gems clean` removes those
bundles again, `agentdocs lookup` answers one API lookup against a gems bundle, and
`agentdocs install-skill` installs the agent skill below into a harness's skills directory
(`--claude`, or `--output DIR` for anywhere else). Each tool file holds only the Toys DSL and
prompting; the behavior lives in
`lib/yard/agentdocs/{builder,gem_builder,gem_cleaner,lookup,bundle_reader,dependency_resolver,skill_installer}.rb`,
so it is unit-tested and documented independently. Decisions about the tools go in
`docs/dev/Tooling.md`, never `DESIGN.md`.

`agentdocs lookup` is the **Reader** in `CONTEXT.md`'s sense: it *implements* `bundle.md`'s
mechanics rather than restating them. It is an accelerator, never a gateway — grepping a bundle
directly stays first-class, and the format, not the Reader, is the contract. So do not move
format mechanics into it as behavior the format itself no longer describes.

The gem additionally ships an agent skill at `skills/yard-agentdocs/SKILL.md` (in the gemspec),
installed by `agentdocs install-skill`. It is scoped to *routing and judgment only* — when to
prefer a generated bundle over gem source or the web, which lookups are in scope, when to give
up. Format mechanics belong to the generated `bundle.md`, CLI mechanics to the Toys tools’ own
`long_desc`, and anything the skill could only restate rather than enforce — deriving a bundle's
path, resolving a version, obtaining a missing bundle — belongs to the Reader. This split is
deliberate anti-drift, so do not move content across it. See "Agent skill written (2026-09-12)"
under "Decisions" in `docs/dev/DESIGN.md`, and "The `agentdocs lookup` Reader (2026-09-15)" in
`docs/dev/Tooling.md`.

## Purpose

`yard-agentdocs` will be a Ruby gem implementing a [YARD](https://yardoc.org/) plugin. It provides a YARD
template that renders an "agent-friendly" yardoc output format: reference documentation structured for
consumption by coding agents (e.g. LLM-based tools) rather than for human browsing in a web browser.

The core problem being solved: agents that need to look up Ruby API details (method signatures, params,
return values, usage) currently have to search through source files or a human-oriented HTML yardoc site,
which burns a lot of input tokens and requires multi-step exploration. This gem should let an agent fetch
exactly the reference info it needs (e.g. one method's docs) with a single, cheap file read.

## Design

Read [`docs/dev/DESIGN.md`](docs/dev/DESIGN.md) for the current design thinking and the list of open
questions (output format, file granularity, lookup/indexing, YARD integration mechanics, cross-referencing).
It's a living document — keep it updated as decisions are made. `docs/dev/` is not shipped in the gem.

`DESIGN.md` covers the generated format only. Decisions about the shipped Toys tools and their
support classes go in [`docs/dev/Tooling.md`](docs/dev/Tooling.md) instead — dated section per
decision, with the rejected alternatives named. Each tool's `long_desc` remains the authoritative
user documentation; `Tooling.md` records only the reasoning behind it.

We're designing the output format example-first: `examples/geometry/lib` will hold hand-written Ruby source
exercising the YARD features we care about, and `examples/geometry/doc` will hold the hand-authored target
output we iterate on directly, before any template/generation code exists. Once stable, that pair becomes the test
fixture for the real implementation.

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

## Architecture & conventions

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
