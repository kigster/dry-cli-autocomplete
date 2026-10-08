# frozen_string_literal: true

module MyCLI
  module CLI
    module Commands
      # A command that works on many items at once: it takes --progress,
      # --spinner and --concurrency, and shows the work with its own
      # ProgressDisplay or SpinnerDisplay. Commands with nothing to run
      # concurrently, such as {Version}, inherit {Base} instead.
      class ConcurrentCommand < Base
        include DisplayOptions
        include Concurrency
      end
    end
  end
end
