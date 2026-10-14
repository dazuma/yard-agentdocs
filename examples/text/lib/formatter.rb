# frozen_string_literal: true

##
# Formats values as plain text. This docstring is written under
# --markup text, so its line breaks are kept and *stars* stay literal.
#
# # A top-of-line hash, not a heading
#
#     A 4-space indent, not a code block
#
class Formatter
  ##
  # Formats one value, keeping
  # this line break.
  #
  # @param value [Object] the value to format, described over
  #   two lines of text
  # @return [String] the value as *text*
  # @see Formatter the class this method belongs to
  # @since 1.0
  #
  def format(value)
    value.to_s
  end
end
