# frozen_string_literal: true

require "concurrent"

module MyCLI
  module CLI
    module Commands
      class DownloadUrls
        # Shows a bar per URL, and a headline bar counting the URLs done.
        # When a URL's turn comes, a HEAD request finds its size for the
        # bar's total, then the file is downloaded. A bar cannot be marked
        # failed, so the URLs that failed are listed once every bar is done.
        #
        # @!attribute [r] ui
        #   @return [Dry::CLI::UI::Console]
        # @!attribute [r] downloader
        #   @return [Downloader]
        # @!attribute [r] concurrency
        #   @return [Integer] how many downloads run at once
        # @!attribute [r] stop
        #   @return [Dry::CLI::UI::Stop] once stopped, no more downloads start
        # @!attribute [r] http
        #   @return [#resolve] finds where a URL ends up, and its size
        ProgressDisplay = Data.define(:ui, :downloader, :concurrency, :stop, :http) do
          def initialize(http: HTTP, **) = super

          # @param urls [Array<String>]
          # @return [Array<String, nil>] the file written for each URL; nil
          #   for one that failed or never started
          def call(urls)
            errors = Concurrent::Array.new
            files = ui.multi_progress("Downloading #{urls.size} URLs", concurrent: concurrency, count: :jobs, stop:) do |m|
              urls.each do |url|
                m.progress(url, total: nil) do |bar|
                  download(url, bar)
                rescue StandardError => e
                  errors << "#{url}: #{e.message}"
                  nil
                end
              end
            end
            ui.warn "#{errors.size} URLs failed", errors.join("\n") if errors.any?
            files
          end

          private

          # @return [String] the file written
          def download(url, bar)
            uri, size = http.resolve(url)
            bar.total = size if size
            downloader.call(url, uri) { |bytes| bar.advance(bytes) }.tap { bar.total = bar.current unless size }
          end
        end
      end
    end
  end
end
