# frozen_string_literal: true

module YARD
  module AgentDocs
    ##
    # Reads one bundle the way the `## Navigating these docs` preamble in its
    # own `bundle.md` says to: a class or module's file path is its fully
    # qualified name with `::` replaced by a directory separator, and every
    # constant, attribute, and method is a `### ` heading inside that file.
    #
    # This class *implements* those mechanics rather than restating them, so
    # the preamble stays authoritative and the two cannot disagree. It is the
    # reading half of the `agentdocs lookup` Toys tool (see {Lookup}), and
    # lives here for the same reason its siblings do: so the behavior is
    # testable and documented apart from the Toys DSL layer.
    #
    # Only {#concept_path}, {#read}, and {#sibling_fqns} touch the
    # filesystem. Everything else takes a file's content as a string, so the
    # structural edge cases that matter — a concept with no `## Member
    # Summary`, one whose docstring contains its own `## ` heading — can be
    # exercised directly rather than through a fixture that happens to have
    # the right shape.
    #
    # ### Why headings are matched by line prefix alone
    #
    # Nothing here tracks fenced code blocks, and that is deliberate rather
    # than an omission. Measured across the 7,472 class/module files in a
    # 117-bundle local corpus, no `## ` or `### ` line inside a closed fence
    # was ever anything but the document's own structure — there are zero
    # real cases to defend against. Meanwhile 57 files *would* be misread by
    # a fence tracker: 47 contain generated markdown whose stray backticks
    # open a fence that swallows the rest of the document, and 10 have
    # genuinely unbalanced fences. Line-prefix matching is correct on all
    # 7,472; fence tracking is correct on 7,415.
    #
    # `# ` is the exception, and is never used as a boundary: Ruby comments
    # inside `@example` blocks (`# good`, `# bad`) match it thousands of
    # times over. {#head} finds the one H1 by looking only above the first
    # `## `/`### `, where no example can reach.
    #
    # What a fence tracker *would* have caught is caught more cheaply by
    # holding `### ` lines to the heading grammar itself: a member name never
    # contains a space, so a prose heading in an example (`### Environment
    # variables`) is not mistaken for one. The residue — a single-word prose
    # heading inside an example, which would truncate a member section early
    # — has no instance anywhere in the corpus, and degrades to a short
    # answer rather than a wrong one.
    #
    class BundleReader
      ##
      # The file extension every Concept in a bundle has.
      #
      CONCEPT_EXTENSION = ".md"

      ##
      # The `## ` section that every class or module file carries when it
      # documents any member at all, and the point the default lookup of a
      # whole Concept reads up to.
      #
      MEMBER_SUMMARY_SECTION = "Member Summary"

      ##
      # The files in a bundle that document the bundle itself rather than a
      # class or module, and so are never Concepts a lookup can name.
      #
      NON_CONCEPT_FILES = ["index.md", "bundle.md"].freeze

      ##
      # The filename prefix marking a Guide — a rendered prose document
      # rather than a class or module.
      #
      GUIDE_PREFIX = "file."

      ##
      # A single segment of a fully qualified name: a Ruby constant name.
      # Applied to every segment before any path is built from it, so a name
      # carrying `..` or a separator can never address a file outside the
      # bundle.
      #
      FQN_SEGMENT = /\A[A-Za-z_][A-Za-z0-9_]*\z/

      ##
      # One `**Inherited from**` / `**Included from**` / `**Extended from**`
      # line of a `## Member Summary`, which names a type, links to its
      # Concept, and lists the members it contributes. These lines are never
      # wrapped, however long the member list gets, so one line is one entry.
      #
      INHERITED_LINE =
        /\A- \*\*(Inherited|Included|Extended) from \[`([^`]+)`\]\(([^)]+)\):\*\*(.*)\z/

      ##
      # @param bundle_dir [String] the root of the bundle to read
      #
      def initialize(bundle_dir)
        @bundle_dir = ::File.expand_path(bundle_dir)
        @children = {}
      end

      ##
      # @return [String] the absolute path of the bundle being read
      #
      attr_reader :bundle_dir

      ##
      # Whether there is a bundle here to read. An empty directory counts as
      # no bundle: {GemBuilder} publishes a build by renaming a finished tree
      # into place, so an empty directory at that path is never a bundle in
      # progress — only debris a lookup should offer to replace.
      #
      # @return [Boolean]
      #
      def exist?
        ::File.directory?(bundle_dir) && !::Dir.empty?(bundle_dir)
      end

      ##
      # The bundle-relative path of a class or module's Concept, or nil if
      # the bundle has no such file.
      #
      # The name is resolved against the directory's actual entries rather
      # than with `File.exist?`, because a case-insensitive filesystem would
      # otherwise answer a lookup of `Geometry::point` with `Point.md` — a
      # match that silently would not reproduce on a case-sensitive one.
      #
      # @param fqn [String] a fully qualified class or module name
      # @return [String, nil] the path relative to {#bundle_dir}
      #
      def concept_path(fqn)
        segments = fqn.to_s.split("::", -1)
        return nil if segments.empty?
        return nil unless segments.all? { |segment| segment.match?(FQN_SEGMENT) }
        relative = "#{segments.join('/')}#{CONCEPT_EXTENSION}"
        entries(::File.dirname(relative)).include?(::File.basename(relative)) ? relative : nil
      end

      ##
      # @param relative_path [String] a path returned by {#concept_path}
      # @return [String] the file's contents
      #
      def read(relative_path)
        ::File.read(::File.join(bundle_dir, relative_path))
      end

      ##
      # The fully qualified names of the Concepts alongside a name in its own
      # namespace, which is what a lookup of a name that isn't there has to
      # offer instead. Nested namespaces are included; Guides, `index.md`,
      # and `bundle.md` are not, since none of them is a name a lookup can
      # ask for.
      #
      # @param fqn [String] a fully qualified class or module name, which
      #   need not exist
      # @return [Array<String>] the sibling names, sorted
      #
      def sibling_fqns(fqn)
        segments = fqn.to_s.split("::", -1)
        return [] unless segments.all? { |segment| segment.match?(FQN_SEGMENT) }
        namespace = segments[0...-1]
        prefix = namespace.empty? ? "" : "#{namespace.join('::')}::"
        entries(namespace.empty? ? "." : namespace.join("/"))
          .select { |entry| concept_file?(entry) }
          .map { |entry| "#{prefix}#{::File.basename(entry, CONCEPT_EXTENSION)}" }
          .sort
      end

      ##
      # A Concept's identifying head: its `# class Foo::Bar` line, the `- `
      # bullets under it naming its superclass, mixins, and source file, and
      # the `* ` flags after those — `Deprecated.`, `Private API.`,
      # `Abstract.`, `Note:`, `Since:`. This is what a single member section
      # is presented with, so a method is never shown without saying what it
      # belongs to, and never shown as current when the whole type it belongs
      # to is deprecated or private.
      #
      # It stops at the class docstring, and the marker is what tells the two
      # apart: everything above the docstring is a bullet, and no concept in
      # the corpus opens its docstring with one. Items are sliced out of the
      # file rather than reassembled, so the blank line that separates the
      # `- ` block from the `* ` block — which is what keeps them rendering as
      # two lists rather than one — survives verbatim.
      #
      # @param content [String] a Concept's contents
      # @return [String, nil] the head, or nil if the file has no H1
      #
      def head(content)
        lines = content.lines
        limit = lines.index { |line| section_boundary?(line) } || lines.length
        start = (0...limit).find { |index| lines[index].start_with?("# ") }
        return nil unless start
        join_section(lines[start...head_end(lines, start + 1, limit)])
      end

      ##
      # One member's `### ` section, ending at the next `### ` or `## `
      # heading or at the end of the file.
      #
      # @param content [String] a Concept's contents
      # @param member [String] the member name exactly as its heading spells
      #   it — `#name` for an instance member, `.name` for a class method,
      #   the bare name for a constant
      # @return [String, nil] the section, or nil if the Concept has no such
      #   heading
      #
      def member_section(content, member)
        lines = content.lines
        start = lines.index { |line| member_heading(line) == member }
        return nil unless start
        finish = start + 1
        finish += 1 while finish < lines.length && !section_boundary?(lines[finish])
        join_section(lines[start...finish])
      end

      ##
      # A Concept read down to the end of its `## Member Summary` — enough to
      # say what the class or module is for and what it defines, without the
      # per-member detail that an agent still orienting has no use for.
      #
      # The delimiter is the first `## ` heading *following* Member Summary,
      # not the first `## ` in the file: a handful of gems write their own
      # `## ` headings in a class docstring, which land above Member Summary
      # and would otherwise cut the file off before it says anything. A
      # Concept with no Member Summary at all — a bare error subclass, say —
      # is returned whole, and so is one whose Member Summary is last,
      # documenting only inherited members.
      #
      # @param content [String] a Concept's contents
      # @return [String] the summary portion, or the whole file
      #
      def summary(content)
        lines = content.lines
        start = lines.index { |line| section_heading(line) == MEMBER_SUMMARY_SECTION }
        return content unless start
        finish = start + 1
        finish += 1 while finish < lines.length && !lines[finish].start_with?("## ")
        join_section(lines[0...finish])
      end

      ##
      # Every member a Concept documents in its own right, in the order the
      # file defines them. Inherited and mixed-in members are not here; they
      # are named only, in {#inherited_sources}.
      #
      # @param content [String] a Concept's contents
      # @return [Array<String>] the member names, as their headings spell
      #   them
      #
      def member_names(content)
        content.lines.filter_map { |line| member_heading(line) }
      end

      ##
      # Where a member a Concept doesn't define itself comes from, read off
      # the names-only list in its `## Member Summary`. One hop only, which
      # is all the format records — but an exact hop, so a lookup that misses
      # can say which file to read next instead of guessing.
      #
      # @param content [String] a Concept's contents
      # @param member [String] the member name being looked for
      # @return [Array<Array(String, String, String)>] one triple per source
      #   contributing that member: the relation (`Inherited`, `Included`, or
      #   `Extended`), the type's name, and the bundle-relative-ish link to
      #   its Concept exactly as the file writes it
      #
      def inherited_sources(content, member)
        content.lines.filter_map do |line|
          match = INHERITED_LINE.match(line.chomp)
          next nil unless match
          next nil unless match[4].scan(/`([^`]+)`/).flatten.include?(member)
          [match[1], match[2], match[3]]
        end
      end

      private

      # The entries of one directory inside the bundle, memoized because a
      # single lookup asks about the same directory several times over.
      # A directory that isn't there reads as empty rather than raising: the
      # caller's question is "is this name here", and "there is no such
      # namespace" is a no like any other.
      def entries(relative_dir)
        @children[relative_dir] ||=
          begin
            dir = relative_dir == "." ? bundle_dir : ::File.join(bundle_dir, relative_dir)
            ::Dir.children(dir)
          rescue ::SystemCallError
            []
          end
      end

      # The index just past the last bullet item below a Concept's heading.
      #
      # An item is its own line plus any indented continuation lines, since a
      # long `**Includes:**` list or a multi-line `**Deprecated.**` note wraps
      # like any other bullet. Blank lines between items are stepped over and
      # kept, and the first line that is neither blank nor a bullet ends the
      # head — that line is the docstring.
      def head_end(lines, index, limit)
        finish = index
        loop do
          index += 1 while index < limit && lines[index].strip.empty?
          break if index >= limit || !lines[index].start_with?("- ", "* ")
          index += 1
          index += 1 while index < limit && !lines[index].strip.empty? &&
                           lines[index].start_with?(" ")
          finish = index
        end
        finish
      end

      def concept_file?(entry)
        entry.end_with?(CONCEPT_EXTENSION) &&
          !entry.start_with?(GUIDE_PREFIX) &&
          !NON_CONCEPT_FILES.include?(entry)
      end

      # The member a `### ` line names, or nil for any other line.
      #
      # The heading grammar is exact — the marker, one space, and the name,
      # with nothing after it — so the name is the rest of the line, and a
      # `### ` line carrying whitespace is not a member heading at all. That
      # last part is not pedantry: across 16,971 distinct member headings in
      # the corpus, not one contains a space, while the `### ` lines that do
      # turn up inside `@example` blocks are prose headings (`### Environment
      # variables`). Rejecting them is the cheap half of what fence tracking
      # would have bought, without its failure mode.
      def member_heading(line)
        return nil unless line.start_with?("### ")
        name = line[4..].strip
        name.empty? || name.match?(/\s/) ? nil : name
      end

      def section_heading(line)
        line.start_with?("## ") ? line[3..].strip : nil
      end

      # Whether a line ends the section above it: any `## ` heading, or a
      # `### ` line that is actually a member heading. `# ` is never a
      # boundary — see this class's own note on why.
      def section_boundary?(line)
        line.start_with?("## ") || !member_heading(line).nil?
      end

      # Joins extracted lines into a block with exactly one trailing newline,
      # so callers can stack blocks without counting the blank lines that
      # happened to precede the next heading.
      def join_section(lines)
        "#{lines.join.rstrip}\n"
      end
    end
  end
end
