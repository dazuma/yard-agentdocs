# frozen_string_literal: true

require_relative "geometry/point"
require_relative "geometry/computations"
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
module Geometry
end
