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
      # See SPECIFICATION.md §2.2 and §2.3.
      class SpecBuilder
        CompletionSpec = Struct.new(:program_name, :nodes, keyword_init: true)
        Node = Struct.new(:path, :options, :arguments, :children, keyword_init: true)

        # :values shadows Struct#values by design: it is the field name the
        # interface contract in .plans/001.00-*/plan.md fixes for emitters.
        # rubocop:disable Lint/StructNewOverride
        OptionSpec = Struct.new(
          :name, :type, :values, :aliases, :default, :desc, :required, :boolean, :array,
          keyword_init: true
        )
        ArgumentSpec = Struct.new(:name, :values, :desc, :required, :file, keyword_init: true)
        # rubocop:enable Lint/StructNewOverride

        # A bare heuristic, used only when a host does not declare `file:`
        # explicitly on the argument. See SPECIFICATION.md §4.3.
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
            options: command ? command.options.map { |option| build_option(option) } : [],
            arguments: command ? command.arguments.map { |argument| build_argument(argument) } : [],
            children: visible.keys
          )
        end

        def build_option(option)
          OptionSpec.new(
            name: option.name.to_s, type: option.type, values: option.values,
            aliases: option.aliases, default: option.default, desc: option.options[:desc],
            required: option.required? || false, boolean: option.boolean?, array: option.array?
          )
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
