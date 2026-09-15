# frozen_string_literal: true

require "helper"
require "fileutils"
require "tmpdir"

describe ::YARD::AgentDocs::GemCleaner do
  # A bundle stands in for one built by `GemBuilder`. Only its name and the
  # fact that it's a nonempty directory matter to the cleaner, so there's no
  # need to run YARD to make one.
  #
  # @param output_root [String] the directory bundles live in
  # @param basename [String] the bundle directory name
  # @return [String] the bundle's path
  def make_bundle(output_root, basename)
    dir = ::File.join(output_root, basename)
    ::FileUtils.mkdir_p(dir)
    ::File.write(::File.join(dir, "index.md"), "# #{basename}\n")
    dir
  end

  # Runs +block+ with a disposable output root, with YARD's logger quieted so
  # a test run isn't buried in the cleaner's announcements.
  def with_output_root
    ::Dir.mktmpdir do |dir|
      output_root = ::File.join(dir, "bundles")
      ::FileUtils.mkdir_p(output_root)
      log.enter_level(::YARD::Logger::FATAL) { yield output_root }
    end
  end

  def cleaner(output_root, **)
    ::YARD::AgentDocs::GemCleaner.new(output_root: output_root, **)
  end

  def resolved_names(output_root, **)
    cleaner(output_root, **).resolve&.map { |dir| ::File.basename(dir) }
  end

  def present_names(output_root)
    ::Dir.children(output_root).sort
  end

  describe ".parse_bundle_name" do
    def parse(basename)
      ::YARD::AgentDocs::GemCleaner.parse_bundle_name(basename)
    end

    it "splits a simple bundle name" do
      assert_equal(["toys", ::Gem::Version.new("0.22.0"), nil], parse("toys-0.22.0"))
    end

    it "keeps hyphens that belong to the gem name" do
      assert_equal(["google-cloud-env", ::Gem::Version.new("2.3.0"), nil],
                   parse("google-cloud-env-2.3.0"))
    end

    it "separates a platform suffix from the version" do
      assert_equal(["nokogiri", ::Gem::Version.new("1.19.4"), "arm64-darwin"],
                   parse("nokogiri-1.19.4-arm64-darwin"))
    end

    it "handles a prerelease version" do
      assert_equal(["widget", ::Gem::Version.new("1.0.0.pre.1"), nil], parse("widget-1.0.0.pre.1"))
    end

    it "handles a gem name that contains digits" do
      assert_equal(["net-http2", ::Gem::Version.new("0.18.3"), nil], parse("net-http2-0.18.3"))
    end

    it "rejects a name with no version in it" do
      assert_nil(parse("widget"))
      assert_nil(parse("no-version-here"))
      assert_nil(parse(".yardoc"))
    end

    # The rule has to invert `Gem::Specification#full_name` for real gems, not
    # just tidy examples, so check it against every gem on this machine —
    # hyphenated names, platform suffixes, prereleases and all.
    it "round-trips every installed gem's full name" do
      specs = [::File.join(::Gem.dir, "specifications"), ::Gem.default_specifications_dir]
              .flat_map { |dir| ::Dir.glob(::File.join(dir, "*.gemspec")) }
              .filter_map { |file| ::Gem::Specification.load(file) }
      refute_empty(specs)
      specs.each do |spec|
        expected_platform = spec.platform.to_s == "ruby" ? nil : spec.platform.to_s
        assert_equal([spec.name, spec.version, expected_platform], parse(spec.full_name),
                     "failed to parse #{spec.full_name}")
      end
    end
  end

  describe "resolution" do
    it "resolves an exact name:version request" do
      with_output_root do |root|
        make_bundle(root, "widget-1.0.0")
        make_bundle(root, "widget-2.0.0")
        assert_equal(["widget-1.0.0"], resolved_names(root, requests: ["widget:1.0.0"]))
      end
    end

    it "resolves a bare name to every version built for that gem" do
      with_output_root do |root|
        make_bundle(root, "widget-1.0.0")
        make_bundle(root, "widget-2.0.0")
        make_bundle(root, "gadget-1.0.0")
        assert_equal(["widget-1.0.0", "widget-2.0.0"], resolved_names(root, requests: ["widget"]))
      end
    end

    it "treats name:all the same as a bare name" do
      with_output_root do |root|
        make_bundle(root, "widget-1.0.0")
        make_bundle(root, "widget-2.0.0")
        assert_equal(["widget-1.0.0", "widget-2.0.0"], resolved_names(root, requests: ["widget:all"]))
      end
    end

    it "resolves every platform build of a requested version" do
      with_output_root do |root|
        make_bundle(root, "widget-1.0.0")
        make_bundle(root, "widget-1.0.0-arm64-darwin")
        assert_equal(["widget-1.0.0", "widget-1.0.0-arm64-darwin"],
                     resolved_names(root, requests: ["widget:1.0.0"]))
      end
    end

    it "compares a requested version as a version rather than a string" do
      with_output_root do |root|
        make_bundle(root, "widget-1.2.0")
        assert_equal(["widget-1.2.0"], resolved_names(root, requests: ["widget:1.2"]))
      end
    end

    it "sorts the resolved bundles by name and version" do
      with_output_root do |root|
        make_bundle(root, "widget-10.0.0")
        make_bundle(root, "widget-2.0.0")
        make_bundle(root, "gadget-1.0.0")
        assert_equal(["gadget-1.0.0", "widget-2.0.0", "widget-10.0.0"],
                     resolved_names(root, all: true))
      end
    end

    it "refuses the whole run when a requested gem has no bundles" do
      with_output_root do |root|
        make_bundle(root, "widget-1.0.0")
        assert_nil(resolved_names(root, requests: ["widget", "gadget"]))
      end
    end

    it "refuses the whole run when a requested version has no bundle" do
      with_output_root do |root|
        make_bundle(root, "widget-1.0.0")
        assert_nil(resolved_names(root, requests: ["widget:9.9.9"]))
      end
    end

    it "refuses a version that isn't a version number" do
      with_output_root do |root|
        make_bundle(root, "widget-1.0.0")
        assert_nil(resolved_names(root, requests: ["widget:newest"]))
      end
    end

    it "refuses a malformed request" do
      with_output_root do |root|
        make_bundle(root, "widget-1.0.0")
        assert_nil(resolved_names(root, requests: ["widget:"]))
        assert_nil(resolved_names(root, requests: [":1.0.0"]))
      end
    end

    it "refuses a run that requests no gems at all" do
      with_output_root do |root|
        make_bundle(root, "widget-1.0.0")
        assert_nil(resolved_names(root))
      end
    end

    it "selects every bundle for all" do
      with_output_root do |root|
        make_bundle(root, "widget-1.0.0")
        make_bundle(root, "widget-2.0.0")
        make_bundle(root, "gadget-1.0.0")
        assert_equal(["gadget-1.0.0", "widget-1.0.0", "widget-2.0.0"], resolved_names(root, all: true))
      end
    end

    it "selects all but the newest version of each gem for all_outdated" do
      with_output_root do |root|
        make_bundle(root, "widget-1.0.0")
        make_bundle(root, "widget-2.0.0")
        make_bundle(root, "widget-10.0.0")
        make_bundle(root, "gadget-1.0.0")
        assert_equal(["widget-1.0.0", "widget-2.0.0"], resolved_names(root, all_outdated: true))
      end
    end

    it "keeps every platform build of the newest version for all_outdated" do
      with_output_root do |root|
        make_bundle(root, "widget-1.0.0")
        make_bundle(root, "widget-2.0.0")
        make_bundle(root, "widget-2.0.0-arm64-darwin")
        assert_equal(["widget-1.0.0"], resolved_names(root, all_outdated: true))
      end
    end

    it "selects nothing for all_outdated when only one version is built" do
      with_output_root do |root|
        make_bundle(root, "widget-1.0.0")
        assert_empty(resolved_names(root, all_outdated: true))
      end
    end

    it "lets all win over all_outdated when both are given" do
      with_output_root do |root|
        make_bundle(root, "widget-1.0.0")
        make_bundle(root, "widget-2.0.0")
        assert_equal(["widget-1.0.0", "widget-2.0.0"],
                     resolved_names(root, all: true, all_outdated: true))
      end
    end

    it "unions explicit requests with a bulk selection" do
      with_output_root do |root|
        make_bundle(root, "widget-1.0.0")
        make_bundle(root, "widget-2.0.0")
        make_bundle(root, "gadget-1.0.0")
        assert_equal(["gadget-1.0.0", "widget-1.0.0"],
                     resolved_names(root, requests: ["gadget"], all_outdated: true))
      end
    end

    it "resolves a bundle twice into one removal" do
      with_output_root do |root|
        make_bundle(root, "widget-1.0.0")
        assert_equal(["widget-1.0.0"], resolved_names(root, requests: ["widget"], all: true))
      end
    end

    it "selects nothing when the output root does not exist" do
      ::Dir.mktmpdir do |dir|
        log.enter_level(::YARD::Logger::FATAL) do
          root = ::File.join(dir, "never-built")
          assert_empty(resolved_names(root, all: true))
          assert_nil(resolved_names(root, requests: ["widget"]))
        end
      end
    end
  end

  # A stray file or directory in the output root is not this tool's to delete,
  # and it must not be mistaken for a gem either.
  describe "foreign entries" do
    it "ignores entries that are not bundle names" do
      with_output_root do |root|
        make_bundle(root, "widget-1.0.0")
        make_bundle(root, "scratch")
        ::File.write(::File.join(root, "notes.txt"), "hello\n")
        assert_equal(["widget-1.0.0"], resolved_names(root, all: true))
      end
    end

    it "leaves them in place when cleaning everything" do
      with_output_root do |root|
        make_bundle(root, "widget-1.0.0")
        make_bundle(root, "scratch")
        ::File.write(::File.join(root, "notes.txt"), "hello\n")
        assert(cleaner(root, all: true).clean)
        assert_equal(["notes.txt", "scratch"], present_names(root))
      end
    end

    # The builder stages every build in this directory, so it shows up in the
    # output root whenever a build was killed before it could clean up after
    # itself. Its name is deliberately one `parse_bundle_name` reads as no
    # bundle at all.
    it "ignores the builder's staging directory" do
      with_output_root do |root|
        make_bundle(root, "widget-1.0.0")
        make_bundle(root, ::YARD::AgentDocs::GemBuilder::TEMP_SUBDIR)
        assert_equal(["widget-1.0.0"], resolved_names(root, all: true))
        assert(cleaner(root, all: true).clean)
        assert_equal([::YARD::AgentDocs::GemBuilder::TEMP_SUBDIR], present_names(root))
      end
    end

    it "refuses a request naming an entry that is not a bundle" do
      with_output_root do |root|
        make_bundle(root, "scratch")
        assert_nil(resolved_names(root, requests: ["scratch"]))
      end
    end
  end

  describe "cleaning" do
    it "removes exactly the resolved bundles" do
      with_output_root do |root|
        make_bundle(root, "widget-1.0.0")
        make_bundle(root, "widget-2.0.0")
        make_bundle(root, "gadget-1.0.0")
        assert(cleaner(root, requests: ["widget:1.0.0", "gadget"]).clean)
        assert_equal(["widget-2.0.0"], present_names(root))
      end
    end

    it "removes a bundle's contents along with it" do
      with_output_root do |root|
        dir = make_bundle(root, "widget-1.0.0")
        ::FileUtils.mkdir_p(::File.join(dir, "Widget"))
        ::File.write(::File.join(dir, "Widget", "spin.md"), "# spin\n")
        assert(cleaner(root, requests: ["widget"]).clean)
        refute(::File.exist?(dir))
      end
    end

    it "leaves the output root itself in place" do
      with_output_root do |root|
        make_bundle(root, "widget-1.0.0")
        assert(cleaner(root, all: true).clean)
        assert_path_exists(root)
        assert_empty(present_names(root))
      end
    end

    it "succeeds without removing anything when nothing is outdated" do
      with_output_root do |root|
        make_bundle(root, "widget-1.0.0")
        assert(cleaner(root, all_outdated: true).clean)
        assert_equal(["widget-1.0.0"], present_names(root))
      end
    end

    it "removes nothing when resolution fails" do
      with_output_root do |root|
        make_bundle(root, "widget-1.0.0")
        refute(cleaner(root, requests: ["widget", "gadget"]).clean)
        assert_equal(["widget-1.0.0"], present_names(root))
      end
    end
  end

  describe "output location" do
    it "defaults the output root to the one gems are built into" do
      ::Dir.mktmpdir do |dir|
        original = ::ENV.fetch("XDG_DATA_HOME", nil)
        begin
          ::ENV["XDG_DATA_HOME"] = dir
          assert_equal(::YARD::AgentDocs::GemBuilder.new(requests: ["widget"]).output_root,
                       ::YARD::AgentDocs::GemCleaner.new(requests: ["widget"]).output_root)
        ensure
          ::ENV["XDG_DATA_HOME"] = original
        end
      end
    end
  end
end
