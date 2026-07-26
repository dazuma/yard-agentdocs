# frozen_string_literal: true

require "fileutils"
require "simple_xdg"

module YARD
  module AgentDocs
    ##
    # Builds agentdocs bundles for gems installed in the current Ruby's global
    # gem directory, one bundle per installed gem version, written to a fixed
    # location under the user's XDG data directory. This is the implementation
    # behind the `agentdocs gems` Toys tool shipped in this gem's `toys/`
    # directory (see `toys/agentdocs/gems.rb`); as with {Builder}, it lives
    # here so the behavior is testable and documented independently of the
    # Toys DSL layer.
    #
    # Neither the input nor the output location is configurable from the
    # command line: the input is whatever is installed globally, and each
    # gem's bundle lands in `<XDG data home>/yard-agentdocs/gems/<full name>`
    # — so an agent looking for a gem's reference docs has one path to
    # compute rather than a project convention to discover. Moving the root
    # is a matter of setting `$XDG_DATA_HOME`. The {#output_root} and
    # {#spec_dirs} constructor arguments exist for tests and for embedders
    # driving this class directly.
    #
    # Each gem is documented by handing its installed directory to {Builder},
    # so a gem's own `.yardopts` is honored just as it would be for a project
    # checkout. One argument is inserted ahead of the caller's {#yard_args}:
    # `--no-save`, because YARD would otherwise write a `.yardoc` database
    # into the installed gem's directory. That directory is shared state,
    # possibly not even writable, and nothing here needs the database, since
    # the same run that parses also generates. It goes *before* the caller's
    # arguments so a caller that really does want a database can say so.
    #
    class GemBuilder
      ##
      # The path, relative to the XDG data home, that bundles are written
      # under.
      #
      DEFAULT_SUBDIR = ::File.join("yard-agentdocs", "gems")

      ##
      # The version keyword, as in `toys:all`, asking for every installed
      # version of a gem rather than one.
      #
      ALL_VERSIONS = "all"

      class << self
        ##
        # The directories searched for installed gem specifications: those of
        # the current Ruby's global gem directory, plus its default gems.
        #
        # Deliberately globbed rather than read through
        # `Gem::Specification.stubs`, because Bundler replaces that with a
        # view of the active bundle only. A tool whose whole premise is "the
        # gems installed on this machine" would otherwise quietly report most
        # of them as not installed whenever it ran under a bundle.
        #
        # @return [Array<String>]
        #
        def default_spec_dirs
          [::File.join(::Gem.dir, "specifications"), ::Gem.default_specifications_dir]
        end

        ##
        # The directory bundles are written under when the caller doesn't name
        # one: {DEFAULT_SUBDIR} within the XDG data home.
        #
        # @return [String]
        #
        def default_output_root
          ::File.join(::SimpleXDG.new.data_home, DEFAULT_SUBDIR)
        end
      end

      ##
      # @param requests [Array<String>] the gems to document, each written as
      #   `name` (the newest installed version), `name:version` (that version
      #   specifically), or `name:all` (every installed version).
      # @param all [Boolean] whether to document every installed version of
      #   every installed gem, in addition to any +requests+.
      # @param all_latest [Boolean] whether to document the newest installed
      #   version of every installed gem, in addition to any +requests+.
      #   Ignored when +all+ is also set, since +all+ subsumes it.
      # @param include_default [Boolean] whether default gems — the ones
      #   shipped with Ruby itself — count as installed. Defaults to false:
      #   they're excluded from +all+ and +all_latest+, and naming one in
      #   +requests+ is an error that says to pass this instead.
      # @param rebuild [Boolean] whether to rebuild a gem that already has a
      #   nonempty bundle. Defaults to true; when false, such a gem is left
      #   exactly as it is.
      # @param yard_args [Array<String>] additional arguments passed straight
      #   through to YARD for every gem, such as `--markup markdown`.
      # @param spec_dirs [Array<String>, nil] the directories to search for
      #   installed gem specifications. Defaults to
      #   {default_spec_dirs}.
      # @param output_root [String, nil] the directory to write per-gem
      #   bundles under. Defaults to {default_output_root}.
      #
      def initialize(requests: [], all: false, all_latest: false, include_default: false,
                     rebuild: true, yard_args: [], spec_dirs: nil, output_root: nil)
        @requests = Array(requests).map(&:to_s)
        @all = all ? true : false
        @all_latest = all_latest ? true : false
        @include_default = include_default ? true : false
        @rebuild = rebuild ? true : false
        @yard_args = Array(yard_args).map(&:to_s)
        @spec_dirs = (spec_dirs || self.class.default_spec_dirs).map { |dir| ::File.expand_path(dir) }
        @output_root = ::File.expand_path(output_root || self.class.default_output_root)
      end

      ##
      # @return [Array<String>] the gem requests to document
      #
      attr_reader :requests

      ##
      # @return [Boolean] whether every installed version of every gem is
      #   documented
      #
      attr_reader :all

      ##
      # @return [Boolean] whether the newest installed version of every gem is
      #   documented
      #
      attr_reader :all_latest

      ##
      # @return [Boolean] whether default gems count as installed
      #
      attr_reader :include_default

      ##
      # @return [Boolean] whether a gem that already has a nonempty bundle is
      #   rebuilt
      #
      attr_reader :rebuild

      ##
      # @return [Array<String>] additional arguments passed through to YARD
      #
      attr_reader :yard_args

      ##
      # @return [Array<String>] the absolute paths searched for installed gem
      #   specifications
      #
      attr_reader :spec_dirs

      ##
      # @return [String] the absolute path of the directory per-gem bundles are
      #   written under
      #
      attr_reader :output_root

      ##
      # The bundle directory for a gem: {#output_root} plus the gem's full
      # name, which carries the platform suffix for a platform-specific gem
      # (`nokogiri-1.19.4-arm64-darwin`) and so keeps two installs of one
      # version apart.
      #
      # @param spec [Gem::Specification] the gem
      # @return [String] the absolute path of the gem's bundle directory
      #
      def output_dir_for(spec)
        ::File.join(output_root, spec.full_name)
      end

      ##
      # Works out which installed gems this build covers, without building
      # anything. Useful on its own for a caller that wants to confirm the
      # scope of a large run before committing to it; {#build} calls it and
      # memoizes, so calling both costs one resolution.
      #
      # Nothing resolves partially: a request naming a gem or version that
      # isn't installed is a typo far more often than an invitation to build
      # everything else, so every problem is reported and the whole run is
      # refused.
      #
      # @return [Array<Gem::Specification>, nil] the gems to document, sorted
      #   by name and version, or nil if the request couldn't be honored
      #
      def resolve
        return @resolve if defined?(@resolve)
        @resolve = compute_resolve
      end

      ##
      # Builds a bundle for each gem covered by this build.
      #
      # A failure is per-gem: the gem's own output directory is removed, so a
      # later `rebuild: false` run can't mistake a half-written bundle for a
      # finished one, and the remaining gems still build. Problems are
      # reported through YARD's logger rather than raised, matching {Builder}.
      #
      # @return [Boolean] whether every gem covered by this build either built
      #   or was deliberately left alone
      #
      def build
        specs = resolve
        return false unless specs
        results = {built: [], skipped: [], unavailable: [], failed: []}
        specs.each_with_index do |spec, index|
          announce("yard-agentdocs: [#{index + 1}/#{specs.size}] #{spec.full_name}")
          results[build_one(spec)] << spec
        end
        report(results)
        results[:failed].empty?
      end

      private

      # Labels for the {#build} summary line, in the order they're reported.
      RESULT_LABELS = {
        built: "built",
        skipped: "already built",
        unavailable: "sources not installed",
        failed: "failed",
      }.freeze
      private_constant :RESULT_LABELS

      # Every gem specification found in {#spec_dirs}, whether or not it's
      # eligible for this build.
      def loaded_specs
        @loaded_specs ||= spec_dirs
                          .flat_map { |dir| ::Dir.glob(::File.join(dir, "*.gemspec")) }
                          .filter_map { |file| ::Gem::Specification.load(file) }
      end

      # The specifications this build may select from, grouped by gem name,
      # each group sorted oldest version first.
      def installed_specs
        @installed_specs ||= begin
          specs = include_default ? loaded_specs : loaded_specs.reject(&:default_gem?)
          specs.group_by(&:name).transform_values { |group| group.sort_by(&:version) }
        end
      end

      # The specs in one name's group sharing its newest version. Normally one
      # spec; more only when a version is installed for several platforms.
      def newest_of(group)
        newest = group.last.version
        group.select { |spec| spec.version == newest }
      end

      def compute_resolve
        if requests.empty? && !all && !all_latest
          log.error "yard-agentdocs: no gems requested; name at least one gem, " \
                    "or pass --all or --all-latest"
          return nil
        end
        selected = {}
        select_in_bulk(selected)
        errors = []
        requests.each { |request| select_request(request, selected, errors) }
        unless errors.empty?
          errors.each { |message| log.error("yard-agentdocs: #{message}") }
          return nil
        end
        selected.values.sort_by { |spec| [spec.name, spec.version, spec.full_name] }
      end

      # Applies the +all+ and +all_latest+ selections. Explicit requests are
      # unioned on top rather than conflicting with these, so asking for
      # `--all-latest` plus one older version means exactly that.
      def select_in_bulk(selected)
        return unless all || all_latest
        installed_specs.each_value do |group|
          (all ? group : newest_of(group)).each { |spec| selected[spec.full_name] = spec }
        end
      end

      def select_request(request, selected, errors)
        name, colon, version = request.partition(":")
        group = installed_specs[name]
        if name.empty? || (!colon.empty? && version.empty?)
          errors << "`#{request}` is not a gem request; expected `name`, `name:version`, " \
                    "or `name:#{ALL_VERSIONS}`"
          return
        end
        return errors << missing_gem_message(name) if group.nil?
        matches = match_versions(name, colon, version, group, errors)
        matches&.each { |spec| selected[spec.full_name] = spec }
      end

      # The specs a single request's version part selects, or nil (having
      # appended to +errors+) if it selects none.
      def match_versions(name, colon, version, group, errors)
        return newest_of(group) if colon.empty?
        return group if version == ALL_VERSIONS
        unless ::Gem::Version.correct?(version)
          errors << "`#{version}` is not a version number, in request `#{name}:#{version}`"
          return nil
        end
        wanted = ::Gem::Version.new(version)
        matches = group.select { |spec| spec.version == wanted }
        return matches unless matches.empty?
        errors << "gem `#{name}` version #{version} is not installed; installed versions are " \
                  "#{group.map(&:version).join(', ')}"
        nil
      end

      # A default gem is invisible unless asked for, so say which of the two
      # reasons a name didn't resolve rather than insisting it isn't there.
      def missing_gem_message(name)
        if !include_default && loaded_specs.any? { |spec| spec.name == name && spec.default_gem? }
          "gem `#{name}` is a default gem; pass --include-default to build it"
        else
          "gem `#{name}` is not installed"
        end
      end

      # Builds one gem, returning the {RESULT_LABELS} key describing what
      # happened to it.
      def build_one(spec)
        output = output_dir_for(spec)
        return :skipped if !rebuild && ::File.directory?(output) && !::Dir.empty?(output)
        unless ::File.directory?(spec.full_gem_path)
          log.warn "yard-agentdocs: #{spec.full_name} has no sources at " \
                   "`#{spec.full_gem_path}`; skipping"
          return :unavailable
        end
        return :built if build_with_builder(spec, output)
        ::FileUtils.rm_rf(output)
        :failed
      end

      def build_with_builder(spec, output)
        Builder.new(input: spec.full_gem_path,
                    output: output,
                    clean: true,
                    yard_args: ["--no-save"] + yard_args).build
      end

      def report(results)
        counts = RESULT_LABELS.filter_map do |key, label|
          "#{results[key].size} #{label}" unless results[key].empty?
        end
        announce("yard-agentdocs: #{counts.join(', ')}") unless counts.empty?
        return if results[:failed].empty?
        log.error("yard-agentdocs: failed to build #{results[:failed].map(&:full_name).join(', ')}")
      end

      # Progress and summary lines go out through YARD's logger, gated the way
      # YARD gates its own statistics: printed regardless of level, except
      # when the level has been raised to ERROR or above (as `yardoc -q`
      # does, and as tests do to keep their output readable).
      def announce(message)
        log.puts(message) if log.level < ::YARD::Logger::ERROR
      end
    end
  end
end
