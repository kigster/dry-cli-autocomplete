# frozen_string_literal: true

require "uri"

module MyCLI
  module CLI
    module Commands
      class DownloadUrls
        # The URLs a download was asked for, split into those it can fetch and
        # those it cannot. A URL it can fetch is http or https, with a host.
        #
        # @!attribute [r] valid
        #   @return [Array<String>] the URLs to download, in the order given
        # @!attribute [r] invalid
        #   @return [Array<String>] the URLs skipped
        UrlList = Data.define(:valid, :invalid) do
          # @param urls [Array<String>] URLs from the command line
          # @param file [String, nil] a file with one URL per line; blank lines
          #   and # comments are skipped
          # @return [UrlList] the command-line URLs first, then the file's
          # @raise [SystemCallError] when the file cannot be read
          def self.from(urls, file: nil)
            valid, invalid = (urls + (file ? read(file) : [])).partition { |url| fetchable?(url) }
            new(valid:, invalid:)
          end

          # @param file [String]
          # @return [Array<String>]
          def self.read(file)
            File.readlines(file, chomp: true).map(&:strip).reject { |line| line.empty? || line.start_with?("#") }
          end

          # @param url [String]
          # @return [Boolean]
          def self.fetchable?(url)
            uri = URI.parse(url)
            uri.is_a?(URI::HTTP) && !uri.host.to_s.empty?
          rescue URI::InvalidURIError
            false
          end

          private_class_method :read, :fetchable?
        end
      end
    end
  end
end
