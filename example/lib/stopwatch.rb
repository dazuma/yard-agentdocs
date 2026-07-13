# frozen_string_literal: true

##
# A simple stopwatch that accumulates elapsed time, in seconds.
#
# Defined at the top level (not nested inside any module), to exercise how
# `yard-agentdocs` renders a class that isn't namespaced.
#
# Call {#reset the reset method} to start over.
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

  ##
  # Runs the given block and adds how long it took to this stopwatch's
  # elapsed time.
  #
  # @yield the work to time
  # @yieldreturn [Object] the block's own return value, passed through unchanged
  # @return [Object] the block's return value
  #
  def measure(&block)
    before = current_time
    result = block.call
    @elapsed += current_time - before
    result
  end

  ##
  # Builds a descriptive label for this stopwatch. Combines every parameter
  # shape this format's signature line can render — a required positional
  # argument, an optional positional argument, a splat, a required keyword,
  # an optional keyword, a double-splat, and a block — in one signature,
  # purely to exercise how they assemble together; not a realistic
  # formatting API.
  #
  # @param name [String] the stopwatch's label
  # @param precision [Integer] decimal places to round the elapsed time to
  # @param tags [Array<String>] extra tags to include
  # @param unit [String] the unit label, e.g. `"s"`
  # @param separator [String] the string used to join the tags
  # @param metadata [Hash{Symbol => Object}] arbitrary extra key/value pairs to include
  # @param block [Proc] a block to post-process the label, used instead of it if given
  # @return [String] the assembled label
  #
  def describe(name, precision = 1, *tags, unit:, separator: ", ", **metadata, &block)
    base = "#{name} (#{@elapsed.round(precision)}#{unit})"
    base += " [#{tags.join(separator)}]" unless tags.empty?
    base += " #{metadata}" unless metadata.empty?
    block ? block.call(base) : base
  end

  ##
  # Formats the elapsed time for internal diagnostic tooling. Kept public so
  # other objects in this library can call it directly, but not meant to be
  # part of the stable public API.
  #
  # @private
  # @return [String] the elapsed time, in seconds, as a plain string
  #
  def raw_elapsed_s
    @elapsed.to_s
  end

  private

  ##
  # The current monotonic clock reading, used to measure elapsed time in
  # {#measure}.
  #
  # @return [Float]
  #
  def current_time
    ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
  end
end
