# frozen_string_literal: true

module YARD
  module AgentDocs
    ##
    # The exit statuses the gem's lookup-family tools report. One taxonomy,
    # shared, because {Lookup} and {BundlePath} answer questions about the
    # same bundle and fail in the same ways — a second dialect of "not found"
    # would be one more thing for a caller to learn and one more thing to
    # drift.
    #
    # Included rather than referenced, so each class's own `EXIT_*` names
    # resolve and neither tool depends on the other for its contract.
    #
    module ExitCodes
      ##
      # Exit code: the request was answered.
      #
      EXIT_SUCCESS = 0

      ##
      # Exit code: no answer — the entity has no matching heading, the name
      # has no file, or there is no bundle and none was built.
      #
      EXIT_NOT_FOUND = 1

      ##
      # Exit code: the request itself was malformed. Matches Toys' own
      # convention for a usage error.
      #
      EXIT_USAGE = 2

      ##
      # Exit code: this dependency has no released version to document — it
      # comes from git or a path — so no bundle is possible for it.
      #
      EXIT_NO_RELEASE = 3

      ##
      # Exit code: a bundle was missing and the build of it failed.
      #
      EXIT_BUILD_FAILED = 4
    end
  end
end
