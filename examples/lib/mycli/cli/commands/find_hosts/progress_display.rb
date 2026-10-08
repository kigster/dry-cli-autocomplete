# frozen_string_literal: true

require "concurrent"

module MyCLI
  module CLI
    module Commands
      class FindHosts
        # Shows two bars, one counting the addresses that answered and one
        # those that did not. Each bar's block is given only its own handle,
        # so the "No answer" job hands its bar to the "Answered" job, which
        # runs the scan, and then waits for the scan to end.
        #
        # @!attribute [r] ui
        #   @return [Dry::CLI::UI::Console]
        # @!attribute [r] scanner
        #   @return [Scanner]
        # @!attribute [r] concurrency
        #   @return [Integer] how many addresses are probed at once
        # @!attribute [r] stop
        #   @return [Dry::CLI::UI::Stop] once stopped, no more addresses start
        ProgressDisplay = Data.define(:ui, :scanner, :concurrency, :stop) do
          # @param addresses [Array<String>]
          # @return [Array<Array<Integer>, nil>] the open ports for each
          #   address; nil where nothing answered, or the scan never started
          def call(addresses)
            silent_bar = Concurrent::Promises.resolvable_future
            scanned = Concurrent::Promises.resolvable_future
            results = nil
            ui.multi_progress("Probing #{addresses.size} addresses", total: addresses.size) do |m|
              m.progress("Answered", total: addresses.size, color: :green) do |answered|
                silent = silent_bar.value!
                results = WorkerPool.new(concurrency, stop:).map(addresses) do |ip|
                  scanner.call(ip).tap { |open| (open ? answered : silent).advance }
                end
              ensure
                scanned.fulfill(true)
              end
              m.progress("No answer", total: addresses.size, color: :red) do |silent|
                silent_bar.fulfill(silent)
                scanned.wait
              end
            end
            results
          end
        end
      end
    end
  end
end
