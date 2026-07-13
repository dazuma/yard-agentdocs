# frozen_string_literal: true

##
# Builds a greeting string. Written in *RDoc* markup instead of
# Markdown, to exercise the +rdoc+ dialect of the "Docstring markup
# dialect" decision. See the {RDoc markup
# reference}[https://ruby.github.io/rdoc/RDoc/Markup.html] for the full
# grammar, and note this paragraph's bare {Greeter#greet} reference is
# left unresolved for now (a separate, not-yet-built checklist item).
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
