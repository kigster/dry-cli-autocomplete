# frozen_string_literal: true

module MyCLI
  module CLI
    module Commands
      class FindHosts
        # Raises the open file limit for a scan. Each address probes its ports
        # all at once, and the default soft limit, often 256, can be too low; a
        # probe that cannot open a socket would read as no answer.
        module FileLimit
          # Files kept free for everything besides the sockets.
          HEADROOM = 64

          module_function

          # @param sockets [Integer] how many sockets may be open at once
          # @return [Integer, nil] the soft limit now in force; nil when it could not be read or changed
          def allow(sockets)
            soft, hard = Process.getrlimit(:NOFILE)
            wanted = sockets + HEADROOM
            return soft if soft >= wanted

            Process.setrlimit(:NOFILE, [wanted, hard].min, hard)
            Process.getrlimit(:NOFILE).first
          rescue SystemCallError
            nil
          end
        end
      end
    end
  end
end
