# frozen_string_literal: true

##
# Builds a greeting string. Written in *RDoc* markup instead of
# Markdown, to exercise the +rdoc+ dialect of the "Docstring markup
# dialect" decision. See the {RDoc markup
# reference}[https://ruby.github.io/rdoc/RDoc/Markup.html] for the full
# grammar. Also proves inline cross-reference resolution runs after RDoc
# conversion: this paragraph's bare {Greeter#greet} reference resolves,
# but renders as a plain, unlinked name — a same-file self-reference.
#
# = Heading demotion
#
# Also proves a prose-embedded RDoc heading is demoted below the heading
# levels this format's own file structure reserves, so it can never
# collide with a real member heading.
#
class Greeter
  ##
  # Greets +name+, wrapping it in _emphasis_.
  #
  # @param name [String] the +name+ to greet
  # @return [String] the greeting, with +name+ emphasized
  #
  def greet(name)
    "Hello, #{name}!"
  end
end
