# frozen_string_literal: true

require "fileutils"

module YARD
  module AgentDocs
    ##
    # Runs YARD against a project directory with the `agentdocs` template,
    # producing a documentation bundle. This is the implementation behind the
    # `agentdocs build` Toys tool shipped in this gem's `toys/` directory (see
    # `toys/agentdocs/build.rb`); it lives here, rather than in the tool file,
    # so the behavior is testable and documented independently of the Toys
    # DSL layer.
    #
    # The build honors the target project's own `.yardopts`, plus any extra
    # YARD arguments passed through, but forces three settings so a project's
    # existing doc configuration can't derail an agentdocs run:
    #
    # * `-f agentdocs` — the output format, the entire point of the run.
    # * `-t default` — the template. `agentdocs` renderers live under
    #   `templates/default/*/agentdocs/`, and YARD resolves a template as the
    #   literal directory `<template>/<type>/<format>`, so a project
    #   `.yardopts` naming a custom template would fail outright.
    # * `-o` — the output directory ({#output_dir}). Left alone, a project's
    #   `.yardopts` would drop markdown into the same directory as its
    #   human-facing HTML docs.
    #
    # Everything else — source globs, `--markup`, `--title`, extra files, and
    # so on — is left to `.yardopts` and the caller. Forcing works simply by
    # ordering: YARD parses `.document`, then `.yardopts`, then the command
    # line into one options object, so the arguments this class appends last
    # win.
    #
    class Builder
      ##
      # The output directory used when the caller doesn't name one.
      #
      DEFAULT_OUTPUT = "agentdocs"

      ##
      # @param input [String] the project directory to document. Treated as
      #   the project root: the build runs with this as its working
      #   directory, so the project's `.yardopts` is picked up and recorded
      #   source paths come out relative to it. Defaults to the current
      #   directory.
      # @param output [String] the directory to write the bundle into. A
      #   relative path is resolved against the current directory, not
      #   against +input+ — so it means what it would mean to any other
      #   command run from the same shell. Defaults to {DEFAULT_OUTPUT}.
      # @param clean [Boolean] whether to delete the output directory before
      #   generating, so files left over from an earlier run (a page for a
      #   class that no longer exists, say) can't linger in the bundle.
      #   Defaults to false.
      # @param yard_args [Array<String>] additional arguments passed straight
      #   through to YARD, such as source globs or `--markup markdown`.
      #
      def initialize(input: ".", output: DEFAULT_OUTPUT, clean: false, yard_args: [])
        @input_dir = ::File.expand_path(input)
        # Resolved up front, against the caller's current directory, because
        # the build itself runs chdir'd into the input directory.
        @output_dir = ::File.expand_path(output)
        @clean = clean
        @yard_args = Array(yard_args).map(&:to_s)
      end

      ##
      # @return [String] the absolute path of the project directory being
      #   documented, and the working directory the build runs in
      #
      attr_reader :input_dir

      ##
      # @return [String] the absolute path of the directory the bundle is
      #   written to
      #
      attr_reader :output_dir

      ##
      # @return [Boolean] whether the output directory is deleted before
      #   generating
      #
      attr_reader :clean

      ##
      # @return [Array<String>] additional arguments passed through to YARD
      #
      attr_reader :yard_args

      ##
      # Generates the documentation bundle.
      #
      # Problems are reported through YARD's logger rather than raised, so a
      # command-line caller gets the same error presentation YARD itself
      # uses.
      #
      # @return [Boolean] whether the build succeeded
      #
      def build
        return false unless validate
        return false unless clean_output

        ::YARD::Registry.clear
        ::Dir.chdir(input_dir) do
          run_yardoc
        end
      end

      private

      # Checks the one precondition that would otherwise surface as a
      # confusing YARD-level failure (or, worse, a build of whatever happens
      # to live in the current directory).
      def validate
        return true if ::File.directory?(input_dir)
        log.error "yard-agentdocs: `#{input_dir}` is not a directory"
        false
      end

      # Deletes the output directory when +clean+ is set, refusing targets
      # that contain the project being documented — without this, an
      # `--output .` or `--output ..` would take the source tree with it.
      def clean_output
        return true unless clean
        if output_contains_input?
          log.error "yard-agentdocs: refusing to clean `#{output_dir}` because it contains " \
                    "the project being documented (`#{input_dir}`)"
          return false
        end
        ::FileUtils.rm_rf(output_dir)
        true
      end

      # Whether the output directory *is* the project being documented, or an
      # ancestor of it.
      #
      # Compares fully resolved paths, because the two are reached by
      # different routes — one typically from an argument, the other from the
      # working directory — and a symlink anywhere along either would
      # otherwise defeat a plain string comparison. On macOS that's the norm
      # rather than an edge case: `Dir.pwd` reports a temp directory as
      # `/private/var/...` while the same path expands to `/var/...`.
      #
      # A directory that doesn't exist can't contain anything, which also
      # covers the ordinary case of a first run writing a fresh bundle.
      def output_contains_input?
        return false unless ::File.directory?(output_dir)
        real_input = ::File.realpath(input_dir)
        real_output = ::File.realpath(output_dir)
        real_input == real_output || real_input.start_with?("#{real_output}/")
      end

      # Invokes YARD with the caller's arguments followed by this gem's
      # forced settings.
      #
      # `YARD::CLI::Yardoc#run` reports failure three different ways: a falsy
      # return when argument parsing rejected something (an unavailable
      # markup provider, for instance), an `abort` when `--fail-on-warning`
      # tripped, and an exception otherwise. The first two are normalized to
      # `false` here so a caller gets a plain boolean instead of having its
      # process killed out from under it.
      def run_yardoc
        args = yard_args + ["-o", output_dir, "-t", "default", "-f", "agentdocs"]
        ::YARD::CLI::Yardoc.new.run(*args) ? true : false
      rescue ::SystemExit => e
        e.success?
      end
    end
  end
end
