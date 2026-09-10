# frozen_string_literal: true

module Geometry
  ##
  # Raised when a string can't be parsed as a point. See {Point.parse}.
  #
  class ParseError < StandardError
  end
end
