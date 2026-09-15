# frozen_string_literal: true

require "helper"
require "fileutils"
require "rbconfig"
require "tmpdir"

describe ::YARD::AgentDocs::DependencyResolver do
  # Writes a gem specification into a fake gem home, laid out the way
  # rubygems lays out a real one. Only the specification is needed here: this
  # class resolves which release to read, and never parses the sources.
  #
  # @param home [String] the fake gem home
  # @param name [String] the gem name
  # @param version [String] the gem version
  # @param platform [String, nil] a platform, for a platform-specific release
  # @return [String] the specification's path
  def install_spec(home, name, version, platform: nil)
    spec_dir = ::File.join(home, "specifications")
    ::FileUtils.mkdir_p(spec_dir)
    full_name = [name, version, platform].compact.join("-")
    path = ::File.join(spec_dir, "#{full_name}.gemspec")
    ::File.write(path, <<~RUBY)
      Gem::Specification.new do |spec|
        spec.name = #{name.inspect}
        spec.version = #{version.inspect}
        spec.platform = #{platform.inspect} if #{!platform.nil?}
        spec.summary = "A test gem."
        spec.authors = ["Nobody"]
      end
    RUBY
    path
  end

  # Runs +block+ with a disposable project directory and fake gem home, and
  # with Bundler's environment cleared.
  #
  # Clearing it is not housekeeping. These tests run under `toys`, which runs
  # under Bundler, so `$BUNDLE_GEMFILE` names this repository's own Gemfile.
  # Left alone it overrides every fixture lockfile below, and a test that
  # happens to ask about a gem this repository also depends on then passes
  # for entirely the wrong reason.
  def with_project
    ::Dir.mktmpdir do |dir|
      project = ::File.join(dir, "project")
      home = ::File.join(dir, "gemhome")
      ::FileUtils.mkdir_p(project)
      ::FileUtils.mkdir_p(home)
      with_env("BUNDLE_GEMFILE" => nil, "BUNDLE_PATH" => nil, "BUNDLE_PATH__SYSTEM" => nil) do
        yield project, home
      end
    end
  end

  def write_lockfile(project, content)
    path = ::File.join(project, "Gemfile.lock")
    ::File.write(path, content)
    path
  end

  def write_bundle_config(project, content)
    ::FileUtils.mkdir_p(::File.join(project, ".bundle"))
    ::File.write(::File.join(project, ".bundle", "config"), content)
  end

  # The specifications directory rubygems creates under a bundle path, for
  # the Ruby running these tests.
  def vendored_spec_dir(project, bundle_path)
    ::File.join(project, bundle_path, ::Gem.ruby_engine,
                ::RbConfig::CONFIG["ruby_version"], "specifications")
  end

  def resolver(name, project, home, **)
    ::YARD::AgentDocs::DependencyResolver.new(
      name, project_dir: project, spec_dirs: [::File.join(home, "specifications")], **
    )
  end

  # A resolver with its real default search path, which is what the bundle
  # path tests are about.
  def default_dirs_for(project)
    ::YARD::AgentDocs::DependencyResolver.new("yard", project_dir: project).default_spec_dirs
  end

  def global_spec_dirs
    ::YARD::AgentDocs::GemBuilder.default_spec_dirs.map { |dir| ::File.expand_path(dir) }
  end

  # Sets environment variables for the duration of +block+, restoring
  # whatever was there before — including "nothing was there".
  def with_env(values)
    previous = values.keys.to_h { |key| [key, ::ENV[key]] }
    values.each { |key, value| ::ENV[key] = value }
    begin
      yield
    ensure
      previous.each { |key, value| ::ENV[key] = value }
    end
  end

  # A lockfile with one of each source kind, plus the sections that carry no
  # resolution at all — the `DEPENDENCIES` constraints and the Bundler 4
  # `CHECKSUMS` block, both of which name gems beside a version at indents a
  # naive scan would pick up.
  let(:mixed_lockfile) { <<~LOCK }
    GIT
      remote: https://github.com/nobody/widget.git
      revision: 0123456789abcdef0123456789abcdef01234567
      branch: main
      specs:
        widget (2.0.0)
          rake (>= 13.0)

    PATH
      remote: ../sprocket
      specs:
        sprocket (0.5.0)

    GEM
      remote: https://rubygems.org/
      specs:
        rake (13.2.1)
        yard (0.9.45)
          rake (>= 13.0)

    PLATFORMS
      arm64-darwin-23
      ruby

    DEPENDENCIES
      rake (~> 99.0)
      sprocket!
      widget!
      yard (~> 99.0)

    CHECKSUMS
      rake (99.9.9) sha256=abc
      yard (99.9.9) sha256=def

    BUNDLED WITH
       4.0.10
  LOCK

  describe "#resolve" do
    it "resolves the version a lockfile's GEM section pins" do
      with_project do |project, home|
        write_lockfile(project, mixed_lockfile)
        install_spec(home, "yard", "0.9.45")
        install_spec(home, "yard", "0.9.99")
        resolution = resolver("yard", project, home).resolve
        assert_equal(:release, resolution.kind)
        assert_equal("0.9.45", resolution.version)
        assert_equal(:lockfile, resolution.version_origin)
        assert_equal("yard-0.9.45", resolution.spec.full_name)
      end
    end

    # A resolved spec is indented four spaces and its own dependencies six,
    # so `rake (>= 13.0)` under `yard` must not be read as resolving rake.
    it "ignores the dependency lines under a resolved spec" do
      with_project do |project, home|
        write_lockfile(project, mixed_lockfile)
        install_spec(home, "rake", "13.2.1")
        assert_equal("13.2.1", resolver("rake", project, home).resolve.version)
      end
    end

    # `DEPENDENCIES` holds constraints and `CHECKSUMS` holds hashes; neither
    # resolves anything, and both name gems beside a version.
    it "ignores the sections that resolve nothing" do
      with_project do |project, home|
        write_lockfile(project, mixed_lockfile)
        install_spec(home, "yard", "0.9.45")
        install_spec(home, "yard", "99.9.9")
        assert_equal("0.9.45", resolver("yard", project, home).resolve.version)
      end
    end

    # `GIT` and `PATH` sections carry `specs:` blocks at exactly the indent a
    # resolved release sits at, which is why the parse has to be sectional.
    it "reports a git dependency rather than resolving it" do
      with_project do |project, home|
        write_lockfile(project, mixed_lockfile)
        install_spec(home, "widget", "2.0.0")
        resolution = resolver("widget", project, home).resolve
        assert_equal(:git, resolution.kind)
        assert_nil(resolution.spec)
        assert_includes(resolution.source, "https://github.com/nobody/widget.git")
        assert_includes(resolution.source, "0123456789abcdef0123456789abcdef01234567")
        assert_includes(resolution.source, "branch main")
      end
    end

    it "reports a path dependency, resolved against the lockfile's directory" do
      with_project do |project, home|
        write_lockfile(project, mixed_lockfile)
        resolution = resolver("sprocket", project, home).resolve
        assert_equal(:path, resolution.kind)
        assert_equal(::File.expand_path("../sprocket", project), resolution.source)
      end
    end

    # Bundler finds a Gemfile by walking up, so a lookup run from `lib/` has
    # to resolve the same versions `bundle exec` would from the same place.
    # Resolving only against the current directory would silently answer with
    # the newest installed version instead.
    it "walks up from a subdirectory to find the lockfile" do
      with_project do |project, home|
        write_lockfile(project, mixed_lockfile)
        install_spec(home, "yard", "0.9.45")
        install_spec(home, "yard", "0.9.99")
        nested = ::File.join(project, "lib", "deep")
        ::FileUtils.mkdir_p(nested)
        assert_equal("0.9.45", resolver("yard", nested, home).resolve.version)
      end
    end

    it "honors $BUNDLE_GEMFILE" do
      with_project do |project, home|
        install_spec(home, "yard", "0.9.45")
        install_spec(home, "yard", "0.9.99")
        elsewhere = ::File.join(::File.dirname(project), "elsewhere")
        ::FileUtils.mkdir_p(elsewhere)
        write_lockfile(elsewhere, mixed_lockfile)
        with_env("BUNDLE_GEMFILE" => ::File.join(elsewhere, "Gemfile")) do
          resolution = resolver("yard", project, home).resolve
          assert_equal("0.9.45", resolution.version)
          assert_equal(::File.join(elsewhere, "Gemfile.lock"), resolution.lockfile)
        end
      end
    end

    it "falls back to the newest installed version with no lockfile" do
      with_project do |project, home|
        install_spec(home, "yard", "0.9.45")
        install_spec(home, "yard", "0.9.99")
        resolution = resolver("yard", project, home).resolve
        assert_equal("0.9.99", resolution.version)
        assert_equal(:installed, resolution.version_origin)
        assert_nil(resolution.lockfile)
      end
    end

    it "prefers an explicit version over the lockfile" do
      with_project do |project, home|
        write_lockfile(project, mixed_lockfile)
        install_spec(home, "yard", "0.9.45")
        install_spec(home, "yard", "0.9.99")
        resolution = resolver("yard", project, home, version: "0.9.99").resolve
        assert_equal("0.9.99", resolution.version)
        assert_equal(:flag, resolution.version_origin)
      end
    end

    # Naming a version is itself the statement that a released version is
    # wanted, so it settles even a gem the lockfile resolves from git.
    it "prefers an explicit version over a non-release source" do
      with_project do |project, home|
        write_lockfile(project, mixed_lockfile)
        install_spec(home, "widget", "2.0.0")
        resolution = resolver("widget", project, home, version: "2.0.0").resolve
        assert_equal(:release, resolution.kind)
        assert_equal("widget-2.0.0", resolution.spec.full_name)
      end
    end

    it "reports a gem that isn't installed" do
      with_project do |project, home|
        write_lockfile(project, mixed_lockfile)
        resolution = resolver("yard", project, home).resolve
        assert_equal(:missing, resolution.kind)
        assert_includes(resolution.message, "not installed")
        assert_empty(resolution.installed_versions)
      end
    end

    it "reports the versions that are installed when the wanted one isn't" do
      with_project do |project, home|
        write_lockfile(project, mixed_lockfile)
        install_spec(home, "yard", "0.9.44")
        install_spec(home, "yard", "0.9.99")
        resolution = resolver("yard", project, home).resolve
        assert_equal(:missing, resolution.kind)
        assert_equal("0.9.45", resolution.version)
        assert_equal(["0.9.44", "0.9.99"], resolution.installed_versions)
      end
    end

    it "rejects a name that isn't a gem name" do
      with_project do |project, home|
        resolution = resolver("../etc/passwd", project, home).resolve
        assert_equal(:missing, resolution.kind)
        assert_includes(resolution.message, "not a gem name")
      end
    end

    # Specifications are globbed by name prefix, which also turns up
    # `yard-agentdocs` when asked for `yard`, so each candidate is confirmed
    # against the name it declares.
    it "doesn't match a longer gem name starting the same way" do
      with_project do |project, home|
        install_spec(home, "yard-agentdocs", "9.9.9")
        assert_equal(:missing, resolver("yard", project, home).resolve.kind)
      end
    end
  end

  describe "#resolve with platform-specific releases" do
    # Each platform of one version is a separate installed gem, and gets a
    # separate bundle, since bundles are named by full name. The one to
    # document is the one this machine would load.
    it "prefers the local platform" do
      with_project do |project, home|
        install_spec(home, "widget", "2.0.0")
        install_spec(home, "widget", "2.0.0", platform: ::Gem::Platform.local.to_s)
        install_spec(home, "widget", "2.0.0", platform: "unreal-cpu-linux")
        resolution = resolver("widget", project, home).resolve
        assert_equal("widget-2.0.0-#{::Gem::Platform.local}", resolution.spec.full_name)
      end
    end

    it "falls back to the pure-Ruby release" do
      with_project do |project, home|
        install_spec(home, "widget", "2.0.0")
        install_spec(home, "widget", "2.0.0", platform: "unreal-cpu-linux")
        assert_equal("widget-2.0.0", resolver("widget", project, home).resolve.spec.full_name)
      end
    end

    # Bundler writes a platform release's platform into the version position,
    # as `2.0.0-arm64-darwin`.
    it "reads the version out of a platform-suffixed lockfile entry" do
      with_project do |project, home|
        write_lockfile(project, <<~LOCK)
          GEM
            remote: https://rubygems.org/
            specs:
              widget (2.0.0-arm64-darwin)

          BUNDLED WITH
             4.0.10
        LOCK
        install_spec(home, "widget", "2.0.0")
        install_spec(home, "widget", "9.9.9")
        assert_equal("2.0.0", resolver("widget", project, home).resolve.version)
      end
    end
  end

  describe "#default_spec_dirs" do
    # A project configured with `bundle config path vendor/bundle` has its
    # gems installed, just not where the global search looks. This is the one
    # case a lookup would otherwise fail for a gem sitting right there.
    it "searches a configured bundle path first" do
      with_project do |project, _home|
        vendor = vendored_spec_dir(project, "vendor/bundle")
        ::FileUtils.mkdir_p(vendor)
        write_bundle_config(project, "---\nBUNDLE_PATH: \"vendor/bundle\"\n")
        dirs = default_dirs_for(project)
        assert_equal(vendor, dirs.first)
        assert_equal(global_spec_dirs, dirs.drop(1))
      end
    end

    it "honors $BUNDLE_PATH" do
      with_project do |project, _home|
        vendor = vendored_spec_dir(project, "elsewhere")
        ::FileUtils.mkdir_p(vendor)
        with_env("BUNDLE_PATH" => "elsewhere") do
          assert_equal(vendor, default_dirs_for(project).first)
        end
      end
    end

    it "ignores a bundle path a project has switched back to the system one" do
      with_project do |project, _home|
        ::FileUtils.mkdir_p(vendored_spec_dir(project, "vendor/bundle"))
        write_bundle_config(project,
                            "---\nBUNDLE_PATH: \"vendor/bundle\"\nBUNDLE_PATH__SYSTEM: \"true\"\n")
        assert_equal(global_spec_dirs, default_dirs_for(project))
      end
    end

    # The configuration lives at the project root, which is where the
    # lockfile is — not wherever the lookup happened to be run from.
    it "reads the configuration from the lockfile's directory" do
      with_project do |project, _home|
        vendor = vendored_spec_dir(project, "vendor/bundle")
        ::FileUtils.mkdir_p(vendor)
        write_bundle_config(project, "---\nBUNDLE_PATH: \"vendor/bundle\"\n")
        write_lockfile(project, mixed_lockfile)
        nested = ::File.join(project, "lib")
        ::FileUtils.mkdir_p(nested)
        assert_equal(vendor, default_dirs_for(nested).first)
      end
    end

    # A sibling directory under the bundle path belongs to a different Ruby,
    # whose specifications wouldn't load here anyway.
    it "ignores a configured bundle path with nothing installed for this Ruby" do
      with_project do |project, _home|
        ::FileUtils.mkdir_p(::File.join(project, "vendor", "bundle", "ruby", "1.8.7"))
        write_bundle_config(project, "---\nBUNDLE_PATH: \"vendor/bundle\"\n")
        assert_equal(global_spec_dirs, default_dirs_for(project))
      end
    end

    it "ignores an unreadable bundler configuration" do
      with_project do |project, _home|
        write_bundle_config(project, "\t- not: [valid\n")
        assert_equal(global_spec_dirs, default_dirs_for(project))
      end
    end
  end

  describe "Resolution#version_origin_description" do
    it "names the lockfile a version came from" do
      with_project do |project, home|
        write_lockfile(project, mixed_lockfile)
        install_spec(home, "yard", "0.9.45")
        assert_equal("from Gemfile.lock",
                     resolver("yard", project, home).resolve.version_origin_description)
      end
    end

    it "names the flag" do
      with_project do |project, home|
        install_spec(home, "yard", "0.9.45")
        assert_equal("from --version",
                     resolver("yard", project, home, version: "0.9.45")
                       .resolve.version_origin_description)
      end
    end

    it "says so when nothing pinned the version" do
      with_project do |project, home|
        install_spec(home, "yard", "0.9.45")
        assert_equal("newest installed",
                     resolver("yard", project, home).resolve.version_origin_description)
      end
    end
  end
end
