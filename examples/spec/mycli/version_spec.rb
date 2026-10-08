# frozen_string_literal: true

RSpec.describe MyCLI::VERSION do
  subject { MyCLI::VERSION }

  it { is_expected.to match(/\A\d+\.\d+\.\d+\z/) }
end
