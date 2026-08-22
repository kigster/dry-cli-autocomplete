# dry-cli-autocomplete: specification

Generate static shell completion scripts for any `Dry::CLI` application, from the command registry alone.

The intended use is one line in a shell profile:

```bash
eval "$(mycli completion bash)"    # ~/.bashrc
eval "$(mycli completion zsh)"     # ~/.zshrc
```

The script is regenerated when the shell starts, so a new command in the host application completes as soon as it ships. Pressing TAB runs nothing: the shell matches against a word list the script already carries.

## Design decisions, and the measurements behind them

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

## 9. Work units

This section did not exist when the folder entered Building; an implementer found nothing here to build against and split it before writing any code, per the instruction that governs exactly this case. Four units, non-overlapping in the files they own, matching §8's table. WU1 has no dependency on the others; WU2 and WU3 depend only on WU1's *interface* below, not its code, so they can be built concurrently with each other and with WU1. WU4 integrates all three and is the last to land.

### WU1 — Registry walk and spec builder

Owns: `lib/dry/cli/autocomplete/spec_builder.rb`, `spec/dry/cli/autocomplete/spec_builder_spec.rb`, `spec/support/fixtures/**`.

Builds the fixture registries the whole suite depends on (§5: at least three, at least one from outside this project) and the walker (§3) that turns a registry into the `CompletionSpec` shape defined below. Owns file-argument *detection* (§4.3): the heuristic and any explicit declaration are resolved here, so emitters only ever read a plain `file?` flag and never re-derive it.

Done when: builds a correct spec for every fixture; hidden commands are absent from it; a node with both a command and children reports both (§1.1 acceptance criterion); nothing outside the registry is touched (no file reads, no host constants beyond what `values:` already declared).

### WU2 — bash emitter

Owns: `lib/dry/cli/autocomplete/emitters/bash.rb`, `spec/dry/cli/autocomplete/emitters/bash_spec.rb`.

Consumes a `CompletionSpec` (build one by hand in specs against the documented shape; do not import WU1's fixtures until WU1 has landed) and emits the `complete -F` script per §4.1: `compgen -W` over each node's word list, `compgen -f` where `file?` is set.

Done when: golden-file tests cover a fixture with a nested group, a file argument, an aliased option, and a hidden command absent from output; every golden file passes `bash -n`.

### WU3 — zsh emitter

Owns: `lib/dry/cli/autocomplete/emitters/zsh.rb`, `spec/dry/cli/autocomplete/emitters/zsh_spec.rb`.

Same `CompletionSpec` input as WU2. Emits a native `#compdef` script using `_arguments`/`_describe` (§4.1), carrying each option's `desc`. Not a bashcompinit shim.

Done when: golden-file tests as WU2, output validated with `zsh -n`, and per-option descriptions are visible in the generated `_describe` calls.

### WU4 — Generator and command shim

Owns: `lib/dry/cli/autocomplete/generator.rb`, `lib/dry/cli/autocomplete/command.rb`, `spec/dry/cli/autocomplete/generator_spec.rb`, `spec/dry/cli/autocomplete/command_spec.rb`.

The generator is the small piece that ties a registry to an emitter: given a registry and a shell name, run WU1's spec builder, hand the result to WU2 or WU3's emitter, return the script. `command.rb` is the shim (§2.4): defines the command class, derives the program's shell-identifier with `Dry::Inflector#underscore` (§4.2, never a hand-rolled `gsub`), and `require`s `generator` only inside `#call`.

Done when: the laziness spec from §5 passes (`defined?(Dry::CLI::Autocomplete::Generator)` is `nil` after requiring only `dry/cli/autocomplete/command`); dashed program names produce valid identifiers; the command actually produces working output end-to-end through a real emitter (a stub is fine mid-flight, but the unit is not done while one remains in the diff).

### Interface contract between the units

`SpecBuilder.call(registry, program_name:)` returns a `CompletionSpec`:

- `program_name` — String, the shell-identifier-safe name (already run through `Dry::Inflector#underscore` by whichever unit constructs it — WU4's command shim owns this call, so WU1's builder just accepts the string it's given).
- `nodes` — Array of `{path: Array<String>, options: [...], arguments: [...], children: Array<String>}`, one entry per node in the registry, hidden nodes excluded.
- Each option: `{name:, type:, values:, aliases:, default:, desc:, required:, boolean:, array:}`.
- Each argument: `{name:, values:, desc:, required:, file:}` — `file:` is the resolved boolean described under WU1 above.

`Emitter.call(spec)` (both `Emitters::Bash` and `Emitters::Zsh`) takes one `CompletionSpec` and returns one String: the complete generated script. Neither emitter takes a registry, and neither knows what dry-cli's own API looks like.
