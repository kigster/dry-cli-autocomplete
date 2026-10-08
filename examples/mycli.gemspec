# frozen_string_literal: true

require_relative "lib/mycli/version"

Gem::Specification.new do |spec|
  spec.name = "mycli"
  spec.version = MyCLI::VERSION
  spec.authors = ["Your Name"]
  spec.email = ["your@email.com"]

  spec.summary = "An example dry-cli application: downloads URLs and scans networks for hosts, several at once"
  spec.description = "Shows dry-cli-autocomplete, dry-cli-help and dry-cli-ui working together in one command line tool."
  spec.homepage = "https://github.com/YOU/mycli"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 4.0"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/YOU/mycli"
  spec.metadata["changelog_uri"] = "https://github.com/YOU/mycli/blob/main/CHANGELOG.md"

  # Uncomment the line below to require MFA for gem pushes.
  # This helps protect your gem from supply chain attacks by ensuring
  # no one can publish a new version without multi-factor authentication.
  # See: https://guides.rubygems.org/mfa-requirement-opt-in/
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ examples/ Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml])
    end
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "concurrent-ruby", ">= 1.3"
  spec.add_dependency "dry-cli", ">= 1.0"
  spec.add_dependency "dry-cli-autocomplete", ">= 0.5"
  spec.add_dependency "dry-cli-help", ">= 0.5"
  spec.add_dependency "dry-cli-ui", ">= 0.6"
  spec.add_dependency "zeitwerk", ">= 2.6"
end
