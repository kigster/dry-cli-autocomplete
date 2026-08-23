## [Unreleased]

## [0.1.1] - 2026-08-22

- Fixed loading inside any host that has dry-struct loaded. The value objects
  were built from a bare `Struct`, which resolves to `Dry::Struct` from inside
  `module Dry`, so `mycli completion bash` raised `wrong number of arguments`
  on the host's machine while this gem's own suite stayed green.
- Value objects are `Data` rather than `Struct`: frozen, and a missing field
  raises instead of arriving as a silent nil.

## [0.1.0] - 2026-08-22

- Initial release
