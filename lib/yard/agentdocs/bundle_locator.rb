# frozen_string_literal: true

module YARD
  module AgentDocs
    ##
    # Works out where one gem's bundle is, and whether it is there — the step
    # every lookup-family tool performs before it can do anything else.
    #
    # It composes {DependencyResolver} (which version this project depends
    # on, installed where) with {GemBuilder} (where that version's bundle
    # goes, and building it if it isn't there yet), and reports the outcome
    # as a {Location}.
    #
    # ### Why this is its own class
    #
    # "Never read a different version's tree" is the invariant the whole
    # lookup family exists to enforce, and it is enforced entirely by this
    # sequence: resolve the version, derive the directory from the resolved
    # spec, confirm the directory is really there. {Lookup} and {BundlePath}
    # both need it, and `agentdocs search` will need it again. Three
    # independent transcriptions of an anti-drift invariant is the worst
    # possible place for a copy.
    #
    # Confirming the directory is there is the whole of the check, with no
    # validation of what is inside it, because a canonical bundle path only
    # ever holds a complete bundle or nothing — see
    # `docs/adr/0002-atomic-bundle-publication.md`.
    #
    # ### It reports, it does not explain
    #
    # A {Location} carries a status, a directory, and the resolution — and no
    # message text at all. That is deliberate: the callers differ precisely
    # in how they speak. {Lookup} writes prose to standard output, because an
    # agent reads stdout and ignores `$?`; {BundlePath} keeps stdout clean
    # enough to sit inside `$( )` and writes its diagnostics to standard
    # error. Neither shape belongs here, and a shared "default message" would
    # be wrong for both.
    #
    # Nothing here reads a bundle. Locating one and understanding its format
    # are separate concerns, which is what lets {BundlePath} depend on this
    # class without depending on the format at all.
    #
    class BundleLocator
      ##
      # The command that builds a bundle, as an agent would type it. It lives
      # here because this is the class that decides *not* to build one, and a
      # caller told "there is no bundle" is owed the command that makes one.
      #
      BUILD_COMMAND = "toys do --gem=yard-agentdocs --on-missing-gem=install agentdocs gems"

      ##
      # Where a gem's bundle is and whether it can be read.
      #
      class Location
        ##
        # @param status [Symbol] one of `:ready`, `:missing`, `:build_failed`,
        #   `:no_release`, `:not_installed`, or `:invalid_name`
        # @param bundle_dir [String, nil] where the bundle is, or would be.
        #   Present whenever a released version resolved, including when no
        #   bundle has been built there yet.
        # @param resolution [DependencyResolver::Resolution, nil] what the
        #   version resolution found. Nil only for `:invalid_name`, which is
        #   rejected before anything is resolved.
        #
        def initialize(status:, bundle_dir: nil, resolution: nil)
          @status = status
          @bundle_dir = bundle_dir
          @resolution = resolution
        end

        ##
        # @return [Symbol] `:ready` when a bundle is present and readable;
        #   `:missing` when the gem resolved but has no bundle and none was
        #   built; `:build_failed` when one was attempted and did not appear;
        #   `:no_release` for a git or path dependency; `:not_installed` when
        #   the resolved version isn't installed; `:invalid_name` when the
        #   gem name isn't one.
        #
        attr_reader :status

        ##
        # @return [String, nil] the bundle's directory, present whenever a
        #   released version resolved
        #
        attr_reader :bundle_dir

        ##
        # @return [DependencyResolver::Resolution, nil] the resolution
        #
        attr_reader :resolution

        ##
        # @return [Boolean] whether a bundle is present and can be read
        #
        def ready?
          status == :ready
        end
      end

      ##
      # @param gem_name [String] the gem whose bundle is wanted
      # @param version [String, nil] the gem version to locate, instead of
      #   the one the project's lockfile resolves
      # @param project_dir [String, nil] the directory the project is
      #   resolved from. Defaults to the current directory.
      # @param spec_dirs [Array<String>, nil] the directories to search for
      #   installed gem specifications, for tests and for embedders driving
      #   this class directly. Defaults to the resolver's own.
      # @param output_root [String, nil] the directory bundles live under.
      #   Defaults to {GemBuilder.default_output_root}.
      #
      def initialize(gem_name, version: nil, project_dir: nil, spec_dirs: nil, output_root: nil)
        @gem_name = gem_name.to_s
        @version = version&.to_s
        @project_dir = project_dir
        @spec_dirs = spec_dirs
        @output_root = output_root
      end

      ##
      # @return [String] the gem whose bundle is wanted
      #
      attr_reader :gem_name

      ##
      # @return [String, nil] the version override, if any
      #
      attr_reader :version

      ##
      # Resolves the gem and reports where its bundle is.
      #
      # Build progress is written to standard error rather than returned, so
      # a caller whose standard output is a documentation body — or a single
      # composable path — keeps it.
      #
      # @param build [Boolean] whether to build a bundle that isn't there
      #   yet. Building a large gem takes minutes, so this is the caller's
      #   decision rather than a default of this class.
      # @return [Location]
      #
      def locate(build: false)
        return location(:invalid_name) unless resolver.valid_name?
        resolution = resolver.resolve
        return non_release(resolution) unless resolution.release?
        dir = bundle_dir(resolution)
        return location(:ready, dir, resolution) if present?(dir)
        return location(:missing, dir, resolution) unless build
        run_build(resolution)
        location(present?(dir) ? :ready : :build_failed, dir, resolution)
      end

      private

      attr_reader :project_dir, :output_root

      def resolver
        @resolver ||= DependencyResolver.new(gem_name, version: version,
                                             project_dir: project_dir, spec_dirs: @spec_dirs)
      end

      # The builder is constructed with the real request rather than only for
      # its path arithmetic, so the same object answers "where would this
      # bundle be" and "build it" and the two cannot drift apart.
      def builder(resolution)
        @builder ||= GemBuilder.new(requests: ["#{gem_name}:#{resolution.version}"],
                                    rebuild: false, spec_dirs: resolver.spec_dirs,
                                    output_root: output_root)
      end

      def bundle_dir(resolution)
        builder(resolution).output_dir_for(resolution.spec)
      end

      # A bundle is published atomically, so a directory with anything in it
      # is a complete one.
      def present?(dir)
        BundleReader.new(dir).exist?
      end

      # A dependency with no released version to document, or one that isn't
      # installed. Neither builds, and neither invents a location: where a git
      # checkout lives is Bundler's business, and the location convention for
      # non-release sources is still an open design question.
      def non_release(resolution)
        status = [:git, :path].include?(resolution.kind) ? :no_release : :not_installed
        location(status, nil, resolution)
      end

      # Runs the build with YARD's logger pointed at standard error for its
      # duration. The logger writes to standard output by default, which
      # would mix parse progress and per-gem announcements into whatever the
      # caller is about to write there.
      def run_build(resolution)
        previous = log.io
        log.io = $stderr
        begin
          builder(resolution).build
        ensure
          log.io = previous
        end
      end

      def location(status, dir = nil, resolution = nil)
        Location.new(status: status, bundle_dir: dir, resolution: resolution)
      end
    end
  end
end
