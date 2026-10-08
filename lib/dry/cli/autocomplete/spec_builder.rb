# frozen_string_literal: true

module Dry
  class CLI
    module Autocomplete
      # Walks a Dry::CLI registry through its public API and returns a
      # shell-agnostic description of every completion: one CompletionSpec
      # carrying one Node per reachable, non-hidden command or group.
      #
      # Touches nothing beyond the registry and the command classes it
      # already holds, so it stays cheap enough to run on every shell start.
      # See docs/SPECIFICATION.md §2.2 and §2.3.
      class SpecBuilder
        # `::Data`, with the leading colons, and never a bare `Data`. This file
        # is lexically inside `module Dry`, so an unqualified constant is looked
        # up there first: a bare `Struct` here meant `Dry::Struct` in any host
        # that had dry-struct loaded, which took different arguments and broke
        # on the host's machine while this gem's own suite stayed green. No
        # `Dry::Data` exists today, but the same trap is one released gem away,
        # and dry_struct_host_spec.rb is what keeps watch.
        #
        # Data rather than Struct because these are descriptions, built once and
        # rendered: frozen is what they should be, a missing field raises rather
        # than arriving as a silent nil, and `:values` stops colliding with a
        # method Struct defines and Data does not.
        CompletionSpec = ::Data.define(:program_name, :nodes)
        Node = ::Data.define(:path, :desc, :options, :arguments, :children)
        # `long`, `negation` and `alias_flags` are spelled the way dry-cli
        # 1.4.1 spells them in Option#parser_options and #alias_names, so
        # both emitters offer exactly what the parser accepts. `flag` is a
        # `type: :flag` option: like a boolean it takes no value, but dry-cli
        # gives it no `--no-` form.
        OptionSpec = ::Data.define(
          :name, :type, :values, :aliases, :default, :desc, :required, :boolean, :array,
          :flag, :long, :negation, :alias_flags
        ) do
          # @return [Array<String>] every spelling: the long name, its `--no-`
          #   form for a boolean, then the aliases
          def flags = [long, negation, *alias_flags].compact
        end
        ArgumentSpec = ::Data.define(:name, :values, :desc, :required, :file)

        # A bare heuristic, used only when a host does not declare `file:`
        # explicitly on the argument. See docs/SPECIFICATION.md §4.3.
        FILE_ARGUMENT_HEURISTIC = /file|path/i

        def self.call(registry, program_name:)
          new(registry, program_name).call
        end

        def initialize(registry, program_name)
          @registry = registry
          @program_name = program_name
        end

        def call
          CompletionSpec.new(program_name: program_name, nodes: walk([]))
        end

        private

        attr_reader :registry, :program_name

        def walk(path, nodes = [])
          result = registry.get(path)
          visible = visible_children(result)

          nodes << build_node(path, result, visible)
          visible.each_key { |name| walk(path + [name], nodes) }
          nodes
        end

        def visible_children(result)
          result.children.reject { |_name, node| node.hidden }
        end

        def build_node(path, result, visible)
          command = result.command

          Node.new(
            path: path,
            desc: command&.description,
            options: command ? command.options.map { |option| build_option(option) } : [],
            arguments: command ? command.arguments.map { |argument| build_argument(argument) } : [],
            children: visible.keys
          )
        end

        def build_option(option)
          long = "--#{dasherize(option.name)}"
          OptionSpec.new(
            name: option.name.to_s, type: option.type, values: option.values,
            aliases: option.aliases, default: option.default, desc: option.options[:desc],
            required: option.required? || false, boolean: option.boolean?, array: option.array?,
            flag: option.respond_to?(:flag?) && option.flag?, long: long,
            negation: option.boolean? ? long.sub("--", "--no-") : nil,
            alias_flags: Array(option.aliases).map { |name| alias_flag(name) }.uniq
          )
        end

        # What Dry::CLI::Inflector.dasherize does, without depending on a
        # module dry-cli marks private: `dry_run` becomes `--dry-run` and `dryRun`
        # becomes `--dryrun`, as dry-cli registers them.
        def dasherize(name) = name.to_s.downcase.gsub(/[[:space:]_]/, "-")

        # One letter gets one dash and anything longer two, whatever the host
        # wrote: `"f"`, `"-f"` and `"--f"` all register as `-f`.
        def alias_flag(name)
          bare = name.to_s.sub(/\A-{1,2}/, "")
          bare.size == 1 ? "-#{bare}" : "--#{bare}"
        end

        def build_argument(argument)
          ArgumentSpec.new(
            name: argument.name.to_s, values: argument.values, desc: argument.options[:desc],
            required: argument.required? || false, file: file_argument?(argument)
          )
        end

        def file_argument?(argument)
          explicit = argument.options[:file]
          return !!explicit unless explicit.nil?

          argument.name.to_s.match?(FILE_ARGUMENT_HEURISTIC)
        end
      end
    end
  end
end
