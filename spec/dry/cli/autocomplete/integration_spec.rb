# frozen_string_literal: true

require "dry/cli/autocomplete/command"
require_relative "../../../support/shell_helpers"
require_relative "../../../support/fixtures/simple_cli"
require_relative "../../../support/fixtures/package_manager_cli"
require_relative "../../../support/fixtures/hanami_like_cli"

# The unit specs build their own spec structs so each piece can be tested
# before the next one lands. Nothing there proves the pieces fit together,
# or that a real registry survives the whole path. This does: registry ->
# SpecBuilder -> emitter -> the shell's own parser. See spec.md §5.
RSpec.describe "generating completions end to end" do
  include ShellHelpers

  REGISTRIES = {
    "a small CLI" => Fixtures::SimpleCLI,
    "a package manager CLI" => Fixtures::PackageManagerCLI,
    "a Hanami-shaped CLI" => Fixtures::HanamiLikeCLI
  }.freeze

  def generate(registry, shell, program_name: "mycli")
    command = Dry::CLI::Autocomplete::Command[registry, program_name: program_name].new
    original = $stdout
    $stdout = StringIO.new
    command.call(shell: shell)
    $stdout.string
  ensure
    $stdout = original
  end

  REGISTRIES.each do |label, registry|
    context "with #{label}" do
      it "produces a bash script bash accepts" do
        requires_shell("bash")
        accepted, stderr = parses?("bash", generate(registry, "bash"), ".sh")
        expect(accepted).to be(true), stderr
      end

      it "produces a zsh script zsh accepts" do
        requires_shell("zsh")
        accepted, stderr = parses?("zsh", generate(registry, "zsh"), ".zsh")
        expect(accepted).to be(true), stderr
      end

      it "binds the completion to the program name in bash" do
        expect(generate(registry, "bash")).to include("complete -F _mycli_completions mycli")
      end

      it "opens the zsh script with a compdef line" do
        expect(generate(registry, "zsh")).to start_with("#compdef mycli\n")
      end

      # spec.md §4.2 and acceptance criterion 7. A dash is legal in a bash
      # function name but not in a zsh one, and neither is legal in the
      # identifier a reader expects, so both emitters underscore it.
      # The two shells name the function differently on purpose: bash uses
      # _my_tool_completions for `complete -F`, zsh uses _my_tool because a
      # compdef file is autoloaded by the name of the function it defines.
      # Both underscore the dash, which is what the criterion is about.
      it "produces a valid identifier for a program installed with a dash" do
        %w[bash zsh].each do |shell|
          script = generate(registry, shell, program_name: "my-tool")

          expect(script).to include("_my_tool"), "#{shell} kept the dash"
          expect(script).not_to include("_my-tool("), "#{shell} named a function with a dash"
        end
      end
    end
  end

  describe "a host that registers the command the documented way" do
    # Mirrors the README and spec.md §2.4 exactly, including Command[self]
    # from inside the registry's own module body.
    module HostCLI
      extend Dry::CLI::Registry

      class Build < Dry::CLI::Command
        desc "Build the project"
        option :target, values: %w[debug release], desc: "Build profile"

        def call(**); end
      end

      register "build", Build
      register "completion", Dry::CLI::Autocomplete::Command[self, program_name: "hostcli"]
    end

    def run_cli(*arguments)
      original = $stdout
      $stdout = StringIO.new
      Dry::CLI.new(HostCLI).call(arguments: arguments)
      $stdout.string
    ensure
      $stdout = original
    end

    it "generates bash through dry-cli's own dispatch" do
      expect(run_cli("completion", "bash")).to include("complete -F _hostcli_completions hostcli")
    end

    it "generates zsh through dry-cli's own dispatch" do
      expect(run_cli("completion", "zsh")).to start_with("#compdef hostcli\n")
    end

    it "completes the host's own commands" do
      expect(run_cli("completion", "bash")).to include("build")
    end

    it "completes the completion command's own shell argument values" do
      expect(run_cli("completion", "zsh")).to include("bash zsh").or include("(bash zsh)")
    end
  end
end
