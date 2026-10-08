# frozen_string_literal: true

RSpec.describe MyCLI::CLI::Commands::FindHosts::Subnet do
  subject(:subnet) { described_class.around("192.168.1.20") }

  its(:ip) { is_expected.to eq(IPAddr.new("192.168.1.20")) }
  its(:network) { is_expected.to eq(IPAddr.new("192.168.1.0/24")) }
  its(:to_s) { is_expected.to eq("192.168.1.0/24") }
  its(:addresses) { is_expected.to have_attributes(size: 254, first: "192.168.1.1", last: "192.168.1.254") }
  it { is_expected.to be_frozen }

  context "with a /28" do
    subject { described_class.around("10.0.0.20", prefix_length: 28) }

    its(:to_s) { is_expected.to eq("10.0.0.16/28") }
    its(:addresses) { is_expected.to eq((17..30).map { |host| "10.0.0.#{host}" }) }
  end

  context "with something that is not an address" do
    it { expect { described_class.around("router") }.to raise_error(IPAddr::InvalidAddressError) }
  end

  its(:size) { is_expected.to eq(254) }

  describe ".from_cidr" do
    subject { described_class.from_cidr(cidr) }

    let(:cidr) { "172.16.0.9/30" }

    its(:ip) { is_expected.to be_nil }
    its(:to_s) { is_expected.to eq("172.16.0.8/30") }
    its(:addresses) { is_expected.to eq(%w[172.16.0.9 172.16.0.10]) }
    its(:size) { is_expected.to eq(2) }

    context "with a single address" do
      let(:cidr) { "10.0.0.7/32" }

      its(:addresses) { is_expected.to eq(%w[10.0.0.7]) }
      its(:size) { is_expected.to eq(1) }
    end

    context "with a /31, where both addresses are hosts" do
      let(:cidr) { "10.0.0.6/31" }

      its(:addresses) { is_expected.to eq(%w[10.0.0.6 10.0.0.7]) }
      its(:size) { is_expected.to eq(2) }
    end

    context "with an IPv6 network" do
      let(:cidr) { "fd00::/64" }

      its(:size) { is_expected.to eq((2**64) - 2) }
    end

    context "with something that is not a network" do
      let(:cidr) { "home" }

      it { expect { subject }.to raise_error(IPAddr::InvalidAddressError) }
    end
  end

  describe "#within!" do
    subject(:subnet) { described_class.from_cidr("10.0.0.0/22") }

    it { expect(subnet.within!(1022)).to be(subnet) }
    it { expect(subnet.within!(nil)).to be(subnet) }

    it do
      expect { subnet.within!(1021) }
        .to raise_error(MyCLI::CLI::Commands::FindHosts::WillNotScanNetworkThisLargeError,
                        "10.0.0.0/22 has 1022 addresses, more than 1021")
    end
  end

  describe ".local" do
    subject { described_class.local(interfaces) }

    def interface(address) = instance_double(Socket::Ifaddr, addr: address && Addrinfo.ip(address))

    context "with a loopback, an unnamed and an IPv6 interface before an IPv4 one" do
      let(:interfaces) { [interface("127.0.0.1"), interface(nil), interface("::1"), interface("10.1.2.3")] }

      it { is_expected.to eq(described_class.around("10.1.2.3")) }
    end

    context "with only loopback" do
      let(:interfaces) { [interface("127.0.0.1")] }

      it { is_expected.to be_nil }
    end
  end
end
