# frozen_string_literal: true

require "dry/cli"

module Fixtures
  # A package-manager-shaped CLI, authored for this project's own suite.
  # Different shape from SimpleCLI: the nested group with a bare command
  # sits at "config" rather than "db", and an array argument is exercised.
  module PackageManagerCLI
    extend Dry::CLI::Registry

    class Install < Dry::CLI::Command
      desc "Install one or more packages"
      argument :packages, type: :array, desc: "Package names to install"
      option :save_dev, type: :boolean, aliases: ["-D"], desc: "Save as a dev dependency"
      option :registry, values: %w[npm yarn pnpm], desc: "Registry to use"

      def call(**); end
    end

    class ConfigShow < Dry::CLI::Command
      desc "Print the current configuration"
      option :format, values: %w[json yaml], desc: "Output format"

      def call(**); end
    end

    class ConfigLoad < Dry::CLI::Command
      desc "Load configuration from a file"
      argument :path, required: true, desc: "Path to a config file"

      def call(**); end
    end

    class Publish < Dry::CLI::Command
      desc "Publish the package (internal, gated behind a flag)"

      def call(**); end
    end

    register "install", Install
    register "config", ConfigShow do |prefix|
      prefix.register "load", ConfigLoad
    end
    register "publish", Publish, hidden: true
  end
end
