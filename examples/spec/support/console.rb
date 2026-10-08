# frozen_string_literal: true

require "stringio"

# A dry-cli-ui console writing to StringIOs, for specs of the displays.
# Neither stream is a terminal, so nothing animates.
RSpec.shared_context "with a console" do
  let(:out) { StringIO.new }
  let(:err) { StringIO.new }
  let(:ui) { Dry::CLI::UI::Console.new(out:, err:) }
  let(:stop) { Dry::CLI::UI::Stop.new }
end

# Runs one command class through Dry::CLI, as the Launcher would, and keeps
# what it printed and the status it exited with.
RSpec.shared_context "with a command" do
  let(:out) { StringIO.new }
  let(:err) { StringIO.new }
  let(:command_class) { described_class }

  # @return [Integer, nil] the status of the last {#run_command}; 0 when the
  #   command returned without exiting
  attr_reader :exit_status

  # @param arguments [Array<String, Array<String>>] the command line, after the command name
  # @return [Integer] the exit status
  def run_command(*arguments)
    Dry::CLI.new(command_class).call(arguments: arguments.flatten.map(&:to_s), out:, err:)
    @exit_status = 0
  rescue SystemExit => e
    @exit_status = e.status
  end
end
