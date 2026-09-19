# frozen_string_literal: true

require "minitest/autorun"
require "minitest/focus"
require "minitest/rg"

require "yard-agentdocs"

# YARD's own source emits two Ruby warnings under `-w`, which `toys test`
# passes, and each fires exactly once per process:
#
#  * `hybrid_markdown.rb:558: character class has duplicated range`, from
#    compiling a regexp literal, so it lands when that file is first required.
#  * `yardoc.rb:230: setting Encoding.default_internal`, from the *first*
#    `YARD::CLI::Yardoc` built; its `unless == utf8` guard leaves every later
#    one silent.
#
# Neither is actionable from here, and neither belongs to any one test: every
# example that documents a fixture gem would emit them, so which one actually
# does depends on the random seed. Provoking both up front, with `$stderr`
# swapped out, retires them before the first test runs — and, as a bonus,
# makes the `Encoding` defaults that second warning is about settle at a fixed
# point rather than partway through a seed-dependent run.
#
# `capture_io` is the right shape for these because Ruby routes warnings
# through `$stderr`. It is *not* interchangeable with `log.enter_level` for
# YARD's own `[warn]` lines: `log.io` holds the `STDOUT` constant, which
# swapping `$stdout` does not touch.
begin
  require "stringio"
  original_stderr = $stderr
  $stderr = ::StringIO.new
  require "yard/templates/helpers/markup/hybrid_markdown"
  ::YARD::CLI::Yardoc.new
ensure
  $stderr = original_stderr
end

# `YARD::CLI::Yardoc#run` switches YARD's progress bar on for the duration of
# every run, and `Logger#show_progress` only declines it when the level is INFO
# or lower — so quieting the logger, which several examples here do, leaves the
# bar on. On a TTY it then writes `\e[2K`, cursor-hide/show sequences and a
# bare `\r` over minitest's own output, repainting from a background thread
# every 0.05s: the line flickers and progress dots get overwritten. Redirect
# the run to a file and it disappears, which is why it only shows up
# interactively.
#
# `--no-progress` is the CLI's own lever but reaches only the runs a test
# assembles arguments for, not the ones driven through `Builder#run_yardoc` or
# `GemBuilder`, which build their own. Pinning the predicate off here disables
# exactly the progress rendering, for every path into YARD, and leaves the log
# level free to mean what it says elsewhere.
log.define_singleton_method(:show_progress) { false }

module AgentdocsTestHelper
  ##
  # Builds a small "template-like" holder object for exercising one or more
  # `YARD::AgentDocs` mixins in isolation, mirroring the `object`/`options`
  # surface `YARD::Templates::Template` normally provides.
  #
  # Always starts from a freshly-cleared `YARD::Registry`, matching how each
  # test previously started (whether or not it parsed anything of its own),
  # so tests never see leftover state from another example.
  #
  # Every call clears the registry, even when +source+ is omitted — so a
  # code object fetched from a *previous* call's registry must never be held
  # across a later call (its resolvable `{...}` references would silently
  # stop resolving once that later call's clear empties the registry under
  # it). When a test needs both a holder and a parsed object together, get
  # both from the same call (pass +source+/+at+ and use the holder's own
  # +object+), not from two separate calls.
  #
  # @param mixins [Array<Module>] modules to include into the holder class
  # @param source [String, nil] a class/module body to parse into the fresh
  #   registry before building the holder (typically used together with
  #   +at:+)
  # @param at [String, nil] the registry path to set as the holder's
  #   +object+, mirroring how a template sees the object currently being
  #   rendered
  # @param markup [Symbol, nil] when given, the holder's +options+ responds
  #   to +#markup+ with this value, standing in for
  #   +YARD::Templates::TemplateOptions+
  # @return [Object] a holder instance with +mixins+ included and
  #   +object+/+options+ set as requested
  #
  def agentdocs_holder(*mixins, source: nil, at: nil, markup: nil)
    ::YARD::Registry.clear
    ::YARD.parse_string(source) if source

    holder_class = ::Class.new do
      mixins.each { |mixin| include mixin }
      attr_accessor :object, :options
    end

    holder_class.new.tap do |holder|
      holder.object = ::YARD::Registry.at(at) if at
      holder.options = ::Struct.new(:markup).new(markup) if markup
    end
  end
end

Minitest::Spec.include(AgentdocsTestHelper)
