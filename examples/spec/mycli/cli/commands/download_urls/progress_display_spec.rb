# frozen_string_literal: true

RSpec.describe MyCLI::CLI::Commands::DownloadUrls::ProgressDisplay do
  include_context "with a console"

  subject(:files) { described_class.new(ui:, downloader:, concurrency: 2, stop:, http:).call(urls) }

  let(:urls) { %w[https://sized.test https://unsized.test https://bad.test] }
  let(:downloader) { instance_double(MyCLI::CLI::Commands::DownloadUrls::Downloader) }
  let(:http) { class_double(MyCLI::CLI::Commands::DownloadUrls::HTTP) }

  before do
    allow(http).to receive(:resolve).with("https://sized.test").and_return([URI("https://cdn.test/sized"), 5])
    allow(http).to receive(:resolve).with("https://unsized.test").and_return([URI("https://unsized.test"), nil])
    allow(http).to receive(:resolve).with("https://bad.test").and_raise(RuntimeError, "HTTP 500")
    allow(downloader).to receive(:call).with("https://sized.test", URI("https://cdn.test/sized")).and_yield(5).and_return("sized")
    allow(downloader).to receive(:call).with("https://unsized.test", URI("https://unsized.test")).and_yield(3).and_return("unsized")

    files # once every stub is in place
  end

  it("returns a file per URL, nil where it failed") { is_expected.to eq(["sized", "unsized", nil]) }
  it("lists the failures once the bars are done") { expect(err.string).to include("1 URLs failed", "https://bad.test: HTTP 500") }

  context "when every download succeeds" do
    let(:urls) { %w[https://sized.test] }

    it { expect(err.string).not_to include("failed") }
  end

  context "with the default client" do
    subject(:display) { described_class.new(ui:, downloader:, concurrency: 1, stop:) }

    let(:urls) { [] }

    its(:http) { is_expected.to be(MyCLI::CLI::Commands::DownloadUrls::HTTP) }
  end
end
