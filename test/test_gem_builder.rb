# frozen_string_literal: true

require "helper"
require "fileutils"
require "tmpdir"

describe ::YARD::AgentDocs::GemBuilder do
  # Installs a gem into a fake gem home laid out the way rubygems lays out a
  # real one: the specification under `specifications/`, the sources under
  # `gems/<full name>/`. That layout is what makes `Gem::Specification#load`
  # report a `full_gem_path` inside the fake home, which is the whole reason
  # the builder can be pointed at one.
  #
  # @param home [String] the fake gem home
  # @param name [String] the gem name
  # @param version [String] the gem version
  # @param yardopts [String, nil] contents for the gem's `.yardopts`, if any
  # @param sources [Boolean] whether to install any sources at all; false
  #   stands in for a gem whose specification is present but whose files are
  #   not (as happens with some default gems)
  # @return [String] the gem's installed directory
  def install_gem(home, name, version, yardopts: nil, sources: true)
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
    ::File.write(::File.join(gem_dir, ".yardopts"), yardopts) if yardopts
    gem_dir
  end

  # Runs +block+ with a fake gem home and an output root, both disposable, and
  # with YARD's logger quieted so a test run isn't buried in parse progress,
  # stats, and the builder's own per-gem announcements.
  def with_gem_home
    ::Dir.mktmpdir do |dir|
      home = ::File.join(dir, "gemhome")
      output_root = ::File.join(dir, "bundles")
      ::FileUtils.mkdir_p(home)
      log.enter_level(::YARD::Logger::FATAL) do
        yield home, output_root
      end
    end
  end

  def gem_builder(home, output_root, **)
    ::YARD::AgentDocs::GemBuilder.new(
      spec_dirs: [::File.join(home, "specifications")], output_root: output_root, **
    )
  end

  def resolved_names(home, output_root, **)
    gem_builder(home, output_root, **).resolve&.map(&:full_name)
  end

  # The directory the builder stages a build in before publishing it.
  def temp_root(output_root)
    ::File.join(output_root, ::YARD::AgentDocs::GemBuilder::TEMP_SUBDIR)
  end

  # Stands in for a build killed partway through: the builder writes part of
  # a tree into the directory it was handed, then dies without unwinding.
  def interrupt_during_build(builder)
    builder.define_singleton_method(:build_with_builder) do |_spec, output|
      ::FileUtils.mkdir_p(::File.join(output, "Widget"))
      ::File.write(::File.join(output, "index.md"), "# partial\n")
      ::File.write(::File.join(output, "Widget", "spin.md"), "# spin\n")
      raise ::Interrupt
    end
    builder
  end

  describe "resolution" do
    it "resolves an exact name:version request" do
      with_gem_home do |home, output_root|
        install_gem(home, "widget", "1.0.0")
        install_gem(home, "widget", "2.0.0")
        assert_equal(["widget-1.0.0"], resolved_names(home, output_root, requests: ["widget:1.0.0"]))
      end
    end

    it "resolves a bare name to the newest installed version" do
      with_gem_home do |home, output_root|
        install_gem(home, "widget", "1.0.0")
        install_gem(home, "widget", "2.10.0")
        install_gem(home, "widget", "2.9.0")
        assert_equal(["widget-2.10.0"], resolved_names(home, output_root, requests: ["widget"]))
      end
    end

    it "resolves name:all to every installed version" do
      with_gem_home do |home, output_root|
        install_gem(home, "widget", "1.0.0")
        install_gem(home, "widget", "2.0.0")
        assert_equal(["widget-1.0.0", "widget-2.0.0"],
                     resolved_names(home, output_root, requests: ["widget:all"]))
      end
    end

    # `1.2` and `1.2.0` are the same version to rubygems, so a request written
    # either way should find the gem either way.
    it "compares a requested version as a version rather than a string" do
      with_gem_home do |home, output_root|
        install_gem(home, "widget", "1.2.0")
        assert_equal(["widget-1.2.0"], resolved_names(home, output_root, requests: ["widget:1.2"]))
      end
    end

    it "sorts the resolved gems by name and version" do
      with_gem_home do |home, output_root|
        install_gem(home, "widget", "2.0.0")
        install_gem(home, "widget", "10.0.0")
        install_gem(home, "gadget", "1.0.0")
        assert_equal(["gadget-1.0.0", "widget-2.0.0", "widget-10.0.0"],
                     resolved_names(home, output_root, all: true))
      end
    end

    it "refuses the whole run when a requested gem is not installed" do
      with_gem_home do |home, output_root|
        install_gem(home, "widget", "1.0.0")
        assert_nil(resolved_names(home, output_root, requests: ["widget", "gadget"]))
      end
    end

    it "refuses the whole run when a requested version is not installed" do
      with_gem_home do |home, output_root|
        install_gem(home, "widget", "1.0.0")
        assert_nil(resolved_names(home, output_root, requests: ["widget:9.9.9"]))
      end
    end

    it "refuses a version that isn't a version number" do
      with_gem_home do |home, output_root|
        install_gem(home, "widget", "1.0.0")
        assert_nil(resolved_names(home, output_root, requests: ["widget:latest"]))
      end
    end

    it "refuses a malformed request" do
      with_gem_home do |home, output_root|
        install_gem(home, "widget", "1.0.0")
        assert_nil(resolved_names(home, output_root, requests: ["widget:"]))
        assert_nil(resolved_names(home, output_root, requests: [":1.0.0"]))
      end
    end

    it "refuses a run that requests no gems at all" do
      with_gem_home do |home, output_root|
        install_gem(home, "widget", "1.0.0")
        assert_nil(resolved_names(home, output_root))
      end
    end

    it "selects every version of every gem for all" do
      with_gem_home do |home, output_root|
        install_gem(home, "widget", "1.0.0")
        install_gem(home, "widget", "2.0.0")
        install_gem(home, "gadget", "1.0.0")
        assert_equal(["gadget-1.0.0", "widget-1.0.0", "widget-2.0.0"],
                     resolved_names(home, output_root, all: true))
      end
    end

    it "selects the newest version of each gem for all_latest" do
      with_gem_home do |home, output_root|
        install_gem(home, "widget", "1.0.0")
        install_gem(home, "widget", "2.0.0")
        install_gem(home, "gadget", "1.0.0")
        assert_equal(["gadget-1.0.0", "widget-2.0.0"],
                     resolved_names(home, output_root, all_latest: true))
      end
    end

    it "lets all win over all_latest when both are given" do
      with_gem_home do |home, output_root|
        install_gem(home, "widget", "1.0.0")
        install_gem(home, "widget", "2.0.0")
        assert_equal(["widget-1.0.0", "widget-2.0.0"],
                     resolved_names(home, output_root, all: true, all_latest: true))
      end
    end

    it "unions explicit requests with a bulk selection" do
      with_gem_home do |home, output_root|
        install_gem(home, "widget", "1.0.0")
        install_gem(home, "widget", "2.0.0")
        assert_equal(["widget-1.0.0", "widget-2.0.0"],
                     resolved_names(home, output_root, requests: ["widget:1.0.0"], all_latest: true))
      end
    end

    it "does not build a gem twice when it is both requested and selected in bulk" do
      with_gem_home do |home, output_root|
        install_gem(home, "widget", "1.0.0")
        assert_equal(["widget-1.0.0"],
                     resolved_names(home, output_root, requests: ["widget"], all: true))
      end
    end
  end

  # Default-gem filtering keys off the real default specifications directory,
  # which a fake gem home can't imitate, so these run against whatever this
  # Ruby actually has installed.
  describe "default gems" do
    it "excludes default gems from a bulk selection by default" do
      ::Dir.mktmpdir do |dir|
        specs = ::YARD::AgentDocs::GemBuilder.new(all: true, output_root: dir).resolve
        refute_empty(specs)
        assert_empty(specs.select(&:default_gem?))
      end
    end

    it "includes default gems in a bulk selection when asked" do
      ::Dir.mktmpdir do |dir|
        specs = ::YARD::AgentDocs::GemBuilder.new(all: true, include_default: true,
                                                  output_root: dir).resolve
        refute_empty(specs.select(&:default_gem?))
      end
    end

    def specs_in(dir)
      ::Dir.glob(::File.join(dir, "*.gemspec")).filter_map { |file| ::Gem::Specification.load(file) }
    end

    # Some default gems (`bundler`, typically) are *also* installed as ordinary
    # gems, so an example of "a default gem" needs a name that is only ever
    # one.
    def purely_default_gem_spec
      regular = specs_in(::File.join(::Gem.dir, "specifications")).map(&:name)
      specs_in(::Gem.default_specifications_dir)
        .reject { |spec| regular.include?(spec.name) }
        .min_by(&:full_name)
    end

    # A name installed both as a default gem and as an ordinary one, whose
    # default version is the newest of the two. Nil if this Ruby has none.
    def default_newest_mixed_gem_name
      by_name = (specs_in(::File.join(::Gem.dir, "specifications")) +
                 specs_in(::Gem.default_specifications_dir)).group_by(&:name)
      by_name.filter_map do |name, group|
        name if group.any?(&:default_gem?) && !group.all?(&:default_gem?) &&
                group.max_by(&:version).default_gem?
      end.min
    end

    it "excludes a default gem from all_latest by default" do
      ::Dir.mktmpdir do |dir|
        specs = ::YARD::AgentDocs::GemBuilder.new(all_latest: true, output_root: dir).resolve
        refute_includes(specs.map(&:name), purely_default_gem_spec.name)
      end
    end

    it "includes a default gem in all_latest when asked" do
      ::Dir.mktmpdir do |dir|
        specs = ::YARD::AgentDocs::GemBuilder.new(all_latest: true, include_default: true,
                                                  output_root: dir).resolve
        assert_includes(specs.map(&:name), purely_default_gem_spec.name)
      end
    end

    # Naming a gem is itself the statement of intent, so `--include-default`
    # governs the bulk selections above and nothing else.
    it "resolves an explicitly named default gem without the flag" do
      ::Dir.mktmpdir do |dir|
        name = purely_default_gem_spec.name
        specs = ::YARD::AgentDocs::GemBuilder.new(requests: [name], output_root: dir).resolve
        assert_equal([name], specs.map(&:name))
      end
    end

    it "resolves an explicitly requested version that is only installed as a default gem" do
      ::Dir.mktmpdir do |dir|
        spec = purely_default_gem_spec
        specs = ::YARD::AgentDocs::GemBuilder.new(
          requests: ["#{spec.name}:#{spec.version}"], output_root: dir
        ).resolve
        assert_equal([spec.full_name], specs.map(&:full_name))
      end
    end

    it "counts a default version among a name:all request without the flag" do
      name = default_newest_mixed_gem_name
      skip("no gem is installed both as a default and as an ordinary gem") unless name
      ::Dir.mktmpdir do |dir|
        specs = ::YARD::AgentDocs::GemBuilder.new(requests: ["#{name}:all"],
                                                  output_root: dir).resolve
        refute_empty(specs.select(&:default_gem?))
      end
    end
  end

  describe "output location" do
    it "keys the output directory by the gem's full name" do
      with_gem_home do |home, output_root|
        install_gem(home, "widget", "1.0.0")
        builder = gem_builder(home, output_root, requests: ["widget"])
        assert_equal(::File.join(output_root, "widget-1.0.0"),
                     builder.output_dir_for(builder.resolve.first))
      end
    end

    it "defaults the output root to the XDG data home" do
      ::Dir.mktmpdir do |dir|
        original = ::ENV.fetch("XDG_DATA_HOME", nil)
        begin
          ::ENV["XDG_DATA_HOME"] = dir
          builder = ::YARD::AgentDocs::GemBuilder.new(requests: ["widget"])
          assert_equal(::File.join(dir, "yard-agentdocs", "gems"), builder.output_root)
        ensure
          ::ENV["XDG_DATA_HOME"] = original
        end
      end
    end
  end

  describe "building" do
    it "builds a bundle for each requested gem" do
      with_gem_home do |home, output_root|
        install_gem(home, "widget", "1.0.0")
        install_gem(home, "gadget", "2.0.0")
        assert(gem_builder(home, output_root, requests: ["widget", "gadget"]).build)
        assert_path_exists(::File.join(output_root, "widget-1.0.0", "index.md"))
        assert_path_exists(::File.join(output_root, "gadget-2.0.0", "index.md"))
        assert_includes(::File.read(::File.join(output_root, "widget-1.0.0", "Widget.md")),
                        "# class Widget")
      end
    end

    # The installed gem directory is shared state that may not even be
    # writable, so the build has to leave no trace in it — in particular not
    # YARD's `.yardoc` database, which it would write there by default.
    it "writes nothing into the installed gem directory" do
      with_gem_home do |home, output_root|
        gem_dir = install_gem(home, "widget", "1.0.0")
        before = ::Dir.children(gem_dir).sort
        assert(gem_builder(home, output_root, requests: ["widget"]).build)
        assert_equal(before, ::Dir.children(gem_dir).sort)
        refute(::File.exist?(::File.join(gem_dir, ".yardoc")))
      end
    end

    it "honors the gem's own .yardopts" do
      with_gem_home do |home, output_root|
        install_gem(home, "widget", "1.0.0", yardopts: "--title \"Widget Works\"\n")
        assert(gem_builder(home, output_root, requests: ["widget"]).build)
        assert_includes(::File.read(::File.join(output_root, "widget-1.0.0", "index.md")),
                        "# Widget Works")
      end
    end

    it "passes extra arguments through to YARD" do
      with_gem_home do |home, output_root|
        install_gem(home, "widget", "1.0.0")
        builder = gem_builder(home, output_root, requests: ["widget"],
                                                 yard_args: ["--title", "Widget Works"])
        assert(builder.build)
        assert_includes(::File.read(::File.join(output_root, "widget-1.0.0", "index.md")),
                        "# Widget Works")
      end
    end

    it "reports a gem whose sources are not installed, without failing" do
      with_gem_home do |home, output_root|
        install_gem(home, "widget", "1.0.0", sources: false)
        install_gem(home, "gadget", "2.0.0")
        assert(gem_builder(home, output_root, requests: ["widget", "gadget"]).build)
        refute(::File.exist?(::File.join(output_root, "widget-1.0.0")))
        assert_path_exists(::File.join(output_root, "gadget-2.0.0", "index.md"))
      end
    end
  end

  describe "rebuilding" do
    # Stands in for a bundle left by an earlier run: the builder should either
    # replace the directory wholesale or leave the sentinel alone, never merge
    # into it.
    def write_stale_bundle(output_root, full_name)
      stale = ::File.join(output_root, full_name, "Gone.md")
      ::FileUtils.mkdir_p(::File.dirname(stale))
      ::File.write(stale, "# Gone\n")
      stale
    end

    it "rebuilds over an existing bundle by default" do
      with_gem_home do |home, output_root|
        install_gem(home, "widget", "1.0.0")
        stale = write_stale_bundle(output_root, "widget-1.0.0")
        assert(gem_builder(home, output_root, requests: ["widget"]).build)
        refute(::File.exist?(stale))
        assert_path_exists(::File.join(output_root, "widget-1.0.0", "Widget.md"))
      end
    end

    it "leaves an existing nonempty bundle alone when not rebuilding" do
      with_gem_home do |home, output_root|
        install_gem(home, "widget", "1.0.0")
        stale = write_stale_bundle(output_root, "widget-1.0.0")
        assert(gem_builder(home, output_root, requests: ["widget"], rebuild: false).build)
        assert_path_exists(stale)
        refute(::File.exist?(::File.join(output_root, "widget-1.0.0", "Widget.md")))
      end
    end

    it "builds into an existing empty bundle directory when not rebuilding" do
      with_gem_home do |home, output_root|
        install_gem(home, "widget", "1.0.0")
        ::FileUtils.mkdir_p(::File.join(output_root, "widget-1.0.0"))
        assert(gem_builder(home, output_root, requests: ["widget"], rebuild: false).build)
        assert_path_exists(::File.join(output_root, "widget-1.0.0", "Widget.md"))
      end
    end

    it "builds only the missing gems when not rebuilding" do
      with_gem_home do |home, output_root|
        install_gem(home, "widget", "1.0.0")
        install_gem(home, "gadget", "2.0.0")
        stale = write_stale_bundle(output_root, "widget-1.0.0")
        assert(gem_builder(home, output_root, all: true, rebuild: false).build)
        assert_path_exists(stale)
        assert_path_exists(::File.join(output_root, "gadget-2.0.0", "index.md"))
      end
    end
  end

  describe "failure" do
    # An unavailable markup provider makes YARD reject its arguments, the same
    # lever `Builder`'s own tests use to force a failed build.
    #
    # The markup name has to be one no test has used before, though: YARD
    # caches markup lookups process-wide and caches the *failures* too (see
    # `MarkupHelper#load_markup_provider`), so a second run naming the same
    # bogus markup sails right through. A counter keeps each failing gem's
    # name unique regardless of what order the examples run in.
    def install_failing_gem(home, name, version)
      @failure_counter = (@failure_counter || 0) + 1
      markup = "no_such_markup_#{object_id}_#{@failure_counter}"
      install_gem(home, name, version, yardopts: "--markup #{markup}\n")
    end

    it "leaves no bundle at the canonical path when a gem's build fails" do
      with_gem_home do |home, output_root|
        install_failing_gem(home, "widget", "1.0.0")
        refute(gem_builder(home, output_root, requests: ["widget"]).build)
        refute(::File.exist?(::File.join(output_root, "widget-1.0.0")))
      end
    end

    it "builds the remaining gems after one fails" do
      with_gem_home do |home, output_root|
        install_failing_gem(home, "widget", "1.0.0")
        install_gem(home, "gadget", "2.0.0")
        refute(gem_builder(home, output_root, all: true).build)
        assert_path_exists(::File.join(output_root, "gadget-2.0.0", "index.md"))
      end
    end

    it "does not preserve a failed bundle for a later no-rebuild run" do
      with_gem_home do |home, output_root|
        install_failing_gem(home, "widget", "1.0.0")
        refute(gem_builder(home, output_root, requests: ["widget"]).build)
        install_gem(home, "widget", "1.0.0")
        assert(gem_builder(home, output_root, requests: ["widget"], rebuild: false).build)
        assert_path_exists(::File.join(output_root, "widget-1.0.0", "Widget.md"))
      end
    end

    # Building in place meant a failed rebuild took the previous bundle with
    # it: the output directory was cleaned before YARD ran, and removed again
    # when the run came back false.
    it "leaves the existing bundle in place when a rebuild fails" do
      with_gem_home do |home, output_root|
        install_gem(home, "widget", "1.0.0")
        assert(gem_builder(home, output_root, requests: ["widget"]).build)
        install_failing_gem(home, "widget", "1.0.0")
        refute(gem_builder(home, output_root, requests: ["widget"]).build)
        assert_path_exists(::File.join(output_root, "widget-1.0.0", "Widget.md"))
      end
    end

    it "fails without building anything when resolution fails" do
      with_gem_home do |home, output_root|
        install_gem(home, "widget", "1.0.0")
        refute(gem_builder(home, output_root, requests: ["widget", "gadget"]).build)
        refute(::File.exist?(output_root))
      end
    end
  end

  describe "atomicity" do
    # A build staged in place would leave these files at the canonical path,
    # where the next `rebuild: false` run counts any nonempty directory as a
    # finished bundle. That is the whole of the bug this covers.
    it "leaves nothing at the canonical path when a build is interrupted" do
      with_gem_home do |home, output_root|
        install_gem(home, "widget", "1.0.0")
        builder = interrupt_during_build(gem_builder(home, output_root, requests: ["widget"]))
        assert_raises(::Interrupt) { builder.build }
        refute(::File.exist?(::File.join(output_root, "widget-1.0.0")))
      end
    end

    it "discards the staged tree of an interrupted build" do
      with_gem_home do |home, output_root|
        install_gem(home, "widget", "1.0.0")
        builder = interrupt_during_build(gem_builder(home, output_root, requests: ["widget"]))
        assert_raises(::Interrupt) { builder.build }
        assert_empty(::Dir.children(temp_root(output_root)))
      end
    end

    it "does not let an interrupted build satisfy a later no-rebuild run" do
      with_gem_home do |home, output_root|
        install_gem(home, "widget", "1.0.0")
        builder = interrupt_during_build(gem_builder(home, output_root, requests: ["widget"]))
        assert_raises(::Interrupt) { builder.build }
        assert(gem_builder(home, output_root, requests: ["widget"], rebuild: false).build)
        assert_path_exists(::File.join(output_root, "widget-1.0.0", "Widget.md"))
      end
    end

    it "keeps the existing bundle whole while a rebuild runs" do
      with_gem_home do |home, output_root|
        install_gem(home, "widget", "1.0.0")
        assert(gem_builder(home, output_root, requests: ["widget"]).build)
        builder = interrupt_during_build(gem_builder(home, output_root, requests: ["widget"]))
        assert_raises(::Interrupt) { builder.build }
        assert_path_exists(::File.join(output_root, "widget-1.0.0", "Widget.md"))
        refute(::File.exist?(::File.join(output_root, "widget-1.0.0", "Widget", "spin.md")))
      end
    end
  end

  describe "abandoned staging directories" do
    # Stands in for what a killed build leaves behind: a partial tree under
    # the staging directory, aged past the sweep threshold or not.
    def stage_dir(output_root, name, age: nil)
      dir = ::File.join(temp_root(output_root), name)
      ::FileUtils.mkdir_p(dir)
      ::File.write(::File.join(dir, "index.md"), "# partial\n")
      ::File.utime(::Time.now - age, ::Time.now - age, dir) if age
      dir
    end

    def stale_age
      ::YARD::AgentDocs::GemBuilder::STALE_TEMP_AGE + 60
    end

    it "removes one left by a build killed long enough ago" do
      with_gem_home do |home, output_root|
        install_gem(home, "widget", "1.0.0")
        stale = stage_dir(output_root, "999999-widget-1.0.0", age: stale_age)
        assert(gem_builder(home, output_root, requests: ["widget"]).build)
        refute(::File.exist?(stale))
      end
    end

    # A build running right now in another process has a staging directory of
    # its own. Sweeping that would kill a live build rather than tidy up
    # after a dead one, so age is the only thing that makes one eligible.
    it "leaves a recent one alone" do
      with_gem_home do |home, output_root|
        install_gem(home, "widget", "1.0.0")
        fresh = stage_dir(output_root, "999998-gadget-2.0.0")
        assert(gem_builder(home, output_root, requests: ["widget"]).build)
        assert_path_exists(fresh)
      end
    end

    it "sweeps before building rather than after" do
      with_gem_home do |home, output_root|
        install_gem(home, "widget", "1.0.0")
        builder = interrupt_during_build(gem_builder(home, output_root, requests: ["widget"]))
        stale = stage_dir(output_root, "999999-widget-1.0.0", age: stale_age)
        assert_raises(::Interrupt) { builder.build }
        refute(::File.exist?(stale))
      end
    end
  end
end
