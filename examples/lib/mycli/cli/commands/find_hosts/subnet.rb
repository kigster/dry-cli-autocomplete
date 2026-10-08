# frozen_string_literal: true

require "ipaddr"
require "socket"

module MyCLI
  module CLI
    module Commands
      class FindHosts
        # Raised for a network with more addresses than a scan may take on.
        class WillNotScanNetworkThisLargeError < StandardError; end

        # A network to scan, and this machine's address on it when the
        # network is the local one. IPAddr does the arithmetic.
        #
        # @example
        #   subnet = Subnet.around("192.168.1.20")
        #   subnet.to_s           # => "192.168.1.0/24"
        #   subnet.addresses.last # => "192.168.1.254"
        #   Subnet.from_cidr("10.0.0.9/30").addresses # => ["10.0.0.9", "10.0.0.10"]
        #
        # @!attribute [r] ip
        #   @return [IPAddr, nil] this machine's address; nil for a network given as a CIDR
        # @!attribute [r] network
        #   @return [IPAddr] the network, masked to its prefix
        class Subnet < Data.define(:ip, :network)
          # The prefix length a home or office network usually has.
          PREFIX_LENGTH = 24

          # The most addresses a scan takes on unless told otherwise: a /22.
          SOFT_MAX_IPS = 2**10

          # @param interfaces [Array<Socket::Ifaddr>]
          # @param prefix_length [Integer]
          # @return [Subnet, nil] the subnet of the first IPv4 address that is
          #   not loopback; nil without one
          def self.local(interfaces = Socket.getifaddrs, prefix_length: PREFIX_LENGTH)
            address = interfaces.map(&:addr).find { |addr| addr&.ipv4? && !addr.ipv4_loopback? }
            address && around(address.ip_address, prefix_length:)
          end

          # @param ip [String] an IPv4 address
          # @param prefix_length [Integer]
          # @return [Subnet]
          # @raise [IPAddr::InvalidAddressError] when ip is not an address
          def self.around(ip, prefix_length: PREFIX_LENGTH)
            address = IPAddr.new(ip)
            new(ip: address, network: address.mask(prefix_length))
          end

          # @param cidr [String] a network such as "172.16.0.0/30"; host bits are ignored
          # @return [Subnet]
          # @raise [IPAddr::InvalidAddressError] when cidr is not a network
          def self.from_cidr(cidr) = new(ip: nil, network: IPAddr.new(cidr))

          # @return [Array<String>] every host address. The network and
          #   broadcast addresses are left out, except on a /31 or /32,
          #   where every address is a host.
          def addresses
            all = network.to_range.map(&:to_s)
            all.size > 2 ? all[1...-1] : all
          end

          # Counts {#addresses} without listing them, so a check on a huge
          # network costs nothing.
          #
          # @return [Integer]
          def size
            total = 2**((network.ipv4? ? 32 : 128) - network.prefix)
            total > 2 ? total - 2 : total
          end

          # @param max [Integer, nil] the most addresses allowed; nil for no limit
          # @return [self]
          # @raise [WillNotScanNetworkThisLargeError] when there are more than max
          def within!(max)
            return self if max.nil? || size <= max

            raise WillNotScanNetworkThisLargeError, "#{self} has #{size} addresses, more than #{max}"
          end

          # @return [String] the network in CIDR form, such as "192.168.1.0/24"
          def to_s = "#{network}/#{network.prefix}"
        end
      end
    end
  end
end
