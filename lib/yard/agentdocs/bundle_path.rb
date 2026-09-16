# frozen_string_literal: true

module YARD
  module AgentDocs
    ##
    # Prints where one gem's bundle is, and nothing else. This is the
    # implementation behind the `agentdocs path` Toys tool shipped in this
    # gem's `toys/` directory (see `toys/agentdocs/path.rb`); as with its
    # siblings, it lives here so the behavior is testable and documented
    # independently of the Toys DSL layer.
    #
    # ### What this is for
    #
    # Reading a bundle directly with `grep` is a first-class path — the
    # format, not {Lookup}, is the contract. But a bundle lives at
    # `<XDG data home>/yard-agentdocs/gems/<name>-<version>`, and an agent
    # cannot derive that: it does not know which version this project
    # resolves, and it should not be reimplementing XDG resolution. Without
    # this tool, entering the direct-grep path means spending a whole
    # {Lookup} on a namespace the agent already knows, purely to read the
    # bundle directory out of the header and throw the rest away.
    #
    # The point is not the tokens that saves, which is real but modest. It is
    # that one bare line on standard output is shell-composable and a prose
    # header is not:
    #
    #     docs_dir=$(toys agentdocs path toys) && grep -i flag "$docs_dir"/index.md
    #
    # That is one invocation doing resolution and grep together. Reading a
    # header cannot collapse that way, because the agent has to read it with
    # its own eyes before it can issue the grep.
    #
    # The `&&` is not decoration. A command substitution that fails prints
    # nothing, so the tempting `grep -i flag "$(…)"/index.md` would go on to
    # search `/index.md` at the root of the filesystem — and would find it if
    # anything were ever there. Gating on the exit status is what makes the
    # failure path unreachable rather than merely noisy, and it is why every
    # recipe this gem publishes is written that way.
    #
    # ### Standard output is the product, so nothing else may touch it
    #
    # This inverts {Lookup}'s rule that the body is primary and carries every
    # explanation on standard output. It has to: one stray line of prose and
    # `$( )` yields a path that is not a path. So standard output carries the
    # directory and a newline, or it carries nothing at all — a line there
    # always means a bundle really is at that location, with no second
    # meaning. Every diagnostic, on every failure, goes to standard error,
    # where an agent still sees it, and the exit code carries the outcome.
    #
    # A path dependency is the case that makes this worth stating: there *is*
    # a real directory on disk for it, and printing it would be the single
    # most tempting way to make `"$(…)"/index.md` a lie.
    #
    class BundlePath
      include ExitCodes

      ##
      # An answer: what to write to each stream, and what to exit with.
      #
      class Result
        ##
        # @param exit_code [Integer] one of the `EXIT_*` codes in {ExitCodes}
        # @param out [String] the text for standard output — the bundle
        #   directory and a newline, or empty
        # @param err [String] the text for standard error
        #
        def initialize(exit_code, out: "", err: "")
          @exit_code = exit_code
          @out = out
          @err = err.empty? || err.end_with?("\n") ? err : "#{err}\n"
        end

        ##
        # @return [Integer] the process exit code
        #
        attr_reader :exit_code

        ##
        # @return [String] the text for standard output: exactly one line
        #   naming an existing bundle, or empty
        #
        attr_reader :out

        ##
        # @return [String] the text for standard error
        #
        attr_reader :err

        ##
        # @return [Boolean] whether a path was found
        #
        def success?
          exit_code == ExitCodes::EXIT_SUCCESS
        end
      end

      ##
      # @param gem_name [String] the gem whose bundle directory is wanted
      # @param version [String, nil] the gem version to locate, instead of
      #   the one the project's lockfile resolves
      # @param build [Boolean] whether to build a missing bundle. Defaults to
      #   true, matching `lookup`: a path printed for a bundle that isn't
      #   there would fail in the composed form for a reason the caller
      #   could not diagnose.
      # @param project_dir [String, nil] the directory the project is
      #   resolved from. Defaults to the current directory.
      # @param spec_dirs [Array<String>, nil] the directories to search for
      #   installed gem specifications, for tests and for embedders driving
      #   this class directly. Defaults to the resolver's own.
      # @param output_root [String, nil] the directory bundles live under.
      #   Defaults to {GemBuilder.default_output_root}.
      #
      def initialize(gem_name, version: nil, build: true,
                     project_dir: nil, spec_dirs: nil, output_root: nil)
        @gem_name = gem_name.to_s
        @version = version&.to_s
        @build = build ? true : false
        @locator = BundleLocator.new(@gem_name, version: @version, project_dir: project_dir,
                                                spec_dirs: spec_dirs, output_root: output_root)
      end

      ##
      # @return [String] the gem whose bundle directory is wanted
      #
      attr_reader :gem_name

      ##
      # @return [String, nil] the version override, if any
      #
      attr_reader :version

      ##
      # @return [Boolean] whether a missing bundle is built
      #
      attr_reader :build

      ##
      # Resolves the gem and reports its bundle directory, building the
      # bundle first if it has none and building is allowed.
      #
      # @return [Result]
      #
      def run
        location = locator.locate(build: build)
        case location.status
        when :ready then found(location)
        when :missing then missing(location)
        when :build_failed then build_failed(location)
        when :no_release then no_release(location)
        when :not_installed then not_installed(location)
        else invalid_name
        end
      end

      private

      attr_reader :locator

      # The whole product: one line, no trailing prose, no header, and
      # nothing on standard error either. A success has nothing to say that
      # the path does not already say — the directory ends in the resolved
      # version — and a line printed on every run is noise in the composed
      # form, where the caller's own output is what it came for.
      def found(location)
        Result.new(EXIT_SUCCESS, out: "#{location.bundle_dir}\n")
      end

      def missing(location)
        resolution = location.resolution
        Result.new(EXIT_NOT_FOUND, err: <<~TEXT)
          No agentdocs bundle for #{gem_name} #{resolution.version}.
            expected at: #{location.bundle_dir}
            gem root:    #{resolution.spec.full_gem_path}

          --no-build was given, so nothing was built. To build it:
            #{BundleLocator::BUILD_COMMAND} #{gem_name}:#{resolution.version}
        TEXT
      end

      def build_failed(location)
        resolution = location.resolution
        Result.new(EXIT_BUILD_FAILED, err: <<~TEXT)
          Failed to build the agentdocs bundle for #{gem_name} #{resolution.version}; see
          the messages above.
            expected at: #{location.bundle_dir}
            gem root:    #{resolution.spec.full_gem_path}

          Read the gem's own source at that gem root instead.
        TEXT
      end

      # The gem root is named here and never printed on standard output. It
      # is a real directory, and for a path dependency a tempting one, but a
      # line on standard output means "a bundle is here" or it means nothing.
      def no_release(location)
        resolution = location.resolution
        locked_in = ::File.basename(resolution.lockfile.to_s)
        next_step =
          if resolution.kind == :path
            "Read its source at that path instead."
          else
            "Read its source instead; `bundle show #{gem_name}` reports the checkout path."
          end
        Result.new(EXIT_NO_RELEASE, err: <<~TEXT)
          `#{gem_name}` is a #{resolution.kind} dependency in #{locked_in}, so it has no
          released version, and no bundle is built for it.
            source: #{resolution.source}

          #{next_step}
        TEXT
      end

      def not_installed(location)
        resolution = location.resolution
        lines = ["#{resolution.message}, so there is no bundle for it."]
        unless resolution.installed_versions.empty?
          lines << "  installed versions: #{resolution.installed_versions.join(', ')}"
          lines << "  Pass --version to locate one of those instead."
        end
        lines << ""
        lines << "Read the gem's own source instead, or install the gem and try again."
        Result.new(EXIT_NOT_FOUND, err: lines.join("\n"))
      end

      def invalid_name
        Result.new(EXIT_USAGE, err: <<~TEXT)
          `#{gem_name}` is not a gem name.

          Expected the name of a gem this project depends on, such as `toys` or
          `rubocop`.
        TEXT
      end
    end
  end
end
