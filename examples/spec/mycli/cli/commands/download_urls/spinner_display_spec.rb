# frozen_string_literal: true

RSpec.describe MyCLI::CLI::Commands::DownloadUrls::SpinnerDisplay do
  include_context "with a console"

  subject(:files) { described_class.new(ui:, downloader:, concurrency: 2, stop:).call(urls) }

  let(:urls) { %w[https://good.test https://bad.test] }
  let(:downloader) { instance_double(MyCLI::CLI::Commands::DownloadUrls::Downloader) }

  before do
    allow(downloader).to receive(:call).with("https://good.test").and_yield(5).and_return("good.test.html")
    allow(downloader).to receive(:call).with("https://bad.test").and_raise(RuntimeError, "HTTP 404")

    files # once every stub is in place
  end

  it("returns a file per URL, nil where it failed") { is_expected.to eq(["good.test.html", nil]) }
  it("marks the failure on its line") { expect(err.string).to include("HTTP 404") }

  context "once a stop is asked for" do
    let(:stop) { Dry::CLI::UI::Stop.new.stop! }

    it("starts no download") { is_expected.to all(be_nil) }
  end
end
