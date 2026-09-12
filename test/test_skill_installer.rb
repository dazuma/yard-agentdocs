# frozen_string_literal: true

require "helper"
require "fileutils"
require "tmpdir"

describe ::YARD::AgentDocs::SkillInstaller do
  # Runs +block+ with a disposable skills directory that does not yet exist,
  # so a test can decide whether to create it, with YARD's logger quieted so
  # a test run isn't buried in the installer's announcements.
  def with_output_root
    ::Dir.mktmpdir do |dir|
      log.enter_level(::YARD::Logger::FATAL) { yield ::File.join(dir, "skills") }
    end
  end

  def installer(output_root)
    ::YARD::AgentDocs::SkillInstaller.new(output_root: output_root)
  end

  # The path the skill is expected to land at, built from the constant rather
  # than from the installer under test.
  def skill_dir(output_root)
    ::File.join(output_root, ::YARD::AgentDocs::SkillInstaller::SKILL_NAME)
  end

  describe ".default_claude_skills_dir" do
    def with_config_dir_env(value)
      key = ::YARD::AgentDocs::SkillInstaller::CLAUDE_CONFIG_DIR_ENV
      old = ::ENV[key]
      ::ENV[key] = value
      begin
        yield
      ensure
        ::ENV[key] = old
      end
    end

    it "defaults to a skills directory under `~/.claude`" do
      with_config_dir_env(nil) do
        assert_equal(::File.join(::Dir.home, ".claude", "skills"),
                     ::YARD::AgentDocs::SkillInstaller.default_claude_skills_dir)
      end
    end

    # The environment variable relocates the entire configuration directory,
    # so `skills` is appended to it rather than replaced by it.
    it "honors CLAUDE_CONFIG_DIR" do
      with_config_dir_env("/somewhere/else/.config-claude") do
        assert_equal("/somewhere/else/.config-claude/skills",
                     ::YARD::AgentDocs::SkillInstaller.default_claude_skills_dir)
      end
    end

    it "ignores an empty CLAUDE_CONFIG_DIR" do
      with_config_dir_env("") do
        assert_equal(::File.join(::Dir.home, ".claude", "skills"),
                     ::YARD::AgentDocs::SkillInstaller.default_claude_skills_dir)
      end
    end
  end

  describe ".source_dir" do
    it "points at this gem's copy of the skill" do
      source = ::YARD::AgentDocs::SkillInstaller.source_dir
      assert(::File.directory?(source))
      assert(::File.file?(::File.join(source, "SKILL.md")))
    end

    # The directory name the installer creates is the skill's own name, so a
    # rename on either side without the other would install the skill under a
    # name that doesn't match what its frontmatter declares.
    it "holds a skill whose frontmatter name matches the installed directory name" do
      content = ::File.read(::File.join(::YARD::AgentDocs::SkillInstaller.source_dir, "SKILL.md"))
      assert_match(/^name: #{::Regexp.escape(::YARD::AgentDocs::SkillInstaller::SKILL_NAME)}$/,
                   content)
    end
  end

  describe "#destination" do
    it "is the skill's own directory within the skills directory" do
      with_output_root do |output_root|
        assert_equal(skill_dir(output_root), installer(output_root).destination)
      end
    end

    it "defaults to Claude Code's skills directory" do
      expected = ::File.join(::YARD::AgentDocs::SkillInstaller.default_claude_skills_dir,
                             ::YARD::AgentDocs::SkillInstaller::SKILL_NAME)
      assert_equal(expected, ::YARD::AgentDocs::SkillInstaller.new.destination)
    end

    it "expands a relative skills directory" do
      assert_equal(::File.join(::Dir.getwd, "skills", "yard-agentdocs"),
                   installer("skills").destination)
    end
  end

  describe "#install" do
    it "creates the skills directory and installs the whole skill" do
      with_output_root do |output_root|
        assert(installer(output_root).install)
        source = ::YARD::AgentDocs::SkillInstaller.source_dir
        expected = ::Dir.children(source).sort
        assert_equal(expected, ::Dir.children(skill_dir(output_root)).sort)
        assert_equal(::File.read(::File.join(source, "SKILL.md")),
                     ::File.read(::File.join(skill_dir(output_root), "SKILL.md")))
      end
    end

    it "installs alongside skills that are already there" do
      with_output_root do |output_root|
        ::FileUtils.mkdir_p(::File.join(output_root, "other-skill"))
        assert(installer(output_root).install)
        assert_equal(["other-skill", "yard-agentdocs"], ::Dir.children(output_root).sort)
      end
    end

    it "replaces an existing install" do
      with_output_root do |output_root|
        ::FileUtils.mkdir_p(skill_dir(output_root))
        ::File.write(::File.join(skill_dir(output_root), "SKILL.md"), "stale\n")
        assert(installer(output_root).install)
        refute_equal("stale\n", ::File.read(::File.join(skill_dir(output_root), "SKILL.md")))
      end
    end

    # An upgrade has to be a replacement rather than a merge, or a file the
    # skill no longer ships is still there to be read afterward.
    it "removes a file the installed skill no longer has" do
      with_output_root do |output_root|
        ::FileUtils.mkdir_p(skill_dir(output_root))
        ::File.write(::File.join(skill_dir(output_root), "dropped.md"), "gone\n")
        assert(installer(output_root).install)
        refute(::File.exist?(::File.join(skill_dir(output_root), "dropped.md")))
      end
    end

    it "leaves an existing install alone when told not to overwrite" do
      with_output_root do |output_root|
        ::FileUtils.mkdir_p(skill_dir(output_root))
        ::File.write(::File.join(skill_dir(output_root), "SKILL.md"), "stale\n")
        assert(installer(output_root).install(overwrite: false))
        assert_equal("stale\n", ::File.read(::File.join(skill_dir(output_root), "SKILL.md")))
      end
    end

    # Nothing is installed yet, so there is nothing for `--no-overwrite` to
    # protect and the install proceeds.
    it "installs with overwrite off when nothing is installed" do
      with_output_root do |output_root|
        assert(installer(output_root).install(overwrite: false))
        assert(::File.file?(::File.join(skill_dir(output_root), "SKILL.md")))
      end
    end
  end

  describe "#installed?" do
    it "is false when the skills directory doesn't exist" do
      with_output_root do |output_root|
        refute(installer(output_root).installed?)
      end
    end

    it "is false when the skill's own directory is empty" do
      with_output_root do |output_root|
        ::FileUtils.mkdir_p(skill_dir(output_root))
        refute(installer(output_root).installed?)
      end
    end

    it "is true after an install" do
      with_output_root do |output_root|
        installer(output_root).install
        assert(installer(output_root).installed?)
      end
    end

    # Not a skill install, but not something to discard without asking either.
    it "is true when a plain file occupies the destination" do
      with_output_root do |output_root|
        ::FileUtils.mkdir_p(output_root)
        ::File.write(skill_dir(output_root), "not a skill\n")
        assert(installer(output_root).installed?)
      end
    end
  end

  describe "#creates_output_root?" do
    it "is true when the skills directory doesn't exist yet" do
      with_output_root do |output_root|
        assert(installer(output_root).creates_output_root?)
      end
    end

    it "is false once the skills directory exists" do
      with_output_root do |output_root|
        ::FileUtils.mkdir_p(output_root)
        refute(installer(output_root).creates_output_root?)
      end
    end
  end
end
