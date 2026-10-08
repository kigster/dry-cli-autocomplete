# frozen_string_literal: true

module MyCLI
  module CLI
    module Commands
      # Prints {MyCLI::VERSION}.
      class Version < Base
        desc "Print version"

        # @return [void]
        def call(**)
          out.puts VERSION
        end
      end
    end
  end
end
