# frozen_string_literal: true

require "fileutils"
require "rubygems/package"
require "yaml"
require "yard-agentdocs"
require "corpus/gem_fetcher"

module Corpus
  ##
  # Builds a Corpus bundle for every gem version the corpus manifest names.
  # This is the implementation behind `toys corpus build`.
  #
  # Everything lives under one corpus directory, which is gitignored:
  #
  # * `gems/` is a gem home of the corpus's own, holding every manifest gem's
  #   sources. Laid out as `gems/<full name>/` plus
  #   `specifications/<full name>.gemspec`, the way RubyGems lays out a real
  #   one, because that is what lets {YARD::AgentDocs::GemBuilder} build from
  #   it unchanged.
  # * `agentdocs/` holds the bundles, one per gem version, written by that
  #   same {YARD::AgentDocs::GemBuilder}.
  #
  # ## Fetched, never installed, never borrowed
  #
  # Gems are downloaded and unpacked, not installed. An install compiles
  # native extensions, and a fair share of the corpus has them — some, like
  # `curb`, cannot compile at all without system libraries present. YARD
  # never needs the compiled result: it documents C *sources*, which the
  # unpacked `ruby`-platform gem carries. For the same reason dependencies
  # are never pulled; the manifest names every gem the corpus wants.
  #
  # Gems already installed on the machine are deliberately ignored, even at
  # the exact version the manifest names. Reusing them would save a download
  # but make the corpus depend on the machine: a globally installed copy may
  # be a precompiled platform variant without its C sources, and a default
  # gem has no sources under its gem path at all. Fetching everything means
  # the same manifest builds the same corpus everywhere.
  #
  # An unpacked gem never changes, so it is fetched once and kept. Only the
  # bundles are rebuilt; deleting `gems/` is the way to force a refetch.
  #
  # ## Order of work
  #
  # A full run first prunes whatever the manifest no longer names, so the
  # corpus directory always matches the manifest exactly and a checker can
  # walk it without consulting the manifest. It then fetches every missing
  # gem before building any, so a network or yank problem surfaces in the
  # first minutes of a run that takes hours rather than at the end of it.
  # A run restricted to named gems skips the prune, since it is not a
  # statement about the whole corpus.
  #
  # A failure to fetch or to build one gem is reported and counted, and the
  # rest carry on.
  #
  class Builder
    # @return [String] Subdirectory of the corpus directory holding gem sources.
    GEMS_SUBDIR = "gems"

    # @return [String] Subdirectory of the corpus directory holding bundles.
    AGENTDOCS_SUBDIR = "agentdocs"

    # @return [String] Subdirectory of the gem home that fetches in progress
    #   are unpacked under before being moved into place.
    TEMP_SUBDIR = ".incomplete"

    ##
    # @param manifest_path [String] Path to `corpus-manifest.yml`.
    # @param corpus_dir [String] The corpus directory.
    # @param names [Array<String>] Gems to restrict the run to; empty means
    #   every gem in the manifest.
    # @param rebuild [Boolean] Whether to rebuild a gem that already has a
    #   bundle.
    # @param fetcher [#fetch] Downloads `.gem` files; see {GemFetcher}.
    # @param out [IO] Where progress and summaries are written.
    #
    def initialize(manifest_path:, corpus_dir:, names: [], rebuild: true, fetcher: GemFetcher.new, out: $stdout)
      @manifest_path = manifest_path
      @corpus_dir = ::File.expand_path(corpus_dir)
      @names = Array(names).map(&:to_s)
      @rebuild = rebuild ? true : false
      @fetcher = fetcher
      @out = out
    end

    # @return [String] Absolute path of the corpus directory.
    attr_reader :corpus_dir

    # @return [Array<String>] Gems the run is restricted to, if any.
    attr_reader :names

    # @return [Boolean] Whether existing bundles are rebuilt.
    attr_reader :rebuild

    ##
    # @return [String] The corpus's own gem home.
    #
    def gem_home
      ::File.join(corpus_dir, GEMS_SUBDIR)
    end

    ##
    # @return [String] The directory bundles are written under.
    #
    def output_root
      ::File.join(corpus_dir, AGENTDOCS_SUBDIR)
    end

    ##
    # The manifest entries this run covers, in manifest order.
    #
    # @return [Array<Array(String, String)>] Name and version pairs.
    # @raise [BuildError] if the manifest is unreadable, or a requested name
    #   is not in it.
    #
    def entries
      @entries ||= select_entries(load_manifest)
    end

    ##
    # Prunes, fetches and builds.
    #
    # @return [Boolean] Whether every gem covered was fetched and built.
    # @raise [BuildError] as {#entries} does, before anything is touched.
    #
    def build
      selected = entries
      prune(selected) if names.empty?
      fetched, failed = fetch_all(selected)
      built = fetched.empty? || build_bundles(fetched)
      unless failed.empty?
        listed = failed.map { |name, version| full_name(name, version) }.join(", ")
        @out.puts "Could not fetch #{failed.size} gem(s): #{listed}"
      end
      failed.empty? && built
    end

    ##
    # Raised when the run cannot start at all.
    #
    class BuildError < ::StandardError
    end

    private

    def spec_dir
      ::File.join(gem_home, "specifications")
    end

    def sources_dir
      ::File.join(gem_home, "gems")
    end

    def load_manifest
      data = ::YAML.safe_load_file(@manifest_path)
      gems = data.is_a?(::Hash) ? data["gems"] : nil
      raise BuildError, "#{@manifest_path} has no `gems` list" unless gems.is_a?(::Array)
      gems.map { |entry| [entry.fetch("name").to_s, entry.fetch("version").to_s] }
    rescue ::SystemCallError, ::Psych::Exception, ::KeyError, ::TypeError => e
      raise BuildError, "could not read #{@manifest_path}: #{e.message}"
    end

    def select_entries(all)
      return all if names.empty?
      unknown = names - all.map(&:first)
      raise BuildError, "not in the corpus manifest: #{unknown.join(', ')}" unless unknown.empty?
      all.select { |entry| names.include?(entry.first) }
    end

    def full_name(name, version)
      "#{name}-#{version}"
    end

    # Removes every bundle, unpacked gem and specification the manifest does
    # not name, plus anything an interrupted fetch left behind. Entries whose
    # names start with a dot are another component's scratch space —
    # {YARD::AgentDocs::GemBuilder} sweeps its own — and are left alone.
    def prune(selected)
      expected = selected.to_set { |name, version| full_name(name, version) }
      removed = strays(output_root, expected) +
                strays(spec_dir, expected, suffix: ".gemspec") +
                strays(sources_dir, expected)
      removed.each do |path|
        ::FileUtils.rm_rf(path)
        @out.puts "Pruned #{path}"
      end
      ::FileUtils.rm_rf(::File.join(gem_home, TEMP_SUBDIR))
    end

    # The paths of the entries in +dir+ whose names, less +suffix+, are not
    # in +expected+, skipping dot-entries.
    def strays(dir, expected, suffix: "")
      return [] unless ::File.directory?(dir)
      ::Dir.children(dir).sort.filter_map do |entry|
        next if entry.start_with?(".") || expected.include?(entry.delete_suffix(suffix))
        ::File.join(dir, entry)
      end
    end

    # Fetches every selected gem not already present, returning the entries
    # now present and the entries that failed.
    def fetch_all(selected)
      missing = selected.reject { |name, version| present?(name, version) }
      missing.each_with_index do |(name, version), index|
        @out.puts "Fetching [#{index + 1}/#{missing.size}] #{full_name(name, version)}"
        fetch_one(name, version)
      end
      selected.partition { |name, version| present?(name, version) }
    end

    # A gem counts as present only once its specification exists, because
    # that is written last.
    def present?(name, version)
      full = full_name(name, version)
      ::File.file?(::File.join(spec_dir, "#{full}.gemspec")) &&
        ::File.directory?(::File.join(sources_dir, full))
    end

    # Downloads and unpacks one gem. It is unpacked into a scratch directory
    # and moved into place, and its specification written only after that,
    # so a fetch killed partway through never leaves something that looks
    # like a present gem. A gem whose specification RubyGems cannot load back
    # is removed again rather than left in place, since
    # {YARD::AgentDocs::GemBuilder} would refuse the whole run over it.
    def fetch_one(name, version)
      full = full_name(name, version)
      temp = ::File.join(gem_home, TEMP_SUBDIR, "#{::Process.pid}-#{full}")
      ::FileUtils.rm_rf(temp)
      ::FileUtils.mkdir_p(temp)
      spec = unpack(name, version, temp)
      install_unpacked(full, temp, spec)
    rescue GemFetcher::FetchError, ::Gem::Exception, ::SystemCallError => e
      @out.puts "Could not fetch #{full}: #{e.message}"
    ensure
      ::FileUtils.rm_rf(temp)
    end

    def unpack(name, version, temp)
      gem_file = ::File.join(temp, "#{full_name(name, version)}.gem")
      @fetcher.fetch(name, version, gem_file)
      package = ::Gem::Package.new(gem_file)
      spec = package.spec
      unless spec.full_name == full_name(name, version)
        raise GemFetcher::FetchError, "the downloaded file contains #{spec.full_name}"
      end
      package.extract_files(::File.join(temp, "unpacked"))
      spec
    end

    def install_unpacked(full, temp, spec)
      spec_path = ::File.join(spec_dir, "#{full}.gemspec")
      gem_dir = ::File.join(sources_dir, full)
      ::FileUtils.rm_f(spec_path)
      ::FileUtils.rm_rf(gem_dir)
      ::FileUtils.mkdir_p([sources_dir, spec_dir])
      ::File.rename(::File.join(temp, "unpacked"), gem_dir)
      ::File.write(::File.join(temp, "spec"), spec.to_ruby)
      ::File.rename(::File.join(temp, "spec"), spec_path)
      return if ::Gem::Specification.load(spec_path)
      ::FileUtils.rm_f(spec_path)
      ::FileUtils.rm_rf(gem_dir)
      raise GemFetcher::FetchError, "RubyGems could not load its specification back"
    end

    def build_bundles(present)
      ::YARD::AgentDocs::GemBuilder.new(
        requests: present.map { |name, version| "#{name}:#{version}" },
        spec_dirs: [spec_dir],
        output_root: output_root,
        rebuild: rebuild
      ).build
    end
  end
end
