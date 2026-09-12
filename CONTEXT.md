# yard-agentdocs

A YARD plugin that renders Ruby API reference documentation for coding agents to look
up cheaply, rather than for humans to browse. This glossary covers the vocabulary of
the generated artifact and the surfaces that describe it.

## The generated artifact

**Bundle**:
The complete directory tree the template generates for one project or gem version.
The term is [OKF](https://github.com/GoogleCloudPlatform/knowledge-catalog)'s, and it
is canonical in design documentation and in the format itself (`bundle.md`).
_Avoid_: package, docset, corpus. In text an agent reads inside a Ruby project, say
**agentdocs tree** instead — bare "bundle" collides with Bundler.

**Agentdocs tree**:
A Bundle, named for readers who are working in a Ruby project where "bundle" already
means Bundler. Used in agent-facing prose only; `bundle.md` is still named literally.

**Gems bundle**:
A Bundle for one installed gem release, written by `agentdocs gems` to
`<XDG data home>/yard-agentdocs/gems/<name>-<version>`. Its input is immutable, and
its identity lives only in that path — nothing inside the tree names the gem or version.

**Build tree**:
A Bundle for a project directory, written by `agentdocs build`. Its input is mutable,
so it can be stale with respect to the source it describes.
_Avoid_: project bundle, local bundle.

**Concept**:
One `.md` file in a Bundle, in OKF's sense: its bundle-relative path minus `.md` is its
concept ID, and it carries YAML frontmatter with a required `type`.

**Member**:
A constant, attribute, or method documented under its own `### ` heading inside the
file for the class or module that defines it.

**Guide**:
A non-API page in a Bundle rendered from a prose source file — a README or a `--files`
document — listed under `## Guides` in `index.md` and named `file.<name>.md`.

## Surfaces that describe the format

Three surfaces document how to use the format, with a strict division of labor so they
cannot drift.

**Preamble**:
The `## Navigating these docs` section of `bundle.md`. In-band, generator-owned, and
version-locked to the tree it ships in. Owns **format mechanics** — path derivation,
heading grammar, grep recipes, the inherited-member policy.

**Skill**:
The harness-neutral `SKILL.md` shipped in the gem, installed into a harness's own
skills directory by `agentdocs install-skill` — the installer knows where a given
harness keeps skills, so the skill itself never has to. Out-of-band, resident
in an agent's context from session start. Owns **routing and judgment only** — prefer
these docs over source, where a Gems bundle lives, what to do when one is missing, when
to give up and read source instead.

**Tool `long_desc`**:
The Toys tools' own help text. Owns **CLI mechanics** — flags, argument separators,
output locations, `--rebuild` and `--all` semantics. Cannot drift from the tools,
because it is the tools.
