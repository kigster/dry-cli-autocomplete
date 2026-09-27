# frozen_string_literal: true

module Dry
  class CLI
    module Autocomplete
      # Walks a Dry::CLI command tree and returns a shell-agnostic
      # description of every completion: one CompletionSpec carrying one Node
      # per reachable, non-hidden command or group.
      #
      # Reads the registry only through `Dry::CLI::Tree`, dry-cli's public view
      # of it, so it stays cheap enough to run on every shell start and does
      # not break when dry-cli changes how it stores commands.
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
        OptionSpec = ::Data.define(
          :name, :type, :values, :aliases, :default, :desc, :required, :boolean, :array
        )
        ArgumentSpec = ::Data.define(:name, :values, :desc, :required, :file)

        # A bare heuristic, used only when a host does not declare `file:`
        # explicitly on the argument. See docs/SPECIFICATION.md §4.3.
        FILE_ARGUMENT_HEURISTIC = /file|path/i

        # @param registry [Dry::CLI::Registry, Dry::CLI::Tree::Node] a registry, or the tree to walk
        # @param program_name [String]
        # @return [CompletionSpec]
        def self.call(registry, program_name:)
          new(registry, program_name).call
        end

        # @param registry [Dry::CLI::Registry, Dry::CLI::Tree::Node]
        # @param program_name [String]
        def initialize(registry, program_name)
          @tree = registry.respond_to?(:tree) ? registry.tree : registry
          @program_name = program_name
        end

        # @return [CompletionSpec]
        def call
          CompletionSpec.new(program_name: program_name, nodes: tree.walk(hidden: false).map { build_node(it) })
        end

        private

        attr_reader :tree, :program_name

        def build_node(node)
          Node.new(
            path: node.path,
            desc: node.description,
            options: node.options.map { |option| build_option(option) },
            arguments: node.arguments.map { |argument| build_argument(argument) },
            children: node.children(hidden: false).map(&:name)
          )
        end

        def build_option(option)
          OptionSpec.new(
            name: option.name.to_s, type: option.type, values: option.values,
            aliases: option.aliases, default: option.default, desc: option.desc,
            required: option.required?, boolean: option.boolean?, array: option.array?
          )
        end

        def build_argument(argument)
          ArgumentSpec.new(
            name: argument.name.to_s, values: argument.values, desc: argument.desc,
            required: argument.required?, file: file_argument?(argument)
          )
        end

        def file_argument?(argument)
          explicit = argument.metadata[:file]
          return !!explicit unless explicit.nil?

          argument.name.to_s.match?(FILE_ARGUMENT_HEURISTIC)
        end
      end
    end
  end
end
