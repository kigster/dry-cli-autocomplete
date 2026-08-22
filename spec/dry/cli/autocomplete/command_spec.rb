# frozen_string_literal: true

require "dry/cli/autocomplete/command"
require "open3"
require_relative "../../../support/fixtures/simple_cli"

RSpec.describe Dry::CLI::Autocomplete::Command do
  subject(:command) { described_class[Fixtures::SimpleCLI, program_name: "mycli"].new }

  def capture(shell)
    original = $stdout
    $stdout = StringIO.new
    command.call(shell: shell)
    $stdout.string
  ensure
    $stdout = original
  end

  describe "the laziness contract" do
    # SPECIFICATION.md §2.4 and acceptance criterion 3. Run in a clean
    # process, because anything else in this suite has already loaded the
    # generator and would make the check pass for the wrong reason.
    it "loads no spec builder and no emitter when only the command is required" do
      script = <<~RUBY_SCRIPT
        $LOAD_PATH.unshift("lib")
        require "dry/cli/autocomplete/command"
        print [
          defined?(Dry::CLI::Autocomplete::SpecBuilder),
          defined?(Dry::CLI::Autocomplete::Emitters)
        ].compact.length
      RUBY_SCRIPT

      stdout, stderr, status = Open3.capture3("ruby", "-e", script, chdir: PROJECT_ROOT)

      expect(status).to be_success, stderr
      expect(stdout).to eq("0")
    end

    it "loads no completion gem's own dependency tree beyond dry-cli" do
      script = <<~RUBY_SCRIPT
        $LOAD_PATH.unshift("lib")
        before = $LOADED_FEATURES.dup
        require "dry/cli/autocomplete/command"
        added = $LOADED_FEATURES - before
        print added.grep(/autocomplete/).length
      RUBY_SCRIPT

      stdout, stderr, status = Open3.capture3("ruby", "-e", script, chdir: PROJECT_ROOT)

      expect(status).to be_success, stderr
      expect(stdout).to eq("1")
    end
  end

  describe "binding a registry" do
    it "carries the registry it was built with" do
      expect(described_class[Fixtures::SimpleCLI].registry).to be(Fixtures::SimpleCLI)
    end

    it "leaves the base class unbound, so one host cannot leak into another" do
      described_class[Fixtures::SimpleCLI]

      expect(described_class.registry).to be_nil
    end

    it "refuses to run unbound rather than generating an empty script" do
      expect { described_class.new.call(shell: "bash") }
        .to raise_error(ArgumentError, /no registry bound/)
    end
  end

  describe "generating" do
    it "prints a bash script for the bound registry" do
      expect(capture("bash")).to include("complete -F _mycli_completions mycli")
    end

    it "prints a zsh script for the bound registry" do
      expect(capture("zsh")).to start_with("#compdef mycli")
    end

    it "declares both shells as the argument's accepted values" do
      expect(described_class.arguments.first.values).to contain_exactly("bash", "zsh")
    end
  end

  describe "the program name" do
    it "uses the one it was bound with" do
      expect(capture("bash")).to include("complete -F _mycli_completions mycli")
    end

    it "falls back to the running program's basename when unbound" do
      unbound = described_class[Fixtures::SimpleCLI].new
      allow(unbound).to receive(:program_name).and_call_original

      expect(unbound.send(:program_name)).to eq(File.basename($PROGRAM_NAME))
    end
  end
end
