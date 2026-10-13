# frozen_string_literal: true

require "helper"
require "fileutils"
require "stringio"
require "tmpdir"
require "yaml"
require "corpus/builder"

# Serves `.gem` files built on the spot rather than downloaded, so the corpus
# builder can be exercised end to end without the network.
#
# Each gem is a real package, built by `Gem::Package.build` from a one-file
# library, so that unpacking it goes through exactly the RubyGems code a real
# download would.
class CorpusFakeFetcher
  def initialize(missing: [], substitute: {})
    @missing = missing
    @substitute = substitute
    @calls = []
  end

  attr_reader :calls

  def fetch(name, version, path)
    @calls << "#{name}-#{version}"
    raise ::Corpus::GemFetcher::FetchError, "#{name} is gone" if @missing.include?(name)
    ::File.binwrite(path, package(name, @substitute.fetch(name, version)))
  end

  private

  def package(name, version)
    ::Dir.mktmpdir do |dir|
      ::FileUtils.mkdir_p(::File.join(dir, "lib"))
      ::File.write(::File.join(dir, "lib", "#{name}.rb"), <<~RUBY)
        # A widget from #{name}-#{version}.
        class Widget
          # Spins the widget.
          # @return [void]
          def spin; end
        end
      RUBY
      spec = ::Gem::Specification.new do |s|
        s.name = name
        s.version = version
        s.summary = "A test gem."
        s.authors = ["Nobody"]
        s.files = ["lib/#{name}.rb"]
      end
      # `Gem::Package.build` announces each build through RubyGems' UI, which
      # would otherwise land in the middle of the test output.
      file = ::Gem::DefaultUserInteraction.use_ui(::Gem::SilentUI.new) do
        ::Dir.chdir(dir) { ::Gem::Package.build(spec, true) }
      end
      ::File.binread(::File.join(dir, file))
    end
  end
end

