# frozen_string_literal: true

require "rbconfig"
require "yaml"

module YARD
  module AgentDocs
    ##
    # Works out which release of a gem a project actually depends on, and
    # where that release is installed. This is the resolving half of the
    # `agentdocs lookup` Toys tool (see {Lookup}), and lives here for the
    # same reason its siblings do: so the behavior is testable and documented
    # apart from the Toys DSL layer.
    #
    # Version resolution is the most mechanical and most error-prone step of
    # a documentation lookup, and the one a prose instruction can only ask an
    # agent to perform correctly. Reading a different version's bundle
    # because it happened to exist is a plausible, silently wrong answer, so
    # this is the part that most needs to be code.
    #
    # ### Reading the lockfile
    #
    # The lockfile is parsed as a text file. Bundler's runtime is never
    # loaded: this tool is documented to run *outside* `bundle exec` — the
    # gems it looks up are whatever is installed on the machine, not whatever
    # one bundle activated — and loading Bundler to answer a question about
    # the bundle it is not in is how that distinction gets lost.
    #
    # A sectional parse is required rather than a grep for the four-space
    # indent that marks a resolved spec, because `GIT` and `PATH` sections
    # carry `specs:` blocks at exactly that indent. Telling them apart is the
    # whole point: a git or path dependency has no release to document and no
    # bundle path to compute, and must be reported as such rather than
    # resolved to some unrelated installed copy of the same name.
    #
    # ### Finding the installation
    #
    # {#spec_dirs} looks in the project's own bundle path first, then in the
    # current Ruby's global gem directory and its default gems. A project
    # configured with `bundle config path vendor/bundle` has the gem
    # installed — just not where {GemBuilder.default_spec_dirs} looks — and
    # that is the one case where a lookup would otherwise fail for a gem that
    # is sitting right there. Nothing here ever *installs* a gem: permanently
    # installing arbitrary third-party code on an agent's behalf is out of
    # proportion to answering a documentation question.
    #
    class DependencyResolver
      ##
      # The characters a gem name may contain. Anything else is a typo or an
      # injection attempt, and either way is not a gem.
      #
      GEM_NAME = /\A[A-Za-z0-9_.-]+\z/

      ##
      # The lockfile names looked for when walking up from the project
      # directory, in the order Bundler prefers them.
      #
      LOCKFILE_NAMES = ["Gemfile.lock", "gems.locked"].freeze

      ##
      # The environment variable naming a Gemfile explicitly. Its lockfile is
      # that path plus `.lock`, which is how Bundler derives it.
      #
      GEMFILE_ENV = "BUNDLE_GEMFILE"

      ##
      # The environment variable, and the `.bundle/config` key, relocating
      # where a project's gems are installed.
      #
      BUNDLE_PATH_KEY = "BUNDLE_PATH"

      ##
      # The environment variable, and the `.bundle/config` key, saying that a
      # project installs into the system gem directory after all — which
      # overrides any {BUNDLE_PATH_KEY} left over beside it.
      #
      BUNDLE_PATH_SYSTEM_KEY = "BUNDLE_PATH__SYSTEM"

      ##
      # A project's bundler configuration file, relative to its root.
      #
      BUNDLE_CONFIG_PATH = ::File.join(".bundle", "config")

      ##
      # The lockfile sections that resolve a gem to something installable,
      # mapped to the {Resolution#kind} each produces.
      #
      SOURCE_KINDS = {"GEM" => :release, "GIT" => :git, "PATH" => :path}.freeze

      ##
      # What a lockfile says about one gem, and what is installed for it.
      # Returned by {DependencyResolver#resolve}; every failure is a
      # resolution too, carrying the detail a caller needs to explain itself,
      # because a lookup that cannot answer still has to say what to do next.
      #
      class Resolution
        ##
        # @param kind [Symbol] `:release` for a gem that resolves to an
        #   installed release, `:git` or `:path` for a dependency with no
        #   release to document, `:missing` for one that isn't installed.
        # @param name [String] the gem name
        # @param version [String, nil] the resolved version
        # @param version_origin [Symbol, nil] where the version came from:
        #   `:flag`, `:lockfile`, or `:installed`
        # @param spec [Gem::Specification, nil] the installed specification,
        #   for a `:release`
        # @param lockfile [String, nil] the lockfile consulted, if any
        # @param source [String, nil] a description of a `:git` or `:path`
        #   dependency's source
        # @param installed_versions [Array<String>] the versions of this gem
        #   that *are* installed, for a `:missing` resolution
        # @param message [String, nil] why a `:missing` resolution failed
        #
        def initialize(kind:, name:, version: nil, version_origin: nil, spec: nil,
                       lockfile: nil, source: nil, installed_versions: [], message: nil)
          @kind = kind
          @name = name
          @version = version
          @version_origin = version_origin
          @spec = spec
          @lockfile = lockfile
          @source = source
          @installed_versions = installed_versions
          @message = message
        end

        ##
        # @return [Symbol] `:release`, `:git`, `:path`, or `:missing`
        #
        attr_reader :kind

        ##
        # @return [String] the gem name
        #
        attr_reader :name

        ##
        # @return [String, nil] the resolved version
        #
        attr_reader :version

        ##
        # @return [Symbol, nil] `:flag`, `:lockfile`, or `:installed`
        #
        attr_reader :version_origin

        ##
        # @return [Gem::Specification, nil] the installed specification
        #
        attr_reader :spec

        ##
        # @return [String, nil] the lockfile consulted
        #
        attr_reader :lockfile

        ##
        # @return [String, nil] a description of a non-release source
        #
        attr_reader :source

        ##
        # @return [Array<String>] the versions of this gem that are installed
        #
        attr_reader :installed_versions

        ##
        # @return [String, nil] why this resolution failed
        #
        attr_reader :message

        ##
        # @return [Boolean] whether this resolves to an installed release
        #
        def release?
          kind == :release
        end

        ##
        # Where the resolved version came from, in words, for the provenance
        # a lookup reports alongside its answer. The invariant that a lookup
        # reads the version the project actually depends on is otherwise
        # enforced but invisible.
        #
        # @return [String]
        #
        def version_origin_description
          case version_origin
          when :flag then "from --version"
          when :lockfile then "from #{::File.basename(lockfile.to_s)}"
          else "newest installed"
          end
        end
      end

      ##
      # @param name [String] the gem to resolve
      # @param version [String, nil] a version to use instead of consulting a
      #   lockfile
      # @param project_dir [String, nil] the directory to resolve the project
      #   from, which is where the walk up to a lockfile starts and what a
      #   relative bundle path is relative to. Defaults to the current
      #   directory.
      # @param spec_dirs [Array<String>, nil] the directories to search for
      #   installed gem specifications, for tests and for embedders driving
      #   this class directly. Defaults to {#default_spec_dirs}.
      #
      def initialize(name, version: nil, project_dir: nil, spec_dirs: nil)
        @name = name.to_s
        @requested_version = version&.to_s
        @project_dir = ::File.expand_path(project_dir || ::Dir.pwd)
        @spec_dirs = spec_dirs&.map { |dir| ::File.expand_path(dir) }
      end

      ##
      # @return [String] the gem being resolved
      #
      attr_reader :name

      ##
      # @return [String, nil] the version named by the caller, if any
      #
      attr_reader :requested_version

      ##
      # @return [String] the absolute path of the project directory
      #
      attr_reader :project_dir

      ##
      # The project's root: the directory holding {#lockfile_path}, or
      # {#project_dir} when there is no lockfile. This is what a relative
      # bundle path and a `PATH` source's remote are relative to, and where
      # `.bundle/config` lives — all of which sit at the root even when a
      # lookup is run from a subdirectory.
      #
      # @return [String]
      #
      def project_root
        lockfile_path ? ::File.dirname(lockfile_path) : project_dir
      end

      ##
      # @return [Boolean] whether the gem name is one rubygems could have
      #   issued at all
      #
      def valid_name?
        name.match?(GEM_NAME)
      end

      ##
      # The lockfile this project resolves versions from: the one
      # `$BUNDLE_GEMFILE` names, if it names one, and otherwise the nearest
      # one at or above {#project_dir}.
      #
      # Walking up matches how Bundler itself finds a Gemfile, so a lookup
      # run from a subdirectory resolves the same versions `bundle exec`
      # would from the same place. Resolving only against the current
      # directory would silently fall back to the newest installed version
      # whenever an agent had moved into `lib/` or `test/` — exactly the
      # plausible wrong answer this class exists to prevent.
      #
      # @return [String, nil] the absolute path, or nil if there is none
      #
      def lockfile_path
        return @lockfile_path if defined?(@lockfile_path)
        @lockfile_path = env_lockfile || nearest_lockfile
      end

      ##
      # The directories searched for installed gem specifications: the
      # project's own bundle path, when it has one configured, followed by
      # {GemBuilder.default_spec_dirs}.
      #
      # @return [Array<String>]
      #
      def spec_dirs
        @spec_dirs ||= default_spec_dirs
      end

      ##
      # The directories {#spec_dirs} defaults to.
      #
      # @return [Array<String>]
      #
      def default_spec_dirs
        (bundle_spec_dirs + GemBuilder.default_spec_dirs).map { |dir| ::File.expand_path(dir) }.uniq
      end

      ##
      # Resolves the gem.
      #
      # An explicit {#requested_version} settles it outright, without
      # consulting the lockfile at all — including for a gem the lockfile
      # resolves from git or a path. Naming a version *is* the statement that
      # a released version is wanted, the same way naming a gem is the
      # statement of intent in {GemBuilder}.
      #
      # @return [Resolution]
      #
      def resolve
        return resolution(:missing, message: "`#{name}` is not a gem name") unless valid_name?
        return select_installed(requested_version, :flag) if requested_version
        locked = locked_entry
        kind = SOURCE_KINDS[locked&.fetch(:section)] || :release
        return non_release_resolution(kind, locked) unless kind == :release
        locked ? select_installed(locked[:version], :lockfile) : select_installed(nil, :installed)
      end

      private

      def resolution(kind, **)
        Resolution.new(kind: kind, name: name, lockfile: lockfile_path, **)
      end

      def non_release_resolution(kind, locked)
        resolution(kind, version: locked[:version], version_origin: :lockfile,
                         source: describe_source(kind, locked))
      end

      # A git source is described by remote and revision rather than by a
      # checkout path: Bundler puts that checkout somewhere this class does
      # not get to know, and inventing a plausible location would be worse
      # than naming the one command that reports the real one.
      def describe_source(kind, locked)
        return ::File.expand_path(locked[:remote].to_s, project_root) if kind == :path
        parts = ["remote #{locked[:remote]}"]
        parts << "revision #{locked[:revision]}" if locked[:revision]
        parts << "#{locked[:ref_label]} #{locked[:ref]}" if locked[:ref]
        parts.join(", ")
      end

      def select_installed(version, origin)
        specs = installed_specs
        if specs.empty?
          return resolution(:missing, message: "gem `#{name}` is not installed")
        end
        matches = version ? specs.select { |spec| spec.version.to_s == version } : newest_of(specs)
        if matches.empty?
          return resolution(:missing, version: version, version_origin: origin,
                            installed_versions: version_strings(specs),
                            message: "gem `#{name}` version #{version} is not installed")
        end
        spec = prefer_local_platform(matches)
        resolution(:release, version: spec.version.to_s, version_origin: origin, spec: spec)
      end

      def newest_of(specs)
        newest = specs.map(&:version).max
        specs.select { |spec| spec.version == newest }
      end

      def version_strings(specs)
        specs.map { |spec| spec.version.to_s }.uniq.sort_by { |version| ::Gem::Version.new(version) }
      end

      # One version can be installed for several platforms at once, and each
      # is a separate bundle, since {GemBuilder#output_dir_for} names bundles
      # by full name. The one to document is the one this machine would load.
      def prefer_local_platform(specs)
        local = ::Gem::Platform.local
        specs.find { |spec| local =~ spec.platform } ||
          specs.find { |spec| spec.platform.to_s == ::Gem::Platform::RUBY } ||
          specs.min_by(&:full_name)
      end

      # Every installed specification for this gem. Globbed by name rather
      # than by loading every specification in sight, because one lookup asks
      # about one gem; the prefix can still catch a longer name that starts
      # the same way (`yard` matching `yard-agentdocs`), so each candidate is
      # confirmed against the name it declares.
      def installed_specs
        @installed_specs ||=
          spec_dirs.flat_map { |dir| ::Dir.glob(::File.join(dir, "#{name}-*.gemspec")) }
                   .filter_map { |file| ::Gem::Specification.load(file) }
                   .select { |spec| spec.name == name }
                   .uniq(&:full_name)
      end

      def env_lockfile
        gemfile = ::ENV[GEMFILE_ENV]
        return nil if gemfile.nil? || gemfile.empty?
        path = ::File.expand_path("#{gemfile}.lock")
        ::File.file?(path) ? path : nil
      end

      def nearest_lockfile
        dir = project_dir
        loop do
          LOCKFILE_NAMES.each do |candidate|
            path = ::File.join(dir, candidate)
            return path if ::File.file?(path)
          end
          parent = ::File.dirname(dir)
          return nil if parent == dir
          dir = parent
        end
      end

      # What {#lockfile_path} says about this gem: the section it resolved
      # in, its version, and the source metadata of that section.
      def locked_entry
        @locked_entry ||= lockfile_path ? parse_lockfile[name] : nil
      end

      # The lockfile's resolved specs, by gem name. Only the sections that
      # resolve a source are tracked; `DEPENDENCIES` holds constraints rather
      # than resolutions, and `CHECKSUMS` and `PLATFORMS` hold neither.
      def parse_lockfile
        entries = {}
        section = nil
        meta = {}
        in_specs = false
        ::File.foreach(lockfile_path) do |raw|
          line = raw.chomp
          if line.match?(/\A[A-Z]/)
            section = line.strip
            meta = {}
            in_specs = false
          elsif line.match?(/\A {2}\S/)
            in_specs = line.strip == "specs:"
            record_meta(meta, line) unless in_specs
          elsif in_specs && SOURCE_KINDS.key?(section)
            record_spec(entries, section, meta, line)
          end
        end
        entries
      end

      def record_meta(meta, line)
        key, colon, value = line.strip.partition(": ")
        return if colon.empty?
        case key
        when "remote" then meta[:remote] = value
        when "revision" then meta[:revision] = value
        when "ref", "branch", "tag" then meta.merge!(ref_label: key, ref: value)
        end
      end

      # One resolved spec line, which is indented four spaces; its own
      # dependencies are indented six and are not resolutions.
      def record_spec(entries, section, meta, line)
        match = /\A {4}(\S+) \(([^)]+)\)\z/.match(line)
        return unless match
        # A platform-specific release writes its platform into the
        # parenthesised part, as `1.19.4-arm64-darwin`. The version is the
        # part before the first hyphen either way, since rubygems spells
        # prereleases with dots.
        version = match[2].split("-").first
        entries[match[1]] = meta.merge(section: section, version: version)
      end

      # The project's own gem installation directory, when `bundle config
      # path` moved it out of the global one. Laid out by rubygems as
      # `<path>/<engine>/<ABI>/specifications`, and pinned to this Ruby's
      # ABI: a sibling directory belongs to a different Ruby, whose
      # specifications would not load here anyway.
      def bundle_spec_dirs
        path = configured_bundle_path
        return [] if path.nil?
        dir = ::File.join(::File.expand_path(path, project_root),
                          ::Gem.ruby_engine, ::RbConfig::CONFIG["ruby_version"], "specifications")
        ::File.directory?(dir) ? [dir] : []
      end

      def configured_bundle_path
        config = bundle_config
        return nil if truthy?(::ENV[BUNDLE_PATH_SYSTEM_KEY] || config[BUNDLE_PATH_SYSTEM_KEY])
        path = ::ENV[BUNDLE_PATH_KEY] || config[BUNDLE_PATH_KEY]
        path.nil? || path.to_s.empty? ? nil : path.to_s
      end

      def bundle_config
        @bundle_config ||=
          begin
            path = ::File.join(project_root, BUNDLE_CONFIG_PATH)
            loaded = ::File.file?(path) ? ::YAML.safe_load_file(path) : nil
            loaded.is_a?(::Hash) ? loaded : {}
          rescue ::StandardError
            {}
          end
      end

      def truthy?(value)
        value.to_s == "true"
      end
    end
  end
end
