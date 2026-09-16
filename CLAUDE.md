# CLAUDE.md

Guidance for Claude Code (claude.ai/code) working in this repository.

## What this is

A Ruby gem that generates static shell completion scripts for any `Dry::CLI` application. A host registers one command; `mycli completion bash` prints a script; the user evaluates it from a shell profile.

**Read `SPECIFICATION.md` first.** It carries the design decisions, the measurements behind them, and the acceptance criteria. This file covers how to work in the repository; that one covers what to build and why.

The gem is implemented and released (tags `v0.1.0` through `v0.1.3`). `README.md` documents the host-facing behaviour; keep it in step with `lib/` when behaviour changes.

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
bundle exec rake               # the suite only; it is the default task and what CI runs
bundle exec rake doc           # YARD documentation
bin/console                    # IRB with the gem loaded
```

The gemspec sets `required_ruby_version >= 4.0`, `.rubocop.yml` sets `TargetRubyVersion: 4.0`, and CI runs Ruby 4.0.6. Keep them in step: raising one without the other produces a linter that permits syntax the gemspec claims to support, or the reverse.

## The trap that has already bitten this repository once

`bundle gem dry-cli-autocomplete` generates `module Dry; module Cli`. **dry-cli declares `Dry::CLI`, and it is a class, not a module.** Reopening a class as a module raises `TypeError` the moment both are loaded, and the error names neither file usefully.

Six files were generated wrong and have been fixed. If you add a file under `lib/dry/cli/`, nest it as:

```ruby
module Dry
  class CLI          # class, and CLI is an acronym
    module Autocomplete
```

`lib/dry/cli/autocomplete/version.rb` deliberately does **not** `require "dry/cli"`, because the gemspec loads it at build time when the dependency may not be installed. It reopens `class CLI` on its own. dry-cli's `CLI` inherits from `Object`, so an empty reopening is compatible whichever loads first.

The same lexical scoping bites constants. Every file here sits inside `module Dry`, so a bare `Struct` or `Data` resolves to `Dry::Struct` or `Dry::Data` first when a host has loaded them. Write `::Data` and `::Struct`. `spec/dry/cli/autocomplete/dry_struct_host_spec.rb` loads dry-struct to catch this.

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

`SpecBuilder` returns frozen `::Data` values: a `CompletionSpec` holding one `Node` per visible command or group, each with `OptionSpec` and `ArgumentSpec` entries. An argument is a file argument when it declares `file: true`, or, with no `file:` key, when its name matches `/file|path/i`.

The emitters take the same description and share no code. A fourth shell should be a new emitter class, never a branch inside an existing one.

## Conventions

- **The generator is not a hot path.** It runs in 0.067ms against a 27-command registry. Do not optimise it, do not add native extensions, and do not cache anything. The reasoning is in `SPECIFICATION.md` §2.3.
- **Read a registry through its methods, not its ivars.** `registry.get(path)` returns a result exposing `command`, `children` and `names`. `instance_variable_get(:@node)` is what the gem this one replaces does, and it will break on a dry-cli release. Do not mistake this for a public API: in 1.4.1 `Registry#get`, all of `CommandRegistry`, every `LookupResult` reader and every `Node` reader carry `@api private`. There is no public way to enumerate a registry, so an upgrade can break the walk and the fixture suite is what catches it.
- **Test against registries this project did not write.** A generator tested against one CLI encodes that CLI's shape. `SPECIFICATION.md` §5.
- **Validate generated shell with the shell.** `bash -n` and `zsh -n` parse without executing. A regex over generated output proves nothing about whether it runs. `spec/support/shell_helpers.rb` skips a missing shell locally and fails on CI.
- **Emitter output is pinned by golden files** in `spec/support/golden/`. A deliberate output change means updating the golden file in the same commit.
- **The bash emitter targets bash 3.2.** macOS ships it as `/bin/bash`, so no associative arrays.
- **The zsh script works both from `$fpath` and from `eval`.** Its footer checks `$funcstack[1]` against the function name, so the function must stay named `_<program>`.
- **Commit messages**: imperative mood, 50-character subject, no full stop. A body only where the change needs explaining, saying what and why.
- **Writing prose here**: no em dashes, active voice, plain words. Say what a thing does, not how it feels. If a sentence could appear unchanged in another project's README, it says nothing about this one and should go.

## Repository layout

| Path                                  | What it is                                                                           |
| ------------------------------------- | ------------------------------------------------------------------------------------ |
| `SPECIFICATION.md`                    | What to build, why, and what "done" means                                            |
| `README.md`                           | Host-facing documentation                                                            |
| `CHANGELOG.md`                        | Release notes                                                                        |
| `lib/dry/cli/autocomplete.rb`         | Entry point for `require "dry/cli/autocomplete"`. Hosts require `command.rb` instead |
| `lib/dry-cli-autocomplete.rb`         | Bundler-style entry point, requires the one above                                    |
| `lib/dry/cli/autocomplete/version.rb` | Version, loaded standalone by the gemspec                                            |
| `sig/`                                | RBS signatures. Only `VERSION` is declared so far                                    |
| `spec/support/fixtures/`              | Registries the suite walks, including shapes modelled on other CLIs                  |
| `spec/support/golden/`                | Expected bash and zsh output, compared byte for byte                                 |
| `.github/workflows/main.yml`          | CI: installs zsh, runs `bundle exec rake`                                            |
| `.github/workflows/rubocop.yml`       | CI: runs `bundle exec rubocop`                                                       |

## Releasing

Bump `VERSION` in `lib/dry/cli/autocomplete/version.rb`, add a `CHANGELOG.md` entry, then `bundle exec rake release`. The gemspec requires MFA for pushes. The `dry-` prefix and the `Dry::CLI::Autocomplete` namespace imply an affiliation with dry-rb that does not exist; the README says so, and that note should stay.
