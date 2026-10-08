# frozen_string_literal: true

require "socket"

RSpec.describe MyCLI::CLI::Commands::FindHosts::PortProbe do
  subject { described_class.call("127.0.0.1", port, 1.0) }

  context "when something listens on the port" do
    let(:server) { TCPServer.new("127.0.0.1", 0) }
    let(:port) { server.addr[1] }

    after { server.close }

    it { is_expected.to eq(:open) }
  end

  context "when nothing listens on the port" do
    let(:port) { 9 }

    # A real closed port is flaky: the client may be handed that same port
    # as its own ephemeral one, and connect to itself.
    before { allow(Socket).to receive(:tcp).and_raise(Errno::ECONNREFUSED) }

    it { is_expected.to eq(:closed) }
  end

  context "when nothing answers in time" do
    let(:port) { 9 }

    before { allow(Socket).to receive(:tcp).and_raise(Errno::ETIMEDOUT) }

    it { is_expected.to eq(:silent) }
  end
end
