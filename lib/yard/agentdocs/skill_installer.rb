# frozen_string_literal: true

require "fileutils"

module YARD
  module AgentDocs
    ##
    # Installs the agent skill shipped in this gem's `skills/` directory into
    # a harness's skills directory. This is the implementation behind the
    # `agentdocs install-skill` Toys tool shipped in this gem's `toys/`
    # directory (see `toys/agentdocs/install-skill.rb`), and lives here for
    # the same reason its siblings do: so the behavior is testable and
    # documented apart from the Toys DSL layer.
    #
    # The skill itself is harness-neutral — one `SKILL.md` making no
    # assumptions about who reads it. Knowing *where* a particular harness
    # keeps its skills is this class's job instead, which is why
    # {default_claude_skills_dir} is here and not in the skill.
    #
    # Installation is a whole-directory copy, not a copy of `SKILL.md` alone,
    # so a skill that grows supporting files installs completely without this
    # class changing. Replacing an existing install removes the old directory
    # first, for the same reason: files dropped from a later version of the
    # skill would otherwise survive the upgrade and still be read.
    #
    class SkillInstaller
      ##
      # The name of the skill this installs. It is both the directory name
      # under `skills/` in this gem and the directory name created in the
      # destination, matching the `name` in the skill's own frontmatter.
      #
      SKILL_NAME = "yard-agentdocs"

      ##
      # The subdirectory of a Claude Code configuration directory that holds
      # user-scoped skills.
      #
      CLAUDE_SKILLS_SUBDIR = "skills"

      ##
      # The environment variable that relocates Claude Code's configuration
      # directory, and with it the skills directory inside it.
      #
      CLAUDE_CONFIG_DIR_ENV = "CLAUDE_CONFIG_DIR"

      ##
      # The default location of a Claude Code configuration directory,
      # relative to the user's home directory.
      #
      DEFAULT_CLAUDE_CONFIG_SUBDIR = ".claude"

      class << self
        ##
        # Claude Code's user-scoped skills directory: `skills` within its
        # configuration directory, which is `~/.claude` unless
        # `$CLAUDE_CONFIG_DIR` says otherwise. Note that the environment
        # variable relocates the entire configuration directory, not the
        # skills directory alone.
        #
        # @return [String]
        #
        def default_claude_skills_dir
          config_dir = ::ENV[CLAUDE_CONFIG_DIR_ENV]
          if config_dir.nil? || config_dir.empty?
            config_dir = ::File.join(::Dir.home, DEFAULT_CLAUDE_CONFIG_SUBDIR)
          end
          ::File.join(config_dir, CLAUDE_SKILLS_SUBDIR)
        end

        ##
        # The directory in this gem holding the skill to install.
        #
        # Located relative to this file rather than through the gem
        # specification, so that a checkout of this repository installs its
        # own copy of the skill rather than an installed release's.
        #
        # @return [String]
        #
        def source_dir
          ::File.expand_path(::File.join(__dir__, "..", "..", "..", "skills", SKILL_NAME))
        end
      end

      ##
      # @param output_root [String, nil] the skills directory to install into
      #   — the directory *containing* skills, not the skill's own directory.
      #   Defaults to {default_claude_skills_dir}.
      #
      def initialize(output_root: nil)
        @output_root = ::File.expand_path(output_root || self.class.default_claude_skills_dir)
        @destination = ::File.join(@output_root, SKILL_NAME)
      end

      ##
      # @return [String] the absolute path of the skills directory installed
      #   into
      #
      attr_reader :output_root

      ##
      # @return [String] the absolute path this skill is installed at, which
      #   is {SKILL_NAME} within {#output_root}
      #
      attr_reader :destination

      ##
      # Whether anything is already present at {#destination} that installing
      # would destroy. An empty directory doesn't count: there is nothing
      # there to lose, so replacing it isn't a decision worth putting to
      # anyone. Anything else does, including a plain file at that path,
      # which is not a skill install but is also not ours to discard quietly.
      #
      # @return [Boolean]
      #
      def installed?
        return false unless ::File.exist?(destination)
        !(::File.directory?(destination) && ::Dir.empty?(destination))
      end

      ##
      # Whether {#output_root} has yet to be created. Worth asking before
      # {#install}, since a harness that scans a skills directory may not
      # notice one that appeared underneath a running session.
      #
      # @return [Boolean]
      #
      def creates_output_root?
        !::File.directory?(output_root)
      end

      ##
      # Installs the skill, replacing an existing install if allowed to.
      #
      # @param overwrite [Boolean] whether to replace an existing install.
      #   When false, an existing install is left exactly as it is, and this
      #   reports success without writing anything.
      # @return [Boolean] whether the skill is installed and current
      #
      def install(overwrite: true)
        if installed? && !overwrite
          announce("yard-agentdocs: skill already installed at #{destination}")
          return true
        end
        copy_skill
      end

      private

      def copy_skill
        source = self.class.source_dir
        unless ::File.directory?(source)
          log.error("yard-agentdocs: skill source `#{source}` is missing")
          return false
        end
        ::FileUtils.rm_rf(destination)
        ::FileUtils.mkdir_p(output_root)
        ::FileUtils.cp_r(source, output_root)
        announce("yard-agentdocs: skill installed at #{destination}")
        true
      end

      # Progress and summary lines, gated exactly as {GemBuilder}'s are:
      # printed regardless of log level, except when the level has been raised
      # to ERROR or above.
      def announce(message)
        log.puts(message) if log.level < ::YARD::Logger::ERROR
      end
    end
  end
end
