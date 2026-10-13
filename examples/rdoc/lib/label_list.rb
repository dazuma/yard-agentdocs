# frozen_string_literal: true

##
# Exercises RDoc label lists in page bodies and tag text.
#
# RDoc has two label-list syntaxes. A label followed by a double colon:
#
# timeout:: Seconds to wait before giving up.
# retries:: How many times to try again.
#
#           A second paragraph belongs to the same item, as does a list:
#
#           * the first nested point
#           * the second nested point
#
# And a bracketed label, where several labels can share one item:
#
# [+:get+]
# [+:head+] Read-only requests.
# [NOTE:] A label that already ends in a colon.
#
# An ordinary bullet list stays a separate list from a label list beside it:
#
# * a bullet point
#
# [label] a label item
#
# A label list's text can itself open with a label, as a header joined onto
# one line does:
#
# Author:: Jane Doe Copyright:: Copyright (c) 2026 Example Corp.
#
# A label with no text, followed directly by a list, as nokogiri writes its
# parameter sections, stays separate from that list:
#
# [Parameters]
# * +host+ the server to connect to
# * +port+ the port to connect on
#
# Prose after a label list follows one blank line.
#
module LabelList
  ##
  # Connects to the server.
  #
  # @param opts [Hash] the connection settings, which also accept:
  #   host:: the server to connect to
  #   port:: the port to connect on
  # @option opts [Boolean] :ack [DEPRECATED] Use +:manual_ack+ instead.
  # @return [void]
  #
  def self.connect(opts)
    opts
  end
end
