# frozen_string_literal: true

RSpec.describe MyCLI::CLI::Commands::FindHosts::FileLimit do
  subject(:allowed) { described_class.allow(sockets) }

  let(:sockets) { 100 }
  let(:wanted) { sockets + described_class::HEADROOM }

  before { allow(Process).to receive(:setrlimit) }

  context "when the soft limit is already high enough" do
    before { allow(Process).to receive(:getrlimit).with(:NOFILE).and_return([wanted, 10_000]) }

    it { is_expected.to eq(wanted) }
    it { allowed.then { expect(Process).not_to have_received(:setrlimit) } }
  end

  context "when the soft limit is too low" do
    before { allow(Process).to receive(:getrlimit).with(:NOFILE).and_return([10, 10_000], [wanted, 10_000]) }

    it { is_expected.to eq(wanted) }
    it { allowed.then { expect(Process).to have_received(:setrlimit).with(:NOFILE, wanted, 10_000) } }
  end

  context "when the hard limit is lower than wanted" do
    before { allow(Process).to receive(:getrlimit).with(:NOFILE).and_return([10, 50], [50, 50]) }

    it { allowed.then { expect(Process).to have_received(:setrlimit).with(:NOFILE, 50, 50) } }
  end

  context "when the limit cannot be changed" do
    before do
      allow(Process).to receive(:getrlimit).with(:NOFILE).and_return([10, 10_000])
      allow(Process).to receive(:setrlimit).and_raise(Errno::EPERM)
    end

    it { is_expected.to be_nil }
  end
end
