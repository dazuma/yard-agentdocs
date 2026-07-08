# frozen_string_literal: true

module YARD
  module AgentDocs
    ##
    # Mixin that gives a YARD template `-%>`/`<%-` ERB trim-mode support.
    #
    # YARD only passes `trim_mode: '-'` to `ERB.new` for its own built-in
    # `:text` format; a custom format like `agentdocs` otherwise gets
    # untrimmed ERB, so a `<% if %>`/`<% end %>` pair's surrounding
    # whitespace leaks into the output regardless of whether the branch
    # produced anything. Including this module in a template's `setup.rb`
    # overrides `YARD::Templates::Template#erb_with` (the method `#erb`/
    # `#superb` both call to build the `ERB` instance) so `.erb` files can
    # opt in to trimming with explicit `<%- -%>` markers where needed.
    #
    module ErbWithTrimMode
      ##
      # @param content [String] the ERB template source
      # @param filename [String, nil] the template's filename, for backtraces
      # @return [::ERB] an ERB instance with trim mode enabled
      #
      def erb_with(content, filename = nil)
        erb = ::ERB.new(content, trim_mode: "-")
        erb.filename = filename if filename
        erb
      end
    end
  end
end
