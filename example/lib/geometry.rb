# frozen_string_literal: true

require_relative "geometry/parse_error"
require_relative "geometry/point"
require_relative "geometry/computations"
require_relative "geometry/angles"
require_relative "geometry/rounding"
require_relative "geometry/taggable"
require_relative "geometry/named"
require_relative "geometry/loud"
require_relative "geometry/shape"
require_relative "geometry/polygon"
require_relative "geometry/triangle"
require_relative "geometry/circle"
require_relative "geometry/vector"

##
# A small toy geometry namespace, used as a worked example and test case for
# the `yard-agentdocs` output format.
#
# Exists purely to group its nested classes and modules; it defines no
# behavior of its own. Not part of the shipped gem.
#
# # Usage
#
# Construct two points and measure the distance between them:
#
# ```ruby
# # build two points and measure the distance between them
# a = Geometry::Point.new(1, 2)
# b = Geometry::Point.new(4, 6)
# Geometry::Segment.new(a, b).length
# ```
#
# ### Further reading
#
# - The [CommonMark spec](https://spec.commonmark.org/), which this output
#   format's Markdown is meant to conform to.
# - The [YARD documentation](https://yardoc.org/) for the docstring markup
#   this namespace's own comments are written in.
#
# ##### Caveat
#
# This heading is already below the level this format's own hierarchy
# reserves, so it renders unchanged.
#
module Geometry
end
