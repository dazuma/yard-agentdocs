# frozen_string_literal: true

module YARD
  module AgentDocs
    ##
    # A single `attr_reader`/`attr_writer`/`attr_accessor`-declared
    # attribute, paired with whichever of its backing reader/writer
    # `YARD::CodeObjects::MethodObject`s actually exist — a reader/writer
    # pair doesn't otherwise have one YARD object of its own.
    # {MemberListing#attribute_objects} is the sole construction site.
    #
    # @!attribute [r] name
    #   @return [String] the attribute's name, without a leading `#`
    # @!attribute [r] read
    #   @return [::YARD::CodeObjects::MethodObject, nil] the reader method,
    #     or `nil` if the attribute is write-only
    # @!attribute [r] write
    #   @return [::YARD::CodeObjects::MethodObject, nil] the writer method,
    #     or `nil` if the attribute is read-only
    #
    Attribute = ::Data.define(:name, :read, :write) do
      ##
      # @return [::YARD::CodeObjects::MethodObject] whichever of the
      #   reader/writer actually exists, preferring the reader
      #
      def source_method
        read || write
      end
    end
  end
end
