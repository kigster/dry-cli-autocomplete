# frozen_string_literal: true

RSpec.describe MyCLI::CLI::Commands::ConcurrentCommand do
  subject { described_class.options.map(&:name) }

  it { is_expected.to eq(%i[progress spinner concurrency]) }
  it { expect(described_class.ancestors).to include(MyCLI::CLI::Commands::Base) }
  it("leaves Version without them") { expect(MyCLI::CLI::Commands::Version.options).to be_empty }
end
