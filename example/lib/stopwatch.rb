# frozen_string_literal: true

##
# A simple stopwatch that accumulates elapsed time, in seconds.
#
# Defined at the top level (not nested inside any module), to exercise how
# `yard-agentdocs` renders a class that isn't namespaced.
#
class Stopwatch
  ##
  # Creates a stopwatch with no elapsed time yet recorded.
  #
  def initialize
    @elapsed = 0.0
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
end
