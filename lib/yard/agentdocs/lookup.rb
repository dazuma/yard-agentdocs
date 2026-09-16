# frozen_string_literal: true

module YARD
  module AgentDocs
    ##
    # Answers one API lookup against a gem's bundle, returning the single
    # member or concept asked for. This is the implementation behind the
    # `agentdocs lookup` Toys tool shipped in this gem's `toys/` directory
    # (see `toys/agentdocs/lookup.rb`); as with its siblings, it lives here
    # so the behavior is testable and documented independently of the Toys
    # DSL layer.
    #
    # It composes {BundleLocator} (which version, installed where, and the
    # bundle built if it isn't there yet) with {BundleReader} (find the one
    # file, cut out the one section).
    #
    # ### What this is for
    #
    # Looking a method up in a bundle is a mechanical procedure — resolve the
    # version, compute the path, derive the file name from the fully
    # qualified name, find the heading — and a prose instruction telling an
    # agent to perform it can only ever be restated, never enforced. "Never
    # read a different version's tree" is a hope in a document and an
    # invariant in code. That is the primary reason this exists; collapsing
    # three or four inference turns into one is the secondary one.
    #
    # It is an **accelerator, never a gateway**. Reading a bundle directly
    # with `grep` stays a first-class path, bundles stay portable to harnesses
    # with no Ruby runtime, and the format — not this class — is the contract.
    # A bug here degrades to "grep still works".
    #
    # For the same reason the body of an answer is reproduced *verbatim*.
    # Nothing rewrites `**Defined in:**` paths to absolute ones, however
    # convenient that would be: doing so would make this a transformer rather
    # than a reader, and `bundle.md` would stop describing what the agent
    # actually sees.
    #
    # ### Talking to an agent, not to a shell
    #
    # An LLM caller reads stdout and mostly ignores `$?`, so every failure's
    # *body* carries the next move — which file to read instead, which
    # command to run, where the gem's own source is. The exit codes exist for
    # scripting and to keep the cases distinct.
    #
    # A lookup that misses never quietly turns into a fuzzy one. Candidates
    # are offered, labelled as candidates; a guess that reads as an answer is
    # precisely the failure this class exists to remove.
    #
    class Lookup
      include ExitCodes

      ##
      # How many candidate member names a miss lists before eliding the rest.
      # A large class can document hundreds, and a wall of them buries the
      # part of the answer that says what to do next.
      #
      MAX_CANDIDATES = 60

      ##
      # The width candidate listings are packed to.
      #
      LINE_WIDTH = 78

      ##
      # One segment of a fully qualified name.
      #
      FQN_SEGMENT_PATTERN = /[A-Za-z_][A-Za-z0-9_]*/

      ##
      # A member name as a `### ` heading spells it, minus the sigil. Ruby
      # method names can be operators (`[]=`, `<=>`, `=~`) but never contain
      # `.` or `#`, which is what keeps the entity grammar unambiguous.
      #
      MEMBER_PATTERN = /[^\s.#]+/

      ##
      # The entity argument: a fully qualified class or module name,
      # optionally followed by `#` and an instance member or `.` and a class
      # method.
      #
      ENTITY =
        /\A(#{FQN_SEGMENT_PATTERN}(?:::#{FQN_SEGMENT_PATTERN})*)(?:([#.])(#{MEMBER_PATTERN}))?\z/

      ##
      # A lookup's answer: what to print, and what to exit with.
      #
      class Result
        ##
        # @param exit_code [Integer] one of the `EXIT_*` codes on {Lookup}
        # @param body [String] the text to write to standard output
        #
        def initialize(exit_code, body)
          @exit_code = exit_code
          @body = body.end_with?("\n") ? body : "#{body}\n"
        end

        ##
        # @return [Integer] the process exit code
        #
        attr_reader :exit_code

        ##
        # @return [String] the text to write to standard output, always
        #   ending in a newline
        #
        attr_reader :body

        ##
        # @return [Boolean] whether the lookup was answered
        #
        def success?
          exit_code == ExitCodes::EXIT_SUCCESS
        end
      end

      ##
      # @param gem_name [String] the gem to look the entity up in
      # @param entity [String] a fully qualified class or module name,
      #   optionally with a member: `Foo::Bar`, `Foo::Bar#baz`,
      #   `Foo::Bar.baz`, or `Foo::Bar::BAZ`
      # @param version [String, nil] the gem version to read, instead of the
      #   one the project's lockfile resolves
      # @param full [Boolean] whether to print the whole concept file rather
      #   than the default slice of it
      # @param build [Boolean] whether to build a missing bundle. Defaults to
      #   true; with false, a missing bundle is reported rather than built.
      # @param project_dir [String, nil] the directory the project is
      #   resolved from. Defaults to the current directory.
      # @param spec_dirs [Array<String>, nil] the directories to search for
      #   installed gem specifications, for tests and for embedders driving
      #   this class directly. Defaults to the resolver's own.
      # @param output_root [String, nil] the directory bundles live under.
      #   Defaults to {GemBuilder.default_output_root}.
      #
      def initialize(gem_name, entity, version: nil, full: false, build: true,
                     project_dir: nil, spec_dirs: nil, output_root: nil)
        @gem_name = gem_name.to_s
        @entity = entity.to_s
        @version = version&.to_s
        @full = full ? true : false
        @build = build ? true : false
        @locator = BundleLocator.new(@gem_name, version: @version, project_dir: project_dir,
                                                spec_dirs: spec_dirs, output_root: output_root)
      end

      ##
      # @return [String] the gem being looked up in
      #
      attr_reader :gem_name

      ##
      # @return [String] the entity being looked up, as given
      #
      attr_reader :entity

      ##
      # @return [String, nil] the version override, if any
      #
      attr_reader :version

      ##
      # @return [Boolean] whether the whole concept file is printed
      #
      attr_reader :full

      ##
      # @return [Boolean] whether a missing bundle is built
      #
      attr_reader :build

      ##
      # Performs the lookup, building the gem's bundle first if it has none
      # and building is allowed.
      #
      # Build progress is written to standard error rather than returned, so
      # the body stays exactly the documentation asked for.
      #
      # @return [Result]
      #
      def run
        concept_fqn, member = parse_entity
        return entity_usage_error if concept_fqn.nil?
        location = locator.locate(build: build)
        return unavailable(location) unless location.ready?
        answer(BundleReader.new(location.bundle_dir), location.resolution, concept_fqn, member)
      end

      private

      attr_reader :locator

      # Every reason there is no bundle to read, each rendered as the prose
      # this tool speaks. The statuses themselves carry no words: {Lookup}
      # explains itself on standard output, where an agent reads, and
      # {BundlePath} explains itself on standard error, where nothing can get
      # into a command substitution.
      def unavailable(location)
        resolution = location.resolution
        case location.status
        when :invalid_name then gem_name_usage_error
        when :no_release then no_release_body(resolution)
        when :not_installed then not_installed_body(resolution)
        when :missing then no_bundle_body(location.bundle_dir, resolution)
        else build_failed_body(location.bundle_dir, resolution)
        end
      end

      # Splits the entity argument into a concept name and, if one was given,
      # a member. Returns a nil name for anything that isn't an entity at all.
      def parse_entity
        match = ENTITY.match(entity)
        return [nil, nil] unless match
        [match[1], match[2] ? "#{match[2]}#{match[3]}" : nil]
      end

      # Both arguments are checked for shape before anything is resolved, so a
      # malformed request reads as the usage error it is rather than as a gem
      # or a name that couldn't be found.
      def gem_name_usage_error
        result(EXIT_USAGE, <<~TEXT)
          `#{gem_name}` is not a gem name.

          Expected the name of a gem this project depends on, such as `toys` or
          `rubocop`, followed by the entity to look up inside it.
        TEXT
      end

      def entity_usage_error
        result(EXIT_USAGE, <<~TEXT)
          `#{entity}` is not an entity.

          Expected a fully qualified class or module name, optionally with one member:
            Foo::Bar            the class or module itself
            Foo::Bar#baz        an instance method or attribute
            Foo::Bar.baz        a class method
            Foo::Bar::BAZ       a constant

          Operator method names collide with shell metacharacters, so quote the
          argument: 'Foo::Bar#[]=', 'Foo::Bar#<=>'.
        TEXT
      end

      def no_release_body(resolution)
        locked_in = ::File.basename(resolution.lockfile.to_s)
        next_step =
          if resolution.kind == :path
            "Read its source at that path instead."
          else
            "Read its source instead; `bundle show #{gem_name}` reports the checkout path."
          end
        result(EXIT_NO_RELEASE, <<~TEXT)
          `#{gem_name}` is a #{resolution.kind} dependency in #{locked_in}, so it has no
          released version, and no bundle is built for it.
            source: #{resolution.source}

          #{next_step}
        TEXT
      end

      def not_installed_body(resolution)
        lines = ["#{resolution.message}, so there is nothing to document."]
        unless resolution.installed_versions.empty?
          lines << "  installed versions: #{resolution.installed_versions.join(', ')}"
          lines << "  Pass --version to read one of those instead."
        end
        lines << ""
        lines << "Read the gem's own source instead, or install the gem and try again."
        result(EXIT_NOT_FOUND, lines.join("\n"))
      end

      def no_bundle_body(bundle_dir, resolution)
        result(EXIT_NOT_FOUND, <<~TEXT)
          No agentdocs bundle for #{gem_name} #{resolution.version}.
            expected at: #{bundle_dir}
            gem root:    #{resolution.spec.full_gem_path}

          --no-build was given, so nothing was built. To build it:
            #{BundleLocator::BUILD_COMMAND} #{gem_name}:#{resolution.version}
        TEXT
      end

      def build_failed_body(bundle_dir, resolution)
        result(EXIT_BUILD_FAILED, <<~TEXT)
          Failed to build the agentdocs bundle for #{gem_name} #{resolution.version}; see
          the messages on standard error above.
            expected at: #{bundle_dir}
            gem root:    #{resolution.spec.full_gem_path}

          Read the gem's own source at that gem root instead.
        TEXT
      end

      # Resolves the entity to a concept file and produces the answer.
      def answer(reader, resolution, concept_fqn, member)
        path = reader.concept_path(concept_fqn)
        return read_concept(reader, resolution, path, member) if path
        return no_concept_body(reader, resolution, concept_fqn) unless member.nil?
        as_constant(reader, resolution, concept_fqn)
      end

      # A name with no member and no file of its own, retried as a constant
      # of its own namespace: `Foo::Bar::BAZ` is how a constant is written,
      # and a bundle documents it inside `Foo/Bar.md`. The file is tried
      # first, so a nested class is never mistaken for a constant of its
      # parent.
      #
      # The constant's heading is confirmed before the retry is accepted,
      # rather than left to the section extraction that follows, because
      # `--full` prints a whole file without extracting anything — and
      # printing a namespace's whole file in answer to a constant that isn't
      # in it is exactly the plausible wrong answer this tool exists to
      # remove.
      def as_constant(reader, resolution, concept_fqn)
        segments = concept_fqn.split("::")
        parent = segments[0...-1].join("::")
        path = segments.length < 2 ? nil : reader.concept_path(parent)
        return no_concept_body(reader, resolution, concept_fqn) if path.nil?
        constant = segments[-1]
        content = reader.read(path)
        unless reader.member_names(content).include?(constant)
          return neither_body(reader, resolution, concept_fqn, content, path, constant)
        end
        read_concept(reader, resolution, path, constant)
      end

      def read_concept(reader, resolution, path, member)
        content = reader.read(path)
        body = body_for(reader, content, member)
        return member_miss_body(reader, resolution, content, path, member) if body.nil?
        result(EXIT_SUCCESS, "#{provenance(resolution, reader, path, member)}\n#{body}")
      end

      def body_for(reader, content, member)
        return content if full
        return reader.summary(content) if member.nil?
        section = reader.member_section(content, member)
        return nil if section.nil?
        head = reader.head(content)
        head ? "#{head}\n#{section}" : section
      end

      # The header naming what was read and where it came from. The version
      # invariant is otherwise enforced but invisible: an agent would receive
      # markdown with nothing in it saying which release it describes. The
      # gem root is free here — the spec is already resolved — and saves the
      # `bundle show` hop, since `**Defined in:**` paths are relative to it
      # and nothing inside a bundle records it.
      def provenance(resolution, reader, path, member)
        lines = ["**yard-agentdocs lookup:** `#{entity}`", ""]
        lines << "* **Gem:** `#{gem_name}` #{resolution.version}" \
                 " (#{resolution.version_origin_description})"
        lines << "* **Gem root:** `#{resolution.spec.full_gem_path}`"
        lines << "* **Bundle:** `#{reader.bundle_dir}`"
        lines << "* **Concept:** `#{path}`"
        lines << "* **Member:** `#{member}`" if member
        lines << ""
        lines << "---"
        "#{lines.join("\n")}\n"
      end

      def no_concept_body(reader, resolution, concept_fqn)
        lines = ["No concept file for `#{concept_fqn}` in this bundle.",
                 "  looked for: #{concept_file_path(concept_fqn)}",
                 "  bundle:     #{reader.bundle_dir}", ""]
        lines.concat(siblings_block(reader, concept_fqn))
        result(EXIT_NOT_FOUND, lines.concat(closing(reader, resolution)).join("\n"))
      end

      def member_miss_body(reader, resolution, content, path, member)
        lines = ["No `### #{member}` heading in `#{path}`.", ""]
        lines.concat(inherited_block(reader, content, member))
        lines.concat(candidate_block("Members defined in `#{path}`",
                                     reader.member_names(content)))
        result(EXIT_NOT_FOUND, lines.concat(closing(reader, resolution)).join("\n"))
      end

      # Both readings of a `Foo::Bar::BAZ` that resolved to neither. Saying
      # only one of them would misdescribe what was searched, and the two
      # readings have different candidate sets: a name meant as a class wants
      # its namespace's other classes, a name meant as a constant wants the
      # namespace's other members.
      def neither_body(reader, resolution, concept_fqn, content, path, constant)
        lines = ["Nothing found for `#{concept_fqn}`, read either way:",
                 "  as a class or module, no file  #{concept_file_path(concept_fqn)}",
                 "  as a constant, no heading      `### #{constant}` in `#{path}`",
                 "  bundle:                        #{reader.bundle_dir}", ""]
        lines.concat(inherited_block(reader, content, constant))
        lines.concat(siblings_block(reader, concept_fqn))
        lines.concat(candidate_block("Members defined in `#{path}`",
                                     reader.member_names(content)))
        result(EXIT_NOT_FOUND, lines.concat(closing(reader, resolution)).join("\n"))
      end

      def concept_file_path(concept_fqn)
        "#{concept_fqn.split('::').join('/')}#{BundleReader::CONCEPT_EXTENSION}"
      end

      def siblings_block(reader, concept_fqn)
        namespace = concept_fqn.split("::")[0...-1].join("::")
        label = namespace.empty? ? "Other concepts at the top level" : "Other concepts in `#{namespace}`"
        candidate_block(label, reader.sibling_fqns(concept_fqn) - [concept_fqn])
      end

      # Every miss ends the same way, because every miss has the same two
      # next moves and neither is "take one of the candidates".
      def closing(reader, resolution)
        ["Those are candidates, not an answer. If none of them is what you meant, try",
         "`grep -i <term> #{::File.join(reader.bundle_dir, 'index.md')}`, or read the gem's own",
         "source at #{resolution.spec.full_gem_path}."]
      end

      # The one hop a bundle does record: a member a concept doesn't define
      # itself, but names in its inherited-and-mixed-in list, together with
      # the file that does define it. Exact information the file already
      # carries, and the single most useful thing to say on a miss.
      def inherited_block(reader, content, member)
        sources = reader.inherited_sources(content, member)
        return [] if sources.empty?
        lines = ["`#{member}` is not defined here, but is listed as inherited or mixed in:"]
        sources.each do |(relation, type, link)|
          lines << "  #{relation.downcase} from #{type} — read #{link}"
        end
        lines << ""
        lines
      end

      def candidate_block(label, names)
        return ["#{label}: none.", ""] if names.empty?
        shown = names.first(MAX_CANDIDATES)
        lines = ["#{label} (#{names.length}):"]
        lines.concat(wrap_columns(shown))
        lines << "  ... and #{names.length - shown.length} more" if names.length > shown.length
        lines << ""
        lines
      end

      # Packs names two spaces apart into lines no wider than {LINE_WIDTH},
      # so a namespace of long fully qualified names doesn't come back as
      # four unreadable lines each hundreds of characters long.
      def wrap_columns(names)
        names.each_with_object([]) do |name, lines|
          if lines.empty? || lines.last.length + name.length + 2 > LINE_WIDTH
            lines << "  #{name}"
          else
            lines[-1] = "#{lines.last}  #{name}"
          end
        end
      end

      def result(exit_code, body)
        Result.new(exit_code, body)
      end
    end
  end
end
