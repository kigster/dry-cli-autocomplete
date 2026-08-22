# frozen_string_literal: true

require "dry/cli"
require_relative "autocomplete/version"

module Dry
  class CLI
    # Generates static shell completion scripts from a Dry::CLI registry.
    #
    # The generator reads the registry and never forces anything beyond it:
    # commands, subcommands, options, their declared enum values, and which
    # arguments look like file paths. Nothing it produces requires loading a
    # host's data, because the script is regenerated on every shell start via
    # `eval "$(mycli completion bash)"` and a slow generator is a slow shell.
    module Autocomplete
      class Error < StandardError; end
    end
  end
end
