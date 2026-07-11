# frozen_string_literal: true

##
# A simple stopwatch that accumulates elapsed time, in seconds.
#
# Defined at the top level (not nested inside any module), to exercise how
# `yard-agentdocs` renders a class that isn't namespaced.
#
class Stopwatch
  ##
  # The elapsed time a newly created stopwatch starts at, and the default
  # value `#reset` resets to.
  #
  # @return [Float]
  #
  DEFAULT_ELAPSED = 0.0

  ##
  # Creates a stopwatch with no elapsed time yet recorded.
  #
  def initialize
    @elapsed = DEFAULT_ELAPSED
  end

  ##
  # Adds to the elapsed time.
  #
  # @param seconds [Float] the number of seconds to add
  # @return [Float] the new total elapsed time
  #
  def add(seconds)
    @elapsed += seconds
  end

  ##
  # Resets the elapsed time.
  #
  # @param to [Float] the elapsed time to reset to; defaults to `DEFAULT_ELAPSED`
  # @return [Float] the new elapsed time
  #
  def reset(to = DEFAULT_ELAPSED)
    @elapsed = to
  end
end
