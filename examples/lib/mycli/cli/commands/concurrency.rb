# frozen_string_literal: true

module MyCLI
  module CLI
    module Commands
      # Adds -c/--concurrency (also --cpus), how many items a command works
      # on at once, and reads the value back.
      module Concurrency
        # Items worked on at once when --concurrency is not given.
        DEFAULT = 10

        # The most --concurrency accepts.
        MAX = 100

        # @param command [Class<Base>] the command declaring the option
        # @return [void]
        def self.included(command)
          command.option :concurrency, aliases: ["-c", "--cpus"], type: :integer, default: DEFAULT,
                                       desc: "How many at once, from 1 to #{MAX}"
        end

        private

        # Reads --concurrency, and ends the command with an error when the
        # value is out of range.
        #
        # @param value [String, Integer, nil] what was given on the command line
        # @return [Integer] the value as an Integer
        # @raise [SystemExit] with status 1, when the value is out of range
        def concurrency(value)
          count = Integer(value, exception: false)
          return count if count&.between?(1, MAX)

          error!("--concurrency must be from 1 to #{MAX}, got #{value}")
        end
      end
    end
  end
end
