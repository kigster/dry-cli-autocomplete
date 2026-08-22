# frozen_string_literal: true

ENV["RUBYOPT"] = "-W0"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "aruba"
require "aruba/rspec"
require "rspec/its"
require "timeout"

if ARGV.empty?
  require "simplecov"
  require "coverage/badge"

  SimpleCov.start do
    add_filter "/spec/"
    self.formatters = SimpleCov::Formatter::MultiFormatter.new(
      [
        SimpleCov::Formatter::HTMLFormatter,
        Coverage::Badge::Formatter
      ]
    )
  end

  SimpleCov.at_exit do
    SimpleCov.result.format!
    # rubocop: disable RSpec/Output
    puts "Coverage: #{SimpleCov.result.covered_percent.round(2)}%"
    # rubocop: enable RSpec/Output
    FileUtils.mkdir_p("docs/img")
    FileUtils.mv("coverage/badge.svg", "docs/img/badge.svg")
  end
end

require "dry-cli-autocomplete"

PROJECT_ROOT = File.expand_path("..", __dir__)
FIXTURES_ROOT = File.join(PROJECT_ROOT, "spec", "fixtures")

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end
end
