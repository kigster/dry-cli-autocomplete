# frozen_string_literal: true

require "dry/cli"

module Dry
  class CLI
    module Autocomplete
      # The command a host registers to expose `mycli completion <shell>`.
      #
      # This file defines the command classes and nothing else. It loads no
      # spec builder, resolver or emitter, and it must stay that way: a host
      # pays for whatever this require pulls on *every* invocation, while the
      # command itself runs about once per shell. The generator is required
      # inside #call, where the cost is actually incurred. See
      # docs/SPECIFICATION.md §1.3 and §2.4, and the spec that pins it.
      class Command < Dry::CLI::Command
        SHELLS = %w[bash zsh].freeze

        # How the script completes:
        #
        # - static: every command, option and value is written into the
        #   script, so a TAB runs no Ruby. Commands registered after the
        #   script was generated are not completed until it is regenerated.
        # - dynamic: the script asks the program on every TAB, through the
        #   hidden `__complete` command, so it completes every command the
        #   program has when it runs, at the cost of starting it.
        # - hybrid: the static script, asking the program only when the
        #   command line leaves what it knows.
        MODES = %w[static dynamic hybrid].freeze

        # Binds the command to a registry, and optionally to the name the
        # host is installed as and the mode its script completes in. Without
        # a name, the program name is taken from $PROGRAM_NAME at call time
        # rather than at registration, since a gem may be required long
        # before anyone knows how it was invoked.
        #
        # Also registers the hidden `__complete` command the dynamic and
        # hybrid scripts call, so that a user can pick either with `--mode`.
        #
        #   register "completion", Dry::CLI::Autocomplete::Command[MyCLI]
        #   register "completion", Dry::CLI::Autocomplete::Command[MyCLI, mode: :hybrid]
        #
        # @param registry [Dry::CLI::Registry]
        # @param program_name [String, nil]
        # @param mode [Symbol, String] one of {MODES}
        # @return [Class] a subclass bound to the registry
        # @raise [ArgumentError] for a mode not in {MODES}
        def self.[](registry, program_name: nil, mode: :static)
          raise ArgumentError, "mode must be one of #{MODES.join(', ')}, got #{mode.inspect}" \
            unless MODES.include?(mode.to_s)

          Complete.install(registry)
          Class.new(self) do
            @registry = registry
            @program_name = program_name
            @mode = mode.to_s
          end
        end

        class << self
          # @return [Dry::CLI::Registry, nil]
          attr_reader :registry

          # @return [String, nil]
          attr_reader :program_name

          # @return [String] the mode a script completes in unless `--mode` says otherwise
          def mode = @mode || "static"
        end

        desc "Print a shell completion script"

        argument :shell, required: true, values: SHELLS, desc: "Shell to generate completions for"
        option :mode, values: MODES, desc: "How the script completes"

        example "bash > /usr/local/etc/bash_completion.d/#{File.basename($PROGRAM_NAME)}"
        example "zsh  > \"${fpath[1]}/_#{File.basename($PROGRAM_NAME)}\""
        example "bash --mode=dynamic", "complete commands registered at runtime too"

        # @param shell [String] one of {SHELLS}
        # @param mode [String, nil] one of {MODES}; the bound mode when nil
        def call(shell:, mode: nil, **)
          require_relative "spec_builder"
          require_relative "emitters/#{shell}"
          require_relative "emitters/#{shell}_dynamic"

          spec = SpecBuilder.call(registry, program_name: program_name)
          stdout.puts script(shell, mode || self.class.mode, spec)
        end

        private

        def registry
          self.class.registry or
            raise ArgumentError, "no registry bound: register Dry::CLI::Autocomplete::Command[MyCLI]"
        end

        def program_name
          self.class.program_name || File.basename($PROGRAM_NAME)
        end

        def script(shell, mode, spec)
          static = Emitters.const_get(shell.capitalize)
          dynamic = Emitters.const_get("#{shell.capitalize}Dynamic")

          case mode
          when "dynamic" then dynamic.call(spec)
          when "hybrid" then static.call(spec, fallback: dynamic)
          else static.call(spec)
          end
        end
      end

      # The hidden command the dynamic and hybrid scripts call on a TAB:
      # `mycli __complete -- <words>` prints the words that may come next,
      # one per line, then {Resolver::FILES} when file names may come next.
      #
      # Registered by {Command.[]}; a host does not register it itself.
      class Complete < Dry::CLI::Command
        # The name it is registered under.
        NAME = "__complete"

        # Registers the command in a registry that does not have it yet.
        #
        # @param registry [Dry::CLI::Registry]
        # @return [void]
        def self.install(registry)
          return if registry.tree[NAME]

          registry.register(NAME, self[registry], hidden: true)
        end

        # @param registry [Dry::CLI::Registry]
        # @return [Class] a subclass bound to the registry
        def self.[](registry)
          Class.new(self) { @registry = registry }
        end

        class << self
          # @return [Dry::CLI::Registry, nil]
          attr_reader :registry
        end

        desc "Print what may come next on a command line, for shell completion"

        argument :words, type: :array, desc: "The words after the program name, the last being completed"

        # @param words [Array<String>]
        def call(words: [], **)
          require_relative "resolver"

          result = Resolver.call(self.class.registry.tree, words)
          result.candidates.each { stdout.puts(it) }
          stdout.puts(Resolver::FILES) if result.files
        end
      end
    end
  end
end
