# frozen_string_literal: true

require "dry/cli"

module Fixtures
  # Modeled on the public command shape of Hanami's CLI (hanami/cli), a
  # dry-cli consumer this project did not write: version, a db group with
  # status and migrate, a generate group with a command-level alias, and
  # a hidden console shortcut. SPECIFICATION.md §5 requires at least one
  # fixture that did not originate with this project's own assumptions.
  module HanamiLikeCLI
    extend Dry::CLI::Registry

    class Version < Dry::CLI::Command
      desc "Print the framework version"

      def call(**); end
    end

    class DBStatus < Dry::CLI::Command
      desc "Show pending migrations"
      option :verbose, type: :boolean, desc: "Print full migration history"

      def call(**); end
    end

    class DBMigrate < Dry::CLI::Command
      desc "Run pending migrations"
      argument :migration_file, desc: "Migration file to run"
      option :dry_run, type: :boolean, aliases: ["-n"], desc: "Print without running"

      def call(**); end
    end

    class GenerateMigration < Dry::CLI::Command
      desc "Generate a new migration file"
      argument :name, required: true, desc: "Migration name"
      option :format, values: %w[ruby sql], desc: "Migration file format"

      def call(**); end
    end

    class Console < Dry::CLI::Command
      desc "Start a console (internal shortcut, undocumented)"

      def call(**); end
    end

    register "version", Version
    register "db", DBStatus do |prefix|
      prefix.register "migrate", DBMigrate
    end
    register "generate", aliases: ["g"] do |prefix|
      prefix.register "migration", GenerateMigration
    end
    register "console", Console, hidden: true
  end
end
