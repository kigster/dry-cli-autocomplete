# frozen_string_literal: true

module MyCLI
  module CLI
    # Every command mycli answers to. Each command class lives in a file of
    # its own under commands/, and only this registry knows their names.
    module Commands
      extend Dry::CLI::Registry

      register "version", Version, aliases: ["v", "-v", "--version"]
      register "download-urls", DownloadUrls, aliases: ["download"]
      register "find-hosts", FindHosts, aliases: ["hosts"]
      register "completion", Dry::CLI::Autocomplete::Command[self, program_name: "mycli"]
    end
  end
end
