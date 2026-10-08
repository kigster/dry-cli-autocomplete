# frozen_string_literal: true

require "tempfile"

RSpec.describe MyCLI::CLI::Commands::DownloadUrls::UrlList do
  subject(:list) { described_class.from(urls, file:) }

  let(:urls) { ["https://example.com", "ftp://example.com/file", "http://", "http://exa mple.com", "not a url"] }
  let(:file) { nil }

  its(:valid) { is_expected.to eq(["https://example.com"]) }
  its(:invalid) { is_expected.to eq(urls.drop(1)) }
  it { is_expected.to be_frozen }

  context "with a file of URLs" do
    let(:urls) { ["https://first.test"] }
    let(:urls_file) do
      Tempfile.create("urls").tap do |io|
        io.write("# a comment\n\n  https://second.test  \nnope\n")
        io.close
      end
    end
    let(:file) { urls_file.path }

    after { File.unlink(file) }

    its(:valid) { is_expected.to eq(%w[https://first.test https://second.test]) }
    its(:invalid) { is_expected.to eq(%w[nope]) }
  end

  context "with a file that does not exist" do
    let(:file) { "/nonexistent/urls.txt" }

    it { expect { list }.to raise_error(Errno::ENOENT) }
  end
end
