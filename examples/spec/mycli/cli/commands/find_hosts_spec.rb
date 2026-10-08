# frozen_string_literal: true

require "tmpdir"

RSpec.describe MyCLI::CLI::Commands::FindHosts do
  include_context "with a command"

  let(:subnet) { described_class::Subnet.around("10.0.0.5") }
  let(:answering) { { "10.0.0.1" => :open, "10.0.0.7" => :closed } }

  before do
    allow(described_class::Subnet).to receive(:local).and_return(subnet)
    allow(described_class::FileLimit).to receive(:allow)
    allow(described_class::PortProbe).to receive(:call) { |ip, _port, _timeout| answering.fetch(ip, :silent) }
  end

  it { expect(described_class.description).to eq("Find hosts on the local network that listen on common TCP ports") }
  it { expect(described_class.superclass).to be(MyCLI::CLI::Commands::ConcurrentCommand) }

  context "with --ports" do
    before { run_command("--ports", "22", "--concurrency", "50") }

    it { expect(out.string).to include("Local IP: 10.0.0.5, scanning 10.0.0.0/24 on port 22") }
    it { expect(out.string).to include("Found 2 hosts", "10.0.0.1: 22", "10.0.0.7: no open ports") }
    it("raises the open file limit for the sockets") { expect(described_class::FileLimit).to have_received(:allow).with(50) }
    it { expect(exit_status).to eq(0) }
  end

  context "with several --ports" do
    before { run_command("--ports", "22,80", "--concurrency", "50") }

    it { expect(out.string).to include("on ports 22, 80") }
    it("raises the limit for every socket") { expect(described_class::FileLimit).to have_received(:allow).with(100) }
  end

  context "with --ports that are not port numbers" do
    before { run_command("--ports", "22,ssh,70000") }

    it { expect(err.string).to include("--ports takes port numbers from 1 to 65535", "Got 22,ssh,70000") }
    it { expect(exit_status).to eq(1) }
    it { expect(described_class::PortProbe).not_to have_received(:call) }
  end

  context "with the common ports and --spinner" do
    before { run_command("--spinner", "--concurrency", "100", "--timeout", "0.1") }

    it { expect(out.string).to include("on ports 22, 53, 80") }
    it { expect(out.string).to include("Found 2 hosts", "10.0.0.1: #{described_class::Scanner::COMMON_PORTS.join(', ')}") }
  end

  context "with --cidr" do
    let(:answering) { { "172.16.0.9" => :open } }

    before { run_command("--cidr", "172.16.0.9/30", "--ports", "22") }

    it { expect(out.string).to include("Scanning 172.16.0.8/30 on port 22") }
    it { expect(out.string).not_to include("Local IP") }
    it { expect(out.string).to include("Found 1 hosts", "172.16.0.9: 22") }
    it("never looks up the local network") { expect(described_class::Subnet).not_to have_received(:local) }
  end

  context "with --cidr naming more than #{described_class::Subnet::SOFT_MAX_IPS} addresses" do
    before { run_command("--cidr", "10.0.0.0/21") }

    it { expect(err.string).to include("10.0.0.0/21 has 2046 addresses, more than 1024", "Pass --unlimited") }
    it { expect(exit_status).to eq(1) }
    it { expect(described_class::PortProbe).not_to have_received(:call) }
  end

  context "with --cidr and --unlimited" do
    let(:answering) { {} }

    before do
      allow(described_class::Subnet).to receive(:from_cidr).and_call_original
      run_command("--cidr", "10.0.0.0/21", "--unlimited", "--ports", "22", "--concurrency", "100", "--timeout", "0.01")
    end

    it { expect(err.string).to include("No hosts answered on 22") }
    it { expect(described_class::PortProbe).to have_received(:call).exactly(2046).times }
  end

  context "with --cidr that is not a network" do
    before { run_command("--cidr", "office") }

    it { expect(err.string).to include("--cidr office is not a network", "192.168.0.0/24") }
    it { expect(exit_status).to eq(1) }
  end

  context "with --list" do
    before { run_command("--list") }

    it { expect(out.string.lines.size).to eq(described_class::Scanner::SERVICES.size) }
    it { expect(out.string).to include("   22  SSH\n", " 7000  AirPlay\n") }
    it { expect(described_class::PortProbe).not_to have_received(:call) }
  end

  context "with --output" do
    let(:directory) { Dir.mktmpdir }
    let(:file) { File.join(directory, "hosts.txt") }

    before { run_command("--ports", "22", "--concurrency", "100", "--output", file) }

    after { FileUtils.rm_rf(directory) }

    it { expect(File.read(file)).to eq("10.0.0.1: 22\n10.0.0.7: no open ports\n") }
    it { expect(out.string).to include("Written to") }
  end

  context "when nothing answers" do
    let(:answering) { {} }

    before { run_command("--ports", "22", "--concurrency", "100") }

    it { expect(err.string).to include("No hosts answered on 22") }
    it { expect(exit_status).to eq(0) }
  end

  context "without a local IPv4 address" do
    let(:subnet) { nil }

    before { run_command }

    it { expect(err.string).to include("No local IPv4 address found", "--cidr") }
    it { expect(exit_status).to eq(1) }
  end

  context "with --concurrency out of range" do
    before { run_command("--concurrency", "500") }

    it { expect(err.string).to include("--concurrency must be from 1 to 100, got 500") }
    it { expect(exit_status).to eq(1) }
    it { expect(described_class::PortProbe).not_to have_received(:call) }
  end

  context "when Ctrl-C stops the scan" do
    before do
      allow(Dry::CLI::UI::Stop).to receive(:new).and_return(Dry::CLI::UI::Stop.new.stop!)
      run_command("--ports", "22")
    end

    it { expect(out.string).to include("Stopped", "Scanned 0 of 254 addresses, and found 0 hosts") }
  end
end
