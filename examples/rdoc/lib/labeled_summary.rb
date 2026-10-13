# frozen_string_literal: true

##
# [EXPERIMENTAL] Exercises summaries that open with an RDoc label-list item.
#
# RDoc reads a leading bracketed label, or a leading label followed by a
# double colon, as a label list. Converted as a list, a summary would span
# two lines, so the summary surfaces render each item inline as
# "label: text" instead.
#
module LabeledSummary
  ##
  # [NOTE:] Retained for compatibility with 1.x, in a label ending in a colon.
  #
  LEGACY = true

  ##
  # Supported versions:: 2.0 and later, in the double-colon form.
  #
  SUPPORTED = ">= 2.0"

  ##
  # Author:: Jane Doe
  # Copyright:: Copyright (c) 2026 Example Corp.
  #
  class Header
  end

  ##
  # [MAINTENANCE MODE] Fetches +key+ from the legacy store.
  #
  # @param key [String] the key to look up
  # @return [String, nil] the stored value, if any
  #
  def self.fetch(key)
    key
  end
end
