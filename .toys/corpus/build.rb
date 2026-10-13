# frozen_string_literal: true

desc "Build agentdocs for every gem in the corpus manifest"

long_desc \
  "Builds a documentation bundle for every gem version named in" \
    " `.toys/.data/corpus-manifest.yml`, writing them to `corpus/agentdocs/`" \
    " at the repository root, one `<name>-<version>` directory per gem.",
  "",
  "This is a repo-internal development tool. It is not part of the" \
    " `yard-agentdocs` gem and is not run by `toys ci`. A full build takes" \
    " hours.",
  "",
  "## Where the gems come from",
  "",
  "Every gem is downloaded from rubygems.org as its `ruby`-platform release" \
    " and unpacked into `corpus/gems/`, which is a gem home of the corpus's" \
    " own. Nothing is installed: no native extension is compiled, no" \
    " dependency is pulled, and the machine's own installed gems are never" \
    " used or touched, even at the same version. A gem is fetched once and" \
    " kept; delete `corpus/gems/` to force a refetch.",
  "",
  "Every missing gem is fetched before any is built, so a download problem" \
    " shows up in the first minutes of the run rather than the last.",
  "",
  "## Pruning",
  "",
  "A full run first deletes every bundle and unpacked gem the manifest no" \
    " longer names, so `corpus/` always matches the manifest exactly." \
    " Naming gems on the command line builds only those, which must be in" \
    " the manifest, and skips the pruning:",
  "",
  ["    toys corpus build psych fileutils"],
  "",
  "## Exit codes",
  "",
  ["    0    every gem covered was fetched and built"],
  ["    1    some gem failed to fetch or build, or the run could not start"]

flag :rebuild, "--[no-]rebuild",
     default: true,
     desc: "Rebuild a gem that already has a bundle (defaults to on)",
     long_desc:
       "Rebuild a gem that already has a bundle. On by default, because a" \
         " bundle built by an older template is silently wrong for checking" \
         " the current one. Pass `--no-rebuild` to resume an interrupted run" \
         " without redoing the gems it finished."

remaining_args :names,
               desc: "Gems to build, instead of the whole manifest"

# Required here rather than at the top of the file so that the corpus tools'
# dependencies are loaded only when one of them actually runs.
def run
  require "corpus/builder"
  builder = ::Corpus::Builder.new(
    manifest_path: manifest_path,
    corpus_dir: ::File.join(context_directory, "corpus"),
    names: names,
    rebuild: rebuild
  )
  exit(1) unless builder.build
rescue ::Corpus::Builder::BuildError => e
  $stderr.puts("ERROR: #{e.message}")
  exit(1)
end

# Locates the committed manifest in the tools' data directory.
def manifest_path
  find_data("corpus-manifest.yml") ||
    raise(::Corpus::Builder::BuildError, "corpus-manifest.yml is missing from .toys/.data")
end
