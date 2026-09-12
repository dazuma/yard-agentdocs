# frozen_string_literal: true

desc "Build agent-friendly reference documentation for a Ruby project"

long_desc \
  "Runs YARD over a Ruby project using the `agentdocs` template, producing a" \
    " documentation bundle designed for coding agents to look up efficiently.",
  "",
  "The project's own `.yardopts` file is honored, as are any source globs and" \
    " extra YARD arguments given here. For example:",
  "",
  ["    toys agentdocs build --markup markdown --title \"My API\" - README.md"],
  "",
  "Three YARD settings are always forced, and cannot be overridden from" \
    " `.yardopts` or the command line: the output format (`agentdocs`), the" \
    " template (`default`, which is where this gem's `agentdocs` renderers" \
    " live), and the output directory (use `--output` to change it). The" \
    " output directory is forced so that an agentdocs build never writes into" \
    " whatever directory the project uses for its human-facing HTML docs."

flag :input, "-i", "--input DIR",
     default: ".",
     desc: "The project directory to document (defaults to the current directory)",
     long_desc:
       "The project directory to document, treated as the project root: the" \
         " build runs with this as its working directory, so the project's" \
         " `.yardopts` is picked up and recorded source paths come out" \
         " relative to it. Defaults to the current directory."

flag :output, "-o", "--output DIR",
     default: "agentdocs",
     desc: "The directory to write the bundle into (defaults to `agentdocs`)",
     long_desc:
       "The directory to write the documentation bundle into. A relative path" \
         " is resolved against the current directory, not against `--input`," \
         " so it means what it would mean to any other command run from the" \
         " same shell. Defaults to `agentdocs`."

flag :clean, "--[no-]clean",
     default: false,
     desc: "Delete the output directory before generating",
     long_desc:
       "Delete the output directory before generating, so files left over" \
         " from an earlier run (a page for a class that no longer exists, say)" \
         " can't linger in the bundle. Off by default."

remaining_args :yard_args,
               desc: "YARD source globs and flags"

treat_unknown_flags_as_args

# Required here rather than at the top of the file so that merely having this
# tool on the path (via `load_gem`) doesn't pull YARD into every Toys
# invocation in the host project.
def run
  require "yard-agentdocs"
  builder = ::YARD::AgentDocs::Builder.new(
    input: input, output: output, clean: clean, yard_args: yard_args
  )
  exit(1) unless builder.build
end
