# Agent skill development

The agent skill, located under `skills/yard-agentdocs/`, teaches how to look up
API usage information for a Ruby dependency. It uses the command line tools to
build the documentation bundle if it is not already present, and then to look
up information, either directly via the lookup command line tool, or using grep.
It is installed by the `agentdocs install-skill` command line tool.

The skill is scoped to *routing and judgment only* — when to prefer a generated
bundle over gem source or the web, which lookups are in scope, when to give up.
The format specification belongs to the `bundle.md` that is part of the
documentation bundle, CLI mechanics to the Toys tools’ own `long_desc`, and
anything the skill could only restate rather than enforce — deriving a bundle's
path, resolving a version, obtaining a missing bundle — belongs to the Reader.
This split is deliberate anti-drift, so do not move content across it. See the
`Lookup` class's own documentation.

Two properties of that skill look like violations of the split and are not. It
routes lookups for **dependencies only**, never consulting an `agentdocs build`
tree: for the project an agent is editing, that source is open, mutable, and
authoritative, so a bundle over it can only produce a wrong answer about code
the agent could simply read. And it states the one mechanic its happy path
needs — deriving a path from an FQN — rather than sending the agent to
`bundle.md` every time, because reading a ~2KB preamble per lookup is a real
cost. The preamble stays the single authority; it is consulted only when a
lookup does not resolve, not recited up front.
