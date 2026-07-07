# frozen_string_literal: true

require "helper"
require "tmpdir"

describe "agentdocs template" do
  let(:project_root) { ::File.expand_path("..", __dir__) }
  let(:example_doc_dir) { ::File.join(project_root, "example/doc") }

  # Runs from the project root so recorded source paths (used in "Defined in"
  # lines) come out relative, matching the example/doc fixtures.
  def generate(output_dir)
    ::YARD::Registry.clear
    ::Dir.chdir(project_root) do
      ::YARD::CLI::Yardoc.new.run(
        "--no-yardopts", "--no-save", "--no-stats", "--no-private",
        "-o", output_dir,
        "-t", "default",
        "-f", "agentdocs",
        "--title", "yard-agentdocs example — API Reference",
        "example/lib/geometry.rb",
        "example/lib/geometry/point.rb"
      )
    end
  end

  it "renders output identical to the example/doc fixture" do
    ::Dir.mktmpdir do |output_dir|
      generate(output_dir)

      ["index.md", "Geometry.md", ::File.join("Geometry", "Point.md")].each do |rel_path|
        actual = ::File.read(::File.join(output_dir, rel_path))
        expected = ::File.read(::File.join(example_doc_dir, rel_path))
        assert_equal(expected, actual, "mismatch for #{rel_path}")
      end
    end
  end
end
