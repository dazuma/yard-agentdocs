# frozen_string_literal: true

require "helper"
require "fileutils"
require "open3"
require "shellwords"
require "tmpdir"

describe ::YARD::AgentDocs::BundlePath do
  let(:project_root) { ::File.expand_path("..", __dir__) }
  let(:geometry_doc_dir) { ::File.join(project_root, "examples/geometry/doc") }

  # Installs a gem into a fake gem home laid out the way rubygems lays out a
  # real one, so the specification reports a `full_gem_path` inside it.
  #
  # @param home [String] the fake gem home
  # @param name [String] the gem name
  # @param version [String] the gem version
  # @return [String] the gem's installed directory
  def install_gem(home, name, version)
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
    ::FileUtils.mkdir_p(::File.join(gem_dir, "lib"))
    ::File.write(::File.join(gem_dir, "lib", "#{name}.rb"), "# A widget.\nclass Widget; end\n")
    gem_dir
  end

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

  def run_path(project, home, output_root, gem_name: "geometry", build: false, **)
    ::YARD::AgentDocs::BundlePath.new(
      gem_name,
      project_dir: project, spec_dirs: [::File.join(home, "specifications")],
      output_root: output_root, build: build, **
    ).run
  end

  describe "a bundle that is there" do
    it "writes the directory and nothing else to standard output" do
      with_fixtures do |project, home, output_root|
        result = run_path(project, home, output_root)
        assert_equal(0, result.exit_code)
        assert(result.success?)
        assert_equal("#{::File.join(output_root, 'geometry-1.0.0')}\n", result.out)
      end
    end

    # The property the whole output shape exists for: one line, no leading or
    # trailing prose, nothing a command substitution would carry along.
    it "writes exactly one bare line" do
      with_fixtures do |project, home, output_root|
        assert_match(/\A\S+\n\z/, run_path(project, home, output_root).out)
      end
    end

    # A success has nothing to say that the path does not already say, and a
    # line on every run is noise in a command the caller composed to get
    # something else's output.
    it "says nothing at all on standard error" do
      with_fixtures do |project, home, output_root|
        write_lockfile(project, <<~LOCK)
          GEM
            remote: https://rubygems.org/
            specs:
              geometry (1.0.0)
        LOCK
        assert_empty(run_path(project, home, output_root).err)
      end
    end

    # Which version was resolved is visible where it matters: in the path.
    it "honors a version override" do
      with_fixtures do |project, home, output_root|
        install_gem(home, "geometry", "2.0.0")
        install_bundle(output_root, "geometry-2.0.0")
        result = run_path(project, home, output_root, version: "2.0.0")
        assert_equal("#{::File.join(output_root, 'geometry-2.0.0')}\n", result.out)
        assert_empty(result.err)
      end
    end

    it "builds a missing bundle when asked" do
      with_fixtures do |project, home, output_root|
        install_gem(home, "geometry", "2.0.0")
        result = run_path(project, home, output_root, version: "2.0.0", build: true)
        assert_equal(0, result.exit_code)
        assert_equal("#{::File.join(output_root, 'geometry-2.0.0')}\n", result.out)
      end
    end
  end

  # Every failure keeps standard output empty. A line there means a bundle is
  # at that location and means nothing else, so a command substitution can
  # never yield a path that isn't one.
  describe "standard output on a failure" do
    it "is empty when there is no bundle and none was built" do
      with_fixtures do |project, home, output_root|
        install_gem(home, "geometry", "2.0.0")
        result = run_path(project, home, output_root, version: "2.0.0")
        assert_equal(1, result.exit_code)
        assert_empty(result.out)
        assert_includes(result.err, "No agentdocs bundle for geometry 2.0.0.")
        assert_includes(result.err, "agentdocs gems geometry:2.0.0")
      end
    end

    it "is empty when a build failed" do
      with_fixtures do |project, home, output_root|
        install_gem(home, "geometry", "3.0.0")
        ::FileUtils.rm_rf(::File.join(home, "gems", "geometry-3.0.0"))
        result = run_path(project, home, output_root, version: "3.0.0", build: true)
        assert_equal(4, result.exit_code)
        assert_empty(result.out)
        assert_includes(result.err, "Failed to build")
      end
    end

    it "is empty when the gem isn't installed" do
      with_fixtures do |project, home, output_root|
        result = run_path(project, home, output_root, gem_name: "nonesuch")
        assert_equal(1, result.exit_code)
        assert_empty(result.out)
        assert_includes(result.err, "Read the gem's own source instead")
      end
    end

    it "is empty when the name isn't a gem name" do
      with_fixtures do |project, home, output_root|
        result = run_path(project, home, output_root, gem_name: "not a gem name")
        assert_equal(2, result.exit_code)
        assert_empty(result.out)
        assert_includes(result.err, "is not a gem name")
      end
    end

    describe "a dependency with no released version" do
      let(:sourced_lockfile) do
        <<~LOCK
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
      end

      it "is empty for a git dependency, which is reported on standard error" do
        with_fixtures do |project, home, output_root|
          write_lockfile(project, sourced_lockfile)
          result = run_path(project, home, output_root, gem_name: "widget")
          assert_equal(3, result.exit_code)
          assert_empty(result.out)
          assert_includes(result.err, "https://github.com/nobody/widget.git")
          assert_includes(result.err, "bundle show widget")
        end
      end

      # The case that makes the rule worth stating: a path dependency has a
      # real directory on disk, and printing it would be the most tempting
      # way to make `"$(…)"/index.md` name something that is not a bundle.
      it "is empty for a path dependency, whose source is a real directory" do
        with_fixtures do |project, home, output_root|
          write_lockfile(project, sourced_lockfile)
          result = run_path(project, home, output_root, gem_name: "sprocket")
          assert_equal(3, result.exit_code)
          assert_empty(result.out)
          assert_includes(result.err, ::File.expand_path("../sprocket", project))
        end
      end
    end
  end

  # These drive the class through a real subprocess inside a real shell, which
  # is the only way to exercise the property the output shape exists for. The
  # subprocess stands in for the Toys tool, whose `run` is the same three
  # lines; what is under test is the stream contract, not the Toys DSL.
  describe "composed into a shell command" do
    def path_command(project, home, output_root, gem_name)
      script = ::File.join(project, "path.rb")
      ::File.write(script, <<~RUBY)
        require "yard-agentdocs"
        result = ::YARD::AgentDocs::BundlePath.new(
          ARGV[0], build: false,
          project_dir: #{project.inspect},
          spec_dirs: [#{::File.join(home, 'specifications').inspect}],
          output_root: #{output_root.inspect}
        ).run
        $stdout.print(result.out)
        $stderr.print(result.err)
        exit(result.exit_code)
      RUBY
      ::Shellwords.join([::RbConfig.ruby, "-I", ::File.join(project_root, "lib"), script, gem_name])
    end

    # Both streams together, the way an agent harness presents them.
    def sh(command)
      out, status = ::Open3.capture2e("sh", "-c", command)
      [out, status.exitstatus]
    end

    it "resolves and greps in one invocation" do
      with_fixtures do |project, home, output_root|
        command = path_command(project, home, output_root, "geometry")
        out, status = sh("docs_dir=$(#{command}) && grep -c . \"$docs_dir\"/index.md")
        assert_equal(0, status)
        # Exactly grep's own output, on both streams together: anything the
        # tool said would either corrupt `$docs_dir` or show up here.
        assert_match(/\A\d+\n\z/, out)
      end
    end

    # The wrinkle a bare `"$( )"` cannot close: an empty substitution leaves
    # `grep` reading `/index.md` off the filesystem root. Gating the grep on
    # the exit status means the failure path never reaches `grep` at all,
    # which is why the published recipe is written this way.
    it "never runs the grep when there is no bundle" do
      with_fixtures do |project, home, output_root|
        command = path_command(project, home, output_root, "nonesuch")
        out, status = sh("docs_dir=$(#{command}) && grep -i point \"$docs_dir\"/index.md")
        refute_equal(0, status)
        assert_includes(out, "Read the gem's own source instead")
        refute_includes(out, "index.md")
      end
    end
  end
end