describe ::Corpus::Builder do
  # Runs +block+ with a disposable directory holding a manifest that names
  # +gems+ (name => version) and an empty corpus directory, with YARD's logger
  # quieted so the builds' own announcements don't bury the test output.
  def with_corpus(gems)
    ::Dir.mktmpdir do |dir|
      manifest = ::File.join(dir, "corpus-manifest.yml")
      entries = gems.map { |name, version| {"name" => name, "version" => version} }
      ::File.write(manifest, ::YAML.dump({"gems" => entries}))
      log.enter_level(::YARD::Logger::FATAL) do
        yield manifest, ::File.join(dir, "corpus")
      end
    end
  end

  def corpus_builder(manifest, corpus, fetcher: CorpusFakeFetcher.new, **)
    @out = ::StringIO.new
    ::Corpus::Builder.new(manifest_path: manifest, corpus_dir: corpus, fetcher: fetcher, out: @out, **)
  end

  def bundles(corpus)
    dir = ::File.join(corpus, "agentdocs")
    ::File.directory?(dir) ? ::Dir.children(dir).reject { |e| e.start_with?(".") }.sort : []
  end

  def bundle_index(corpus, full_name)
    ::File.join(corpus, "agentdocs", full_name, "index.md")
  end

  def spec_path(corpus, full_name)
    ::File.join(corpus, "gems", "specifications", "#{full_name}.gemspec")
  end

  def gem_dir(corpus, full_name)
    ::File.join(corpus, "gems", "gems", full_name)
  end

  describe "a full run" do
    it "fetches every gem and builds a bundle for each" do
      with_corpus("alpha" => "1.0.0", "beta" => "2.1.0") do |manifest, corpus|
        fetcher = CorpusFakeFetcher.new
        assert corpus_builder(manifest, corpus, fetcher: fetcher).build
        assert_equal ["alpha-1.0.0", "beta-2.1.0"], fetcher.calls.sort
        assert_equal ["alpha-1.0.0", "beta-2.1.0"], bundles(corpus)
        assert_path_exists bundle_index(corpus, "alpha-1.0.0")
      end
    end

    it "lays the gems out as a gem home, with sources and specifications" do
      with_corpus("alpha" => "1.0.0") do |manifest, corpus|
        corpus_builder(manifest, corpus).build
        assert_path_exists ::File.join(gem_dir(corpus, "alpha-1.0.0"), "lib", "alpha.rb")
        spec = ::Gem::Specification.load(spec_path(corpus, "alpha-1.0.0"))
        assert_equal gem_dir(corpus, "alpha-1.0.0"), spec.full_gem_path
        assert_empty ::Dir.children(::File.join(corpus, "gems", ".incomplete"))
      end
    end

    it "does not fetch a gem a second time" do
      with_corpus("alpha" => "1.0.0") do |manifest, corpus|
        corpus_builder(manifest, corpus).build
        fetcher = CorpusFakeFetcher.new
        assert corpus_builder(manifest, corpus, fetcher: fetcher).build
        assert_empty fetcher.calls
      end
    end

    it "refetches a gem whose specification is missing" do
      with_corpus("alpha" => "1.0.0") do |manifest, corpus|
        corpus_builder(manifest, corpus).build
        ::File.delete(spec_path(corpus, "alpha-1.0.0"))
        fetcher = CorpusFakeFetcher.new
        assert corpus_builder(manifest, corpus, fetcher: fetcher).build
        assert_equal ["alpha-1.0.0"], fetcher.calls
        assert_path_exists spec_path(corpus, "alpha-1.0.0")
      end
    end

    it "prunes bundles and gems the manifest no longer names" do
      with_corpus("alpha" => "1.0.0") do |manifest, corpus|
        stale = ["alpha-0.9.0", "gone-1.0.0"]
        stale.each do |full_name|
          ::FileUtils.mkdir_p(::File.join(corpus, "agentdocs", full_name))
          ::FileUtils.mkdir_p(gem_dir(corpus, full_name))
          ::FileUtils.mkdir_p(::File.dirname(spec_path(corpus, full_name)))
          ::File.write(spec_path(corpus, full_name), "")
        end
        scratch = ::File.join(corpus, "agentdocs", ".incomplete")
        ::FileUtils.mkdir_p(scratch)
        assert corpus_builder(manifest, corpus).build
        assert_equal ["alpha-1.0.0"], bundles(corpus)
        stale.each do |full_name|
          refute_path_exists gem_dir(corpus, full_name)
          refute_path_exists spec_path(corpus, full_name)
        end
        assert_path_exists scratch
        assert_includes @out.string, "Pruned #{::File.join(corpus, 'agentdocs', 'gone-1.0.0')}"
      end
    end

    it "keeps an existing bundle with rebuild off" do
      with_corpus("alpha" => "1.0.0") do |manifest, corpus|
        corpus_builder(manifest, corpus).build
        ::File.write(bundle_index(corpus, "alpha-1.0.0"), "marker\n")
        assert corpus_builder(manifest, corpus, rebuild: false).build
        assert_equal "marker\n", ::File.read(bundle_index(corpus, "alpha-1.0.0"))
      end
    end
  end

  describe "a run restricted to named gems" do
    it "fetches and builds only those" do
      with_corpus("alpha" => "1.0.0", "beta" => "2.1.0") do |manifest, corpus|
        fetcher = CorpusFakeFetcher.new
        assert corpus_builder(manifest, corpus, fetcher: fetcher, names: ["beta"]).build
        assert_equal ["beta-2.1.0"], fetcher.calls
        assert_equal ["beta-2.1.0"], bundles(corpus)
      end
    end

    it "does not prune" do
      with_corpus("alpha" => "1.0.0") do |manifest, corpus|
        other = ::File.join(corpus, "agentdocs", "gone-1.0.0")
        ::FileUtils.mkdir_p(other)
        assert corpus_builder(manifest, corpus, names: ["alpha"]).build
        assert_path_exists other
      end
    end

    it "refuses a name not in the manifest, before touching anything" do
      with_corpus("alpha" => "1.0.0") do |manifest, corpus|
        fetcher = CorpusFakeFetcher.new
        error = assert_raises(::Corpus::Builder::BuildError) do
          corpus_builder(manifest, corpus, fetcher: fetcher, names: ["alpha", "nope"]).build
        end
        assert_match(/nope/, error.message)
        assert_empty fetcher.calls
        refute_path_exists corpus
      end
    end
  end

  describe "failures" do
    it "builds the other gems when one cannot be fetched, and reports failure" do
      with_corpus("alpha" => "1.0.0", "beta" => "2.1.0") do |manifest, corpus|
        fetcher = CorpusFakeFetcher.new(missing: ["alpha"])
        refute corpus_builder(manifest, corpus, fetcher: fetcher).build
        assert_equal ["beta-2.1.0"], bundles(corpus)
        refute_path_exists spec_path(corpus, "alpha-1.0.0")
        assert_includes @out.string, "Could not fetch 1 gem(s): alpha-1.0.0"
      end
    end

    it "rejects a download that holds a different version" do
      with_corpus("alpha" => "1.0.0") do |manifest, corpus|
        fetcher = CorpusFakeFetcher.new(substitute: {"alpha" => "1.0.1"})
        refute corpus_builder(manifest, corpus, fetcher: fetcher).build
        refute_path_exists spec_path(corpus, "alpha-1.0.0")
        refute_path_exists gem_dir(corpus, "alpha-1.0.0")
        assert_match(/contains alpha-1\.0\.1/, @out.string)
      end
    end

    it "raises when the manifest cannot be read" do
      ::Dir.mktmpdir do |dir|
        builder = corpus_builder(::File.join(dir, "missing.yml"), ::File.join(dir, "corpus"))
        assert_raises(::Corpus::Builder::BuildError) { builder.build }
      end
    end
  end
end
