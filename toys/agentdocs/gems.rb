# frozen_string_literal: true

desc "Build agent-friendly reference documentation for installed gems"

long_desc \
  "Runs YARD over gems installed in the current Ruby's global gem directory," \
    " using the `agentdocs` template, producing one documentation bundle per" \
    " gem version for coding agents to look up efficiently.",
  "",
  "Name the gems to build as `name`, `name:version`, or `name:all`. A bare" \
    " name means the newest installed version; `all` in place of a version" \
    " means every installed version. For example:",
  "",
  ["    toys agentdocs gems toys:0.22.0 toys-core:0.22.0"],
  "",
  "Alternatively, pass `--all` for every installed version of every gem, or" \
    " `--all-latest` for the newest installed version of each. Because those" \
    " can mean hundreds of builds, they ask for confirmation first unless" \
    " `--yes` is given. Asking for no gems at all is an error.",
  "",
  "Neither the input nor the output location can be set here. The input is" \
    " whatever is installed globally, and each gem's bundle is written to" \
    " `<XDG data home>/yard-agentdocs/gems/<name>-<version>` — so an agent" \
    " looking for a gem's docs has one path to compute rather than a" \
    " convention to discover. Set `$XDG_DATA_HOME` to move the root; it" \
    " defaults to `~/.local/share`.",
  "",
  "Each gem's own `.yardopts` is honored, as are any extra YARD arguments" \
    " given here. YARD *flags* must come after a `--` separator, following" \
    " the gem names, so this tool doesn't try to interpret them itself:",
  "",
  ["    toys agentdocs gems toys:0.22.0 -- --markup markdown"],
  "",
  "Default gems — the ones shipped with Ruby itself — are left out unless" \
    " `--include-default` is given, since many of them are C-backed and" \
    " document poorly."

flag :all, "-a", "--all",
     desc: "Build every installed version of every installed gem",
     long_desc:
       "Build every installed version of every installed gem, in addition to" \
         " any gems named explicitly. Asks for confirmation first unless" \
         " `--yes` is given."

flag :all_latest, "--all-latest",
     desc: "Build the newest installed version of every installed gem",
     long_desc:
       "Build the newest installed version of every installed gem, in" \
         " addition to any gems named explicitly. Asks for confirmation first" \
         " unless `--yes` is given. Ignored if `--all` is also given, which" \
         " subsumes it."

flag :include_default, "--[no-]include-default",
     default: false,
     desc: "Treat default gems as installed (defaults to off)",
     long_desc:
       "Treat default gems — the ones shipped with Ruby itself, such as" \
         " `json` or `logger` — as installed, both for `--all` and for gems" \
         " named explicitly. Off by default, since many of them are C-backed" \
         " and document poorly."

flag :rebuild, "--[no-]rebuild",
     default: true,
     desc: "Rebuild a gem that already has a bundle (defaults to on)",
     long_desc:
       "Rebuild a gem that already has a nonempty bundle, deleting the old" \
         " one first. On by default. With `--no-rebuild`, such a gem is left" \
         " exactly as it is, which is what makes it cheap to top up a" \
         " previous `--all` run after installing a few new gems."

flag :yes, "-y", "--yes",
     desc: "Skip the confirmation prompt for `--all` and `--all-latest`"

remaining_args :gem_args,
               desc: "Gem requests, plus any YARD flags following a `--` separator"

include :terminal

# Splits the trailing arguments at the first flag-looking one: everything
# before it names gems, everything from it on belongs to YARD. Toys eats the
# `--` separator itself, so the separator can't be found by name — but since
# the documented contract puts every YARD flag after it, the first `-` is
# where the handoff happened.
def split_gem_args
  index = gem_args.index { |arg| arg.start_with?("-") }
  index ? [gem_args[0...index], gem_args[index..]] : [gem_args, []]
end

# Required here rather than at the top of the file so that merely having this
# tool on the path (via `load_gem`) doesn't pull YARD into every Toys
# invocation in the host project.
def run
  require "yard-agentdocs"
  requests, yard_args = split_gem_args
  builder = ::YARD::AgentDocs::GemBuilder.new(
    requests: requests, all: all, all_latest: all_latest,
    include_default: include_default, rebuild: rebuild, yard_args: yard_args
  )
  specs = builder.resolve
  exit(1) unless specs
  exit(1) unless confirm_scope(builder, specs)
  exit(1) unless builder.build
end

# Confirms a bulk build before it starts, since `--all` can easily mean
# hundreds of YARD runs. Defaults to declining, which also means a
# noninteractive run without `--yes` stops rather than failing on a missing
# input stream.
def confirm_scope(builder, specs)
  return true if yes || !(all || all_latest)
  return true if confirm("Build agentdocs for #{specs.size} gem(s) into #{builder.output_root}? ",
                         default: false)
  puts "Cancelled."
  false
end
