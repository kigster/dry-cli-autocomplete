# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "dry-cli-autocomplete"

PROJECT_ROOT = File.expand_path("..", __dir__)
FIXTURES_ROOT = File.join(PROJECT_ROOT, "spec", "support", "fixtures")

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end
end
