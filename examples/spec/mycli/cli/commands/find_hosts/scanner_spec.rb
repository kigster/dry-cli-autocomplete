# frozen_string_literal: true

RSpec.describe MyCLI::CLI::Commands::FindHosts::Scanner do
  subject(:scanner) { described_class.new(ports: [22, 80, 443], timeout: 0.1, probe:) }

  let(:states) { { 22 => :open, 80 => :closed, 443 => :open } }
  let(:probe) { ->(_ip, port, _timeout) { states.fetch(port) } }

  it("lists the open ports") { expect(scanner.call("10.0.0.1")).to eq([22, 443]) }

  it "yields each port's state as its probe ends" do
    expect { |block| scanner.call("10.0.0.1", &block) }.to yield_successive_args(*states.values.map { anything })
  end

  it "counts the addresses scanned" do
    2.times { scanner.call("10.0.0.1") }
    expect(scanner.scanned).to eq(2)
  end

  context "when every port refuses" do
    let(:states) { { 22 => :closed, 80 => :closed, 443 => :closed } }

    it("still finds a host") { expect(scanner.call("10.0.0.1")).to eq([]) }
  end

  context "when nothing answers" do
    let(:states) { { 22 => :silent, 80 => :silent, 443 => :silent } }

    it { expect(scanner.call("10.0.0.1")).to be_nil }
  end

  context "with the defaults" do
    subject { described_class.new }

    its(:ports) { is_expected.to eq(described_class::COMMON_PORTS) }
    its(:scanned) { is_expected.to eq(0) }
  end
end
