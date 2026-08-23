# frozen_string_literal: true

require_relative "lib/dry/cli/autocomplete/version"

Gem::Specification.new do |spec|
  spec.name = "dry-cli-autocomplete"
  spec.version = Dry::CLI::Autocomplete::VERSION
  spec.authors = ["Konstantin Gredeskoul"]
  spec.email = ["kigster@gmail.com"]

  spec.summary = "A missing auto-complete addition for dry-cli powered Ruby CLI tools for BASH & ZSH"
  spec.description = "Supports auto-completion for dry-cli powered Ruby CLI tools, including sub-commands, in BASH and ZSH."
  spec.homepage = "https://github.com/kigster/dry-cli-autocomplete"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 4.0"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/kigster/dry-cli-autocomplete"
  spec.metadata["changelog_uri"] = "https://github.com/kigster/dry-cli-autocomplete/blob/main/CHANGELOG.md"

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
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml])
    end
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "dry-cli", ">= 1.0"
  spec.add_dependency "dry-inflector", ">= 1.0"
end
