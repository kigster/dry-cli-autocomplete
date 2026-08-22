# frozen_string_literal: true

require "dry/cli/autocomplete/emitters/zsh"
require "open3"
require "tempfile"

# Built by hand against the CompletionSpec shape documented in
# .plans/001.00-*/plan.md, matching bash_spec's approach: an emitter is
# tested on the contract, not on whatever SpecBuilder happens to produce.
module ZshFixtures
  CompletionSpec = Struct.new(:program_name, :nodes, keyword_init: true)
  Node = Struct.new(:path, :desc, :options, :arguments, :children, keyword_init: true)

  # :values shadows Struct#values by design, matching the field name
  # the interface contract fixes for emitters.
  # rubocop:disable Lint/StructNewOverride
  OptionSpec = Struct.new(
    :name, :type, :values, :aliases, :default, :desc, :required, :boolean, :array,
    keyword_init: true
  )
  ArgumentSpec = Struct.new(:name, :values, :desc, :required, :file, keyword_init: true)
  # rubocop:enable Lint/StructNewOverride

  def self.option(name:, desc: nil, aliases: [], boolean: false, values: nil)
    OptionSpec.new(
      name: name, type: boolean ? "bool" : "string", values: values, aliases: aliases,
      default: nil, desc: desc || "#{name} option", required: false, boolean: boolean, array: false
    )
  end

  def self.argument(name:, desc: nil, file: false, values: nil)
    ArgumentSpec.new(name: name, values: values, desc: desc, required: true, file: file)
  end
end

GOLDEN_ZSH_DIR = File.join(FIXTURES_ROOT, "..", "golden", "zsh")

RSpec.describe Dry::CLI::Autocomplete::Emitters::Zsh do
  def golden(name)
    File.read(File.join(GOLDEN_ZSH_DIR, name))
  end

  def zsh_accepts?(script)
    Tempfile.create(["zsh_completion", ".zsh"]) do |file|
      file.write(script)
      file.flush
      _stdout, stderr, status = Open3.capture3("zsh", "-n", file.path)
      [status.success?, stderr]
    end
  end

  let(:nested_spec) do
    ZshFixtures::CompletionSpec.new(
      program_name: "mycli",
      nodes: [
        ZshFixtures::Node.new(
          path: [], desc: nil, options: [], arguments: [], children: %w[version deploy db]
        ),
        ZshFixtures::Node.new(
          path: ["version"], desc: "Print the version", arguments: [], children: [],
          options: [ZshFixtures.option(name: "format", desc: "Output format", values: %w[json plain])]
        ),
        ZshFixtures::Node.new(
          path: ["deploy"], desc: "Deploy the application", children: [],
          options: [ZshFixtures.option(name: "force", desc: "Skip confirmation", aliases: ["-f"], boolean: true)],
          arguments: [ZshFixtures.argument(name: "target", desc: "Target environment",
                                           values: %w[staging production])]
        ),
        ZshFixtures::Node.new(
          path: ["db"], desc: "Show pending migrations", arguments: [], children: %w[migrate],
          options: [ZshFixtures.option(name: "verbose", desc: "Print full history", boolean: true)]
        ),
        ZshFixtures::Node.new(
          path: %w[db migrate], desc: "Run pending migrations", options: [], children: [],
          arguments: [ZshFixtures.argument(name: "file", desc: "Migration file", file: true)]
        )
      ]
    )
  end

  it "matches the golden script byte for byte" do
    expect(described_class.call(nested_spec)).to eq(golden("_mycli"))
  end

  it "produces a script zsh accepts" do
    accepted, stderr = zsh_accepts?(described_class.call(nested_spec))
    expect(accepted).to be(true), stderr
  end

  it "opens with a compdef line naming the program" do
    expect(described_class.call(nested_spec).lines.first).to eq("#compdef mycli\n")
  end

  it "is not a bashcompinit shim" do
    output = described_class.call(nested_spec)
    expect(output).not_to include("bashcompinit")
    expect(output).not_to include("compgen")
  end

  it "carries each option's description as zsh help text" do
    expect(described_class.call(nested_spec)).to include("'--force[Skip confirmation]'")
  end

  it "gives an option alias its own spec, with the same description" do
    expect(described_class.call(nested_spec)).to include("'-f[Skip confirmation]'")
  end

  it "completes an option's declared values" do
    expect(described_class.call(nested_spec)).to include("'--format[Output format]:format:(json plain)'")
  end

  it "describes subcommands with their own descriptions" do
    expect(described_class.call(nested_spec)).to include("'migrate:Run pending migrations'")
  end

  it "offers a group's own options alongside its children" do
    arm = described_class.call(nested_spec)[/\('db'\)(.*?);;/m, 1]

    expect(arm).to include("--verbose").and include("_describe")
  end

  it "uses _files for a file argument" do
    expect(described_class.call(nested_spec)).to include(":Migration file:_files'")
  end

  it "does not offer _files outside a file argument's node" do
    arm = described_class.call(nested_spec)[/\('deploy'\)(.*?);;/m, 1]

    expect(arm).not_to include("_files")
  end

  describe "a program name that is not a shell identifier" do
    let(:dashed_spec) do
      ZshFixtures::CompletionSpec.new(
        program_name: "my-tool",
        nodes: [ZshFixtures::Node.new(path: [], desc: nil, options: [], arguments: [], children: %w[status])]
      )
    end

    it "matches the golden script byte for byte" do
      expect(described_class.call(dashed_spec)).to eq(golden("_my-tool"))
    end

    it "underscores the function name while leaving the command alone" do
      output = described_class.call(dashed_spec)

      expect(output).to include("_my_tool_completions()").and include("#compdef my-tool")
    end

    it "produces a script zsh accepts" do
      accepted, stderr = zsh_accepts?(described_class.call(dashed_spec))
      expect(accepted).to be(true), stderr
    end
  end

  describe "escaping" do
    let(:awkward_spec) do
      ZshFixtures::CompletionSpec.new(
        program_name: "mycli",
        nodes: [
          ZshFixtures::Node.new(
            path: [], desc: nil, arguments: [], children: [],
            options: [ZshFixtures.option(name: "note", desc: "Use [brackets], colons: and 'quotes'")]
          )
        ]
      )
    end

    it "still produces a script zsh accepts" do
      accepted, stderr = zsh_accepts?(described_class.call(awkward_spec))
      expect(accepted).to be(true), stderr
    end
  end
end
