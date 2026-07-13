# frozen_string_literal: true

require "helper"

describe ::YARD::AgentDocs::AttributeInfo do
  let(:holder_class) do
    Class.new do
      include ::YARD::AgentDocs::AttributeInfo
      include ::YARD::AgentDocs::Markdownify

      attr_accessor :options
    end
  end

  let(:holder) do
    holder_class.new.tap { |h| h.options = ::Struct.new(:markup).new(:markdown) }
  end

  # Parses +source+ and returns the `{ name:, read:, write: }` hash for
  # +name+ on +namespace_path+, the same shape
  # `module/agentdocs/setup.rb#attribute_objects` builds.
  def attr_hash(source, namespace_path, name)
    ::YARD::Registry.clear
    ::YARD.parse_string(source)
    rw = ::YARD::Registry.at(namespace_path).attributes[:instance][name.to_sym]
    { name: name.to_s, read: rw[:read], write: rw[:write] }
  end

  describe "read-only attribute (attr_reader)" do
    let(:attr) do
      attr_hash(<<~RUBY, "Point", :x)
        class Point
          # The x-coordinate.
          #
          # @return [Numeric]
          attr_reader :x
        end
      RUBY
    end

    it "#attribute_source_method returns the reader" do
      assert_equal(:x, holder.attribute_source_method(attr).name)
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
      attr_hash(<<~RUBY, "Point", :x)
        class Point
          # @return [Numeric]
          attr_writer :x
        end
      RUBY
    end

    it "#attribute_source_method returns the writer" do
      assert_equal(:x=, holder.attribute_source_method(attr).name)
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
      attr_hash(<<~RUBY, "Point", :x)
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
      attr = attr_hash(<<~RUBY, "Point", :x)
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
      attr = attr_hash(<<~RUBY, "Point", :x)
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
