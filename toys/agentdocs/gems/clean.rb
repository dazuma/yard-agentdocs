# frozen_string_literal: true

toys_version! ">= 0.23.0"

desc "Remove agentdocs built for installed gems"

long_desc \
  "Removes documentation bundles previously built by `agentdocs gems`, from" \
    " the same fixed location that tool writes to:" \
    " `<XDG data home>/yard-agentdocs/gems`, which is `~/.local/share`" \
    " unless `$XDG_DATA_HOME` says otherwise.",
  "",
  "Name the gems to clean as `name`, `name:version`, or `name:all`. A bare" \
    " name removes every version built for that gem; `all` in place of a" \
    " version means the same thing. For example:",
  "",
  ["    toys agentdocs gems clean toys:0.22.0 toys-core"],
  "",
  "Alternatively, pass `--all` to remove every bundle, or `--all-outdated`" \
    " to remove all but the newest built version of each gem. Both ask for" \
    " confirmation first unless `--yes` is given. Asking for no gems at all" \
    " is an error.",
  "",
  "What can be removed is whatever is actually built, not whatever happens" \
    " to be installed — a bundle for a gem you've since uninstalled is" \
    " exactly the kind of thing worth cleaning. Anything in that directory" \
    " that isn't a gem bundle is left alone, and if any named gem or version" \
    " has no bundle, nothing at all is removed."

flag :all, "-a", "--all",
     desc: "Remove every bundle present",
     long_desc:
       "Remove every bundle present, in addition to any gems named" \
         " explicitly. Asks for confirmation first unless `--yes` is given."

flag :all_outdated, "--all-outdated",
     desc: "Remove all but the newest built version of each gem",
     long_desc:
       "Remove every bundle except the newest built version of each gem, in" \
         " addition to any gems named explicitly. Asks for confirmation first" \
         " unless `--yes` is given. Ignored if `--all` is also given, which" \
         " subsumes it."

flag :yes, "-y", "--yes",
     desc: "Skip the confirmation prompt for `--all` and `--all-outdated`"

remaining_args :gem_args,
               desc: "The gems to clean, as `name`, `name:version`, or `name:all`"

include :terminal

# Required here rather than at the top of the file so that merely having this
# tool on the path (via `load_gem`) doesn't pull YARD into every Toys
# invocation in the host project.
def run
  require "yard-agentdocs"
  cleaner = ::YARD::AgentDocs::GemCleaner.new(
    requests: gem_args, all: all, all_outdated: all_outdated
  )
  dirs = cleaner.resolve
  exit(1) unless dirs
  exit(1) unless confirm_scope(cleaner, dirs)
  exit(1) unless cleaner.clean
end

# Confirms a bulk removal before it starts. Defaults to declining, which also
# means a noninteractive run without `--yes` stops rather than failing on a
# missing input stream.
def confirm_scope(cleaner, dirs)
  return true if yes || !(all || all_outdated) || dirs.empty?
  return true if confirm("Remove agentdocs for #{dirs.size} gem(s) from #{cleaner.output_root}? ",
                         default: false)
  puts "Cancelled."
  false
end
