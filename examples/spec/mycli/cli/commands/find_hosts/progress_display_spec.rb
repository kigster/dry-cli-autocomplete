# frozen_string_literal: true

RSpec.describe MyCLI::CLI::Commands::FindHosts::ProgressDisplay do
  include_context "with a console"

  subject(:results) { described_class.new(ui:, scanner:, concurrency: 2, stop:).call(%w[10.0.0.1 10.0.0.2 10.0.0.3]) }

  let(:scanner) { instance_double(MyCLI::CLI::Commands::FindHosts::Scanner) }

  before do
    allow(scanner).to receive(:call).with("10.0.0.1").and_return([22])
    allow(scanner).to receive(:call).with("10.0.0.2").and_return(nil)
    allow(scanner).to receive(:call).with("10.0.0.3").and_return([])

    results # once every stub is in place
  end

  it("returns the open ports per address") { is_expected.to eq([[22], nil, []]) }
  it("shows both bars") { expect(err.string).to include("Answered", "No answer") }

  context "once a stop is asked for" do
    let(:stop) { Dry::CLI::UI::Stop.new.stop! }

    it("probes no address") { is_expected.to all(be_nil) }
  end
end
