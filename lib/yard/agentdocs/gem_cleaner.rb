# frozen_string_literal: true

require "fileutils"

module YARD
  module AgentDocs
    ##
    # Removes agentdocs bundles previously built for installed gems by
    # {GemBuilder}. This is the implementation behind the `agentdocs gems
    # clean` Toys tool shipped in this gem's `toys/` directory (see
    # `toys/agentdocs/gems/clean.rb`), and lives here for the same reason its
    # siblings do: so the behavior is testable and documented apart from the
    # Toys DSL layer.
    #
    # What can be removed is decided entirely by what's on disk, not by what's
    # installed — the point of cleaning is usually a bundle whose gem is gone.
    # Only immediate subdirectories of {#output_root} whose names parse as a
    # gem bundle (see {parse_bundle_name}) are visible to this class: anything
    # else in that directory is neither counted nor deleted, which is also
    # what keeps a surprising `$XDG_DATA_HOME` from turning a clean into
    # something worse.
    #
    # Nothing is removed unless the whole request resolves. A name or version
    # that isn't there is a typo far more often than a reason to delete
    # everything else, so {#resolve} reports every problem and gives up.
    #
    class GemCleaner
      ##
      # Splits a bundle directory name back into the gem it was built from.
      #
      # Bundle directories are named for a gem's full name — `toys-0.22.0`,
      # or `nokogiri-1.19.4-arm64-darwin` for a platform-specific gem — which
      # runs a name that may contain hyphens, a version, and a platform that
      # may contain hyphens together with no separator to tell them apart. The
      # rule here: the version is the rightmost hyphen-separated segment that
      # starts with a digit and is a valid version. Everything before it is
      # the gem name, everything after it is the platform.
      #
      # That's unambiguous in practice because `Gem::Version` normalizes a
      # hyphenated prerelease (`1.0.0-beta` becomes `1.0.0.pre.beta`), so a
      # version never contributes a hyphen of its own to a full name, and a
      # platform never starts with a digit. The unit tests check the rule
      # against every gem installed on the machine running them.
      #
      # @param basename [String] a bundle directory name
      # @return [Array(String, Gem::Version, String), nil] the gem name,
      #   version, and platform (nil if the gem is platform-independent), or
      #   nil if the name isn't a gem bundle name at all
      #
      def self.parse_bundle_name(basename)
        parts = basename.split("-")
        index = (parts.size - 1).downto(1).find do |i|
          parts[i].match?(/\A\d/) && ::Gem::Version.correct?(parts[i])
        end
        return nil unless index
        platform = parts[(index + 1)..].join("-")
        [parts[0...index].join("-"), ::Gem::Version.new(parts[index]), platform.empty? ? nil : platform]
      end

      ##
      # @param requests [Array<String>] the gems to clean, each written as
      #   `name` (every version built for that gem), `name:version` (that
      #   version alone), or `name:all` (the same as a bare name, accepted so
      #   a command line can read the same as one given to `agentdocs gems`).
      # @param all [Boolean] whether to remove every bundle present, in
      #   addition to any +requests+.
      # @param all_outdated [Boolean] whether to remove every bundle except
      #   the newest built version of each gem, in addition to any +requests+.
      #   Ignored when +all+ is also set, since +all+ subsumes it.
      # @param output_root [String, nil] the directory bundles live in.
      #   Defaults to {GemBuilder.default_output_root}, so cleaning can't
      #   disagree with building about where they are.
      #
      def initialize(requests: [], all: false, all_outdated: false, output_root: nil)
        @requests = Array(requests).map(&:to_s)
        @all = all ? true : false
        @all_outdated = all_outdated ? true : false
        @output_root = ::File.expand_path(output_root || GemBuilder.default_output_root)
      end

      ##
      # @return [Array<String>] the gems to clean
      #
      attr_reader :requests

      ##
      # @return [Boolean] whether every bundle present is removed
      #
      attr_reader :all

      ##
      # @return [Boolean] whether every bundle but the newest of each gem is
      #   removed
      #
      attr_reader :all_outdated

      ##
      # @return [String] the absolute path of the directory bundles live in
      #
      attr_reader :output_root

      ##
      # Works out which bundles this clean covers, without removing anything.
      # Useful on its own for a caller that wants to confirm the scope of a
      # bulk removal first; {#clean} calls it and memoizes, so calling both
      # costs one resolution.
      #
      # @return [Array<String>, nil] the absolute paths of the bundle
      #   directories to remove, sorted by gem name and version, or nil if the
      #   request couldn't be honored
      #
      def resolve
        return @resolve if defined?(@resolve)
        @resolve = compute_resolve
      end

      ##
      # Removes every bundle covered by this clean.
      #
      # @return [Boolean] whether the resolved bundles are all gone
      #
      def clean
        dirs = resolve
        return false unless dirs
        if dirs.empty?
          announce("yard-agentdocs: nothing to remove")
          return true
        end
        failed = remove_all(dirs)
        announce("yard-agentdocs: #{dirs.size - failed.size} removed")
        failed.empty?
      end

      private

      # One bundle found in {#output_root}.
      Bundle = ::Data.define(:dir, :name, :version, :platform)
      private_constant :Bundle

      # Every bundle currently present, in directory order.
      def bundles
        @bundles ||= bundle_dir_names.filter_map do |entry|
          name, version, platform = self.class.parse_bundle_name(entry)
          next unless name
          Bundle.new(dir: ::File.join(output_root, entry), name: name,
                     version: version, platform: platform)
        end
      end

      def bundle_dir_names
        return [] unless ::File.directory?(output_root)
        ::Dir.children(output_root).select do |entry|
          ::File.directory?(::File.join(output_root, entry))
        end
      end

      # Bundles grouped by gem name, each group sorted oldest version first.
      def bundles_by_name
        @bundles_by_name ||= bundles.group_by(&:name).transform_values do |group|
          group.sort_by { |bundle| [bundle.version, bundle.dir] }
        end
      end

      def compute_resolve
        if requests.empty? && !all && !all_outdated
          log.error "yard-agentdocs: no gems requested; name at least one gem, " \
                    "or pass --all or --all-outdated"
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
        selected.values.sort_by { |bundle| [bundle.name, bundle.version, bundle.dir] }.map(&:dir)
      end

      # Applies the +all+ and +all_outdated+ selections. Explicit requests are
      # unioned on top rather than conflicting with these, so `--all-outdated`
      # plus one current version means exactly that.
      def select_in_bulk(selected)
        return unless all || all_outdated
        return bundles.each { |bundle| selected[bundle.dir] = bundle } if all
        bundles_by_name.each_value do |group|
          newest = group.last.version
          group.each { |bundle| selected[bundle.dir] = bundle unless bundle.version == newest }
        end
      end

      def select_request(request, selected, errors)
        name, colon, version = request.partition(":")
        if name.empty? || (!colon.empty? && version.empty?)
          errors << "`#{request}` is not a gem request; expected `name`, `name:version`, " \
                    "or `name:#{GemBuilder::ALL_VERSIONS}`"
          return
        end
        group = bundles_by_name[name]
        return errors << "no agentdocs are built for gem `#{name}`" if group.nil?
        matches = match_versions(name, colon, version, group, errors)
        matches&.each { |bundle| selected[bundle.dir] = bundle }
      end

      # The bundles a single request's version part selects, or nil (having
      # appended to +errors+) if it selects none.
      def match_versions(name, colon, version, group, errors)
        return group if colon.empty? || version == GemBuilder::ALL_VERSIONS
        unless ::Gem::Version.correct?(version)
          errors << "`#{version}` is not a version number, in request `#{name}:#{version}`"
          return nil
        end
        wanted = ::Gem::Version.new(version)
        matches = group.select { |bundle| bundle.version == wanted }
        return matches unless matches.empty?
        errors << "gem `#{name}` version #{version} has no agentdocs; built versions are " \
                  "#{group.map(&:version).join(', ')}"
        nil
      end

      # Removes each directory, returning the ones that survived. `rm_rf`
      # swallows the errors it hits, so what's left on disk is the only
      # trustworthy report of what happened.
      def remove_all(dirs)
        dirs.each_with_index.filter_map do |dir, index|
          announce("yard-agentdocs: [#{index + 1}/#{dirs.size}] removing #{::File.basename(dir)}")
          ::FileUtils.rm_rf(dir)
          next unless ::File.exist?(dir)
          log.error("yard-agentdocs: could not remove `#{dir}`")
          dir
        end
      end

      # Progress and summary lines, gated exactly as {GemBuilder}'s are:
      # printed regardless of log level, except when the level has been raised
      # to ERROR or above.
      def announce(message)
        log.puts(message) if log.level < ::YARD::Logger::ERROR
      end
    end
  end
end
