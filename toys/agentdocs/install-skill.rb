# frozen_string_literal: true

desc "Install the agentdocs agent skill for a coding agent"

long_desc \
  "Installs the agent skill shipped with this gem, which teaches a coding" \
    " agent when to look up a gem's API in the documentation bundles built" \
    " by `agentdocs gems`, and how to find the one file it needs.",
  "",
  "Name where to install it. `--claude` installs into Claude Code's" \
    " user-scoped skills directory, which is `~/.claude/skills` unless" \
    " `$CLAUDE_CONFIG_DIR` says otherwise. For any other harness, or for a" \
    " project-scoped install, use `--output` to name the directory that" \
    " holds skills. For example:",
  "",
  ["    toys agentdocs install-skill --output .claude/skills"],
  "",
  "Either way, the skill is installed as a `yard-agentdocs` subdirectory of" \
    " that directory, so the two differ only in where they write. Exactly" \
    " one of them is required: there is no default, because both plausible" \
    " defaults — the current directory, or your home directory — are wrong" \
    " half the time.",
  "",
  "The skill itself is harness-neutral; only this tool knows where any" \
    " particular harness keeps its skills.",
  "",
  "If the skill is already installed, you are asked whether to replace it," \
    " which is usually what you want after upgrading this gem. Pass" \
    " `--overwrite` or `--no-overwrite` to answer in advance. Note that the" \
    " prompt takes its default — replacing it — when there is nothing to" \
    " read an answer from, so an unattended run upgrades an existing" \
    " install rather than stopping."

exactly_one desc: "Destination flags (exactly one required)" do
  flag :claude, "--claude",
       desc: "Install into Claude Code's user-scoped skills directory",
       long_desc:
         "Install into Claude Code's user-scoped skills directory: `skills`" \
           " within its configuration directory, which is `~/.claude` unless" \
           " `$CLAUDE_CONFIG_DIR` says otherwise."

  flag :output, "-o", "--output DIR",
       desc: "Install into the skills directory DIR",
       long_desc:
         "Install into `DIR`, which names a directory that holds skills —" \
           " not the skill's own directory, which is always a" \
           " `yard-agentdocs` subdirectory of it. A relative path is" \
           " resolved against the current directory, so" \
           " `--output .claude/skills` installs the skill for the current" \
           " project."
end

flag :overwrite, "--[no-]overwrite",
     desc: "Replace an existing install without asking",
     long_desc:
       "Replace an existing install without asking, or with" \
         " `--no-overwrite`, leave it exactly as it is and write nothing." \
         " Without either, you are asked. Replacing removes the installed" \
         " skill directory first, so a file dropped from an earlier version" \
         " of the skill doesn't survive the upgrade."

include :terminal

# Required here rather than at the top of the file so that merely having this
# tool on the path (via `load_gem`) doesn't pull YARD into every Toys
# invocation in the host project.
def run
  require "yard-agentdocs"
  installer = ::YARD::AgentDocs::SkillInstaller.new(output_root: output)
  creating_root = installer.creates_output_root?
  decision = resolve_overwrite(installer)
  exit(1) if decision.nil?
  exit(1) unless installer.install(overwrite: decision)
  report_new_skills_dir if creating_root && claude
end

# Whether to replace an existing install: the flag if it was given, the
# user's answer if it wasn't, or nil if they declined. Defaults to replacing,
# since the usual reason to run this tool again is a newer skill to install.
def resolve_overwrite(installer)
  return true unless installer.installed?
  return overwrite unless overwrite.nil?
  return true if confirm("Replace the skill already installed at #{installer.destination}? ",
                         default: true)
  puts "Cancelled."
  nil
end

# Claude Code picks up an edited skill live, but only scans for a `skills`
# directory that existed when the session started, so creating one is worth
# mentioning.
def report_new_skills_dir
  puts "Restart Claude Code to pick up the newly created skills directory."
end
