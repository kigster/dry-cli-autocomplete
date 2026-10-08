# frozen_string_literal: true

require "concurrent"

module MyCLI
  module CLI
    module Commands
      class FindHosts
        # Shows a spinner per address, counting the ports probed so far. An
        # address where nothing answered is marked failed.
        #
        # @!attribute [r] ui
        #   @return [Dry::CLI::UI::Console]
        # @!attribute [r] scanner
        #   @return [Scanner]
        # @!attribute [r] concurrency
        #   @return [Integer] how many addresses are probed at once
        # @!attribute [r] stop
        #   @return [Dry::CLI::UI::Stop] once stopped, no more addresses start
        SpinnerDisplay = Data.define(:ui, :scanner, :concurrency, :stop) do
          # @param addresses [Array<String>]
          # @return [Array<Array<Integer>, nil>] the open ports for each
          #   address; nil where nothing answered, or the scan never started
          def call(addresses)
            ui.multi_spinner("Probing #{addresses.size} addresses", concurrent: concurrency, stop:) do |m|
              addresses.each do |ip|
                m.spinner(ip) do |line|
                  probed = Concurrent::AtomicFixnum.new
                  open = scanner.call(ip) { |_state| line.detail = "#{probed.increment} of #{scanner.ports.size} ports" }
                  line.fail("no answer") unless open
                  open
                end
              end
            end
          end
        end
      end
    end
  end
end
