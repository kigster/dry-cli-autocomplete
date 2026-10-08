# frozen_string_literal: true

RSpec.describe MyCLI::Launcher do
  describe "#execute!" do
    subject(:launcher) { described_class.new(argv, StringIO.new, stdout, stderr, kernel) }

    let(:stdout) { StringIO.new }
    let(:stderr) { StringIO.new }
    let(:kernel) { class_spy(Kernel) }

    before { launcher.execute! }

    context "with a command that succeeds" do
      let(:argv) { %w[version] }

      it { expect(kernel).to have_received(:exit).with(0) }
      it { expect(stdout.string).to eq("#{MyCLI::VERSION}\n") }
    end

    context "with a command that raises" do
      let(:argv) { %w[find-hosts --timeout soon] }

      before { allow(MyCLI::CLI::Commands::FindHosts::Subnet).to receive(:local).and_return(MyCLI::CLI::Commands::FindHosts::Subnet.around("10.0.0.5")) }

      it { expect(kernel).to have_received(:exit).with(1) }
      it { expect(stderr.string).to start_with("error: ") }
    end

    context "with a command that reports an error" do
      let(:argv) { %w[find-hosts --cidr office] }

      it { expect(kernel).to have_received(:exit).with(1) }
      it { expect(stderr.string).to include("--cidr office is not a network") }
    end

    context "with a command dry-cli does not know" do
      let(:argv) { %w[frobnicate] }

      it { expect(kernel).to have_received(:exit).with(1) }
    end
  end

  describe "the executable", type: :aruba do
    subject { last_command_started }

    context "without arguments" do
      before { run_command_and_stop("mycli") }

      it { is_expected.to have_exit_status(0) }
      it { is_expected.to have_output_on_stdout(/download-urls.*Download URLs/) }
      it { is_expected.to have_output_on_stdout(/completion\s+Print a shell completion script/) }
    end

    context "with --version" do
      before { run_command_and_stop("mycli --version") }

      it { is_expected.to have_output_on_stdout(MyCLI::VERSION) }
    end

    %w[bash zsh].each do |shell|
      context "with completion #{shell}" do
        before { run_command_and_stop("mycli completion #{shell}") }

        it { is_expected.to have_output_on_stdout(/mycli/) }
        it { is_expected.to have_output_on_stdout(/find-hosts/) }
      end
    end

    context "with completion --help" do
      before { run_command_and_stop("mycli completion --help") }

      it { is_expected.to have_output_on_stdout(/Print a shell completion script/) }
    end
  end
end
