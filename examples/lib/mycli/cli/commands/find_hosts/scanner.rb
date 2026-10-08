# frozen_string_literal: true

require "concurrent"
require "socket"

module MyCLI
  module CLI
    module Commands
      class FindHosts
        # Probes a list of ports on an address, all at once, and counts the
        # addresses it has scanned so far.
        #
        # @example
        #   scanner = Scanner.new(ports: [22, 80], timeout: 0.5)
        #   scanner.call("192.168.1.1") # => [22], or [] when both refused, or nil
        class Scanner
          # Well-known TCP ports, and what usually listens on each.
          SERVICES = {
            22 => "SSH",
            53 => "DNS",
            80 => "HTTP",
            123 => "NTP",
            139 => "NetBIOS",
            443 => "HTTPS",
            445 => "SMB",
            631 => "IPP printing",
            3389 => "Remote Desktop",
            5000 => "AirPlay, Synology DSM",
            5001 => "Synology DSM over HTTPS",
            7000 => "AirPlay"
          }.freeze

          # The ports probed when none are given.
          COMMON_PORTS = SERVICES.keys.freeze

          # @return [Array<Integer>] the ports probed on every address
          attr_reader :ports

          # @param ports [Array<Integer>]
          # @param timeout [Float] seconds to wait for each port
          # @param probe [#call] answers :open, :closed or :silent for an address and port
          def initialize(ports: COMMON_PORTS, timeout: 0.5, probe: PortProbe)
            @ports   = ports
            @timeout = timeout
            @probe   = probe
            @counter = Concurrent::AtomicFixnum.new
          end

          # Probes every port on an address at once.
          #
          # @param ip [String]
          # @yieldparam state [Symbol] once for each port, as its probe ends
          # @return [Array<Integer>] the open ports; empty when every port refused
          # @return [nil] when nothing answered at all
          def call(ip)
            states = ports.map do |port|
              Thread.new { probe.call(ip, port, timeout).tap { |state| yield state if block_given? } }
            end.map(&:value)
            counter.increment
            return if states.all?(:silent)

            ports.zip(states).filter_map { |port, state| port if state == :open }
          end

          # @return [Integer] how many addresses {#call} has finished
          def scanned = counter.value

          private

          # @return [Float]
          attr_reader :timeout

          # @return [#call]
          attr_reader :probe

          # @return [Concurrent::AtomicFixnum]
          attr_reader :counter
        end
      end
    end
  end
end
