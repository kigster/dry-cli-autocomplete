# frozen_string_literal: true

RSpec.describe MyCLI::CLI::Commands::DisplayOptions do
  let(:command_class) do
    Class.new(MyCLI::CLI::Commands::Base) do
      include MyCLI::CLI::Commands::DisplayOptions

      const_set(:ProgressDisplay, Class.new)
      const_set(:SpinnerDisplay, Class.new)
    end
  end

  def option(name) = command_class.options.find { |o| o.name == name }

  describe "--progress" do
    subject { option(:progress) }

    its(:default) { is_expected.to be(true) }
    its(:aliases) { is_expected.to eq(["-p"]) }
  end

  describe "--spinner" do
    subject { option(:spinner) }

    its(:default) { is_expected.to be(false) }
    its(:aliases) { is_expected.to eq(["-s"]) }
  end

  describe "#display" do
    subject(:command) { command_class.new }

    it { expect(command.send(:display, true)).to be(command_class::SpinnerDisplay) }
    it { expect(command.send(:display, false)).to be(command_class::ProgressDisplay) }
  end
end
