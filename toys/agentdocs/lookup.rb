# frozen_string_literal: true

desc "Look up one class, module, or member in a gem's agentdocs bundle"

long_desc \
  "Answers a single API lookup against the documentation bundle for a gem" \
    " this project depends on, and writes the one class, module, or member" \
    " asked for to standard output. For example:",
  "",
  ["    toys agentdocs lookup toys Toys::Acceptor::Enum#initialize"],
  "",
  "Everything the lookup needs is worked out here rather than left to the" \
    " caller: which version of the gem this project actually depends on," \
    " where that version is installed, where its bundle lives, which file" \
    " inside it documents the name, and which section of that file documents" \
    " the member. If the bundle doesn't exist yet, it is built first.",
  "",
  "This is an accelerator, not a gateway. A bundle is ordinary Markdown and" \
    " reading it directly with `grep` remains a perfectly good way to use" \
    " one; `bundle.md` inside each bundle documents the format in full and" \
    " is the authority on it.",
  "",
  "## The entity argument",
  "",
  "`ENTITY` is a fully qualified class or module name, optionally naming one" \
    " member of it:",
  "",
  ["    Foo::Bar            the class or module itself"],
  ["    Foo::Bar#baz        an instance method or attribute"],
  ["    Foo::Bar.baz        a class method"],
  ["    Foo::Bar::BAZ       a constant"],
  "",
  "A name that could be read either as a nested class or as a constant is" \
    " read as the nested class if the bundle documents one, and as a" \
    " constant otherwise. Whichever it resolved to is stated in the output.",
  "",
  "Ruby operator method names collide with shell metacharacters, so quote" \
    " the argument whenever one is involved:",
  "",
  ["    toys agentdocs lookup rgeo 'RGeo::Cartesian::PointImpl#[]'"],
  "",
  "## How much is printed",
  "",
  "Naming a member prints that member's section, preceded by the lines that" \
    " identify the file it came from — the class or module's own heading," \
    " its superclass, its mixins, where its source is, and any flags on the" \
    " type itself, such as `Deprecated.` or `Private API.`. A method is" \
    " never shown without saying what it belongs to, and never shown as" \
    " current when the type it belongs to is not.",
  "",
  "Naming a class or module without a member prints it down to the end of" \
    " its member summary: what it is for, and the names of everything it" \
    " defines, without the per-member detail. That is what is useful when" \
    " you are still working out which member you want. Pass `--full` for" \
    " the whole file.",
  "",
  "The documentation itself is reproduced exactly as the bundle stores it," \
    " never rewritten. In particular, `Defined in:` paths are relative to" \
    " the gem's own root directory, which is printed in the header above" \
    " each answer.",
  "",
  "## Which version is read",
  "",
  "By default, the version this project's `Gemfile.lock` resolves — the" \
    " nearest one at or above the current directory, or the one" \
    " `$BUNDLE_GEMFILE` names. Failing that, the newest installed version." \
    " `--version` overrides both, and reading some other version's bundle" \
    " because it happens to exist is exactly what this tool exists to" \
    " prevent, so the version that was used and where it came from are" \
    " always stated in the output.",
  "",
  "Run this outside `bundle exec`: the gems it can document are the ones" \
    " installed on the machine, not the ones one bundle has activated. A" \
    " project that installs into its own directory (`bundle config path" \
    " vendor/bundle`) is handled — that directory is searched first.",
  "",
  "A gem is never installed on your behalf. A dependency resolved from git" \
    " or from a path has no released version to document, and is reported" \
    " with its source rather than built.",
  "",
  "## Exit codes",
  "",
  ["    0    the lookup was answered"],
  ["    1    no match, or no bundle and none was built"],
  ["    2    the request was malformed"],
  ["    3    the dependency has no released version to document"],
  ["    4    a bundle was missing and the build of it failed"],
  "",
  "Standard output always carries the full explanation, including on a" \
    " failure, so the exit code never has to be consulted to know what" \
    " happened or what to do next. A lookup that misses never falls back to" \
    " a near match: candidates are offered, labelled as candidates."

required_arg :gem_name,
             display_name: "GEM",
             desc: "The gem to look the entity up in",
             long_desc:
               "The gem to look the entity up in. Required, and not guessed" \
                 " from the entity name: a fully qualified name does not say" \
                 " which gem defines it, and the caller nearly always knows."

required_arg :entity,
             display_name: "ENTITY",
             desc: "The class, module, or member to look up",
             long_desc:
               "A fully qualified class or module name, optionally naming" \
                 " one member of it — `Foo::Bar`, `Foo::Bar#baz`," \
                 " `Foo::Bar.baz`, or `Foo::Bar::BAZ`. Quote it when an" \
                 " operator method name is involved, since those collide" \
                 " with shell metacharacters."

flag :gem_version, "--version VERSION",
     desc: "Read this version instead of the one the lockfile resolves",
     long_desc:
       "Read this version of the gem, instead of the one the project's" \
         " lockfile resolves or the newest one installed. Naming a version" \
         " is itself the statement that a released version is wanted, so" \
         " this applies even to a gem the lockfile resolves from git or a" \
         " path."

flag :full, "--[no-]full",
     default: false,
     desc: "Print the whole file rather than the default portion of it",
     long_desc:
       "Print the whole of the class or module's file, rather than the" \
         " default portion. Without a member that default is everything" \
         " down to the end of the member summary; with one it is that" \
         " member's section plus the lines identifying the file."

flag :build, "--[no-]build",
     default: true,
     desc: "Build the bundle if it doesn't exist yet (defaults to on)",
     long_desc:
       "Build the gem's bundle if it doesn't exist yet. On by default." \
         " Building a large gem can take several minutes, and its progress" \
         " goes to standard error so that standard output stays exactly the" \
         " documentation asked for. With `--no-build`, a missing bundle is" \
         " reported along with the command that would build it, and nothing" \
         " is written."

# Required here rather than at the top of the file so that merely having this
# tool on the path (via `load_gem`) doesn't pull YARD into every Toys
# invocation in the host project.
def run
  require "yard-agentdocs"
  result = ::YARD::AgentDocs::Lookup.new(
    gem_name, entity, version: gem_version, full: full, build: build
  ).run
  $stdout.print(result.body)
  exit(result.exit_code)
end
