# frozen_string_literal: true

module Dry
  class CLI
    module Autocomplete
      # Answers one TAB at runtime: given the words of a partial command line,
      # the words that may come next.
      #
      # This is what dynamic completion runs instead of a script generated in
      # advance, so it sees every command the program has registered by the
      # time it runs, including ones registered after a script was generated.
      # It reads the registry only through `Dry::CLI::Tree`, and finds the
      # command the words lead to by the same rules the CLI uses to run one.
      class Resolver
        # The line printed after the candidates when the word being completed
        # may be a file name. The shell script turns it into file completion.
        FILES = ":files"

        # What may come next: candidate words, and whether file names may too.
        Result = ::Data.define(:candidates, :files)

        # @param tree [Dry::CLI::Tree::Node] the root of the program's commands
        # @param words [Array<String>] the words after the program name, the
        #   last one being the word under the cursor, possibly empty
        # @return [Result]
        def self.call(tree, words)
          new(tree, words).call
        end

        # @param tree [Dry::CLI::Tree::Node]
        # @param words [Array<String>]
        def initialize(tree, words)
          @tree = tree
          @current = words.last.to_s
          @before = words[0...-1] || []
        end

        # @return [Result]
        def call
          node, = tree.resolve(before)
          option = value_option(node)
          return value_result(option) if option

          Result.new(candidates: matching(words_for(node)), files: node.arguments.any? { file?(it) })
        end

        private

        attr_reader :tree, :current, :before

        # The option whose value the cursor is on: the word before it names an
        # option that takes a value.
        def value_option(node)
          previous = before.last
          node.options.find { !it.boolean? && !it.flag? && it.switches.include?(previous) }
        end

        # An option declaring its values is completed from them; any other
        # value may be anything, so file names are the most useful guess.
        def value_result(option)
          Result.new(candidates: matching(option.values || []), files: option.values.nil?)
        end

        # Subcommands, the node's switches, and the values its arguments
        # declare, as the static script offers.
        def words_for(node)
          node.children(hidden: false).map(&:name) +
            node.options.flat_map(&:switches) +
            node.arguments.flat_map { it.values || [] }
        end

        def matching(words)
          words.select { it.start_with?(current) }.uniq
        end

        # Mirrors SpecBuilder: an explicit `file:` wins, and otherwise the
        # argument's name decides.
        def file?(argument)
          explicit = argument.metadata[:file]
          return !!explicit unless explicit.nil?

          argument.name.to_s.match?(/file|path/i)
        end
      end
    end
  end
end
