# frozen_string_literal: true

##
# Exercises RDoc::Markup::ToMarkdown's raw-HTML-leak bug.
#
# A character outside plain word characters or whitespace, inside any
# styled delimiter, converts to literal HTML instead of the equivalent
# Markdown span — see "RDoc::Markup::ToMarkdown raw-HTML leaks" under
# "Decisions" in devdocs/DESIGN.md. Covers the plain shorthand (+word+,
# `word`, *word*, _word_) and the HTML-ish tag form (<tt>, <code>, <b>,
# <i>, <em>, <s>, <del>) alike.
#
# Punctuated shorthand: +valid?+, +save!+, +name=+, +Foo::Bar+, `x[0]`,
# *bold?*, _em!_.
#
# Punctuated tag form: <tt>=~</tt>, <code>a.b</code>, <b>foo=~bar</b>,
# <i>a.b</i>, <em>foo!</em>, <s>strike!</s>, <del>del?</del>.
#
# Nested styled content — multiple inline nodes inside one styled tag,
# not just punctuated single-string content: <b>foo *bar* baz</b>,
# <em>foo <b>bar</b> baz</em>, <s>foo *bar* baz</s>. <tt>foo <b>bar</b>
# baz</tt> looks similar but isn't: RDoc's own parser captures tt/code
# content as one literal string, never nested nodes, so it already
# rendered correctly before this fix.
#
# A verbatim example — the literal angle-bracket text below must survive
# untouched, unlike the prose above:
#
#   example_code = "<code>literal</code>"
#   another_line <tt>also literal</tt>
#
class TagConversion
  ##
  # Returns whether the receiver is +valid?+.
  #
  # @return [Boolean] whether valid
  #
  def valid?
    true
  end

  ##
  # +save!+ persists the receiver, raising on failure.
  #
  # @return [void]
  #
  def save!
  end

  ##
  # Sets the receiver's +name=+.
  #
  # @param value [String] the new name
  #
  def name=(value)
    @name = value
  end
end
