# frozen_string_literal: true

require "uri"

module MyCLI
  module CLI
    module Commands
      class DownloadUrls
        # Names the file a URL is saved as: its host, path and query as one
        # safe name, keeping the path's extension. Without one, the extension
        # comes from the media type, and is .txt when that is unknown too.
        #
        # @example
        #   FileName.call("https://httpbin.org/json", "application/json") # => "httpbin.org_json.json"
        module FileName
          # File extensions for the media types a URL's own name may not reveal.
          EXTENSIONS = {
            "application/gzip" => ".gz",
            "application/javascript" => ".js",
            "application/json" => ".json",
            "application/pdf" => ".pdf",
            "application/xml" => ".xml",
            "application/zip" => ".zip",
            "image/gif" => ".gif",
            "image/jpeg" => ".jpg",
            "image/png" => ".png",
            "image/svg+xml" => ".svg",
            "image/webp" => ".webp",
            "text/css" => ".css",
            "text/csv" => ".csv",
            "text/html" => ".html",
            "text/javascript" => ".js",
            "text/markdown" => ".md",
            "text/plain" => ".txt",
            "text/xml" => ".xml"
          }.freeze

          # The extension for a media type missing from {EXTENSIONS}.
          FALLBACK = ".txt"

          module_function

          # @param url [String]
          # @param content_type [String, nil] the response's media type, without parameters
          # @return [String] a file name with no directory
          def call(url, content_type)
            uri       = URI(url)
            extension = File.extname(uri.path)
            stem      = "#{uri.host}#{uri.path.delete_suffix(extension)}#{"_#{uri.query}" if uri.query}"
            extension = EXTENSIONS.fetch(content_type, FALLBACK) if extension.empty?
            "#{stem.gsub(/[^\w.-]+/, '_').delete_suffix('_')}#{extension}"
          end
        end
      end
    end
  end
end
