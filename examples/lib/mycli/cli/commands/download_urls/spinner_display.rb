# frozen_string_literal: true

module MyCLI
  module CLI
    module Commands
      class DownloadUrls
        # Shows each download under a spinner of its own, counting the bytes
        # received. A URL that fails is marked failed on its line.
        #
        # @!attribute [r] ui
        #   @return [Dry::CLI::UI::Console]
        # @!attribute [r] downloader
        #   @return [Downloader]
        # @!attribute [r] concurrency
        #   @return [Integer] how many downloads run at once
        # @!attribute [r] stop
        #   @return [Dry::CLI::UI::Stop] once stopped, no more downloads start
        SpinnerDisplay = Data.define(:ui, :downloader, :concurrency, :stop) do
          # @param urls [Array<String>]
          # @return [Array<String, nil>] the file written for each URL; nil
          #   for one that failed or never started
          def call(urls)
            ui.multi_spinner("Downloading #{urls.size} URLs", concurrent: concurrency, stop:) do |m|
              urls.each do |url|
                m.spinner(url) do |line|
                  received = 0
                  downloader.call(url) { |bytes| line.detail = "#{received += bytes} bytes" }
                rescue StandardError => e
                  line.fail(e.message)
                  nil
                end
              end
            end
          end
        end
      end
    end
  end
end
