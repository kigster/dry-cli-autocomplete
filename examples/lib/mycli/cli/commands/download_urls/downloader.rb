# frozen_string_literal: true

require "fileutils"

module MyCLI
  module CLI
    module Commands
      class DownloadUrls
        # Streams a URL's body into a file in one directory, named by
        # {FileName}, and removes what it wrote when the download fails.
        class Downloader
          # @param directory [String] where files are written; it must exist
          # @param http [#get] the client that fetches the body
          def initialize(directory, http: HTTP)
            @directory = directory
            @http      = http
          end

          # @param url [String] what the file is named after
          # @param uri [URI] where to download it from: the URL itself, or where
          #   a HEAD request found it redirects to
          # @yieldparam bytes [Integer] the size of each chunk as it is written
          # @return [String] the file written
          # @raise [StandardError] whatever stopped the download, once the
          #   partial file is gone
          def call(url, uri = URI(url))
            file = nil
            http.get(uri) do |response|
              file = File.join(directory, FileName.call(url, response.content_type))
              File.open(file, "wb") do |io|
                response.read_body do |chunk|
                  io.write(chunk)
                  yield chunk.bytesize if block_given?
                end
              end
            end
            file
          rescue StandardError
            FileUtils.rm_f(file) if file
            raise
          end

          private

          # @return [String]
          attr_reader :directory

          # @return [#get]
          attr_reader :http
        end
      end
    end
  end
end
