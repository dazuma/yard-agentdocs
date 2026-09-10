# frozen_string_literal: true

module Geometry
  class Segment
    ENDPOINT_COUNT = 2

    def initialize(start_point, end_point)
      @start_point = start_point
      @end_point = end_point
    end

    attr_reader :start_point, :end_point

    def length
      @start_point.distance_to(@end_point)
    end
  end
end
