# frozen_string_literal: true

RSpec.describe MyCLI::CLI::Commands::FindHosts::Report do
  subject(:report) { described_class.new(addresses: %w[10.0.0.1 10.0.0.2 10.0.0.3], results:, stopped: false) }

  let(:results) { [[22, 80], nil, []] }

  its(:hosts) { is_expected.to eq([["10.0.0.1", [22, 80]], ["10.0.0.3", []]]) }
  its(:lines) { is_expected.to eq(["10.0.0.1: 22, 80", "10.0.0.3: no open ports"]) }
  its(:text) { is_expected.to eq("10.0.0.1: 22, 80\n10.0.0.3: no open ports\n") }
  it { is_expected.to be_found }

  context "when nothing answered" do
    let(:results) { [nil, nil, nil] }

    it { is_expected.not_to be_found }
    its(:text) { is_expected.to eq("") }
  end
end
