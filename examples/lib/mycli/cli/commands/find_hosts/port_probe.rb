# frozen_string_literal: true

require "socket"

module MyCLI
  module CLI
    module Commands
      class FindHosts
        # Opens a TCP connection to one port, and says how the address answered.
        # A refused connection still means something is at that address.
        module PortProbe
          module_function

          # @param ip [String]
          # @param port [Integer]
          # @param timeout [Float] seconds to wait for the connection
          # @return [Symbol] :open, :closed, or :silent when nothing answered
          def call(ip, port, timeout)
            Socket.tcp(ip, port, connect_timeout: timeout).close
            :open
          rescue Errno::ECONNREFUSED
            :closed
          rescue SystemCallError, IOError, SocketError
            :silent
          end
        end
      end
    end
  end
end
