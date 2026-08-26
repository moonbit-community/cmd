# `cmd`

Wasm-first Unix command-line utilities implemented in
[MoonBit](https://www.moonbitlang.com/) for policy-controlled execution.

This repository provides one MoonBit module, `mooxCLI/cmd`, containing
executable packages such as `mooxCLI/cmd/cat` and `mooxCLI/cmd/head`. The
commands are intended for use by the MoonSeek harness through
[moonx](https://github.com/moonbitlang/moon/blob/main/docs/dev/reference/moonx.md)
and [Moonrun](https://github.com/moonbitlang/moon/tree/main/crates/moonrun).

## Status

The initial command migration is complete for the fixed upstream snapshot. The
repository imports the existing command implementations and their CLI test
suite from
[`moonbit-community/moonbit-jq`](https://github.com/moonbit-community/moonbit-jq/tree/main/cmd).

The initial migration covers:

```text
base64  cat    comm  cut    false  head  join  jq     jqlog  nl
paste   printf sleep sort   tail   tr    true  uniq   wc     xxd
```

See the [migration and development plan](docs/migration-plan.md) for the
architecture, migration stages, test strategy, and security acceptance work.
Stage 3 CLI/CI migration and Stage 4 policy smoke coverage are complete for
this snapshot.

## Package layout

All commands belong to the single `mooxCLI/cmd` module. Each command is an
executable package directly under the repository root:

```text
cmd/
|-- moon.mod              # name = "mooxCLI/cmd"
|-- cat/
|   |-- moon.pkg          # executable package mooxCLI/cmd/cat
|   |-- main.mbt
|   `-- README.md
|-- head/
|-- jq/
`-- ...
```

Command directories do not contain separate `moon.mod` files. Module-level
dependencies and versions are managed once in the root `moon.mod`.

After the first release, commands will be runnable through pinned coordinates:

```bash
moonx mooxCLI/cmd/cat@0.1.0 -- README.md
moonx mooxCLI/cmd/head@0.1.0 -- -n 10 README.md
```

## Goals

- Port commonly used Unix commands to MoonBit.
- Prefer Wasm execution and explicit runtime-visible resource access.
- Preserve predictable stdout, stderr, argument, and exit-code behavior.
- Keep implementations streaming or bounded-memory where practical.
- Provide a versioned command surface that a harness can allow-list and audit.
- Avoid delegating command behavior to same-named host executables.

## Security model

The command implementations are designed to run under Moonrun policy
enforcement. Filesystem, environment, network, and process access must remain
visible to the runtime policy.

This repository supplies auditable command implementations; Moonrun and
`moonx` remain responsible for policy enforcement and policy inheritance across
the execution chain. Commands that can create child processes or expand
authority require dedicated policy integration tests before they can enter a
default harness allow-list. Native-only commands, including the currently
planned `jqlog` package, are not enabled by default. The fixed snapshot's
Wasm allow-list and policy checks live under `tests/policy/`; CI verifies that
file reads are denied or allowed according to the supplied policy and that
command packages do not import process-spawning APIs.

## Development

The project carries the upstream Moon Cram CLI suite and CI checks. The standard
local validation sequence is:

```bash
moon update
moon check --deny-warn
moon info
moon fmt
moon test --target all
moon cram test tests/cram TUTORIAL.md
sh tests/policy/check-wasm-policy.sh
```

Use the repository-local `AGENTS.md` tooling rule when selecting the Moon home
for local commands.

When adding a command, include its executable `moon.pkg`, implementation,
README, generated interface, and CLI tests. Test native and Wasm targets where
supported, including invalid arguments, stdin, missing files, binary data, and
large inputs as applicable.

## Publishing

The module is published from the `mooxCLI` Mooncakes account as
`mooxCLI/cmd`. All executable packages share the module version. Publishing
credentials and account-selection details must remain outside the repository.
The initial `mooxCLI/cmd@0.1.0` release has been published; later releases
must repeat the validation process before publication.

## License

Licensed under the [Apache License, Version 2.0](LICENSE).
