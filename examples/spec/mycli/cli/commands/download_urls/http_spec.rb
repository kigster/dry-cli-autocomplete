# frozen_string_literal: true

RSpec.describe MyCLI::CLI::Commands::DownloadUrls::HTTP do
  let(:url) { "https://example.test/file.bin" }

  describe ".resolve" do
    subject(:resolved) { described_class.resolve(url) }

    context "when HEAD succeeds" do
      before { stub_request(:head, url).to_return(status: 200, headers: { "Content-Length" => "42" }) }

      it { is_expected.to eq([URI(url), 42]) }
    end

    context "when HEAD redirects" do
      before do
        stub_request(:head, url).to_return(status: 301, headers: { "Location" => "/moved.bin" })
        stub_request(:head, "https://example.test/moved.bin").to_return(status: 200, headers: { "Content-Length" => "7" })
      end

      it { is_expected.to eq([URI("https://example.test/moved.bin"), 7]) }
    end

    context "when the server serves only GET" do
      before { stub_request(:head, url).to_return(status: 405) }

      it { is_expected.to eq([URI(url), nil]) }
    end

    context "when HEAD fails" do
      before { stub_request(:head, url).to_return(status: 500) }

      it { expect { resolved }.to raise_error(RuntimeError, "HTTP 500") }
    end

    context "when redirects never end" do
      before { stub_request(:head, url).to_return(status: 302, headers: { "Location" => url }) }

      it { expect { resolved }.to raise_error(RuntimeError, "Too many redirects") }
    end

    context "when a redirect has no Location" do
      before { stub_request(:head, url).to_return(status: 302) }

      it { expect { resolved }.to raise_error(RuntimeError, "HTTP 302 without a Location") }
    end
  end

  describe ".get" do
    subject(:body) { described_class.get(URI(url), &:body) }

    context "when GET succeeds" do
      before { stub_request(:get, url).to_return(status: 200, body: "payload") }

      it { is_expected.to eq("payload") }

      it "asks for the body as it is stored" do
        body
        expect(a_request(:get, url).with(headers: { "Accept-Encoding" => "identity" })).to have_been_made
      end
    end

    context "when GET redirects" do
      before do
        stub_request(:get, url).to_return(status: 307, headers: { "Location" => "https://mirror.test/file.bin" })
        stub_request(:get, "https://mirror.test/file.bin").to_return(status: 200, body: "mirrored")
      end

      it { is_expected.to eq("mirrored") }
    end

    context "when GET fails" do
      before { stub_request(:get, url).to_return(status: 404) }

      it { expect { body }.to raise_error(RuntimeError, "HTTP 404") }
    end
  end
end
