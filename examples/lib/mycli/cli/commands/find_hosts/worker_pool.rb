# frozen_string_literal: true

module MyCLI
  module CLI
    module Commands
      class FindHosts
        # Runs a block for each item on a fixed number of threads, and stops
        # taking new items once a stop is asked for.
        #
        # @example
        #   WorkerPool.new(4).map(%w[a b c]) { |item| item.upcase } # => ["A", "B", "C"]
        class WorkerPool
          # @param size [Integer] how many threads run the block
          # @param stop [#stopped?, nil] once it is stopped, no more items start
          def initialize(size, stop: nil)
            @size = size
            @stop = stop
          end

          # @param items [Array]
          # @yieldparam item [Object]
          # @return [Array] what the block returned for each item, in order; nil
          #   for an item a stop skipped
          def map(items)
            queue = Queue.new
            items.each_with_index { |item, index| queue << [item, index] }
            queue.close
            results = Array.new(items.size)
            Array.new(size) do
              Thread.new do
                while !stopped? && (pair = queue.pop)
                  item, index    = pair
                  results[index] = yield item
                end
              end
            end.each(&:join)
            results
          end

          private

          # @return [Integer]
          attr_reader :size

          # @return [#stopped?, nil]
          attr_reader :stop

          # @return [Boolean]
          def stopped? = stop&.stopped? || false
        end
      end
    end
  end
end
