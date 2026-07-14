# frozen_string_literal: true

module Geometry
  class Segment
    def initialize(start_point, end_point)
      @start_point = start_point
      @end_point = end_point
    end

    def length
      @start_point.distance_to(@end_point)
    end
  end
end
