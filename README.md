# yard-agentdocs

`yard-agentdocs` is a [YARD](https://yardoc.org/) plugin that renders Ruby API
reference documentation in a format designed for coding agents (e.g.
LLM-based tools) to look up efficiently — for example, a method's signature,
parameters, and usage — without having to search through source files or
browse a human-oriented HTML yardoc site. The goal is to minimize the input
tokens an agent needs to spend finding the reference information it needs.

**Status:** this gem is in early development. The output format and file
layout are not yet designed. See `CLAUDE.md` for the current status and open
design questions.

## Quick start

Install yard-agentdocs as a gem, or include it in your bundle.

```sh
gem install yard-agentdocs
```

`yard-agentdocs` requires Ruby 3.4.0 or later.

## Contributing

Contributions are welcome, although please [contact the maintainer](https://github.com/dazuma)
before embarking on a major change, to make sure it's something I'm willing
to accept.

Report bugs and feature requests on the [GitHub issue tracker](https://github.com/dazuma/yard-agentdocs/issues).

## License

This project is licensed under the MIT license. See the [LICENSE](LICENSE.md)
file for details.
