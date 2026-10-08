# frozen_string_literal: true

module MyCLI
  module CLI
    module Commands
      # What every mycli command inherits: dry-cli-ui's `ui`, which writes
      # results to the command's stdout and everything else to its stderr.
      class Base < Dry::CLI::Command
        include Dry::CLI::UI

        # dry-cli-ui presents through `stdout` when a command has one, and
        # through $stdout otherwise. dry-cli calls the stream it hands a
        # command `out`, so this passes that on.
        #
        # @return [IO] the stream Dry::CLI#call was given as `out:`
        def stdout = out || $stdout

        # @return [IO] the stream Dry::CLI#call was given as `err:`
        def stderr = err || $stderr

        private

        # Reports the error and ends the command with exit status 1. The
        # Launcher turns the SystemExit into the process's exit status.
        #
        # @param paragraphs [Array<String>] what went wrong, and what to do about it
        # @return [void] never returns
        # @raise [SystemExit] always, with status 1
        def error!(*paragraphs)
          ui.error(*paragraphs)
          exit(1)
        end
      end
    end
  end
end
