# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in dry-cli-autocomplete.gemspec
gemspec

group :development, :test do
  gem "coverage-badge"
  gem "irb"
  gem "rake", "~> 13.0"
  gem "rspec", "~> 3.0"
  gem "rspec-its"
  gem "rubocop"
  gem "simplecov"
  gem "yard"
end

# Not a dependency, a collision test. This gem's files sit inside `module Dry`,
# so an unqualified constant resolves there first and a bare `Struct` becomes
# `Dry::Struct` in any host that loads it. Most dry-rb applications do.
gem "dry-struct", require: false
