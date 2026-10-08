# frozen_string_literal: true

require "tmpdir"

RSpec.describe MyCLI::CLI::Commands::DownloadUrls::Downloader do
  subject(:downloader) { described_class.new(directory) }

  let(:directory) { Dir.mktmpdir }
  let(:url) { "https://example.test/notes" }
  let(:chunks) { [] }

  after { FileUtils.rm_rf(directory) }

  context "when the download succeeds" do
    subject(:file) { downloader.call(url) { |bytes| chunks << bytes } }

    before do
      stub_request(:get, url).to_return(status: 200, body: "hello", headers: { "Content-Type" => "text/plain" })
      file
    end

    it { is_expected.to eq(File.join(directory, "example.test_notes.txt")) }
    it { expect(File.read(file)).to eq("hello") }
    it("reports each chunk's size") { expect(chunks.sum).to eq(5) }
  end

  context "without a block" do
    before { stub_request(:get, url).to_return(status: 200, body: "hello") }

    it { expect(File.read(downloader.call(url))).to eq("hello") }
  end

  context "when the download fails part way" do
    subject(:downloader) { described_class.new(directory, http:) }

    let(:response) { instance_double(Net::HTTPOK, content_type: "text/plain") }
    let(:http) { class_double(MyCLI::CLI::Commands::DownloadUrls::HTTP) }

    before do
      allow(response).to receive(:read_body) do |&block|
        block.call("partial")
        raise IOError, "connection reset"
      end
      allow(http).to receive(:get) { |_uri, &block| block.call(response) }
    end

    it { expect { downloader.call(url) }.to raise_error(IOError, "connection reset") }

    it "removes what it wrote" do
      expect { downloader.call(url) }.to raise_error(IOError)
      expect(Dir.children(directory)).to be_empty
    end
  end

  context "when the server refuses" do
    before { stub_request(:get, url).to_return(status: 403) }

    it { expect { downloader.call(url) }.to raise_error(RuntimeError, "HTTP 403") }
  end
end
