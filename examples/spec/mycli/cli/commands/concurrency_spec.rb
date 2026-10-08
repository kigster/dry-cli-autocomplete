# frozen_string_literal: true

RSpec.describe MyCLI::CLI::Commands::Concurrency do
  include_context "with a command"

  let(:command_class) do
    Class.new(MyCLI::CLI::Commands::Base) do
      include MyCLI::CLI::Commands::Concurrency

      def call(concurrency:, **) = out.puts(concurrency(concurrency).inspect)
    end
  end

  describe "the option" do
    subject(:option) { command_class.options.find { |o| o.name == :concurrency } }

    its(:default) { is_expected.to eq(described_class::DEFAULT) }
    its(:aliases) { is_expected.to eq(["-c", "--cpus"]) }
  end

  context "without --concurrency" do
    before { run_command }

    it { expect(out.string).to eq("#{described_class::DEFAULT}\n") }
  end

  %w[--concurrency=1 -c42 --cpus=100].each do |argument|
    context "with #{argument}" do
      before { run_command(argument) }

      it { expect(out.string).to eq("#{argument[/\d+/]}\n") }
      it { expect(err.string).to be_empty }
      it { expect(exit_status).to eq(0) }
    end
  end

  %w[0 101 many].each do |value|
    context "with --concurrency=#{value}" do
      before { run_command("--concurrency=#{value}") }

      it { expect(out.string).to be_empty }
      it { expect(err.string).to include("--concurrency must be from 1 to 100, got #{value}") }
      it { expect(exit_status).to eq(1) }
    end
  end
end
