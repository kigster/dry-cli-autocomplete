# frozen_string_literal: true

require "dry/cli/autocomplete/emitters/bash"
require "open3"
require "tempfile"
require "tmpdir"
require "fileutils"

# Built by hand against the CompletionSpec shape documented in
# .plans/001.00-*/plan.md, not against WU1's SpecBuilder: this unit
# must stand on its own before that one has landed. See plan.md's
# "Interface contract between the units".
module BashFixtures
  CompletionSpec = Struct.new(:program_name, :nodes, keyword_init: true)
  Node = Struct.new(:path, :options, :arguments, :children, keyword_init: true)

  # :values shadows Struct#values by design, matching the field name
  # the interface contract fixes for emitters.
  OptionSpec = Struct.new(
    :name, :type, :values, :aliases, :default, :desc, :required, :boolean, :array,
    keyword_init: true
  )
  ArgumentSpec = Struct.new(:name, :values, :desc, :required, :file, keyword_init: true)
  # rubocop:enable Lint/StructNewOverride

  def self.option(name:, aliases: [], boolean: false, values: nil)
    OptionSpec.new(
      name: name, type: boolean ? "bool" : "string", values: values, aliases: aliases,
      default: nil, desc: "#{name} option", required: false, boolean: boolean, array: false
    )
  end

  def self.argument(name:, file: false, values: nil)
    ArgumentSpec.new(name: name, values: values, desc: "#{name} argument", required: true, file: file)
  end
end

GOLDEN_BASH_DIR = File.join(FIXTURES_ROOT, "..", "golden", "bash")

RSpec.describe Dry::CLI::Autocomplete::Emitters::Bash do
  def golden(name)
    File.read(File.join(GOLDEN_BASH_DIR, name))
  end

  # Mirrors plan.md §3's walk example, plus a node that carries both a
  # command and children (§1.1 acceptance criterion); a hidden command
  # is deliberately absent since exclusion is SpecBuilder's job, not
  # the emitter's.
  let(:nested_spec) do
    BashFixtures::CompletionSpec.new(
      program_name: "mycli",
      nodes: [
        BashFixtures::Node.new(path: [], options: [], arguments: [], children: %w[version deploy db]),
        BashFixtures::Node.new(
          path: ["version"], arguments: [], children: [],
          options: [BashFixtures.option(name: "format", values: %w[json plain])]
        ),
        BashFixtures::Node.new(
          path: ["deploy"], children: [],
          options: [BashFixtures.option(name: "force", aliases: ["-f"], boolean: true)],
          arguments: [BashFixtures.argument(name: "target", values: %w[staging production])]
        ),
        BashFixtures::Node.new(
          path: ["db"], arguments: [], children: %w[migrate],
          options: [BashFixtures.option(name: "verbose", aliases: ["-v"], boolean: true)]
        ),
        BashFixtures::Node.new(
          path: %w[db migrate], options: [], children: [],
          arguments: [BashFixtures.argument(name: "file", file: true)]
        )
      ]
    )
  end

  it "matches the golden script byte for byte" do
    expect(described_class.call(nested_spec)).to eq(golden("mycli.sh"))
  end

  it "produces a script bash accepts" do
    Tempfile.create(["bash_completion", ".sh"]) do |file|
      file.write(described_class.call(nested_spec))
      file.flush
      _stdout, stderr, status = Open3.capture3("bash", "-n", file.path)
      expect(status).to be_success, stderr
    end
  end

  it "derives the shell identifier from an already-underscored program name" do
    spec = BashFixtures::CompletionSpec.new(
      program_name: "my_tool",
      nodes: [BashFixtures::Node.new(path: [], options: [], arguments: [], children: %w[status])]
    )

    expect(described_class.call(spec)).to eq(golden("my_tool.sh"))
  end

  it "excludes a name that never appears in the spec, standing in for a hidden command" do
    expect(described_class.call(nested_spec)).not_to include("secret")
  end

  describe "actual completion behaviour, run under bash" do
    def completion_harness(spec, words)
      script = described_class.call(spec)
      quoted_words = words.map { |w| %("#{w}") }.join(" ")
      <<~HARNESS
        #{script}
        COMP_WORDS=(#{quoted_words})
        COMP_CWORD=#{words.length - 1}
        _mycli_completions
        printf '%s\\n' "${COMPREPLY[@]}"
      HARNESS
    end

    def complete(spec, *words)
      Tempfile.create(["bash_completion", ".sh"]) do |file|
        file.write(completion_harness(spec, words))
        file.flush

        stdout, stderr, status = Open3.capture3("bash", file.path)
        raise stderr unless status.success?

        stdout.split("\n")
      end
    end

    it "completes top-level children" do
      expect(complete(nested_spec, "mycli", "")).to contain_exactly("version", "deploy", "db")
    end

    it "completes a group's own options alongside its children" do
      expect(complete(nested_spec, "mycli", "db", "")).to contain_exactly("migrate", "--verbose", "-v")
    end

    it "completes an option's long name and its alias" do
      # Alongside the positional's declared values, which belong at this
      # position too; the example below covers those separately.
      expect(complete(nested_spec, "mycli", "deploy", "")).to include("--force", "-f")
    end

    it "completes real filenames under a file argument, not the enum's words" do
      Dir.mktmpdir do |dir|
        FileUtils.touch(File.join(dir, "20240101_add_users.rb"))
        Dir.chdir(dir) do
          expect(complete(nested_spec, "mycli", "db", "migrate", "")).to include("20240101_add_users.rb")
        end
      end
    end

    # spec.md §2.2: values declared on an option are free, and must be
    # included. They were emitted for zsh and dropped for bash, so
    # `mycli version --format <TAB>` repeated the command list instead of
    # answering the question the user had just asked.
    it "completes an option's declared values once that option is the previous word" do
      expect(complete(nested_spec, "mycli", "version", "--format", "")).to contain_exactly("json", "plain")
    end

    it "offers only those values, not the node's own word list" do
      expect(complete(nested_spec, "mycli", "version", "--format", "")).not_to include("--format")
    end

    it "narrows the values on a partial word" do
      expect(complete(nested_spec, "mycli", "version", "--format", "j")).to contain_exactly("json")
    end

    it "answers an alias the same way it answers the long name" do
      spec = BashFixtures::CompletionSpec.new(
        program_name: "mycli",
        nodes: [
          BashFixtures::Node.new(path: [], options: [], arguments: [], children: %w[emit]),
          BashFixtures::Node.new(
            path: ["emit"], arguments: [], children: [],
            options: [BashFixtures.option(name: "format", aliases: ["-o"], values: %w[json yaml])]
          )
        ]
      )

      expect(complete(spec, "mycli", "emit", "-o", "")).to contain_exactly("json", "yaml")
    end

    it "falls through to the word list after a boolean flag, which takes no value" do
      expect(complete(nested_spec, "mycli", "deploy", "--force", ""))
        .to contain_exactly("--force", "-f", "staging", "production")
    end

    it "offers a positional's declared values at that position" do
      expect(complete(nested_spec, "mycli", "deploy", "")).to include("staging", "production")
    end

    it "does not offer file completion outside a file argument's node" do
      Dir.mktmpdir do |dir|
        FileUtils.touch(File.join(dir, "should_not_appear.rb"))
        Dir.chdir(dir) do
          expect(complete(nested_spec, "mycli", "deploy", "")).not_to include("should_not_appear.rb")
        end
      end
    end
  end
end
