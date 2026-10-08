# frozen_string_literal: true

RSpec.describe MyCLI::CLI::Commands::FindHosts::SpinnerDisplay do
  include_context "with a console"

  subject(:results) { described_class.new(ui:, scanner:, concurrency: 2, stop:).call(%w[10.0.0.1 10.0.0.2]) }

  let(:scanner) { instance_double(MyCLI::CLI::Commands::FindHosts::Scanner, ports: [22, 80]) }

  before do
    allow(scanner).to receive(:call).with("10.0.0.1").and_yield(:open).and_yield(:closed).and_return([22])
    allow(scanner).to receive(:call).with("10.0.0.2").and_yield(:silent).and_yield(:silent).and_return(nil)

    results # once every stub is in place
  end

  it("returns the open ports per address") { is_expected.to eq([[22], nil]) }
  it("marks an address that never answered") { expect(err.string).to include("no answer") }
end
