# The plugin adds no YARD handler classes

## Context

`yard-agentdocs` is a YARD template. Its entire integration with YARD is one
line — `lib/yard-agentdocs.rb` calling `Templates::Engine.register_template_path`
— and everything else reads the object registry YARD's own parsing and handler
stack has already built.

That stack is lossy. YARD's handlers decide what a `.rb` file means, and where
they cannot statically evaluate a construct, or deliberately collapse a
distinction, the information is gone before any template sees it. A template
that wants it back has exactly one recourse in YARD's architecture: ship a
`Handler` subclass that reparses the construct itself.

The temptation is real and recurs. Each individual gap looks small, looks
fixable in twenty lines, and looks like the difference between correct output
and silently missing documentation.

## Decision

This plugin ships no `Handler` subclasses, and no substitute for one — nothing
that tracks source positions across statements, reparses call sites, or
otherwise re-derives what the handler stack discarded. Where YARD's handlers
lose information, the output loses it too, and that is accepted as a permanent
gap rather than logged as a defect to close later.

The boundary is about *re-deriving parse results*, not about compensating for
YARD's rendering. Post-processing what the registry already holds — the
`Docstring#summary` reimplementation in `DocstringSummary`, the
`RDoc::Markup::ToMarkdown` subclass in `RDocToMarkdown` — is on the near side
of it and is used freely.

## Consequences

The known gaps this produces, each verified against a real gem during the
dogfood runs. They are deliberate, not oversights, and none of them is a TODO:

- **`prepend` is indistinguishable from `include`.** `Handlers::Ruby::MixinHandler`
  pushes both onto the same `mixins(:instance)` array, so a `prepend`ed module
  renders in `**Includes:**` with nothing marking the different ancestry. This
  is the only gap a gem author could not compensate for even in principle.
- **Attributes defined by a non-literal `attr_*` call vanish.**
  `Parser::Context` declares 8 flags via `attr_accessor(*FLAGS)` — a splat over
  a constant array. YARD's `AttributeHandler` cannot statically evaluate it,
  logs `Undocumentable FLAGS`, and drops all 8 attributes and 16 accessors.
- **Macro-defined methods vanish unless the author wrote a directive.**
  RuboCop's `ExcludeLimit#exclude_limit` defines methods through `define_method`
  from a statically nameable call site (`exclude_limit 'Max'`), across 8 call
  sites and 11 cop classes, with no `@!method` anywhere; the resulting methods
  are absent from the output entirely.
- **`:stopdoc:`/`:startdoc:` block scoping is ignored, exposing what an author
  hid.** Minitest wraps all of `lib/hoe/minitest.rb` in a file-spanning
  `# :stopdoc:`; it renders in full, signatures and all. This one inverts the
  others — the failure is content appearing, not disappearing — and honoring it
  needs source-position ranges tracked across unrelated statements, which is a
  Handler in all but name. Stock YARD's own HTML template behaves identically.

Two further findings bound the cost rather than adding to it: RuboCop's
`def_node_matcher`/`def_node_search` and `google-cloud-secret_manager-v1`'s
`config_attr` both render correctly, because those gems' authors wrote the
compensating `@!method`/`@!attribute` directives themselves. The principle has
been running on an assumption that authors generally do. Two of the four gaps
above are cases where they did not, so the assumption holds often but not
universally.

**Revisit trigger.** These four are accepted individually. If further dogfood
runs keep surfacing cases where stock handlers discard data this format wants,
reopen the principle once and deliberately, rather than accumulating more
permanent gaps one at a time. Nothing tracks that as an open task; this
paragraph is the only place it is recorded.

## Considered options

- **A `Handler` subclass per construct.** Cheap the first time and compounding
  after: each one couples this plugin to the internals of a YARD version, has
  to be kept working across YARD releases, and must produce registry objects
  indistinguishable from the ones stock handlers build or the template's
  assumptions quietly stop holding.
- **Fixing the gaps upstream in YARD.** Correct in principle, and the right
  home for the `attr_accessor(*CONST)` case in particular, but it does not
  change what this plugin does with the YARD version a user actually has
  installed.
- **Rendering a placeholder where a construct was undocumentable.** Considered
  for the splat-attribute case, where YARD does at least emit a warning. It
  would put a stub in the output naming something the format cannot describe,
  which is worse for an agent than the member being absent: a name with no
  signature invites a call.
