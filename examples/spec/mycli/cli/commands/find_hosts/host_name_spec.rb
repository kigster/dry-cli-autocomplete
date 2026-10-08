# frozen_string_literal: true

RSpec.describe MyCLI::CLI::Commands::FindHosts::HostName do
  subject { described_class.call("10.0.0.1") }

  let(:address) { instance_double(Addrinfo) }

  before { allow(Addrinfo).to receive(:tcp).with("10.0.0.1", 0).and_return(address) }

  context "with a host that has a name" do
    before { allow(address).to receive(:getnameinfo).with(Socket::NI_NAMEREQD).and_return(["nas.local", "0"]) }

    it { is_expected.to eq("nas.local") }
  end

  context "with a host that has none" do
    before { allow(address).to receive(:getnameinfo).and_raise(SocketError, "nodename nor servname provided") }

    it { is_expected.to be_nil }
  end
end
