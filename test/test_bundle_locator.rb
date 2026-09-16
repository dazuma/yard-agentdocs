# frozen_string_literal: true

require "helper"
require "fileutils"
require "tmpdir"

describe ::YARD::AgentDocs::BundleLocator do
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

  # Puts an already-built bundle at a gem version's canonical path.
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

  def locate(project, home, output_root, gem_name: "geometry", build: false, **)
    ::YARD::AgentDocs::BundleLocator.new(
      gem_name,
      project_dir: project, spec_dirs: [::File.join(home, "specifications")],
      output_root: output_root, **
    ).locate(build: build)
  end

  describe "a bundle that is there" do
    it "reports it ready, with the directory and the resolution" do
      with_fixtures do |project, home, output_root|
        location = locate(project, home, output_root)
        assert_equal(:ready, location.status)
        assert(location.ready?)
        assert_equal(::File.join(output_root, "geometry-1.0.0"), location.bundle_dir)
        assert_equal("1.0.0", location.resolution.version)
      end
    end

    it "derives the directory from the version the lockfile resolves" do
      with_fixtures do |project, home, output_root|
        install_gem(home, "geometry", "2.0.0")
        install_bundle(output_root, "geometry-2.0.0")
        write_lockfile(project, <<~LOCK)
          GEM
            remote: https://rubygems.org/
            specs:
              geometry (1.0.0)
        LOCK
        location = locate(project, home, output_root)
        assert_equal(::File.join(output_root, "geometry-1.0.0"), location.bundle_dir)
        assert_equal(:lockfile, location.resolution.version_origin)
      end
    end

    it "honors a version override" do
      with_fixtures do |project, home, output_root|
        install_gem(home, "geometry", "2.0.0")
        install_bundle(output_root, "geometry-2.0.0")
        location = locate(project, home, output_root, version: "2.0.0")
        assert_equal(::File.join(output_root, "geometry-2.0.0"), location.bundle_dir)
        assert_equal(:flag, location.resolution.version_origin)
      end
    end
  end

  describe "a bundle that is not there" do
    # The directory is still reported, because a caller has to be able to say
    # where it looked and where a build would put it.
    it "reports it missing, with the directory it would occupy" do
      with_fixtures do |project, home, output_root|
        install_gem(home, "geometry", "2.0.0")
        location = locate(project, home, output_root, version: "2.0.0")
        assert_equal(:missing, location.status)
        refute(location.ready?)
        assert_equal(::File.join(output_root, "geometry-2.0.0"), location.bundle_dir)
      end
    end

    # An empty directory is not a bundle. Publication is atomic, so anything
    # with content in it is a complete one.
    it "treats an empty directory as missing" do
      with_fixtures do |project, home, output_root|
        install_gem(home, "geometry", "2.0.0")
        ::FileUtils.mkdir_p(::File.join(output_root, "geometry-2.0.0"))
        location = locate(project, home, output_root, version: "2.0.0")
        assert_equal(:missing, location.status)
      end
    end

    it "builds it when asked, and reports it ready" do
      with_fixtures do |project, home, output_root|
        install_gem(home, "geometry", "2.0.0")
        location = locate(project, home, output_root, version: "2.0.0", build: true)
        assert_equal(:ready, location.status)
        assert(::File.directory?(::File.join(output_root, "geometry-2.0.0")))
      end
    end

    # A specification with no sources behind it has nothing to document, so
    # the build produces no bundle.
    it "reports a build that produced nothing as failed" do
      with_fixtures do |project, home, output_root|
        install_gem(home, "geometry", "3.0.0", sources: false)
        location = locate(project, home, output_root, version: "3.0.0", build: true)
        assert_equal(:build_failed, location.status)
        assert_equal(::File.join(output_root, "geometry-3.0.0"), location.bundle_dir)
      end
    end
  end

  describe "a dependency with nothing to locate" do
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

    # Neither invents a location: where a git checkout lives is Bundler's
    # business, and a path dependency's source directory is not a bundle.
    it "reports a git dependency with no directory at all" do
      with_fixtures do |project, home, output_root|
        write_lockfile(project, sourced_lockfile)
        location = locate(project, home, output_root, gem_name: "widget")
        assert_equal(:no_release, location.status)
        assert_nil(location.bundle_dir)
        assert_equal(:git, location.resolution.kind)
      end
    end

    it "reports a path dependency with no directory at all" do
      with_fixtures do |project, home, output_root|
        write_lockfile(project, sourced_lockfile)
        location = locate(project, home, output_root, gem_name: "sprocket")
        assert_equal(:no_release, location.status)
        assert_nil(location.bundle_dir)
      end
    end

    it "reports a gem that isn't installed" do
      with_fixtures do |project, home, output_root|
        location = locate(project, home, output_root, gem_name: "nonesuch")
        assert_equal(:not_installed, location.status)
        assert_nil(location.bundle_dir)
      end
    end

    # Checked before anything is resolved, so a malformed request reads as one.
    it "rejects a name that isn't a gem name, without resolving" do
      with_fixtures do |project, home, output_root|
        location = locate(project, home, output_root, gem_name: "not a gem name")
        assert_equal(:invalid_name, location.status)
        assert_nil(location.resolution)
      end
    end
  end
end
