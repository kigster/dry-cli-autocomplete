# frozen_string_literal: true

module Dry
  # Reopened rather than defined: dry-cli declares `class CLI`, not a module,
  # and getting that wrong raises TypeError the moment both are loaded.
  #
  # Declared here without requiring dry-cli, because the gemspec loads this
  # file at build time when the dependency may not be installed. dry-cli's CLI
  # inherits from Object, so an empty reopening is compatible either way.
  class CLI
    module Autocomplete
      VERSION = "0.1.2"
    end
  end
end
