# frozen_string_literal: true

require "tmpdir"

RSpec.describe MyCLI::CLI::Commands::DownloadUrls do
  include_context "with a command"

  let(:directory) { Dir.mktmpdir }
  let(:url) { "https://example.test/notes.txt" }

  before do
    stub_request(:head, url).to_return(status: 200, headers: { "Content-Length" => "5" })
    stub_request(:get, url).to_return(status: 200, body: "hello")
  end

  after { FileUtils.rm_rf(directory) }

  it { expect(described_class.description).to eq("Download URLs, each to its own file") }

  context "with a URL" do
    before { run_command(url, "--output", directory) }

    it { expect(out.string).to include("Wrote 1 of 1 URLs") }
    it { expect(exit_status).to eq(0) }
    it { expect(File.read(File.join(directory, "example.test_notes.txt"))).to eq("hello") }
  end

  context "with --spinner" do
    before { run_command(url, "--spinner", "--output", directory) }

    it { expect(out.string).to include("Wrote 1 of 1 URLs") }
    it("sends no HEAD request") { expect(a_request(:head, url)).not_to have_been_made }
  end

  context "with an output directory to create" do
    before { run_command(url, "--output", File.join(directory, "nested", "deeper")) }

    it { expect(File).to exist(File.join(directory, "nested", "deeper", "example.test_notes.txt")) }
  end

  context "with an output directory that cannot be created" do
    let(:blocker) { File.join(directory, "file") }

    before do
      File.write(blocker, "")
      run_command(url, "--output", File.join(blocker, "sub"))
    end

    it { expect(err.string).to include("Cannot create") }
    it { expect(exit_status).to eq(1) }
  end

  context "with a file of URLs" do
    before do
      File.write(File.join(directory, "urls.txt"), "# list\n#{url}\nnot-a-url\n")
      run_command("--urls-file", File.join(directory, "urls.txt"), "--output", directory)
    end

    it { expect(out.string).to include("Wrote 1 of 1 URLs") }
    it { expect(err.string).to include("Skipped 1 invalid URLs", "not-a-url") }
  end

  context "with a file of URLs that cannot be read" do
    before { run_command("--urls-file", File.join(directory, "missing.txt")) }

    it { expect(err.string).to include("Cannot read") }
    it { expect(exit_status).to eq(1) }
  end

  context "without any URL it can fetch" do
    before { run_command("nope", "--output", directory) }

    it { expect(err.string).to include("No URLs to download", "Skipped 1 invalid URLs") }
    it { expect(exit_status).to eq(1) }
  end

  context "with --concurrency out of range" do
    before { run_command(url, "--concurrency", "0", "--output", directory) }

    it { expect(err.string).to include("--concurrency must be from 1 to 100") }
    it { expect(a_request(:get, url)).not_to have_been_made }
    it { expect(exit_status).to eq(1) }
  end

  context "when Ctrl-C stops the downloads" do
    before do
      allow(Dry::CLI::UI::Stop).to receive(:new).and_return(Dry::CLI::UI::Stop.new.stop!)
      run_command(url, "--output", directory)
    end

    it { expect(out.string).to include("Stopped", "Downloaded 0 of 1 URLs") }
  end
end
