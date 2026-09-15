# frozen_string_literal: true

require "helper"
require "fileutils"
require "stringio"
require "tmpdir"

describe ::YARD::AgentDocs::Lookup do
  let(:project_root) { ::File.expand_path("..", __dir__) }
  let(:geometry_doc_dir) { ::File.join(project_root, "examples/geometry/doc") }

  # Installs a gem into a fake gem home laid out the way rubygems lays out a
  # real one, so the specification reports a `full_gem_path` inside it.
  #
  # @param home [String] the fake gem home
  # @param name [String] the gem name
  # @param version [String] the gem version
  # @param sources [Boolean] whether to install any sources at all; false
  #   stands in for a gem whose specification is present but whose files are
  #   not, which is what a build has nothing to document
  # @return [String] the gem's installed directory
  def install_gem(home, name, version, sources: true)
    full_name = "#{name}-#{version}"
    spec_dir = ::File.join(home, "specifications")
    gem_dir = ::File.join(home, "gems", full_name)
    ::FileUtils.mkdir_p(spec_dir)
    ::File.write(::File.join(spec_dir, "#{full_name}.gemspec"), <<~RUBY)
      Gem::Specification.new do |spec|
        spec.name = #{name.inspect}
        spec.version = #{version.inspect}
        spec.summary = "A test gem."
        spec.authors = ["Nobody"]
        spec.files = ["lib/#{name}.rb"]
      end
    RUBY
    return gem_dir unless sources
    ::FileUtils.mkdir_p(::File.join(gem_dir, "lib"))
    ::File.write(::File.join(gem_dir, "lib", "#{name}.rb"), <<~RUBY)
      # A widget from #{full_name}.
      class Widget
        # Spins the widget.
        # @return [void]
        def spin; end
      end
    RUBY
    gem_dir
  end

  # Puts an already-built bundle at a gem version's canonical path, by
  # copying the hand-authored `examples/geometry/doc` fixture there. The
  # fixture is a build tree rather than a gems bundle, but the two are the
  # same format, which is the only thing a lookup reads.
  def install_bundle(output_root, full_name)
    dir = ::File.join(output_root, full_name)
    ::FileUtils.mkdir_p(::File.dirname(dir))
    ::FileUtils.cp_r(geometry_doc_dir, dir)
    dir
  end

  # Runs +block+ with a disposable project directory, gem home, and bundle
  # root, with `geometry` 1.0.0 installed and already documented, and with
  # Bundler's environment cleared so this repository's own Gemfile can't
  # stand in for the fixture project.
  def with_fixtures
    ::Dir.mktmpdir do |dir|
      project = ::File.join(dir, "project")
      home = ::File.join(dir, "gemhome")
      output_root = ::File.join(dir, "bundles")
      ::FileUtils.mkdir_p(project)
      install_gem(home, "geometry", "1.0.0")
      install_bundle(output_root, "geometry-1.0.0")
      with_env("BUNDLE_GEMFILE" => nil, "BUNDLE_PATH" => nil, "BUNDLE_PATH__SYSTEM" => nil) do
        log.enter_level(::YARD::Logger::FATAL) do
          yield project, home, output_root
        end
      end
    end
  end

  def with_env(values)
    previous = values.keys.to_h { |key| [key, ::ENV[key]] }
    values.each { |key, value| ::ENV[key] = value }
    begin
      yield
    ensure
      previous.each { |key, value| ::ENV[key] = value }
    end
  end

  def write_lockfile(project, content)
    ::File.write(::File.join(project, "Gemfile.lock"), content)
  end

  def lookup(entity, project, home, output_root, gem_name: "geometry", **)
    ::YARD::AgentDocs::Lookup.new(
      gem_name, entity,
      project_dir: project, spec_dirs: [::File.join(home, "specifications")],
      output_root: output_root, **
    )
  end

  # Nothing in these tests should ever build; the bundle is already there.
  # Anything that does want to build says so.
  def run_lookup(entity, project, home, output_root, **)
    lookup(entity, project, home, output_root, build: false, **).run
  end

  describe "a member" do
    it "answers with the member's section" do
      with_fixtures do |project, home, output_root|
        result = run_lookup("Geometry::Triangle.new", project, home, output_root)
        assert_equal(0, result.exit_code)
        assert_includes(result.body, "### .new")
        assert_includes(result.body, "Creates a triangle, with sides fixed to 3.")
      end
    end

    # A method is never presented without saying what it belongs to.
    it "includes the lines identifying the file it came from" do
      with_fixtures do |project, home, output_root|
        body = run_lookup("Geometry::Triangle.new", project, home, output_root).body
        assert_includes(body, "# class Geometry::Triangle")
        assert_includes(body, "- **Superclass:** [`Polygon`](Polygon.md)")
        assert_includes(body, "- **Extends:** [`Named`](Named.md)")
        assert_includes(body, "- **Defined in:** `examples/geometry/lib/geometry/triangle.rb`")
      end
    end

    # A member of a deprecated or private type must not read as current, so
    # the flags below the context bullets come along with them.
    it "includes the type's deprecation and visibility flags" do
      with_fixtures do |project, home, output_root|
        body = run_lookup("Geometry::Circle#area", project, home, output_root).body
        assert_includes(body, "* **Deprecated.**")
        assert_includes(body, "  exercising the `Struct.new` case.")
        refute_includes(body, "A circle, defined by its radius.")
      end
    end

    it "leaves out the rest of the file" do
      with_fixtures do |project, home, output_root|
        body = run_lookup("Geometry::Point#x", project, home, output_root).body
        refute_includes(body, "### #y")
        refute_includes(body, "## Member Summary")
      end
    end

    it "answers for an operator method" do
      with_fixtures do |project, home, output_root|
        body = run_lookup("Geometry::Point#[]=", project, home, output_root).body
        assert_includes(body, "### #[]=")
      end
    end

    # Rewriting the documentation would make this a transformer rather than a
    # reader, and `bundle.md` would stop describing what the agent sees.
    it "reproduces the documentation verbatim" do
      with_fixtures do |project, home, output_root|
        body = run_lookup("Geometry::Triangle.new", project, home, output_root).body
        source = ::File.read(::File.join(geometry_doc_dir, "Geometry/Triangle.md"))
        assert_includes(body, source[/^### \.new\n.*?\Z/m].rstrip)
      end
    end
  end

  describe "a concept" do
    it "answers down to the end of the member summary" do
      with_fixtures do |project, home, output_root|
        result = run_lookup("Geometry::Point", project, home, output_root)
        assert_equal(0, result.exit_code)
        assert_includes(result.body, "A point in two-dimensional space.")
        assert_includes(result.body, "## Member Summary")
        refute_includes(result.body, "## Constants")
      end
    end

    it "answers with the whole file for --full" do
      with_fixtures do |project, home, output_root|
        body = run_lookup("Geometry::Point", project, home, output_root, full: true).body
        assert_includes(body, "## Constants")
        assert_includes(body, "### #zero?")
      end
    end

    it "names no member in the header" do
      with_fixtures do |project, home, output_root|
        refute_includes(run_lookup("Geometry::Point", project, home, output_root).body,
                        "* **Member:**")
      end
    end
  end

  describe "a name that could be a constant" do
    it "reads it as a constant when there is no file for it" do
      with_fixtures do |project, home, output_root|
        result = run_lookup("Geometry::Point::DIMENSIONS", project, home, output_root)
        assert_equal(0, result.exit_code)
        assert_includes(result.body, "* **Concept:** `Geometry/Point.md`")
        assert_includes(result.body, "* **Member:** `DIMENSIONS`")
        assert_includes(result.body, "### DIMENSIONS")
      end
    end

    # The file always wins, so a nested class is never mistaken for a
    # constant of its parent.
    it "reads it as a nested class when there is a file for it" do
      with_fixtures do |project, home, output_root|
        result = run_lookup("Geometry::ThreeD::Point", project, home, output_root)
        assert_equal(0, result.exit_code)
        assert_includes(result.body, "* **Concept:** `Geometry/ThreeD/Point.md`")
        refute_includes(result.body, "* **Member:**")
      end
    end

    # `--full` prints a whole file without extracting anything, so the
    # constant's heading has to be confirmed before the retry is accepted —
    # otherwise this would answer with the whole of `Geometry/Point.md`.
    it "doesn't let --full answer with the namespace's file" do
      with_fixtures do |project, home, output_root|
        result = run_lookup("Geometry::Point::NONESUCH", project, home, output_root, full: true)
        assert_equal(1, result.exit_code)
        refute_includes(result.body, "A point in two-dimensional space.")
      end
    end
  end

  describe "provenance" do
    it "names the gem, its version, where it came from, and both roots" do
      with_fixtures do |project, home, output_root|
        write_lockfile(project, <<~LOCK)
          GEM
            remote: https://rubygems.org/
            specs:
              geometry (1.0.0)
        LOCK
        body = run_lookup("Geometry::Point", project, home, output_root).body
        assert_includes(body, "**yard-agentdocs lookup:** `Geometry::Point`")
        assert_includes(body, "* **Gem:** `geometry` 1.0.0 (from Gemfile.lock)")
        assert_includes(body, "* **Gem root:** `#{::File.join(home, 'gems', 'geometry-1.0.0')}`")
        assert_includes(body, "* **Bundle:** `#{::File.join(output_root, 'geometry-1.0.0')}`")
        assert_includes(body, "* **Concept:** `Geometry/Point.md`")
      end
    end

    it "says when the version was not pinned by anything" do
      with_fixtures do |project, home, output_root|
        assert_includes(run_lookup("Geometry::Point", project, home, output_root).body,
                        "(newest installed)")
      end
    end

    # The bundle an agent gets must be the version the project depends on,
    # never whichever one happens to be on disk.
    it "reads the version the lockfile pins, not the newest built" do
      with_fixtures do |project, home, output_root|
        install_gem(home, "geometry", "2.0.0")
        ::FileUtils.mkdir_p(::File.join(output_root, "geometry-2.0.0"))
        ::File.write(::File.join(output_root, "geometry-2.0.0", "Geometry.md"), "# wrong\n")
        write_lockfile(project, <<~LOCK)
          GEM
            remote: https://rubygems.org/
            specs:
              geometry (1.0.0)
        LOCK
        body = run_lookup("Geometry::Point", project, home, output_root).body
        assert_includes(body, "* **Bundle:** `#{::File.join(output_root, 'geometry-1.0.0')}`")
        assert_includes(body, "A point in two-dimensional space.")
      end
    end
  end

  describe "a miss" do
    it "lists the concept's own members when a member isn't there" do
      with_fixtures do |project, home, output_root|
        result = run_lookup("Geometry::Triangle#nonesuch", project, home, output_root)
        assert_equal(1, result.exit_code)
        assert_includes(result.body, "No `### #nonesuch` heading in `Geometry/Triangle.md`.")
        assert_includes(result.body, "Members defined in `Geometry/Triangle.md` (1):")
        assert_includes(result.body, ".new")
      end
    end

    # The one hop a bundle records: exactly which file does define it.
    it "points at the concept an inherited member comes from" do
      with_fixtures do |project, home, output_root|
        body = run_lookup("Geometry::Triangle#describe", project, home, output_root).body
        assert_includes(body, "inherited from Polygon")
        assert_includes(body, "Polygon.md")
      end
    end

    it "lists the namespace's other concepts when a name has no file" do
      with_fixtures do |project, home, output_root|
        result = run_lookup("Geometry::Nonesuch#anything", project, home, output_root)
        assert_equal(1, result.exit_code)
        assert_includes(result.body, "No concept file for `Geometry::Nonesuch`")
        assert_includes(result.body, "looked for: Geometry/Nonesuch.md")
        assert_includes(result.body, "Geometry::Point")
      end
    end

    # A `Foo::Bar::BAZ` that resolved to neither was searched for two ways,
    # and saying only one of them would misdescribe what was looked at.
    it "reports both readings of a name that could be a constant" do
      with_fixtures do |project, home, output_root|
        result = run_lookup("Geometry::Point::NONESUCH", project, home, output_root)
        assert_equal(1, result.exit_code)
        assert_includes(result.body, "as a class or module, no file  Geometry/Point/NONESUCH.md")
        assert_includes(result.body, "as a constant, no heading      `### NONESUCH`")
        # `Geometry::Point` has no nested concepts at all, which is itself the
        # answer to the class reading, and the member list answers the other.
        assert_includes(result.body, "Other concepts in `Geometry::Point`: none.")
        assert_includes(result.body, "Members defined in `Geometry/Point.md` (17):")
        assert_includes(result.body, "DIMENSIONS")
      end
    end

    # A guess that reads as an answer is the failure this tool exists to
    # remove, so candidates always say what they are.
    it "labels candidates as candidates" do
      with_fixtures do |project, home, output_root|
        body = run_lookup("Geometry::Triangle#nonesuch", project, home, output_root).body
        assert_includes(body, "Those are candidates, not an answer.")
      end
    end

    it "reports a gem that isn't installed" do
      with_fixtures do |project, home, output_root|
        result = run_lookup("Foo::Bar", project, home, output_root, gem_name: "nonesuch")
        assert_equal(1, result.exit_code)
        assert_includes(result.body, "not installed")
      end
    end
  end

  describe "a malformed request" do
    it "rejects an entity that isn't a name" do
      with_fixtures do |project, home, output_root|
        result = run_lookup("not an entity", project, home, output_root)
        assert_equal(2, result.exit_code)
        assert_includes(result.body, "is not an entity")
      end
    end

    it "rejects a trailing sigil with no member" do
      with_fixtures do |project, home, output_root|
        assert_equal(2, run_lookup("Geometry::Point#", project, home, output_root).exit_code)
      end
    end

    it "rejects two members" do
      with_fixtures do |project, home, output_root|
        assert_equal(2, run_lookup("Geometry::Point#x#y", project, home, output_root).exit_code)
      end
    end

    # Both arguments are checked for shape before anything is resolved, so
    # this reads as the usage error it is rather than as a gem not installed.
    it "rejects a gem name that isn't a gem name" do
      with_fixtures do |project, home, output_root|
        result = run_lookup("Foo::Bar", project, home, output_root, gem_name: "../etc/passwd")
        assert_equal(2, result.exit_code)
        assert_includes(result.body, "is not a gem name")
      end
    end

    # The argument-quoting note in the tool's help exists because of these.
    it "explains that operator names need quoting" do
      with_fixtures do |project, home, output_root|
        body = run_lookup("not an entity", project, home, output_root).body
        assert_includes(body, "quote the")
        assert_includes(body, "'Foo::Bar#[]='")
      end
    end
  end

  describe "a dependency with no released version" do
    let(:sourced_lockfile) { <<~LOCK }
      GIT
        remote: https://github.com/nobody/widget.git
        revision: 0123456789abcdef0123456789abcdef01234567
        specs:
          widget (2.0.0)

      PATH
        remote: ../sprocket
        specs:
          sprocket (0.5.0)
    LOCK

    it "reports a git dependency and does not build" do
      with_fixtures do |project, home, output_root|
        write_lockfile(project, sourced_lockfile)
        result = lookup("Foo::Bar", project, home, output_root, gem_name: "widget").run
        assert_equal(3, result.exit_code)
        assert_includes(result.body, "https://github.com/nobody/widget.git")
        assert_includes(result.body, "bundle show widget")
        refute(::File.exist?(::File.join(output_root, "widget-2.0.0")))
      end
    end

    it "reports a path dependency with its resolved path" do
      with_fixtures do |project, home, output_root|
        write_lockfile(project, sourced_lockfile)
        result = lookup("Foo::Bar", project, home, output_root, gem_name: "sprocket").run
        assert_equal(3, result.exit_code)
        assert_includes(result.body, ::File.expand_path("../sprocket", project))
      end
    end
  end

  describe "a missing bundle" do
    it "reports it and the command that would build it, with --no-build" do
      with_fixtures do |project, home, output_root|
        install_gem(home, "geometry", "2.0.0")
        result = run_lookup("Geometry::Point", project, home, output_root, version: "2.0.0")
        assert_equal(1, result.exit_code)
        assert_includes(result.body, "No agentdocs bundle for geometry 2.0.0.")
        assert_includes(result.body, ::File.join(output_root, "geometry-2.0.0"))
        assert_includes(result.body, "agentdocs gems geometry:2.0.0")
        refute(::File.exist?(::File.join(output_root, "geometry-2.0.0")))
      end
    end

    it "treats an empty directory as no bundle" do
      with_fixtures do |project, home, output_root|
        install_gem(home, "geometry", "2.0.0")
        ::FileUtils.mkdir_p(::File.join(output_root, "geometry-2.0.0"))
        result = run_lookup("Geometry::Point", project, home, output_root, version: "2.0.0")
        assert_equal(1, result.exit_code)
        assert_includes(result.body, "No agentdocs bundle")
      end
    end

    it "builds it by default and answers from it" do
      with_fixtures do |project, home, output_root|
        install_gem(home, "widget", "1.0.0")
        result = lookup("Widget#spin", project, home, output_root, gem_name: "widget").run
        assert_equal(0, result.exit_code)
        assert_includes(result.body, "### #spin")
        assert_includes(result.body, "Spins the widget.")
        assert(::File.directory?(::File.join(output_root, "widget-1.0.0")))
      end
    end

    # A specification whose sources aren't installed has nothing to document,
    # so the build produces no bundle and there is nothing to read.
    it "reports a build that produced nothing" do
      with_fixtures do |project, home, output_root|
        install_gem(home, "widget", "1.0.0", sources: false)
        result = lookup("Widget#spin", project, home, output_root, gem_name: "widget").run
        assert_equal(4, result.exit_code)
        assert_includes(result.body, "Failed to build")
      end
    end
  end

  # The body an agent reads is documentation and nothing else. YARD's logger
  # writes to standard output by default, so a build would otherwise mix
  # parse progress and per-gem announcements straight into it.
  describe "build progress" do
    it "goes to standard error, and the logger is put back afterwards" do
      with_fixtures do |project, home, output_root|
        install_gem(home, "widget", "1.0.0")
        stdout_stand_in = ::StringIO.new
        stderr_capture = ::StringIO.new
        previous_io = log.io
        previous_stderr = $stderr
        log.io = stdout_stand_in
        $stderr = stderr_capture
        io_after = nil
        begin
          log.enter_level(::YARD::Logger::WARN) do
            lookup("Widget#spin", project, home, output_root, gem_name: "widget").run
          end
          io_after = log.io
        ensure
          $stderr = previous_stderr
          log.io = previous_io
        end
        assert_empty(stdout_stand_in.string)
        assert_includes(stderr_capture.string, "yard-agentdocs:")
        assert_same(stdout_stand_in, io_after)
      end
    end
  end

  describe ::YARD::AgentDocs::Lookup::Result do
    it "always ends the body with a newline" do
      with_fixtures do |project, home, output_root|
        entities = ["Geometry::Point", "Geometry::Triangle.new", "Geometry::Nonesuch", "not an entity"]
        entities.each do |entity|
          assert(run_lookup(entity, project, home, output_root).body.end_with?("\n"), entity)
        end
      end
    end

    it "reports success only for exit code zero" do
      with_fixtures do |project, home, output_root|
        assert(run_lookup("Geometry::Point", project, home, output_root).success?)
        refute(run_lookup("Geometry::Nonesuch", project, home, output_root).success?)
      end
    end
  end
end
