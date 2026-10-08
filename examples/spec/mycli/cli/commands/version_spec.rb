# frozen_string_literal: true

RSpec.describe MyCLI::CLI::Commands::Version do
  include_context "with a command"

  subject { out.string }

  before { run_command }

  it { is_expected.to eq("#{MyCLI::VERSION}\n") }
  it { expect(described_class.description).to eq("Print version") }
end
