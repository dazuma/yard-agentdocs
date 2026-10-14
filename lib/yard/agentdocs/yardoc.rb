# frozen_string_literal: true

require "yard"
require "yard/agentdocs/markdownify"

module YARD
  module AgentDocs
    ##
    # YARD's `yardoc` command, with markup verification replaced by one that
    # checks what this template can actually convert. {Builder} runs every
    # build through it, and the template's fixture test does too, so the
    # fixtures exercise the same entry point production does.
    #
    # YARD's own `verify_markup_options` loads a markup provider for the
    # run-wide `--markup` and for every extra file's dialect, and fails the
    # build when one can't be loaded. Neither half fits a template that
    # converts prose itself and never renders through a provider:
    #
    # * A provider pinned by a project's `.yardopts` (kramdown, maruku, even
    #   redcarpet) that isn't installed would fail the build, so whether it
    #   succeeded would depend on which markup gems the machine happens to
    #   have.
    # * A dialect with no usable provider (textile without redcloth, say)
    #   fails with a message blaming the provider, when the real cause is
    #   that this template can't convert the dialect.
    #
    # This replacement loads no provider. It checks only the run-wide
    # dialect, in three classes:
    #
    # * {Markdownify::CONVERTED_DIALECTS} pass.
    # * Dialects YARD renders without a provider ({Markdownify.provider_less?})
    #   pass, and {Markdownify} converts them too.
    # * Anything else ({Markdownify.unsupported?}) fails the build with a
    #   message naming the dialect. Every docstring is written in the
    #   run-wide dialect, so there is no useful partial output.
    #
    # Extra files are deliberately not checked here. An extra file in an
    # unsupported dialect is included verbatim, with a warning, by
    # `fulldoc/agentdocs/setup.rb`: failing would cost a gem its entire API
    # bundle over one guide, and an `agentdocs gems` user can't edit the
    # gem's `.yardopts`.
    #
    # The method is replaced outright rather than wrapped around `super`,
    # because YARD's version fails on the first extra file without a
    # provider, and getting an unsupported guide past it would mean
    # rewriting the file's recorded dialect, which the template reads later.
    # The cost is tracking YARD's version across releases; it is unchanged
    # through 0.9.45.
    #
    class Yardoc < ::YARD::CLI::Yardoc
      ##
      # Fails the run when the run-wide `--markup` names a dialect this
      # template can't convert.
      #
      # `options.markup` needs no defaulting here: `YardocOptions` already
      # defaults it to `:rdoc`, the same default YARD's own version assigns.
      # Nor is there a no-RDoc fallback to `:none`, since no provider is ever
      # loaded.
      #
      # @return [Boolean] whether the markup options are valid
      #
      def verify_markup_options
        return true unless Markdownify.unsupported?(options.markup)
        log.error "yard-agentdocs: markup dialect `#{options.markup}` is not supported " \
                  "(only markdown and rdoc can be converted)"
        false
      end
    end
  end
end
