# frozen_string_literal: true

##
# Exercises a constant alias that a signature file redeclares as a module.
#
# YARD's RBS handler records the constant alias itself as a mixin of
# +Host+, alongside the module that later replaces it. The
# +Includes+ and +Extends+ lines and the member roster must show
# +Filtering+ once, as the module, and must not fail on the stale
# constant. The shape comes from +OAuth2::FilteredAttributes+ in the
# +oauth2+ gem.
#
module AliasedMixin
  ##
  # Includes and extends the aliased mixin.
  #
  # Its Ruby +include+ and +extend+ run before the alias is assigned, as
  # in +oauth2+, where the including class lives in a file parsed first.
  #
  class Host
    include Filtering
    extend Filtering
  end

  ##
  # Overwritten by the signature file's module declaration of the same
  # name.
  #
  Filtering = Vendor::Filtering
end
