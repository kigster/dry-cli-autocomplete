# frozen_string_literal: true

RSpec.describe MyCLI::CLI::HelpSettings do
  subject(:config) { described_class.apply(columns:) }

  let(:columns) { 80 }

  after { described_class.apply }

  its(:title) { is_expected.to eq("mycli") }
  its(:description) { is_expected.to include("several at once") }
  its(:exit_code_without_arguments) { is_expected.to eq(0) }

  context "on an 80-column terminal" do
    its(:width) { is_expected.to eq(80 - described_class::MARGIN) }
  end

  context "on a very wide terminal" do
    let(:columns) { 300 }

    its(:width) { is_expected.to eq(described_class::MAX_WIDTH) }
  end

  context "without a width given" do
    subject(:config) { described_class.apply }

    before { allow(IO).to receive(:console).and_return(instance_double(IO, winsize: [40, 100])) }

    its(:width) { is_expected.to eq(100 - described_class::MARGIN) }
  end

  describe ".terminal_columns" do
    subject { described_class.terminal_columns(console) }

    context "with a terminal" do
      let(:console) { instance_double(IO, winsize: [40, 132]) }

      it { is_expected.to eq(132) }
    end

    context "with a terminal that reports no size" do
      let(:console) { instance_double(IO, winsize: nil) }

      it { is_expected.to eq(described_class::DEFAULT_COLUMNS) }
    end

    context "without a terminal, as when piped" do
      let(:console) { nil }

      it { is_expected.to eq(described_class::DEFAULT_COLUMNS) }
    end
  end
end
