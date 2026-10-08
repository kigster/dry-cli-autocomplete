# frozen_string_literal: true

RSpec.describe MyCLI::CLI::Commands::Base do
  include_context "with a command"

  context "when called through Dry::CLI" do
    let(:command_class) do
      Class.new(described_class) do
        def call(**)
          ui.success "done"
          ui.error "broken"
        end
      end
    end

    before { run_command }

    it("sends results to its out") { expect(out.string).to include("done") }
    it("sends errors to its err") { expect(err.string).to include("broken") }
    it("exits 0 after ui.error alone") { expect(exit_status).to eq(0) }
  end

  describe "#error!" do
    let(:command_class) do
      Class.new(described_class) do
        def call(**)
          error!("Cannot go on", "Try again")
          out.puts "never printed"
        end
      end
    end

    before { run_command }

    it { expect(err.string).to include("Cannot go on", "Try again") }
    it { expect(out.string).to be_empty }
    it { expect(exit_status).to eq(1) }
  end

  context "when built directly" do
    subject { described_class.new }

    its(:stdout) { is_expected.to be($stdout) }
    its(:stderr) { is_expected.to be($stderr) }
  end
end
