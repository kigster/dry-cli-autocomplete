# frozen_string_literal: true

RSpec.describe MyCLI::CLI::Commands do
  def command(name) = described_class.get([name]).command

  {
    "version" => MyCLI::CLI::Commands::Version,
    "v" => MyCLI::CLI::Commands::Version,
    "--version" => MyCLI::CLI::Commands::Version,
    "download-urls" => MyCLI::CLI::Commands::DownloadUrls,
    "download" => MyCLI::CLI::Commands::DownloadUrls,
    "find-hosts" => MyCLI::CLI::Commands::FindHosts,
    "hosts" => MyCLI::CLI::Commands::FindHosts
  }.each do |name, klass|
    it("registers #{name} as #{klass.name.split('::').last}") { expect(command(name)).to be(klass) }
  end

  describe "completion" do
    subject { command("completion") }

    it { is_expected.to be < Dry::CLI::Autocomplete::Command }
    its(:registry) { is_expected.to be(described_class) }
    its(:program_name) { is_expected.to eq("mycli") }
    its(:description) { is_expected.to eq("Print a shell completion script") }
  end
end
