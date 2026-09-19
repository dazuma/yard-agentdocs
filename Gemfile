# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# Not used directly: YARD requires `irb/notifier` from its legacy lexer when
# it parses an `@overload` signature, and irb stopped being a default gem in
# Ruby 4.0. Declaring it here keeps that out-of-bundle warning out of every
# `toys test` run.
gem "irb"
gem "minitest", "~> 6.0", ">= 6.0.1"
gem "minitest-focus", "~> 1.4", ">= 1.4.1"
gem "minitest-rg", "~> 5.4"
gem "rubocop", "~> 1.82", ">= 1.82.1"
