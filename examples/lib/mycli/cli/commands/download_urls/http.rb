# frozen_string_literal: true

require "net/http"

module MyCLI
  module CLI
    module Commands
      class DownloadUrls
        # A small HTTP client for download-urls. It follows up to REDIRECTS
        # redirects on every request, and asks for the body as it is stored, so
        # the bytes counted match Content-Length.
        module HTTP
          # Sent with every request.
          HEADERS = { "Accept-Encoding" => "identity" }.freeze

          # Redirects followed before giving up.
          REDIRECTS = 5

          # Statuses a server answers HEAD with when it only serves GET.
          NO_HEAD = %w[403 405 501].freeze

          module_function

          # Finds where a URL ends up with a HEAD request, and its size.
          #
          # @param url [String]
          # @param hops [Integer] redirects left to follow
          # @return [Array(URI, Integer)] where the URL ends up, and its size
          # @return [Array(URI, nil)] when the server does not say the size
          # @raise [RuntimeError] for a response that is neither a redirect nor a success
          def resolve(url, hops = REDIRECTS)
            uri      = URI(url)
            response = start(uri) { |http| http.head(uri.request_uri, HEADERS) }
            return resolve(redirect(uri, response, hops), hops - 1) if response.is_a?(Net::HTTPRedirection)
            return [uri, nil] if NO_HEAD.include?(response.code) # the GET finds out
            raise "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

            [uri, response.content_length]
          end

          # Sends a GET, following redirects, and hands the successful response
          # to the block before its body is read.
          #
          # @param uri [URI]
          # @param hops [Integer] redirects left to follow
          # @yieldparam response [Net::HTTPSuccess] the response, whose body is read in the block
          # @return [Object] what the block returned
          # @raise [RuntimeError] for a response that is not a success
          def get(uri, hops = REDIRECTS, &)
            result   = nil
            location = nil
            start(uri) do |http|
              http.request_get(uri.request_uri, HEADERS) do |response|
                next location = redirect(uri, response, hops) if response.is_a?(Net::HTTPRedirection)
                raise "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

                result = yield response
              end
            end
            return get(URI(location), hops - 1, &) if location

            result
          end

          # @param uri [URI] the URL that was redirected
          # @param response [Net::HTTPRedirection]
          # @param hops [Integer] redirects left to follow
          # @return [String] the absolute URL the redirect points to
          # @raise [RuntimeError] once there are no hops left, or without a Location
          def redirect(uri, response, hops)
            raise "Too many redirects" unless hops.positive?
            raise "HTTP #{response.code} without a Location" unless response["location"]

            URI.join(uri, response["location"]).to_s
          end

          # @param uri [URI]
          # @yieldparam http [Net::HTTP] the open connection
          # @return [Object] what the block returned
          def start(uri, &)
            Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 10, &)
          end
        end
      end
    end
  end
end
