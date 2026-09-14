# frozen_string_literal: true

##
# This comment is *overridden* by the one in the signature file.
#
# When an object is documented in both a Ruby source file and an
# +.rbs+ signature file, YARD keeps the signature file's comment. This
# text exists so the fixture has the two-source shape real gems ship
# (+base64+, +prime+); if it ever appears in the rendered output, that
# override stopped happening.
#
class Provenance
  ##
  # Also overridden by the signature file's comment, for the same reason.
  #
  def render(text)
    text
  end
end
