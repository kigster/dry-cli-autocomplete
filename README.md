# dry-cli-autocomplete

[![Ruby](https://github.com/kigster/dry-cli-autocomplete/actions/workflows/main.yml/badge.svg)](https://github.com/kigster/dry-cli-autocomplete/actions/workflows/main.yml)
![Coverage](docs/img/badge.svg)

Shell completion for [dry-cli](https://github.com/dry-rb/dry-cli) applications, with no Ruby in the TAB path.

> [!NOTE]
> 
> For the specification of this gem see [SPECIFICATION](SPECIFICATION.md)

Your CLI knows its own commands, options, aliases and enum values. The shell does not. This gem walks your registry once, prints a bash or zsh script, and you source it from your profile. Pressing TAB then spawns nothing and costs nothing, because every completion the script will ever offer is already inside it.

```bash
mycli completion bash > /usr/local/etc/bash_completion.d/mycli
```

## The problem

A dry-cli app with nested subcommands gives the shell nothing to work with. `mycli db <TAB>` completes filenames from the current directory, which is never what you wanted.

[`rngtng/dry-cli-completion`](https://github.com/rngtng/dry-cli-completion) already solves part of this, and it is worth reading before you reach for this gem. It falls short in four ways, and each one is an acceptance criterion here.

**A group that has both a command and children loses the children.** Register an overview command at a group's bare name so `mycli db --help` can explain the group, and its subcommands stop completing:

```ruby
register "db", DbStatus         # the node now has a command
register "db migrate", Migrate  # ...and children, which never get walked
```

`mycli db <TAB>` then offers `--help` and nothing else. This is what any app does when it wants group-level help.

**File arguments vanish.** `Input#input_line` returns early on `<file>`, so a command with a path argument produces no `compgen -f`, no `-o default`, no `_filedir`. Completing a path is the single most common thing a user wants from a CLI, and it is the one thing that does not work.

**The entry point is not free.** `command.rb` opens with a require that pulls the generator, which pulls `completely`. Every host pays for that at boot. Measured: `require "dry/cli"` costs 160ms, and adding the completion gem takes it to 190ms. Thirty milliseconds on every single invocation, for a command that runs once per shell.

**zsh is a bashcompinit shim.** It emits `autoload -Uz +X bashcompinit && bashcompinit` followed by bash. That works, but zsh users get no per-option descriptions and none of the behaviour they expect from a native completion.

There is a dependency argument too. `completely` pulls `colsole`, `docopt_ng` and `mister_bin`, and `mister_bin` is itself a CLI framework. That is four gems, one of them a second CLI framework, to print a shell script. This gem depends on `dry-cli` and `dry-inflector`, and nothing else.

## What it generates

Given this registry:

```ruby
register "version", Version
register "deploy", Deploy
register "db", DbStatus do |prefix|
  prefix.register "migrate", DbMigrate
end
register "secret", Secret, hidden: true
```

`mycli completion bash` prints a `complete -F` function that dispatches on the command path:

```bash
_mycli_completions() {
  # ...walks COMP_WORDS to find the current command path...
  words=""
  case "$path" in
    "") words="version deploy db" ;;
    "version") words="--format" ;;
    "deploy") words="--force -f" ;;
    "db") words="migrate --verbose" ;;
  esac

  COMPREPLY=($(compgen -W "$words" -- "$cur"))
  case "$path" in
    "db migrate") COMPREPLY+=($(compgen -f -- "$cur")) ;;
  esac
}
complete -F _mycli_completions mycli
```

Read what that output proves. `db` offers `migrate` alongside its own `--verbose`, so a group with both a command and children keeps both. `db migrate` gets real file completion. `secret` is absent, because hidden commands stay hidden. The `-f` alias on `deploy` is there because you declared it.

`mycli completion zsh` prints a native `#compdef` script built on `_arguments` and `_describe`, carrying each option's `desc` as help text next to it.

Enum values declared on an option or argument come through at no cost:

```ruby
option :format, values: %w[json yaml table]    # completes json yaml table
argument :component, values: %w[major minor]   # completes major minor
```

## Installation

```bash
gem install dry-cli-autocomplete
```

Or add it to your `Gemfile`.

Then register the command in your CLI. Require the command file, not the gem:
it pulls in no emitter and no generator, so a host pays nothing at boot for a
command that runs once per shell.

```ruby
require "dry/cli/autocomplete/command"

module MyCLI
  extend Dry::CLI::Registry

  register "version", Version
  register "deploy", Deploy
  register "completion", Dry::CLI::Autocomplete::Command[MyCLI]
end
```

That require pulls in the command class and nothing else. No emitter loads until someone actually runs `mycli completion`.

Then have your users write the script once and source it. For bash:

```bash
mycli completion bash > /usr/local/etc/bash_completion.d/mycli
```

For zsh, put it anywhere on your `$fpath`:

```bash
mycli completion zsh > "${fpath[1]}/_mycli"
```

Regenerate it when you add or rename commands. Nothing watches for changes, by design.

## Why the script is static

Cobra and clap route every TAB press to a hidden `__complete` subcommand. That is the right call for a Go or Rust binary that starts in 10ms. It is the wrong call here.

| Measurement                                               |           Time |
| --------------------------------------------------------- | -------------: |
| Bare `ruby -e ''`                                         |          100ms |
| `require "dry/cli"`                                       |          160ms |
| `require "dry/cli"` + `dry-cli-completion` + `completely` |          190ms |
| `require "tax_engine"` (a heavy host)                     |          520ms |
| First touch of that host's data store                     |         +239ms |
| **Registry walk and full completion spec build**          |    **0.067ms** |
| Generated bash script for 27 commands                     | 257 lines, 9KB |

Half a second of dead air per keystroke is unusable, and no amount of lazy loading gets under the host's own require cost. So there is no `__complete` command. It was considered, costed at roughly 90 lines, and rejected on that table.

The same table explains two other decisions. The generator will not be optimised, because at 0.067ms it is 0.01% of the cheapest possible invocation and all the time goes to interpreter startup. Native extensions were rejected for the same reason, plus they would put a compiled artifact in every consumer's dependency chain.

## What it will not do

**Values your host has to compute.** The walk touches only objects dry-cli already holds. The moment an option's `values:` calls into your data layer, that cost lands at class-definition time on *every* invocation, not just completion. In the profiled host that meant 239ms of YAML parsing added to shell startup. Declare the values on the option, where dry-cli validates against them anyway and the generator sees them free.

**fish, PowerShell, nushell.** Worth adding later. The emitter interface is built so a fourth shell is a new class rather than a new branch in an existing one.

**Watch your registry.** Regenerating is your call, in your release process.

## Development

Ruby 3.2 or newer. This repository uses rbenv, so activate it first:

```bash
eval "$(rbenv init -)"
bundle install
bundle exec rspec       # the suite
bundle exec rubocop     # the linter
bundle exec rake        # both
bin/console             # IRB with the gem loaded
```

Two conventions in the suite are worth knowing before you add to it. Fixtures include registries this project did not write, because a generator tested against one CLI quietly encodes that CLI's shape. And generated scripts are validated by the shells themselves, with `bash -n` and `zsh -n` parsing without executing, since a regex over the output proves nothing about whether it runs.

## Contributing

Bug reports and pull requests are welcome at <https://github.com/kigster/dry-cli-autocomplete>.

> [!WARNING]
>
> A quick note on the name. The `dry-` prefix and the `Dry::CLI::Autocomplete` namespace do not imply endorsement by `dry-rb`. This is an independent gem that extends theirs. I hope this functionality will make it into `dry-cli` one day, however.


## License

MIT. See [LICENSE.txt](LICENSE.txt).
