# frozen_string_literal: true

desc "Print the directory of a gem's agentdocs bundle"

long_desc \
  "Writes the directory holding the documentation bundle for a gem this" \
    " project depends on to standard output, as a single bare line, and" \
    " nothing else. For example:",
  "",
  ["    toys agentdocs path toys"],
  "",
  "Which version of the gem this project actually depends on, where that" \
    " version is installed, and where its bundle lives are all worked out" \
    " here, exactly as `agentdocs lookup` works them out. If the bundle" \
    " doesn't exist yet, it is built first.",
  "",
  "## What this is for",
  "",
  "A bundle is ordinary Markdown, and reading one directly with `grep` is a" \
    " first-class way to use it — `bundle.md` inside each bundle documents" \
    " the format in full. But a bundle's location depends on which version" \
    " this project resolves and on where XDG puts it, neither of which a" \
    " caller should be working out by hand. This is the cheap way in:",
  "",
  ["    docs_dir=$(toys agentdocs path toys) && grep -i flag \"$docs_dir\"/index.md"],
  ["    docs_dir=$(toys agentdocs path toys) && grep -rn '^### #run' \"$docs_dir\""],
  "",
  "One command does the resolution and the search together, which is why" \
    " the output is a bare path rather than something more readable. Use" \
    " `agentdocs lookup` instead whenever you know the name you want.",
  "",
  "Gate the search on the exit status, as above, rather than substituting" \
    " straight into the argument. A command substitution that fails prints" \
    " nothing, so `grep -i flag \"$(...)\"/index.md` would go on to search" \
    " `/index.md` at the root of the filesystem; `&&` means the search" \
    " never runs at all when there is no path to search.",
  "",
  "## What lands on which stream",
  "",
  "Standard output carries the directory and nothing else, ever. A line" \
    " there always means a bundle really is at that location, so the" \
    " substitution above cannot silently produce a path that isn't one." \
    " Everything else — build progress, and every failure — goes to" \
    " standard error, along with a nonzero exit status. A run that succeeds" \
    " says nothing on either stream beyond the path itself, which already" \
    " ends in the version that was resolved.",
  "",
  "A dependency resolved from git or from a path has no released version to" \
    " document, so it has no bundle. Its source directory is reported on" \
    " standard error and never on standard output: a path printed there" \
    " would be a real directory that is not an agentdocs bundle, which is" \
    " exactly the mistake this output shape exists to make impossible.",
  "",
  "## Which version is read",
  "",
  "By default, the version this project's `Gemfile.lock` resolves — the" \
    " nearest one at or above the current directory, or the one" \
    " `$BUNDLE_GEMFILE` names. Failing that, the newest installed version." \
    " `--version` overrides both.",
  "",
  "Run this outside `bundle exec`: the gems it can document are the ones" \
    " installed on the machine, not the ones one bundle has activated. A" \
    " gem is never installed on your behalf.",
  "",
  "## Exit codes",
  "",
  ["    0    the directory was printed"],
  ["    1    no bundle, and none was built"],
  ["    2    the request was malformed"],
  ["    3    the dependency has no released version to document"],
  ["    4    a bundle was missing and the build of it failed"]

required_arg :gem_name,
             display_name: "GEM",
             desc: "The gem whose bundle directory is wanted"

flag :gem_version, "--version VERSION",
     desc: "Locate this version instead of the one the lockfile resolves",
     long_desc:
       "Locate this version of the gem, instead of the one the project's" \
         " lockfile resolves or the newest one installed. Naming a version" \
         " is itself the statement that a released version is wanted, so" \
         " this applies even to a gem the lockfile resolves from git or a" \
         " path."

flag :build, "--[no-]build",
     default: true,
     desc: "Build the bundle if it doesn't exist yet (defaults to on)",
     long_desc:
       "Build the gem's bundle if it doesn't exist yet. On by default," \
         " matching `agentdocs lookup`: a directory printed for a bundle" \
         " that isn't there would send the caller's `grep` at nothing." \
         " Building a large gem can take several minutes, and its progress" \
         " goes to standard error. With `--no-build`, a missing bundle is" \
         " reported on standard error along with the command that would" \
         " build it, and standard output stays empty."

# Required here rather than at the top of the file so that merely having this
# tool on the path (via `load_gem`) doesn't pull YARD into every Toys
# invocation in the host project.
def run
  require "yard-agentdocs"
  result = ::YARD::AgentDocs::BundlePath.new(
    gem_name, version: gem_version, build: build
  ).run
  $stdout.print(result.out)
  $stderr.print(result.err)
  exit(result.exit_code)
end
