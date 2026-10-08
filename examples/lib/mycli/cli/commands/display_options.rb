# frozen_string_literal: true

module MyCLI
  module CLI
    module Commands
      # Adds -p/--progress and -s/--spinner, which choose how a command shows
      # its concurrent work, and picks the display class to match. Progress
      # bars are the default; --spinner wins when both are given.
      module DisplayOptions
        # @param command [Class<Base>] the command declaring the options
        # @return [void]
        def self.included(command)
          command.option :progress, aliases: ["-p"], type: :flag, default: true, desc: "Show progress bars"
          command.option :spinner, aliases: ["-s"], type: :flag, default: false, desc: "Show spinners instead"
        end

        private

        # @param spinner [Boolean] whether --spinner was given
        # @return [Class] the command's SpinnerDisplay with --spinner, and its
        #   ProgressDisplay otherwise. Both take the same keywords and answer `call`.
        def display(spinner) = spinner ? self.class::SpinnerDisplay : self.class::ProgressDisplay
      end
    end
  end
end
