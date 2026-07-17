# frozen_string_literal: true

require "helper"

describe ::YARD::AgentDocs::AttributeInfo do
  let(:holder) do
    agentdocs_holder(
      ::YARD::AgentDocs::AttributeInfo, ::YARD::AgentDocs::CrossReferencing, ::YARD::AgentDocs::Markdownify,
      markup: :markdown
    )
  end

  # Parses +source+ and returns the {::YARD::AgentDocs::Attribute} for
  # +name+ on +namespace_path+, the same value
  # {::YARD::AgentDocs::MemberListing#attribute_objects} builds.
  def attribute_for(source, namespace_path, name)
    namespace = agentdocs_holder(source: source, at: namespace_path).object
    rw = namespace.attributes[:instance][name.to_sym]
    ::YARD::AgentDocs::Attribute.new(name: name.to_s, read: rw[:read], write: rw[:write])
  end

  describe "read-only attribute (attr_reader)" do
    let(:attr) do
      attribute_for(<<~RUBY, "Point", :x)
        class Point
          # The x-coordinate.
          #
          # @return [Numeric]
          attr_reader :x
        end
      RUBY
    end

    it "#source_method returns the reader" do
      assert_equal(:x, attr.source_method.name)
    end

    it "#attribute_type returns the declared @return type" do
      assert_equal("Numeric", holder.attribute_type(attr))
    end

    it "#attribute_annotation reports Read-only." do
      assert_equal("Read-only.", holder.attribute_annotation(attr))
    end

    it "#attribute_annotation_short reports read-only" do
      assert_equal("read-only", holder.attribute_annotation_short(attr))
    end

    it "#attribute_docstring_summary returns the summary line" do
      assert_equal("The x-coordinate.", holder.attribute_docstring_summary(attr))
    end
  end

  describe "write-only attribute (attr_writer)" do
    let(:attr) do
      attribute_for(<<~RUBY, "Point", :x)
        class Point
          # @return [Numeric]
          attr_writer :x
        end
      RUBY
    end

    it "#source_method returns the writer" do
      assert_equal(:x=, attr.source_method.name)
    end

    it "#attribute_annotation reports Write-only." do
      assert_equal("Write-only.", holder.attribute_annotation(attr))
    end

    it "#attribute_annotation_short reports write-only" do
      assert_equal("write-only", holder.attribute_annotation_short(attr))
    end
  end

  describe "read-write attribute (attr_accessor)" do
    let(:attr) do
      attribute_for(<<~RUBY, "Point", :x)
        class Point
          # @return [Numeric]
          attr_accessor :x
        end
      RUBY
    end

    it "#attribute_annotation is nil" do
      assert_nil(holder.attribute_annotation(attr))
    end

    it "#attribute_annotation_short is nil" do
      assert_nil(holder.attribute_annotation_short(attr))
    end
  end

  describe "#attribute_docstring" do
    it "returns the full (stripped) docstring, not just the summary" do
      attr = attribute_for(<<~RUBY, "Point", :x)
        class Point
          # The x-coordinate.
          #
          # Always finite.
          #
          # @return [Numeric]
          attr_reader :x
        end
      RUBY
      assert_equal("The x-coordinate.\n\nAlways finite.", holder.attribute_docstring(attr).to_s)
    end
  end

  describe "#attribute_file and #attribute_line" do
    it "return the backing method's source location" do
      attr = attribute_for(<<~RUBY, "Point", :x)
        class Point
          # @return [Numeric]
          attr_reader :x
        end
      RUBY
      assert_equal("(stdin)", holder.attribute_file(attr))
      assert_equal(3, holder.attribute_line(attr))
    end
  end
end
