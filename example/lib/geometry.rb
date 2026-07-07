# frozen_string_literal: true

require_relative "geometry/point"

##
# A small toy geometry namespace, used as a worked example for the
# `yard-agentdocs` output format. Not part of the shipped gem.
#
module Geometry
  ##
  # Computes the distance between two points.
  #
  # @param a [Point] the first point
  # @param b [Point] the second point
  # @return [Float] the distance between the two points
  # @see Point#distance_to
  #
  def self.distance(a, b)
    a.distance_to(b)
  end
end
