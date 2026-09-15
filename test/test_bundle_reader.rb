# frozen_string_literal: true

require "helper"

describe ::YARD::AgentDocs::BundleReader do
  let(:project_root) { ::File.expand_path("..", __dir__) }
  let(:bundle_dir) { ::File.join(project_root, "examples/geometry/doc") }
  let(:reader) { ::YARD::AgentDocs::BundleReader.new(bundle_dir) }

  def concept(fqn)
    reader.read(reader.concept_path(fqn))
  end

  describe "#exist?" do
    it "recognizes a bundle" do
      assert(reader.exist?)
    end

    it "rejects a directory that isn't there" do
      refute(::YARD::AgentDocs::BundleReader.new(::File.join(bundle_dir, "nope")).exist?)
    end

    # A build is published by renaming a finished tree into place, so an
    # empty directory at a bundle's path is debris, never work in progress.
    it "rejects an empty directory" do
      ::Dir.mktmpdir do |dir|
        refute(::YARD::AgentDocs::BundleReader.new(dir).exist?)
      end
    end
  end

  describe "#concept_path" do
    it "derives a top-level name" do
      assert_equal("Stopwatch.md", reader.concept_path("Stopwatch"))
    end

    it "derives a namespaced name" do
      assert_equal("Geometry/Point.md", reader.concept_path("Geometry::Point"))
    end

    it "derives a deeply namespaced name" do
      assert_equal("Geometry/ThreeD/Point.md", reader.concept_path("Geometry::ThreeD::Point"))
    end

    it "returns nil for a name the bundle doesn't document" do
      assert_nil(reader.concept_path("Geometry::Nonesuch"))
    end

    # On a case-insensitive filesystem `File.exist?` would answer this with
    # `Point.md`, producing a match that wouldn't reproduce elsewhere.
    it "returns nil for a name differing only in case" do
      assert_nil(reader.concept_path("Geometry::point"))
    end

    it "returns nil for a name that isn't a fully qualified name" do
      assert_nil(reader.concept_path("Geometry::Point#x"))
      assert_nil(reader.concept_path(""))
    end

    # Segments are validated before any path is built from them, so no
    # entity argument can address a file outside the bundle.
    it "refuses to escape the bundle" do
      assert_nil(reader.concept_path("../../../etc/passwd"))
      assert_nil(reader.concept_path(".."))
      assert_nil(reader.concept_path("Geometry::..::Geometry::Point"))
    end
  end

  describe "#sibling_fqns" do
    it "lists the concepts of a namespace" do
      siblings = reader.sibling_fqns("Geometry::Nonesuch")
      assert_includes(siblings, "Geometry::Point")
      assert_includes(siblings, "Geometry::ThreeD")
      assert_equal(siblings.sort, siblings)
    end

    it "lists top-level concepts for an unnamespaced name" do
      assert_includes(reader.sibling_fqns("Nonesuch"), "Stopwatch")
    end

    # `index.md`, `bundle.md`, and Guides are files in a bundle but are not
    # names a lookup can ask for, so offering them as candidates would be
    # offering an answer that cannot be requested.
    it "omits the files that aren't concepts" do
      siblings = reader.sibling_fqns("Nonesuch")
      refute_includes(siblings, "index")
      refute_includes(siblings, "bundle")
      refute(siblings.any? { |name| name.start_with?("file.") })
    end

    it "is empty for a namespace that isn't there" do
      assert_empty(reader.sibling_fqns("Nonesuch::Deeper::Still"))
    end
  end

  describe "#head" do
    it "extracts the heading and the identifying bullets" do
      assert_equal(<<~MD, reader.head(concept("Geometry::Triangle")))
        # class Geometry::Triangle

        - **Superclass:** [`Polygon`](Polygon.md)
        - **Extends:** [`Named`](Named.md)
        - **Defined in:** `examples/geometry/lib/geometry/triangle.rb`
      MD
    end

    it "stops before the docstring" do
      refute_includes(reader.head(concept("Geometry::Triangle")), "A triangle")
    end

    # A method must never be shown as current when the type it belongs to is
    # deprecated, so the `* ` flags below the context bullets come along.
    it "includes a deprecation flag and its continuation lines" do
      head = reader.head(concept("Geometry::Circle"))
      assert_includes(head, "* **Deprecated.** Struct-based value objects like this one are being phased")
      assert_includes(head, "  exercising the `Struct.new` case.")
      refute_includes(head, "A circle, defined by its radius.")
    end

    it "includes an abstract flag" do
      assert_includes(reader.head(concept("Geometry::Shape")), "* **Abstract.**")
    end

    it "includes a private-API flag" do
      assert_includes(reader.head(concept("Geometry::Cache")), "* **Private API.**")
    end

    # The marker change from `- ` to `* ` is what keeps the two blocks from
    # rendering as one list, and the blank line between them is part of that,
    # so the head is sliced out of the file rather than reassembled.
    it "keeps the blank line between the context bullets and the flags" do
      assert_includes(reader.head(concept("Geometry::Cache")),
                      "cache.rb`\n\n* **Private API.**")
    end

    # A long `**Includes:**` list wraps like any other bullet; taking only
    # lines that start with the marker would drop the rest of it.
    it "includes a wrapped context bullet's continuation lines" do
      head = reader.head(<<~MD)
        # class Foo::Bar

        - **Includes:** [`One`](One.md), [`Two`](Two.md),
          [`Three`](Three.md)
        - **Defined in:** `lib/foo/bar.rb`

        The docstring.
      MD
      assert_includes(head, "  [`Three`](Three.md)")
      assert_includes(head, "- **Defined in:** `lib/foo/bar.rb`")
      refute_includes(head, "The docstring.")
    end

    # A module with no superclass still has a `Defined in` bullet, and the
    # heading itself says which of class and module it is.
    it "handles a module" do
      head = reader.head(concept("Geometry::Named"))
      assert(head.start_with?("# module Geometry::Named\n"))
      assert_includes(head, "- **Defined in:**")
    end

    it "returns nil for content with no heading" do
      assert_nil(reader.head("just some prose\n"))
    end
  end

  describe "#member_section" do
    it "extracts a class method" do
      section = reader.member_section(concept("Geometry::Triangle"), ".new")
      assert(section.start_with?("### .new\n"))
      assert_includes(section, "Creates a triangle, with sides fixed to 3.")
      assert(section.end_with?("triangle.rb:21`\n"))
    end

    it "extracts a constant" do
      section = reader.member_section(concept("Geometry::Point"), "DIMENSIONS")
      assert(section.start_with?("### DIMENSIONS\n"))
      assert_includes(section, "- **Value:** `2`")
      refute_includes(section, "### ORIGIN")
    end

    it "extracts an attribute" do
      section = reader.member_section(concept("Geometry::Point"), "#x")
      assert(section.start_with?("### #x\n"))
      refute_includes(section, "### #y")
    end

    it "extracts an operator method" do
      section = reader.member_section(concept("Geometry::Point"), "#[]=")
      assert(section.start_with?("### #[]=\n"))
      refute_includes(section, "### #[]\n")
    end

    # The last member of a file has no following heading to stop at.
    it "reads the last member to the end of the file" do
      section = reader.member_section(concept("Geometry::Point"), "#zero?")
      assert(section.start_with?("### #zero?\n"))
      assert(section.end_with?("point.rb:221`\n"))
    end

    it "stops at the next `## ` section heading" do
      section = reader.member_section(concept("Geometry::Point"), "ORIGIN")
      refute_includes(section, "## Instance Attributes")
    end

    it "returns nil for a member the concept doesn't define" do
      assert_nil(reader.member_section(concept("Geometry::Point"), "#nonesuch"))
    end

    # `#x` and `.x` are different members, and matching one for the other
    # would be a plausible wrong answer rather than a miss.
    it "distinguishes the sigils" do
      content = concept("Geometry::Point")
      assert(reader.member_section(content, "#round"))
      assert_nil(reader.member_section(content, ".round"))
    end
  end

  describe "#summary" do
    it "reads through the end of the member summary" do
      summary = reader.summary(concept("Geometry::Point"))
      assert_includes(summary, "A point in two-dimensional space.")
      assert_includes(summary, "## Member Summary")
      assert_includes(summary, "- `#zero?`")
      refute_includes(summary, "## Constants")
    end

    # A bare error subclass documents no members at all, so there is no
    # summary section to stop at and nothing to leave out.
    it "returns the whole of a concept with no sections" do
      content = concept("Geometry::ParseError")
      assert_equal(content, reader.summary(content))
    end

    # A concept whose only members are inherited has a member summary and
    # nothing after it.
    it "returns the whole of a concept whose summary is last" do
      content = concept("Geometry::ThreeD")
      assert_includes(content, "## Member Summary")
      assert_equal(content, reader.summary(content))
    end

    # A handful of gems write `## ` headings into a class docstring, which
    # land above the member summary. Stopping at the first `## ` in the file
    # would cut those concepts off before they said anything.
    it "ignores a `## ` heading in the docstring above the member summary" do
      content = <<~MD
        # module FileUtils

        - **Defined in:** `lib/fileutils.rb`

        ## Avoiding the TOCTTOU Vulnerability

        Be careful.

        ## Member Summary

        - `VERSION`

        ## Constants

        ### VERSION
      MD
      summary = reader.summary(content)
      assert_includes(summary, "Be careful.")
      assert_includes(summary, "- `VERSION`")
      refute_includes(summary, "## Constants")
    end
  end

  describe "#member_names" do
    it "lists the members a concept defines, in file order" do
      names = reader.member_names(concept("Geometry::Triangle"))
      assert_equal([".new"], names)
    end

    it "includes constants, attributes, and both method sigils" do
      names = reader.member_names(concept("Geometry::Point"))
      assert_includes(names, "DIMENSIONS")
      assert_includes(names, "#x")
      assert_includes(names, ".parse")
      assert_includes(names, "#[]=")
    end

    # A member name never contains whitespace, so holding `### ` lines to
    # that grammar rejects prose headings inside an `@example` block without
    # any of the fence tracking that would misread a bundle whose generated
    # markdown has an unbalanced fence in it.
    it "ignores a `### ` line that isn't a member heading" do
      content = <<~MD
        ### #go

        ```ruby
        ### Environment variables
        ```

        ### #stop
      MD
      assert_equal(["#go", "#stop"], reader.member_names(content))
      assert_includes(reader.member_section(content, "#go"), "### Environment variables")
    end
  end

  describe "#inherited_sources" do
    it "finds the concept a superclass member comes from" do
      sources = reader.inherited_sources(concept("Geometry::Triangle"), "#describe")
      assert_equal([["Inherited", "Polygon", "Polygon.md"]], sources)
    end

    it "finds the concept an extended member comes from" do
      sources = reader.inherited_sources(concept("Geometry::Triangle"), ".kind")
      assert_equal([["Extended", "Named", "Named.md"]], sources)
    end

    it "finds the concept an included member comes from" do
      sources = reader.inherited_sources(concept("Geometry::Shape"), "#tag")
      assert_equal([["Included", "Taggable", "Taggable.md"]], sources)
    end

    it "is empty for a member the concept defines itself" do
      assert_empty(reader.inherited_sources(concept("Geometry::Triangle"), ".new"))
    end

    it "is empty for a member nothing contributes" do
      assert_empty(reader.inherited_sources(concept("Geometry::Triangle"), "#nonesuch"))
    end

    # The names in one of these lines are backticked and comma separated, so
    # a shorter name must not match inside a longer one.
    it "matches a whole name only" do
      assert_empty(reader.inherited_sources(concept("Geometry::Triangle"), "#desc"))
    end
  end
end
