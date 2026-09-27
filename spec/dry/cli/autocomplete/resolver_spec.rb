# frozen_string_literal: true

require "dry/cli/autocomplete/resolver"
require_relative "../../../support/fixtures/simple_cli"

RSpec.describe Dry::CLI::Autocomplete::Resolver do
  subject(:result) { described_class.call(tree, words) }

  let(:tree) { Fixtures::SimpleCLI.tree }

  context "with nothing typed" do
    let(:words) { [""] }

    its(:candidates) { is_expected.to eq(%w[version deploy db]) }
    its(:files) { is_expected.to be(false) }
  end

  context "with no words at all" do
    let(:words) { [] }

    its(:candidates) { is_expected.to eq(%w[version deploy db]) }
  end

  context "with a prefix" do
    let(:words) { ["de"] }

    its(:candidates) { is_expected.to eq(%w[deploy]) }
  end

  context "under a command with subcommands and options" do
    let(:words) { ["db", ""] }

    its(:candidates) { is_expected.to eq(%w[migrate --verbose --no-verbose]) }
  end

  context "after a switch that takes one of the declared values" do
    let(:words) { ["version", "--format", "j"] }

    its(:candidates) { is_expected.to eq(%w[json]) }
    its(:files) { is_expected.to be(false) }
  end

  context "after a switch whose value may be anything" do
    let(:words) { ["db", "migrate", "--step", ""] }

    its(:candidates) { is_expected.to be_empty }
    its(:files) { is_expected.to be(true) }
  end

  context "for a command with a file argument" do
    let(:words) { ["db", "migrate", ""] }

    its(:candidates) { is_expected.to eq(%w[--step]) }
    its(:files) { is_expected.to be(true) }
  end

  context "for a command whose argument declares its values" do
    let(:words) { ["deploy", "p"] }

    its(:candidates) { is_expected.to eq(%w[production]) }
  end

  context "for a boolean switch, which takes no value" do
    let(:words) { ["deploy", "-f", ""] }

    its(:candidates) { is_expected.to include("staging", "--force", "-f") }
  end

  context "with an explicit file: false on an argument named like a file" do
    let(:tree) do
      Module.new do
        extend Dry::CLI::Registry

        register "open", Class.new(Dry::CLI::Command) { argument :path, file: false }
      end.tree
    end
    let(:words) { ["open", ""] }

    its(:files) { is_expected.to be(false) }
  end

  context "with a command registered after the tree was taken" do
    let(:registry) do
      Module.new do
        extend Dry::CLI::Registry

        register "early", Class.new(Dry::CLI::Command)
      end
    end
    let(:tree) { registry.tree }
    let(:words) { ["la"] }

    before { registry.register "late", Class.new(Dry::CLI::Command) }

    its(:candidates) { is_expected.to eq(%w[late]) }
  end

  context "with a hidden command" do
    let(:words) { ["se"] }

    its(:candidates) { is_expected.to be_empty }
  end
end
