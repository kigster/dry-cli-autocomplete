# frozen_string_literal: true

require "dry/cli"

module Fixtures
  # A small CLI, authored for this project's own suite. Matches the walk
  # example in .plans/001.00-*/plan.md §3: version, deploy, and a db group
  # with both a bare command and a migrate subcommand.
  module SimpleCLI
    extend Dry::CLI::Registry

    class Version < Dry::CLI::Command
      desc "Print the version"
      option :format, values: %w[json plain], desc: "Output format"

      def call(**); end
    end

    class DbStatus < Dry::CLI::Command
      desc "Show pending migrations"
      option :verbose, type: :boolean, desc: "Print full migration history"

      def call(**); end
    end

    class DbMigrate < Dry::CLI::Command
      desc "Run pending migrations"
      option :step, desc: "Migrate to a specific step"
      argument :file, desc: "Migration file to run"

      def call(**); end
    end

    class Deploy < Dry::CLI::Command
      desc "Deploy the application"
      option :force, type: :boolean, aliases: ["-f"], desc: "Skip confirmation"
      argument :environment, values: %w[staging production], required: true, desc: "Target environment"

      def call(**); end
    end

    class Secret < Dry::CLI::Command
      desc "Internal maintenance command"

      def call(**); end
    end

    register "version", Version
    register "deploy", Deploy
    register "db", DbStatus do |prefix|
      prefix.register "migrate", DbMigrate
    end
    register "secret", Secret, hidden: true
  end
end
