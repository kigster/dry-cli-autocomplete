# frozen_string_literal: true

RSpec.describe MyCLI::CLI::Commands::FindHosts::WorkerPool do
  subject(:results) { described_class.new(size, stop:).map(items) { |item| item * 2 } }

  let(:items) { (1..20).to_a }
  let(:size) { 4 }
  let(:stop) { nil }

  it("keeps the items' order") { is_expected.to eq(items.map { |item| item * 2 }) }

  context "with one thread" do
    let(:size) { 1 }

    it { is_expected.to eq(items.map { |item| item * 2 }) }
  end

  context "with no items" do
    let(:items) { [] }

    it { is_expected.to eq([]) }
  end

  context "once a stop is asked for" do
    let(:stop) { Dry::CLI::UI::Stop.new.stop! }

    it("starts no item") { is_expected.to all(be_nil) }
  end
end
