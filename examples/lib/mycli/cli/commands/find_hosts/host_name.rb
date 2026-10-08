# frozen_string_literal: true

require "socket"

module MyCLI
  module CLI
    module Commands
      class FindHosts
        # Looks up the name a host goes by, through the system resolver, so
        # mDNS names such as "printer.local" are found as well as DNS ones.
        #
        # @example
        #   HostName.call("192.168.1.1") # => "router.local", or nil
        module HostName
          module_function

          # @param ip [String]
          # @return [String, nil] the host's name; nil when it has none
          def call(ip)
            Addrinfo.tcp(ip, 0).getnameinfo(Socket::NI_NAMEREQD).first
          rescue SocketError
            nil
          end
        end
      end
    end
  end
end
