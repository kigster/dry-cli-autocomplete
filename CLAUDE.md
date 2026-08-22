# CLAUDE.md

Guidance for Claude Code (claude.ai/code) working in this repository.

## What this is

A Ruby gem that generates static shell completion scripts for any `Dry::CLI` application. A host registers one command; `mycli completion bash` prints a script; the user evaluates it from a shell profile.

**Read `SPECIFICATION.md` first.** It carries the design decisions, the measurements behind them, and the acceptance criteria. This file covers how to work in the repository; that one covers what to build and why.

The gem is a skeleton from `bundle gem` with no implementation yet. Nothing in `lib/` does anything.

## Environment

Ruby is managed by rbenv. Prefix every Ruby command:

```bash
eval "$(rbenv init -)" && bundle exec rspec
```

```bash
bundle install
bundle exec rspec              # the suite
bundle exec rubocop            # the linter
bundle exec rubocop -a         # autocorrect
bundle exec rake               # both, and the default task
bin/console                    # IRB with the gem loaded
```

The gemspec sets `required_ruby_version >= 3.2.0` and `.rubocop.yml` sets `TargetRubyVersion: 3.2`. Keep the two in step: raising one without the other produces a linter that permits syntax the gemspec claims to support, or the reverse.

## The trap that has already bitten this repository once

`bundle gem dry-cli-autocomplete` generates `module Dry; module Cli`. **dry-cli declares `Dry::CLI`, and it is a class, not a module.** Reopening a class as a module raises `TypeError` the moment both are loaded, and the error names neither file usefully.

Six files were generated wrong and have been fixed. If you add a file under `lib/dry/cli/`, nest it as:

```ruby
module Dry
  class CLI          # class, and CLI is an acronym
    module Autocomplete
```

`lib/dry/cli/autocomplete/version.rb` deliberately does **not** `require "dry/cli"`, because the gemspec loads it at build time when the dependency may not be installed. It reopens `class CLI` on its own. dry-cli's `CLI` inherits from `Object`, so an empty reopening is compatible whichever loads first.

For deriving names at runtime, use `dry-inflector`. `Dry::Inflector.new { |i| i.acronym("CLI") }` handles both the casing above and the `underscore` needed for shell function identifiers. `Dry::CLI::Inflector` ships with dry-cli but only has `dasherize` and is marked `@api private`; do not depend on it.

## Architecture

Four pieces, and the boundary between the first and the rest is load-bearing.

| File                                        | Role                                                                                                                                  |
| ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/dry/cli/autocomplete/command.rb`       | The shim a host registers. Defines the command class and nothing else. `require`s the generator **inside `#call`**, never at the top. |
| `lib/dry/cli/autocomplete/spec_builder.rb`  | Walks a registry through public API and returns a shell-agnostic description of every completion.                                     |
| `lib/dry/cli/autocomplete/emitters/bash.rb` | Turns that description into a `complete -F` script.                                                                                   |
| `lib/dry/cli/autocomplete/emitters/zsh.rb`  | Turns it into a native `#compdef` script with per-option descriptions.                                                                |

Two rules hold this shape together, both measured rather than assumed:

- **The command shim loads no emitter.** A host pays nothing at boot for a command run once per shell. `SPECIFICATION.md` §2.4.
- **The spec builder touches only the registry.** It must be safe to run at shell startup, because it runs at every shell startup. `SPECIFICATION.md` §2.2.

The emitters take the same description and share no code. A fourth shell should be a new emitter class, never a branch inside an existing one.

## Conventions

- **The generator is not a hot path.** It runs in 0.067ms against a 27-command registry. Do not optimise it, do not add native extensions, and do not cache anything. The reasoning is in `SPECIFICATION.md` §2.3.
- **Public API only when reading a registry.** `registry.get(path)` returns a result exposing `command`, `children` and `names`. `instance_variable_get(:@node)` is what the gem this one replaces does, and it will break on a dry-cli release.
- **Test against registries this project did not write.** A generator tested against one CLI encodes that CLI's shape. `SPECIFICATION.md` §5.
- **Validate generated shell with the shell.** `bash -n` and `zsh -n` parse without executing. A regex over generated output proves nothing about whether it runs.
- **Commit messages**: imperative mood, 50-character subject, no full stop. A body only where the change needs explaining, saying what and why.
- **Writing prose here**: no em dashes, active voice, plain words. Say what a thing does, not how it feels. If a sentence could appear unchanged in another project's README, it says nothing about this one and should go.

## Repository layout

| Path                                  | What it is                                                                                                        |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `SPECIFICATION.md`                    | What to build, why, and what "done" means                                                                         |
| `lib/dry/cli/autocomplete.rb`         | Entry point                                                                                                       |
| `lib/dry/cli/autocomplete/version.rb` | Version, loaded standalone by the gemspec                                                                         |
| `sig/`                                | RBS signatures, generated by `bundle gem` and not yet real                                                        |
| `exe/dry-cli-autocomplete`            | Generated by `bundle gem`. **Probably should be deleted**: this is a library, and a host provides the executable. |
| `.github/workflows/main.yml`          | CI                                                                                                                |

## Before the first release

The gemspec still carries `bundle gem` TODOs that will refuse to build: `spec.summary`, `spec.description`, and `spec.metadata["allowed_push_host"]`. The `dry-` prefix and the `Dry::CLI::Autocomplete` namespace imply an affiliation with dry-rb that does not exist, so say so in the README, or ask them first.
