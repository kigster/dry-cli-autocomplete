# frozen_string_literal: true

require "dry/inflector"

module Dry
  class CLI
    module Autocomplete
      module Emitters
        # Turns a CompletionSpec into a bash `complete -F` script.
        # See docs/SPECIFICATION.md §4.1: a static, case-statement walk over
        # COMP_WORDS resolves which node the cursor is under, then
        # `compgen -W` fills COMPREPLY from that node's children and
        # option flags, with `compgen -f` added where an argument is a
        # file (§4.3).
        #
        # Deliberately avoids bash associative arrays (bash 4+ only):
        # macOS still ships bash 3.2 as /bin/bash, and this script is
        # meant to be eval'd from exactly that.
        class Bash
          # @param spec [SpecBuilder::CompletionSpec]
          # @param fallback [Class, nil] in hybrid mode, the dynamic emitter
          #   whose function answers what this script does not know
          # @return [String]
          def self.call(spec, fallback: nil)
            new(spec, fallback:).call
          end

          def initialize(spec, fallback: nil)
            @spec = spec
            @fallback = fallback
          end

          def call
            "#{body.join("\n")}\n"
          end

          private

          attr_reader :spec, :fallback

          def body
            fallback_helper_lines + header_lines + path_walk_lines + unknown_word_lines +
              option_value_lines + word_lookup_lines + footer_lines
          end

          def header_lines
            [
              "#{function_name}() {",
              "  local cur prev path word next_path words i#{' unknown' if fallback}",
              "  COMPREPLY=()",
              '  cur="${COMP_WORDS[COMP_CWORD]}"',
              '  prev=""',
              '  if [ "$COMP_CWORD" -gt 0 ]; then',
              '    prev="${COMP_WORDS[$((COMP_CWORD - 1))]}"',
              "  fi",
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
              *unknown_detection_lines,
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
              *empty_fallback_lines,
              "}",
              "complete -F #{function_name} #{spec.program_name}"
            ]
          end

          def function_name = "_#{shell_identifier}_completions"

          # Hybrid mode only, from here to {#empty_fallback_lines}: the
          # dynamic emitter's function, defined ahead of this one.
          def fallback_helper_lines
            fallback ? [*fallback.helper_lines(spec), ""] : []
          end

          # A word this script does not know, where a subcommand could go, may
          # be a command registered after the script was generated.
          def unknown_detection_lines
            return [] unless fallback && group_paths.any?

            [
              '      case "$word" in',
              "        -*) ;;",
              "        *)",
              '          case "$path" in',
              "            #{group_pattern}) unknown=1 ;;",
              "          esac",
              "          ;;",
              "      esac"
            ]
          end

          # Such a word hands the whole line to the program.
          def unknown_word_lines
            return [] unless fallback

            ['  if [ -n "$unknown" ]; then', "    #{fallback.function_name(spec)}", "    return", "  fi", ""]
          end

          # So does a word that matches nothing the script knows.
          def empty_fallback_lines
            return [] unless fallback

            ['  if [ "${#COMPREPLY[@]}" -eq 0 ]; then', "    #{fallback.function_name(spec)}", "  fi"]
          end

          # A case pattern matching every path in {#group_paths}.
          def group_pattern
            group_paths.map { |key| %("#{quote(key)}") }.join(" | ")
          end

          # The paths of every node that has subcommands.
          def group_paths
            spec.nodes.reject { it.children.empty? }.map { path_key(it.path) }
          end

          # A program installed as `my-tool` cannot name a shell function
          # directly. See docs/SPECIFICATION.md §4.2.
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

              "\"#{quote(path_key(node.path))}\") words=\"#{quote(words.join(' '))}\" ;;"
            end
          end

          # Children, flags, and any values a positional declares: all three are
          # legitimate next words at this point in the line.
          def node_words(node)
            node.children +
              node.options.flat_map { |option| option_words(option) } +
              node.arguments.flat_map { |argument| Array(argument.values) }
          end

          def option_words(option) = ["--#{option.name}"] + Array(option.aliases)

          # An option that declares values gets its own arm, keyed on the word
          # before the cursor. Typing `--format ` then TAB should offer what
          # --format accepts, not the command list again, so this arm answers
          # and returns rather than falling through. Long name and every alias
          # are listed together, since `-f` accepts what `--format` accepts.
          def option_value_lines
            arms = spec.nodes.flat_map do |node|
              node.options.filter_map do |option|
                values = Array(option.values)
                next if values.empty?

                key = path_key(node.path)
                option_words(option).map do |name|
                  "    \"#{quote(key)}:#{quote(name)}\") " \
                    "COMPREPLY=($(compgen -W \"#{quote(values.join(' '))}\" -- \"$cur\")); return ;;"
                end
              end
            end.flatten

            return [] if arms.empty?

            ['  case "$path:$prev" in', *arms, "  esac", ""]
          end

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
