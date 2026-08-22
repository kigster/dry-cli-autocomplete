# frozen_string_literal: true

require "dry/cli/autocomplete/spec_builder"
require_relative "../../../support/fixtures/simple_cli"
require_relative "../../../support/fixtures/package_manager_cli"
require_relative "../../../support/fixtures/hanami_like_cli"

RSpec.describe Dry::CLI::Autocomplete::SpecBuilder do
  shared_examples "a completion spec" do |registry:, hidden_name:, group_with_own_command:|
    subject(:spec) { described_class.call(registry, program_name: "mycli") }

    def node_at(spec, *path)
      spec.nodes.find { |node| node.path == path }
    end

    it "returns the program name unchanged" do
      expect(spec.program_name).to eq("mycli")
    end

    it "builds one node for the root" do
      expect(node_at(spec)).not_to be_nil
    end

    it "excludes the hidden command from the node list" do
      expect(spec.nodes.map(&:path)).not_to include([hidden_name])
    end

    it "excludes the hidden command from its parent's children" do
      expect(node_at(spec).children).not_to include(hidden_name)
    end

    it "reports both a command's own options and its children on a node that has both" do
      node = node_at(spec, group_with_own_command)
      expect(node.children).not_to be_empty
      expect(node.options).not_to be_empty
    end

    it "flags at least one argument as a file argument" do
      all_arguments = spec.nodes.flat_map(&:arguments)
      expect(all_arguments).to include(having_attributes(file: true))
    end

    it "flags at least one argument as not a file argument" do
      all_arguments = spec.nodes.flat_map(&:arguments)
      expect(all_arguments).to include(having_attributes(file: false))
    end

    it "carries values declared on an option" do
      all_options = spec.nodes.flat_map(&:options)
      option_with_values = all_options.find { |option| option.values&.any? }
      expect(option_with_values).not_to be_nil
    end

    it "carries a boolean flag" do
      all_options = spec.nodes.flat_map(&:options)
      expect(all_options).to include(having_attributes(boolean: true))
    end

    it "carries an option alias" do
      all_options = spec.nodes.flat_map(&:options)
      option_with_alias = all_options.find { |option| option.aliases&.any? }
      expect(option_with_alias).not_to be_nil
    end

    it "never reaches outside the registry for data" do
      expect(File).not_to receive(:read)
      described_class.call(registry, program_name: "mycli")
    end
  end

  describe "against SimpleCLI" do
    include_examples "a completion spec",
      registry: Fixtures::SimpleCLI,
      hidden_name: "secret",
      group_with_own_command: "db"
  end

  describe "against PackageManagerCLI" do
    include_examples "a completion spec",
      registry: Fixtures::PackageManagerCLI,
      hidden_name: "publish",
      group_with_own_command: "config"
  end

  describe "against HanamiLikeCLI (not written for this project)" do
    include_examples "a completion spec",
      registry: Fixtures::HanamiLikeCLI,
      hidden_name: "console",
      group_with_own_command: "db"
  end

  describe "the walk example from plan.md §3" do
    subject(:spec) { described_class.call(Fixtures::SimpleCLI, program_name: "mycli") }

    def node_at(*path)
      spec.nodes.find { |node| node.path == path }
    end

    it "lists top-level commands, hidden ones excluded" do
      expect(node_at.children).to contain_exactly("version", "deploy", "db")
    end

    it "lists version's option values" do
      option = node_at("version").options.first
      expect(option.name).to eq("format")
      expect(option.values).to eq(%w[json plain])
    end

    it "lists deploy's alias and enum argument" do
      node = node_at("deploy")
      expect(node.options.first.aliases).to eq(["-f"])
      expect(node.arguments.first.values).to eq(%w[staging production])
    end

    it "lists db's own subcommand" do
      expect(node_at("db").children).to eq(["migrate"])
    end

    it "detects the file argument on db migrate" do
      node = node_at("db", "migrate")
      expect(node.arguments.find { |a| a.name == "file" }.file).to be true
    end
  end

  describe "explicit file: declaration" do
    it "overrides the name heuristic in either direction" do
      command_class = Class.new(Dry::CLI::Command) do
        argument :output, file: true
        argument :path, file: false

        def call(**); end
      end
      registry = Module.new { extend Dry::CLI::Registry }
      registry.register("run", command_class)

      spec = described_class.call(registry, program_name: "mycli")
      node = spec.nodes.find { |n| n.path == ["run"] }

      expect(node.arguments.find { |a| a.name == "output" }.file).to be true
      expect(node.arguments.find { |a| a.name == "path" }.file).to be false
    end
  end
end
