# frozen_string_literal: true

require "helper"
require "fileutils"
require "tmpdir"

describe ::YARD::AgentDocs::Builder do
  # A minimal but real project tree for the builder to point at. Everything
  # here is written fresh into a tmpdir per example, so nothing leaks between
  # tests (and YARD's `.yardoc` database, which the builder deliberately does
  # not suppress, lands somewhere disposable).
  #
  # @param dir [String] the directory to populate
  # @param yardopts [String, nil] contents for a `.yardopts` file, if any
  def make_project(dir, yardopts: nil)
    ::FileUtils.mkdir_p(::File.join(dir, "lib"))
    ::File.write(::File.join(dir, "lib", "widget.rb"), <<~RUBY)
      # A widget.
      class Widget
        # Spins the widget.
        # @return [void]
        def spin; end
      end
    RUBY
    ::File.write(::File.join(dir, "GUIDE.md"), "# Guide\n\nHow to widget.\n")
    ::File.write(::File.join(dir, ".yardopts"), yardopts) if yardopts
    dir
  end

  # Runs +block+ with a freshly populated project directory, *from inside*
  # that directory — the ordinary way the tool gets used (`cd myproject &&
  # toys agentdocs build`), and what makes a relative output directory land
  # alongside the project. Examples that specifically need a foreign working
  # directory chdir somewhere disposable themselves. Also quiets YARD's
  # logger so a test run isn't buried in parse progress and stats.
  def with_project(yardopts: nil)
    ::Dir.mktmpdir do |dir|
      make_project(dir, yardopts: yardopts)
      log.enter_level(::YARD::Logger::FATAL) do
        ::Dir.chdir(dir) { yield dir }
      end
    end
  end

  def build(input, **)
    ::YARD::AgentDocs::Builder.new(input: input, **).build
  end

  def read_output(input, *path, output: "agentdocs")
    ::File.read(::File.join(input, output, *path))
  end

  it "generates a bundle into agentdocs/ by default" do
    with_project do |dir|
      assert(build(dir))
      assert_path_exists(::File.join(dir, "agentdocs", "index.md"))
      assert_includes(read_output(dir, "Widget.md"), "# class Widget")
    end
  end

  it "honors options set in the project's .yardopts" do
    with_project(yardopts: "--title \"Widget Works\"\n") do |dir|
      assert(build(dir))
      assert_includes(read_output(dir, "index.md"), "# Widget Works")
    end
  end

  it "overrides an output directory set in .yardopts" do
    with_project(yardopts: "-o htmldoc\n") do |dir|
      assert(build(dir))
      assert_path_exists(::File.join(dir, "agentdocs", "index.md"))
      refute(::File.exist?(::File.join(dir, "htmldoc")),
             "the .yardopts output directory should be left alone")
    end
  end

  it "overrides a format set in .yardopts" do
    with_project(yardopts: "-f html\n") do |dir|
      assert(build(dir))
      assert_path_exists(::File.join(dir, "agentdocs", "Widget.md"))
      refute(::File.exist?(::File.join(dir, "agentdocs", "Widget.html")))
    end
  end

  # A custom template would send YARD looking for the nonexistent directory
  # `<template>/module/agentdocs`, so `-t default` has to be forced too.
  it "overrides a template set in .yardopts" do
    with_project(yardopts: "-t some_custom_template\n") do |dir|
      assert(build(dir))
      assert_includes(read_output(dir, "Widget.md"), "# class Widget")
    end
  end

  # YARD's own `yardoc` refuses to run when a pinned markup provider can't be
  # loaded, even though this template never renders through one. The gem
  # name is made up so the example holds on a machine that has any real
  # provider installed.
  it "ignores a markup provider set in .yardopts" do
    with_project(yardopts: "--markup markdown --markup-provider no_such_gem_xyz\n") do |dir|
      assert(build(dir))
      assert_includes(read_output(dir, "Widget.md"), "# class Widget")
    end
  end

  # Source paths recorded in the output are relative to wherever YARD ran, so
  # they pin down that the build really happened inside the input directory
  # and not in the shell's own.
  it "runs with the input directory as the working directory" do
    ::Dir.mktmpdir do |elsewhere|
      with_project do |dir|
        ::Dir.chdir(elsewhere) do
          assert(build(dir, output: ::File.join(dir, "agentdocs")))
        end
        assert_includes(read_output(dir, "Widget.md"), "**Defined in:** `lib/widget.rb`")
      end
    end
  end

  it "resolves a relative output directory against the current directory" do
    ::Dir.mktmpdir do |elsewhere|
      with_project do |dir|
        ::Dir.chdir(elsewhere) do
          assert(build(dir, output: "bundle"))
        end
        assert_path_exists(::File.join(elsewhere, "bundle", "index.md"))
        refute(::File.exist?(::File.join(dir, "bundle")),
               "a relative output should not follow the input directory")
      end
    end
  end

  it "writes to an absolute output directory as given" do
    ::Dir.mktmpdir do |elsewhere|
      with_project do |dir|
        output = ::File.join(elsewhere, "bundle")
        assert(build(dir, output: output))
        assert_path_exists(::File.join(output, "index.md"))
        refute(::File.exist?(::File.join(dir, "agentdocs")))
      end
    end
  end

  # Both a YARD flag and the bare `-` extra-files marker have to survive the
  # trip through the tool's passthrough.
  it "passes extra arguments through to YARD" do
    with_project do |dir|
      assert(build(dir, yard_args: ["--markup", "markdown", "lib/**/*.rb", "-", "GUIDE.md"]))
      assert_path_exists(::File.join(dir, "agentdocs", "file.GUIDE.md"))
    end
  end

  it "leaves YARD's .yardoc database behavior alone" do
    with_project do |dir|
      assert(build(dir))
      assert_path_exists(::File.join(dir, ".yardoc"))
    end
  end

  it "leaves stale output in place by default" do
    with_project do |dir|
      stale = ::File.join(dir, "agentdocs", "Gone.md")
      ::FileUtils.mkdir_p(::File.dirname(stale))
      ::File.write(stale, "# Gone\n")
      assert(build(dir))
      assert_path_exists(stale)
    end
  end

  it "removes stale output when asked to clean" do
    with_project do |dir|
      stale = ::File.join(dir, "agentdocs", "Gone.md")
      ::FileUtils.mkdir_p(::File.dirname(stale))
      ::File.write(stale, "# Gone\n")
      assert(build(dir, clean: true))
      refute(::File.exist?(stale))
      assert_path_exists(::File.join(dir, "agentdocs", "Widget.md"))
    end
  end

  it "refuses to clean an output directory containing the project" do
    with_project do |dir|
      refute(build(dir, output: ".", clean: true))
      assert_path_exists(::File.join(dir, "lib", "widget.rb"))
    end
  end

  # Nested one level deeper than the other examples on purpose: if the guard
  # ever regressed, `..` must resolve to a disposable directory rather than
  # the system temp directory that holds every other example's project.
  it "refuses to clean an output directory above the project" do
    ::Dir.mktmpdir do |outer|
      dir = make_project(::File.join(outer, "project"))
      log.enter_level(::YARD::Logger::FATAL) do
        ::Dir.chdir(dir) do
          refute(build(dir, output: "..", clean: true))
        end
      end
      assert_path_exists(::File.join(dir, "lib", "widget.rb"))
    end
  end

  # The input and output directories arrive by different routes — one from an
  # argument, the other typically from the working directory — so a symlinked
  # ancestor can make two names for the same place look unrelated. Here the
  # project is reached through `alias/`, and the clean target is the very same
  # directory reached through `real/`. macOS hits exactly this shape without
  # anyone setting it up, since `Dir.pwd` resolves a temp directory to
  # `/private/var/...` while the argument stays `/var/...`.
  it "sees through symlinks when refusing to clean" do
    ::Dir.mktmpdir do |outer|
      real = ::File.join(outer, "real")
      make_project(::File.join(real, "project"))
      ::File.symlink(real, ::File.join(outer, "alias"))
      log.enter_level(::YARD::Logger::FATAL) do
        refute(build(::File.join(outer, "alias", "project"), output: real, clean: true))
      end
      assert_path_exists(::File.join(real, "project", "lib", "widget.rb"))
    end
  end

  it "fails when the input directory does not exist" do
    ::Dir.mktmpdir do |dir|
      log.enter_level(::YARD::Logger::FATAL) do
        refute(build(::File.join(dir, "nope")))
      end
    end
  end

  # `Yardoc#run` returns a falsy value rather than raising when argument
  # parsing rejects something, which has to surface as a plain `false`.
  it "fails when YARD rejects the arguments" do
    with_project do |dir|
      refute(build(dir, yard_args: ["--markup", "no_such_markup"]))
    end
  end

  # Runs +block+ with YARD's logger at WARN level, writing to a buffer that
  # is yielded to it. YARD records a warning for `--fail-on-warning` only
  # when it is actually emitted, so the FATAL level {#with_project} sets
  # would hide every warning from these examples.
  def with_warnings_emitted
    saved_io = log.io
    saved_warned = log.warned
    log.io = ::StringIO.new
    log.enter_level(::YARD::Logger::WARN) { yield log.io }
  ensure
    log.io = saved_io
    log.warned = saved_warned
  end

  # The message has to name the dialect: YARD's own would blame the markup
  # provider instead.
  it "fails with a clear message for an unsupported run-wide markup" do
    with_project do |dir|
      with_warnings_emitted do |io|
        refute(build(dir, yard_args: ["--markup", "textile"]))
        assert_match(/markup dialect `textile` is not supported/, io.string)
      end
    end
  end

  # What a `.txt` guide resolves to. It has no conversion yet, but must not
  # fail the build (dazuma/yard-agentdocs#31).
  it "accepts a run-wide markup YARD renders without a provider" do
    with_project do |dir|
      assert(build(dir, yard_args: ["--markup", "text"]))
      assert_path_exists(::File.join(dir, "agentdocs", "Widget.md"))
    end
  end

  it "includes an unsupported extra file verbatim, with a warning" do
    with_project(yardopts: "- NOTES.textile\n") do |dir|
      ::File.write(::File.join(dir, "NOTES.textile"), "h1. Notes\n\n# first\n")
      with_warnings_emitted do |io|
        assert(build(dir))
        assert_match(/`NOTES.textile` is written in the `textile` markup dialect/, io.string)
      end
      assert_includes(read_output(dir, "file.NOTES.md"), "```textile\nh1. Notes\n\n# first\n```")
    end
  end

  # A misspelled shebang names a dialect YARD doesn't know at all, which is
  # handled the same way as one it knows but can't render here.
  it "includes an extra file with an unknown shebang dialect verbatim" do
    with_project(yardopts: "- NOTES.md\n") do |dir|
      ::File.write(::File.join(dir, "NOTES.md"), "#!markdwon\n# Notes\n")
      with_warnings_emitted do |io|
        assert(build(dir))
        assert_match(/`NOTES.md` is written in the `markdwon` markup dialect/, io.string)
      end
      assert_includes(read_output(dir, "file.NOTES.md"), "```markdwon\n# Notes\n```")
    end
  end

  # YARD's logger remembers that a warning was ever logged for the life of
  # the process, and `--fail-on-warning` consults that memory. A warning from
  # some earlier run in the same process must not fail this one.
  it "ignores warnings logged before the build under --fail-on-warning" do
    with_project(yardopts: "--fail-on-warning\n") do |dir|
      with_warnings_emitted do
        log.warn("a warning from some earlier build")
        assert(build(dir))
      end
    end
  end

  it "fails on the project's own warnings under --fail-on-warning" do
    with_project(yardopts: "--fail-on-warning\n") do |dir|
      ::File.write(::File.join(dir, "lib", "gadget.rb"), "# @no_such_tag\nclass Gadget; end\n")
      with_warnings_emitted do
        refute(build(dir))
      end
    end
  end
end
