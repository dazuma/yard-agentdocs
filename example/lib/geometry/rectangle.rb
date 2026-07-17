# frozen_string_literal: true

module Geometry
  ##
  # An axis-aligned rectangle, defined by its width and height.
  #
  # Its area and perimeter helpers live in separate files
  # (`rectangle.rb` and `rectangle_perimeter.rb`), the way a class's
  # methods might be split by concern across files in a real codebase.
  #
  class Rectangle
    ##
    # Creates a rectangle from its width and height.
    #
    # @param width [Float] the width
    # @param height [Float] the height
    #
    def initialize(width, height)
      @width = width
      @height = height
    end

    ##
    # The rectangle's width. Reassigning it resizes the rectangle in place.
    #
    # @return [Float]
    #
    attr_accessor :width

    ##
    # Reassigns the rectangle's height, resizing it in place. Deliberately
    # has no reader — unlike `#width`'s ordinary read-write pair — so this
    # fixture also exercises a write-only attribute.
    #
    # @return [Float]
    #
    attr_writer :height

    ##
    # Computes the area of the rectangle.
    #
    # @return [Float] the area
    #
    def area
      @width * @height
    end
  end
end
