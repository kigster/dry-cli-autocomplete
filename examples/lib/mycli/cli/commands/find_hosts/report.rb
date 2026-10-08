# frozen_string_literal: true

module MyCLI
  module CLI
    module Commands
      class FindHosts
        # What a scan found: each address that answered, its name when it
        # has one, and its open ports.
        #
        # @example
        #   report = Report.new(addresses: %w[10.0.0.1 10.0.0.2], results: [[22], nil], stopped: false)
        #   report.lines # => ["10.0.0.1: 22"]
        #   report.with(names: { "10.0.0.1" => "nas.local" }).lines # => ["10.0.0.1 (nas.local): 22"]
        #
        # @!attribute [r] addresses
        #   @return [Array<String>] every address the scan was given
        # @!attribute [r] results
        #   @return [Array<Array<Integer>, nil>] the open ports for each
        #     address, in the same order; nil where nothing answered
        # @!attribute [r] stopped
        #   @return [Boolean] whether Ctrl-C ended the scan early
        # @!attribute [r] names
        #   @return [Hash{String => String}] the name of each host that has one
        Report = Data.define(:addresses, :results, :stopped, :names) do
          # @param names [Hash{String => String}] none until they are looked up
          def initialize(names: {}, **) = super

          # @return [Array<Array(String, Array<Integer>)>] each address that answered, with its open ports
          def hosts = addresses.zip(results).select { |_, open| open }

          # @return [Boolean] whether any address answered
          def found? = hosts.any?

          # @return [Array<String>] a line per host, such as "10.0.0.1 (nas.local): 22, 80"
          def lines = hosts.map { |host, open| "#{label(host)}: #{open.empty? ? 'no open ports' : open.join(', ')}" }

          # @return [String] the lines, each ending in a newline
          def text = lines.map { |line| "#{line}\n" }.join

          private

          # @return [String] the address, with its name in parentheses when it has one
          def label(host) = names[host] ? "#{host} (#{names[host]})" : host
        end
      end
    end
  end
end
