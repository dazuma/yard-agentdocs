# frozen_string_literal: true

##
# Exercises rdoc-dialect prose whose summary sentence runs on past a single
# source line, as most real-world RDoc summaries eventually do.
#
# RDoc joins a paragraph's source lines into one before converting it, so the
# line breaks in this comment are the author's, not part of the text. The
# converter must emit each paragraph on one line rather than re-wrap it at a
# fixed width of its own choosing.
#
module WrappedProse
  ##
  # Stands in for a nested member whose summary is long enough to have wrapped
  # in its parent's Member Summary bullet.
  #
  class Member
    ##
    # Directive letters, one per line:<br>
    # %w - a word<br>
    # %s - the separator
    #
    # Each <tt><br></tt> is a hard break, which the summary surfaces render
    # as a space.
    #
    DIRECTIVES = %w[w s].freeze

    ##
    # Joins +words+ with +separator+, in a summary sentence long enough to have
    # been split across lines by a 78-column re-wrap.
    #
    # A body paragraph past 78 columns, whose source lines are joined into one
    # and must then stay that way in the output, with no break inserted.
    #
    # * A list item whose text also runs past 78 columns, so a re-wrap would
    #   have pushed its tail onto an indented continuation line.
    # * A short item.
    #
    # @param words [Array<String>] the words to join, in a description long
    #   enough that a 78-column re-wrap would have split it across two lines
    # @param separator [String] the separator
    # @return [String] the joined words
    #
    def join(words, separator = " ")
      words.join(separator)
    end
  end
end
