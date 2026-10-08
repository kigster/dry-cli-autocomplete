# frozen_string_literal: true

require "io/console"

module MyCLI
  module CLI
    # How dry-cli-help renders every help screen mycli prints.
    module HelpSettings
      # Help never gets wider than this, however wide the terminal.
      MAX_WIDTH = 120

      # Columns left free at the right edge of the terminal.
      MARGIN = 6

      # The width assumed without a terminal, as when output is piped.
      DEFAULT_COLUMNS = 80

      module_function

      # Applies the settings. dry-cli-help keeps one configuration per
      # process, so calling this again only makes the same settings again.
      #
      # @param columns [Integer] the terminal's width
      # @return [Dry::CLI::Help::Configuration]
      def apply(columns: terminal_columns)
        Dry::CLI::Help.configure do
          title "mycli"
          description "Downloads URLs and finds hosts on the local network, several at once."
          width [columns - MARGIN, MAX_WIDTH].min
          exit_code_without_arguments 0
        end
      end

      # @param console [IO, nil] the controlling terminal; nil without one
      # @return [Integer] the terminal's width, or {DEFAULT_COLUMNS} without a terminal
      def terminal_columns(console = IO.console)
        console&.winsize&.last || DEFAULT_COLUMNS
      end
    end
  end
end
