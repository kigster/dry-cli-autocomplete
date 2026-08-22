# frozen_string_literal: true

require "dry/inflector"

module Dry
  class CLI
    module Autocomplete
      module Emitters
        # Turns a CompletionSpec into a bash `complete -F` script.
        # See SPECIFICATION.md §4.1: a static, case-statement walk over
        # COMP_WORDS resolves which node the cursor is under, then
        # `compgen -W` fills COMPREPLY from that node's children and
        # option flags, with `compgen -f` added where an argument is a
        # file (§4.3).
        #
        # Deliberately avoids bash associative arrays (bash 4+ only):
        # macOS still ships bash 3.2 as /bin/bash, and this script is
        # meant to be eval'd from exactly that.
        class Bash
          def self.call(spec)
            new(spec).call
          end

          def initialize(spec)
            @spec = spec
          end

          def call
            "#{body.join("\n")}\n"
          end

          private

          attr_reader :spec

          def body
            header_lines + path_walk_lines + word_lookup_lines + footer_lines
          end

          def header_lines
            [
              "#{function_name}() {",
              "  local cur path word next_path words i",
              "  COMPREPLY=()",
              '  cur="${COMP_WORDS[COMP_CWORD]}"',
              '  path=""',
              "  i=1"
            ]
          end

          def path_walk_lines
            path_walk_open_lines + path_walk_close_lines
          end

          def path_walk_open_lines
            lines = [
              '  while [ "$i" -lt "$COMP_CWORD" ]; do',
              '    word="${COMP_WORDS[$i]}"',
              '    next_path=""',
              '    case "$path:$word" in'
            ]
            edge_arms.each { |arm| lines << "      #{arm}" }
            lines << "    esac"
          end

          def path_walk_close_lines
            [
              '    if [ -z "$next_path" ]; then',
              "      break",
              "    fi",
              '    path="$next_path"',
              "    i=$((i + 1))",
              "  done",
              ""
            ]
          end

          def word_lookup_lines
            lines = ['  words=""', '  case "$path" in']
            word_arms.each { |arm| lines << "    #{arm}" }
            lines + ["  esac", ""]
          end

          def footer_lines
            [
              '  COMPREPLY=($(compgen -W "$words" -- "$cur"))',
              *file_completion_lines,
              "}",
              "complete -F #{function_name} #{spec.program_name}"
            ]
          end

          def function_name = "_#{shell_identifier}_completions"

          # A program installed as `my-tool` cannot name a shell function
          # directly. See SPECIFICATION.md §4.2.
          def shell_identifier
            Dry::Inflector.new.underscore(spec.program_name.to_s).gsub(/[^A-Za-z0-9_]/, "_")
          end

          def path_key(path) = path.join(" ")

          def edge_arms
            spec.nodes.flat_map do |node|
              parent_key = path_key(node.path)
              node.children.map do |child|
                child_key = path_key(node.path + [child])
                "\"#{quote(parent_key)}:#{quote(child)}\") next_path=\"#{quote(child_key)}\" ;;"
              end
            end
          end

          def word_arms
            spec.nodes.filter_map do |node|
              words = node_words(node)
              next if words.empty?

              "\"#{quote(path_key(node.path))}\") words=\"#{quote(words.join(" "))}\" ;;"
            end
          end

          def node_words(node)
            node.children + node.options.flat_map { |option| option_words(option) }
          end

          def option_words(option) = ["--#{option.name}"] + Array(option.aliases)

          def file_completion_lines
            paths = spec.nodes.select { |node| node.arguments.any?(&:file) }.map { |node| path_key(node.path) }
            return [] if paths.empty?

            lines = ['  case "$path" in']
            paths.each do |key|
              lines << "    \"#{quote(key)}\") COMPREPLY+=($(compgen -f -- \"$cur\")) ;;"
            end
            lines << "  esac"
            lines
          end

          def quote(str) = str.to_s.gsub("\\", "\\\\\\\\").gsub('"', "\\\"")
        end
      end
    end
  end
end
