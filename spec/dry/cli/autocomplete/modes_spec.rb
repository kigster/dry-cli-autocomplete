# frozen_string_literal: true

require "dry/cli/autocomplete/command"
require "open3"
require "tmpdir"
require_relative "../../../support/shell_helpers"
require_relative "../../../support/fixtures/simple_cli"
require_relative "../../../support/fixtures/package_manager_cli"
require_relative "../../../support/fixtures/hanami_like_cli"

RSpec.describe "Completion modes" do
  include ShellHelpers

  def run_cli(registry, *arguments)
    out = StringIO.new
    Dry::CLI.new(registry).call(arguments:, stdout: out)
    out.string
  end

  def generate(registry, shell, mode)
    command = Dry::CLI::Autocomplete::Command[registry, program_name: "mycli", mode:].new
    out = StringIO.new
    command.send(:set_streams, stdout: out, stderr: StringIO.new, stdin: StringIO.new)
    command.call(shell:)
    out.string
  end

  describe "binding" do
    it "registers the hidden __complete command once" do
      registry = Module.new { extend Dry::CLI::Registry }
      2.times { Dry::CLI::Autocomplete::Command[registry] }

      expect(registry.tree["__complete"]).to be_hidden
      expect(registry.tree.children.count { it.name == "__complete" }).to eq(1)
    end

    it "defaults to static" do
      expect(Dry::CLI::Autocomplete::Command[Fixtures::SimpleCLI].mode).to eq("static")
      expect(Dry::CLI::Autocomplete::Command.mode).to eq("static")
    end

    it "refuses a mode it does not know" do
      expect { Dry::CLI::Autocomplete::Command[Fixtures::SimpleCLI, mode: :psychic] }
        .to raise_error(ArgumentError, /mode must be one of static, dynamic, hybrid/)
    end
  end

  describe "__complete" do
    let(:registry) do
      Module.new do
        extend Dry::CLI::Registry

        register "deploy", Fixtures::SimpleCLI::Deploy
        register "completion", Dry::CLI::Autocomplete::Command[self]
      end
    end

    it "prints the words that may come next" do
      expect(run_cli(registry, "__complete", "--", "dep")).to eq("deploy\n")
    end

    it "passes switches being completed through to the resolver" do
      expect(run_cli(registry, "__complete", "--", "deploy", "--f")).to eq("--force\n")
    end

    it "ends with :files when file names may come next" do
      registry.register "open", Class.new(Dry::CLI::Command) { argument :file }

      expect(run_cli(registry, "__complete", "--", "open", "")).to eq(":files\n")
    end

    it "prints every top-level command given no words" do
      expect(run_cli(registry, "__complete").lines.map(&:chomp)).to include("deploy", "completion")
    end
  end

  describe "a script in each mode" do
    {
      "a small CLI" => Fixtures::SimpleCLI,
      "a package manager CLI" => Fixtures::PackageManagerCLI,
      "a Hanami-shaped CLI" => Fixtures::HanamiLikeCLI
    }.each do |label, registry|
      %w[dynamic hybrid].each do |mode|
        it "is a bash script bash accepts, for #{label} in #{mode} mode" do
          requires_shell("bash")
          accepted, stderr = parses?("bash", generate(registry, "bash", mode), ".sh")
          expect(accepted).to be(true), stderr
        end

        it "is a zsh script zsh accepts, for #{label} in #{mode} mode" do
          requires_shell("zsh")
          accepted, stderr = parses?("zsh", generate(registry, "zsh", mode), ".zsh")
          expect(accepted).to be(true), stderr
        end
      end
    end

    it "asks the program on every TAB in dynamic mode" do
      script = generate(Fixtures::SimpleCLI, "bash", "dynamic")

      expect(script).to include("__complete --", "complete -F _mycli_completions mycli")
      expect(script).not_to include("deploy")
    end

    it "carries the static table and the fallback in hybrid mode" do
      script = generate(Fixtures::SimpleCLI, "zsh", "hybrid")

      expect(script).to include("_mycli_complete_dynamic() {", "'deploy:", "(( ret )) && _mycli_complete_dynamic")
    end

    it "takes --mode over the bound mode" do
      registry = Module.new do
        extend Dry::CLI::Registry

        register "completion", Dry::CLI::Autocomplete::Command[self, program_name: "mycli"]
      end

      expect(run_cli(registry, "completion", "bash", "--mode=dynamic")).to include("_mycli_complete_dynamic")
      expect(run_cli(registry, "completion", "bash")).not_to include("_mycli_complete_dynamic")
    end

    it "leaves out the unknown-word check when no command has subcommands" do
      registry = Module.new { extend Dry::CLI::Registry }
      script = generate(registry, "bash", "hybrid") + generate(registry, "zsh", "hybrid")

      expect(script).not_to include("unknown=1")
    end
  end

  # Runs the generated bash function the way bash's completion does, against
  # a program that registers one more command than the script was generated
  # from: the case dynamic and hybrid mode exist for.
  describe "completing in bash" do
    let(:program) do
      <<~RUBY
        #!/usr/bin/env ruby
        $LOAD_PATH.unshift(#{File.join(PROJECT_ROOT, 'lib').inspect})
        require "dry/cli/autocomplete/command"
        require #{File.join(FIXTURES_ROOT, 'simple_cli').inspect}
        registry = Fixtures::SimpleCLI
        registry.register "completion", Dry::CLI::Autocomplete::Command[registry] unless registry.tree["completion"]
        registry.register "late", (Class.new(Dry::CLI::Command) { option :speed }) unless registry.tree["late"]
        Dry::CLI.new(registry).call
      RUBY
    end

    def complete(script, line)
      Dir.mktmpdir do |dir|
        path = File.join(dir, "mycli")
        File.write(path, program)
        File.chmod(0o755, path)
        words = line.split(" ", -1)
        driver = <<~BASH
          #{script}
          COMP_WORDS=(#{[path, *words].map { "'#{it}'" }.join(' ')})
          COMP_CWORD=#{words.length}
          _mycli_completions
          printf '%s\\n' "${COMPREPLY[@]}"
        BASH
        stdout, stderr, status = Open3.capture3("bash", "-c", driver)
        raise stderr unless status.success?

        stdout.lines.map(&:chomp).reject(&:empty?)
      end
    end

    before { requires_shell("bash") }

    it "completes a late command in dynamic mode" do
      expect(complete(generate(Fixtures::SimpleCLI, "bash", "dynamic"), "la")).to eq(["late"])
    end

    it "completes a late command in hybrid mode, where the static table has none" do
      expect(complete(generate(Fixtures::SimpleCLI, "bash", "hybrid"), "la")).to eq(["late"])
    end

    it "answers from the static table in hybrid mode when it can" do
      expect(complete(generate(Fixtures::SimpleCLI, "bash", "hybrid"), "de")).to eq(["deploy"])
    end

    it "hands a line past a word the table does not know to the program in hybrid mode" do
      expect(complete(generate(Fixtures::SimpleCLI, "bash", "hybrid"), "late ")).to eq(["--speed"])
    end

    it "does not complete a late command in static mode" do
      expect(complete(generate(Fixtures::SimpleCLI, "bash", "static"), "la")).to be_empty
    end
  end
end
