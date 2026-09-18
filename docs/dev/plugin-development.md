# YARD plugin development

The YARD plugin implements the "agent-friendly" output format for YARD. This
document includes information useful for working on this system. In particluar,
always follow the TDD Loop described below when making additions or changes to
the output format.

## Architecture

### Entrypoints

`lib/yard-agentdocs.rb` is the integration point, calling
`Templates::Engine.register_template_path` to install the "agentdocs" template
located under the `templates/default/` directory. No custom handler classes are
present ([ADR-0003](docs/adr/0003-no-custom-handler-classes.md)).

### Templates

The "agentdocs" template provides a complete output format for YARD.

Generation entrypoints, worth reading in this order — each `setup.rb` starts
with a comment explaining what that directory is responsible for:

- `templates/default/fulldoc/agentdocs/setup.rb` — the main driver.
- `templates/default/module/agentdocs/setup.rb` — driver for modules/classes.
- `templates/default/class/agentdocs/setup.rb` — what only classes have.

Alongside each `setup.rb` is a set of `.erb` files implementing the document
structure and control flow of the template.

Which sections exist, in what order, looped over which members, should be
visible in the `.erb` template as ordinary `<%- if -%>`/`<%- each -%>`, so the
`.erb` reads as a skeleton of the output. A Ruby method here that pre-builds
and joins strings hides exactly that shape. This is viable because
{YARD::AgentDocs::ErbWithTrimMode} turns trim mode on — without it, a
conditional or loop leaks its surrounding blank lines into the output, which is
what once forced the string-assembly approach. What stays Ruby: single-value
formatting helpers with no multi-line structure to leak whitespace from
(`type_ref`, `signature_text`, the various `*_summary_line`s), read as one-line
`<%= %>` calls from the loops above.

### Support mixins

Support mixins located under `lib/yard/agentdocs/` implement nontrivial or
shared logic needed by templates.

A helper method in `setup.rb` graduates to a `lib/yard/agentdocs/` mixin once
it is both generic enough that another template module could want it and
nontrivial enough to deserve isolated unit tests — branching logic, parsing,
regexes, anything bug-prone. `include` it here rather than leaving it a bare
top-level method. Test it against a stub class that includes just that module
(see `test/test_cross_referencing.rb`), so a failure names the one  helper that
broke instead of surfacing as a fixture mismatch. The mixins live under `lib/`
rather than in a `setup.rb` because `fulldoc` and `module` are separate
template modules and neither inherits the other's methods.

### Example test fixtures

The `examples/` directory contains a set of test fixtures: hand-written input
Ruby files and the corresponding hand-written expected output documentation
files. They document the use cases implemented by the output format, and serve
as an end-to-end test via `test/test_agentdocs_template.rb`.

`examples/geometry/lib` holds Ruby source exercising the YARD features the
format cares about, and `examples/geometry/doc` the target output.
`examples/rdoc` is the same pair for the `--markup rdoc` path and for non-`.rb`
input. Each pair is both the design medium and the test fixture, asserted byte
for byte.

All changes to the output format should be gated through updates to the
examples. See the Output Format TDD Loop below.

## Making output format changes: the TDD Loop

New format coverage is built test-first, and the loop is collaborative and
human-gated — the example files encode real design decisions, so they get 
eviewed before any implementation code is touched.

1. The user picks what to tackle next.
2. Claude proposes the `examples/<tree>/lib` source exercising it and the
   `examples/<tree>/doc` output it should produce, asking about any design
   choice not already settled. For multi-line tag or docstring text, mirror the
   source comment's exact line breaks — the template preserves raw text verbatim
   rather than rewrapping.
3. The user reviews and iterates on those `examples/` changes. Nothing outside
   `examples/` is touched yet.
4. Once the user explicitly approves, Claude implements: confirm `toys test`
   fails against the new fixture, then change the template until it passes byte
   for byte. Fix the generator; never loosen the assertion.
5. Run `toys test` and `toys rubocop`.

Wait for the step-3 approval before implementing, even when the example changes
look finished — the review is the point of working test-first. Within a tree,
source and output files are discovered automatically; only a new file
*extension* needs the glob in `test/test_agentdocs_template.rb` edited.

## Related information

- [`docs/dev/YARD-notes.md`](docs/dev/YARD-notes.md) — traps in YARD itself.
  Read before debugging surprising template behavior; each one costs a session
  to rediscover.
- [`docs/adr/`](docs/adr/) — invariants spanning several classes.
