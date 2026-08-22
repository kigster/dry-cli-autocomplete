# frozen_string_literal: true

require "dry/cli"

module Dry
  class CLI
    module Autocomplete
      # The command a host registers to expose `mycli completion <shell>`.
      #
      # This file defines the command class and nothing else. It loads no
      # spec builder and no emitter, and it must stay that way: a host pays
      # for whatever this require pulls on *every* invocation, while the
      # command itself runs about once per shell. The generator is required
      # inside #call, where the cost is actually incurred. See
      # SPECIFICATION.md §1.3 and §2.4, and the spec that pins it.
      class Command < Dry::CLI::Command
        SHELLS = %w[bash zsh].freeze

        # Binds the command to a registry, and optionally to the name the
        # host is installed as. Without one, the program name is taken from
        # $PROGRAM_NAME at call time rather than at registration, since a
        # gem may be required long before anyone knows how it was invoked.
        #
        #   register "completion", Dry::CLI::Autocomplete::Command[MyCLI]
        def self.[](registry, program_name: nil)
          Class.new(self) do
            @registry = registry
            @program_name = program_name
          end
        end

        class << self
          attr_reader :registry, :program_name
        end

        desc "Print a shell completion script"

        argument :shell, required: true, values: SHELLS,
          desc: "Shell to generate completions for"

        example [
          "bash > /usr/local/etc/bash_completion.d/#{File.basename($PROGRAM_NAME)}",
          "zsh  > \"${fpath[1]}/_#{File.basename($PROGRAM_NAME)}\""
        ]

        def call(shell:, **)
          require_relative "spec_builder"
          require_relative "emitters/#{shell}"

          spec = SpecBuilder.call(registry, program_name: program_name)
          out.puts emitter_for(shell).call(spec)
        end

        private

        def registry
          self.class.registry or
            raise ArgumentError, "no registry bound: register Dry::CLI::Autocomplete::Command[MyCLI]"
        end

        def program_name
          self.class.program_name || File.basename($PROGRAM_NAME)
        end

        def emitter_for(shell)
          Emitters.const_get(shell.capitalize)
        end

        # Overridable so specs can capture output without reaching for $stdout.
        def out = $stdout
      end
    end
  end
end
