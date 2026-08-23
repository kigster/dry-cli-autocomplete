## [Unreleased]

## [0.1.2] - 2026-08-22

- The bash script now completes values declared on an option. `mycli fmt --format` then TAB offered the command list again instead of the values `--format` accepts; zsh had always emitted them, so only the bash side was dropping them.
- The bash script now offers values declared on a positional argument at that position, alongside the node's flags and subcommands.

## [0.1.1] - 2026-08-22

- Fixed loading inside any host that has dry-struct loaded. The value objects were built from a bare `Struct`, which resolves to `Dry::Struct` from inside `module Dry`, so `mycli completion bash` raised `wrong number of arguments` on the host's machine while this gem's own suite stayed green.
- Value objects are `Data` rather than `Struct`: frozen, and a missing field raises instead of arriving as a silent nil.

## [0.1.0] - 2026-08-22

- Initial release
