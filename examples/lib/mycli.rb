# frozen_string_literal: true

require "dry/cli"
require "dry/cli/help"
require "dry/cli/ui"
require "dry/cli/autocomplete/command"
require "zeitwerk"

# A sample dry-cli application: two commands that show off dry-cli-ui's
# concurrent widgets, and the completion command this repository provides.
module MyCLI
end

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect("mycli" => "MyCLI", "cli" => "CLI", "http" => "HTTP")
loader.setup

MyCLI::CLI::HelpSettings.apply
