# yard-agentdocs

`yard-agentdocs` is a [YARD](https://yardoc.org/) plugin that provides the
`agentdocs` output format, which is optimized for LLM-based coding agents.
The goal is to minimize the input tokens an agent needs to spend finding
information about a Ruby API.

Documentation produced by `yard-agentdocs`:

* Is markdown, a terse format with high content density that is well understood
  by AI models.
* Has a standard structure designed to allow quick, reliable lookup of Ruby
  classes, methods, and other entities.
* Conforms to the emerging [Open Knowledge Format](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/README.md)
  standard for knowledge bundles.

Without `yard-agentdocs`, coding agents generally must either search the source
of a Ruby library, or wade through verbose HTML-formatted documentation.

## Quick start

**NOTE:** Some of this content references capabilities that are not yet
implemented in this project.

### Installation

Install yard-agentdocs as a gem, or include it in your bundle.

```sh
gem install yard-agentdocs
```

`yard-agentdocs` requires Ruby 3.4.0 or later.

### Generating agentdocs

Generate a documentation bundle for a Ruby code base in one of two ways:

 1. **Use `--plugin agentdocs` and `--format agentdocs`**

    Run `yardoc` yourself and set the format to `agentdocs`. This requires that
    `yard-agentdocs` gets loaded as a YARD plugin. You can do this by adding
    the two flags to your `yardoc` command line or your project's `.yardopts`
    file.

 2. **Use the provided toys tool**

    The `yard-agentdocs` gem also comes with a [toys](https://dazuma.github.io/toys)
    tool for building agentdocs. In your Ruby project, you can:

    ```
    $ toys do --gem=yard-agentdocs agentdocs build
    ```

    or add the following to your `.toys.rb`:

    ```ruby
    load_gem "yard-agentdocs"
    ```

    and then simply:

    ```
    $ toys agentdocs build
    ```

    This will build agentdocs into the `agentdocs/` directory. You can output
    to a different directory by passing the `--output` flag.

 3. **Generate for all installed gems**

    *TODO*
 
### Using agentdocs

Great, so you have a set of agent-optimized documentation. How do you get your
coding agent to use it?

The easiest way is to use the provided skill. Install the skill provided in
the `/skills/agentdocs` directory.

*TODO: details*

## Contributing

Contributions are welcome, although please [contact the maintainer](https://github.com/dazuma)
before embarking on a major change, to make sure it's something I'm willing
to accept.

Report bugs and feature requests on the [GitHub issue tracker](https://github.com/dazuma/yard-agentdocs/issues).

## License

This project is licensed under the MIT license. See the [LICENSE](LICENSE.md)
file for details.
