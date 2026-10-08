# frozen_string_literal: true

require "fileutils"

module MyCLI
  module CLI
    module Commands
      # Downloads URLs, each to its own file as its body arrives, at most
      # --concurrency at once and in the order given. This class reads the
      # options and reports the outcome; {UrlList}, {Downloader} and {HTTP}
      # do the downloading, and {ProgressDisplay} or {SpinnerDisplay} shows it.
      class DownloadUrls < ConcurrentCommand
        desc "Download URLs, each to its own file"

        argument :urls, type: :array, required: false, desc: "URLs to download, separated by spaces"
        option :'urls-file', aliases: ["-u"], desc: "A file with one URL per line; blank lines and # comments are skipped"
        option :output, aliases: ["-o"], default: ".", desc: "A directory to save the files in, created when missing"

        example [
          "https://example.com https://httpbin.org/json",
          "--urls-file urls.txt --output downloads --spinner",
          "-u urls.txt -o downloads -c 4"
        ]

        # @param urls [Array<String>] URLs from the command line
        # @param output [String] the directory to save into
        # @param spinner [Boolean] show spinners instead of progress bars
        # @param options [Hash] :"urls-file" and :concurrency
        # @return [void]
        # @raise [SystemExit] with status 1, after reporting an error
        def call(urls: [], output: ".", spinner: false, **options)
          count = concurrency(options[:concurrency])
          list = url_list(urls, options[:'urls-file'])
          ui.warn "Skipped #{list.invalid.size} invalid URLs", list.invalid.join("\n") if list.invalid.any?

          download(list.valid, output, display(spinner), count)
        end

        private

        # @return [UrlList]
        def url_list(urls, file)
          UrlList.from(urls, file:)
        rescue SystemCallError => e
          error!("Cannot read #{file}", e.message)
        end

        # @param urls [Array<String>]
        # @param directory [String]
        # @param display [Class<SpinnerDisplay>, Class<ProgressDisplay>]
        # @param concurrency [Integer]
        # @return [void]
        def download(urls, directory, display, concurrency)
          error!("No URLs to download", "Pass them as arguments, or in a file with --urls-file") if urls.empty?
          create(directory)

          downloader = Downloader.new(directory)
          # Ctrl-C lets the downloads running finish, and starts no more.
          files, stopped = ui.stoppable do |stop|
            [display.new(ui:, downloader:, concurrency:, stop:).call(urls).compact, stop.stopped?]
          end
          return ui.info("Stopped", "Downloaded #{files.size} of #{urls.size} URLs into #{directory}") if stopped

          ui.success "Wrote #{files.size} of #{urls.size} URLs", files.join("\n")
        end

        # @param directory [String] created, with its parents, when missing
        # @return [void]
        def create(directory)
          FileUtils.mkdir_p(directory)
        rescue SystemCallError => e
          error!("Cannot create #{directory}", e.message)
        end
      end
    end
  end
end
