# dry-cli-autocomplete: specification

Generate static shell completion scripts for any `Dry::CLI` application, from the command registry alone.

The intended use is one line in a shell profile:

```bash
eval "$(mycli completion bash)"    # ~/.bashrc
eval "$(mycli completion zsh)"     # ~/.zshrc
```

The script is regenerated when the shell starts, so a new command in the host application completes as soon as it ships. Pressing TAB runs nothing: the shell matches against a word list the script already carries.

## Research

For `dry-cli` gems there is no automatic auto-complete today. There is third party gem [https://github.com/rngtng/dry-cli-completion](https://github.com/rngtng/dry-cli-completion), but it brings several unwanted dependencies and only suppors bash.



## Goals 

## 1. Why this exists when `dry-cli-completion` already does

`rngtng/dry-cli-completion` (MIT, v2.0.0) works and is the obvious starting point. Read it before writing anything. It falls short in four specific ways, each of which is an acceptance criterion below.

**1.1 A node carrying both a command and children loses its children.** `Input#extract_commands` branches `if sub_node.command ... elsif sub_node.children`. An application that registers an overview command at a group's bare name, so that `mycli db --help` can explain what the group is for, gets:

```ruby
register "db", DbOverview      # node now has a command
register "db migrate", Migrate # ...and children, which are never walked
```

Completion for `mycli db <TAB>` offers `--help` and nothing else. The subcommands are invisible. This is not exotic: it is what any application does when it wants group-level help.

**1.2 File arguments are dropped silently.** `Input#input_line` opens with `return if name.include?("<file>")`. A command whose argument name matches `/path/` produces no entry at all, and the generated script contains no `compgen -f`, no `-o default`, no `_filedir`. So `mycli deploy <TAB>` on a path argument completes nothing, which is the single most common thing a user wants.

**1.3 There is no light entry point.** `command.rb` opens with `require "dry/cli/completion"`, which loads the generator, which loads `completely`. A host that only wants to register the command pays for the whole tree at boot. Measured: `require "dry/cli"` is 160ms, adding the completion gem makes it 190ms. Thirty milliseconds on every invocation of a command run once per shell.

**1.4 zsh is a bashcompinit shim.** It emits `autoload -Uz +X bashcompinit && bashcompinit` and then bash. It works, but zsh users get no per-option descriptions and none of the native behaviour they expect.

There is also a dependency argument. `completely` pulls `colsole`, `docopt_ng` and `mister_bin`, and `mister_bin` is itself a CLI framework. Four gems, one of them a second CLI framework, to emit a shell script. This gem generates the script itself and depends on `dry-cli` and `dry-inflector` only.

## 2. Design decisions, and the measurements behind them

These were settled by profiling a real dry-cli application (`tax_engine`, 27 commands, 33 options, 7 arguments). Reproduce them before overturning any of this.

| Measurement                                               |           Time |
| --------------------------------------------------------- | -------------: |
| Bare `ruby -e ''`                                         |          100ms |
| `require "dry/cli"`                                       |          160ms |
| `require "dry/cli"` + `dry-cli-completion` + `completely` |          190ms |
| `require "tax_engine"` (a heavy host)                     |          520ms |
| First touch of that host's data store                     |         +239ms |
| **Registry walk and full completion spec build**          |    **0.067ms** |
| Generated bash script for 27 commands                     | 257 lines, 9KB |

### 2.1 Static generation, never a runtime callback

Cobra and clap route every TAB press to a hidden `__complete` subcommand. That is correct for a Go or Rust binary that starts in 10ms. It is wrong here: a Ruby host costs 100ms at absolute best and 520ms in the case measured above. Half a second of dead air per keystroke is unusable, and no amount of lazy loading gets under the host's own require cost.

So the generated script carries every completion it will ever offer, and TAB spawns no process. **Do not add a `__complete` command.** It was considered, costed at about 90 lines, and rejected on this measurement.

### 2.2 The generator reads the registry and never forces anything beyond it

The full walk plus spec build takes 0.067ms because it only touches objects dry-cli already holds. The moment an option's `values:` calls into a host's data, that cost lands at class-definition time on *every* invocation of the host, not just completion. In the profiled host that would have added 239ms of YAML parsing to shell startup.

Enum values *declared on an option* are free and must be included:

```ruby
option :format, values: %w[json yaml table]   # completes json yaml table
argument :component, values: %w[major minor]  # completes major minor
```

Values a host would have to compute are out of scope. There is no API for them. A host that wants them declares them as a constant on the option, where dry-cli validates the input and the generator sees it for free.

### 2.3 Optimising the generator is pointless

At 0.067ms, the work this gem does is 0.01% of the cheapest possible invocation. Native extensions were considered and rejected: they cannot reduce interpreter startup, which is where all the time goes, and they would put a compiled artifact in the dependency chain of every consumer. Keep it plain Ruby.

### 2.4 Nothing loads until the command runs

The host registers a command whose file pulls in no emitters:

```ruby
require "dry/cli/autocomplete/command"
register "completion", Dry::CLI::Autocomplete::Command[MyCLI]
```

`command.rb` must define the command class and nothing else, and `require` the generator inside `#call`. This is the mistake in §1.3 and it cannot be retrofitted politely, so build it this way from the first commit. Verified working: after registering the shim, `defined?(Dry::CLI::Autocomplete::Generator)` is nil and `$LOADED_FEATURES` shows nothing, until the command is invoked.

## 3. Reading a registry

Everything needed is public API. **Do not use `instance_variable_get(:@node)`**, which is what the existing gem does. `Registry#get` returns a lookup result exposing `command`, `children` and `names`.

This walk is proven against a foreign registry:

```ruby
def walk(registry, path = [], acc = [])
  result = registry.get(path)
  acc << [path, result.command, (result.children || {}).keys]
  (result.children || {}).each_key { |name| walk(registry, path + [name], acc) }
  acc
end
```

Available per command: `.options` and `.arguments`. Per option: `name`, `type`, `values`, `aliases`, `default`, `desc`, `required?`, `boolean?`, `array?`. Per argument: `name`, `values`, `desc`, `required?`. Per node: `children`, `command`, `aliases`, `hidden`.

Registering with `hidden: true` keeps a command out of `--help`; **the generator must skip hidden commands too**.

Run against a registry with three commands, one of them nested, this produces:

```
(root)       -> version deploy db
version      -> --format json plain
deploy       -> --force -f staging production
db           -> migrate
db migrate   -> --step <file>
```

Note what that output demonstrates: the `-f` alias, enum values on both an option and an argument, a nested group with no command of its own, and a file argument detected.

## 4. What the generated scripts must do

### 4.1 Both shells, natively

**bash** emits a `complete -F _mycli_completions mycli` function using `compgen -W` over the word list for the current command path, plus `compgen -f` where an argument takes a file.

**zsh** emits a real `#compdef` script using `_arguments` and `_describe`, carrying each option's `desc` as help text. It is not a bashcompinit shim. This is the largest single piece of work in the gem, roughly 120 lines, and it is the reason the gem exists rather than a patch to the existing one.

### 4.2 Program names that are not identifiers

A host may be installed as `my-tool`. Shell function names cannot contain a dash, so derive the identifier with `Dry::Inflector#underscore` rather than a hand-rolled `gsub`. `Dry::CLI::Inflector` ships with dry-cli but only has `dasherize` and is marked `@api private`; do not use it.

### 4.3 File arguments

An argument whose name suggests a path should complete filenames. Matching on the name (`/file|path/`) is a heuristic and a poor one. Prefer letting the host be explicit, and fall back to the heuristic only when nothing is declared. Whatever the mechanism, the generated script must contain real file completion, which is the gap in §1.2.

## 5. Testing

**Never test only against one CLI.** A generator tested against a single registry bakes in that registry's shape. The suite must carry at least three fixture registries, and at least one must come from outside this project. Candidates: the examples in dry-cli's own repository, and Hanami's CLI.

Each fixture must exercise: a nested group with a command at its bare name (§1.1), a file argument (§1.2), an option with `values`, a boolean flag, an option with an alias, and a hidden command.

Validate generated output by running the shells, not by matching strings: `bash -n script` and `zsh -n script` both parse without executing. Golden-file the scripts so a change in output is visible in review.

Pin the laziness contract with a spec, because it erodes silently:

```ruby
it "loads no emitter until the command runs" do
  expect(defined?(Dry::CLI::Autocomplete::Generator)).to be_nil
end
```

## 6. Acceptance criteria

1. A node with both a command and children completes its children *and* its own options.
1. Commands with file arguments produce real file completion in the generated script.
1. `require "dry/cli/autocomplete/command"` loads no generator and no emitter.
1. zsh output is a native `#compdef` script with per-option descriptions, not a bashcompinit shim.
1. `bash -n` and `zsh -n` accept the generated scripts.
1. Hidden commands do not appear.
1. Program names containing dashes produce valid shell identifiers.
1. Generating completions touches nothing outside the registry.
1. Runtime dependencies are `dry-cli` and `dry-inflector`, and nothing else.
1. The suite passes against at least one registry not written for this project.

## 7. Out of scope

- A `__complete` hidden command or any per-TAB process. See §2.1.
- Values that require the host to load data. See §2.2.
- Native extensions. See §2.3.
- fish, PowerShell, nushell. Worth adding later; the emitter interface should make a fourth shell a new class rather than a new branch, but do not build them now.

## 8. Scope estimate

About 470 lines, most of it the zsh emitter and the specs.

| Part                               | Lines |
| ---------------------------------- | ----: |
| Registry walk and spec builder     |    60 |
| bash emitter                       |    60 |
| zsh emitter                        |   120 |
| Command shim and installation help |    30 |
| Specs, including foreign fixtures  |   200 |

Suggested order: walk, then bash, then zsh. The bash emitter proves the spec builder against a real shell quickly, and the zsh emitter is where the estimate is most likely to be wrong.
