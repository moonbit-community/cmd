# `cmd`

Common Unix command-line utilities implemented in [MoonBit](https://www.moonbitlang.com/).

This repository provides standalone, Wasm-first command modules for use by
[MoonSeek](https://github.com/moonbitlang/moon) and
[Moonrun](https://github.com/moonbitlang/moon/tree/main/crates/moonrun).
Commands are designed to make file, environment, and process access explicit
and policy-controlled inside a sandbox.

## Goals

- Port commonly used Unix commands to MoonBit.
- Keep each command independently buildable and publishable as a Mooncake.
- Prefer streaming implementations that work well with large inputs.
- Preserve predictable command-line behavior, including stdout, stderr, and
  exit codes.
- Provide a command surface that a harness can allow-list and audit.

## Command layout

Each command lives in its own module under `cmd/` and is intended to be
invoked through `moonx`, for example:

```bash
moonx bobzhang/cat -- README.md
```

The repository will first collect the existing migrated commands from
[`moonbit-community/moonbit-jq`](https://github.com/moonbit-community/moonbit-jq/tree/main/cmd),
then continue with additional common utilities. Existing package names such as
`bobzhang/cat` remain stable so callers can migrate without changing their
command references.

## Security model

The command implementations are intended to run under Moonrun policy
enforcement. A command must not silently delegate to a host executable to
perform the same operation, and operations that access the filesystem,
environment, network, or child processes must remain visible to the runtime
policy.

Commands that can create child processes or otherwise expand authority require
additional policy and integration tests before they are enabled by default in
a harness.

## Development

From the repository root:

```bash
moon check
moon test
moon fmt
moon info
```

When adding a command, include its module metadata, README, and tests. Test
both native and Wasm targets where the command supports them, and cover empty
input, binary data, invalid arguments, missing files, stdin handling, and
large inputs.

## License

Licensed under the [Apache License, Version 2.0](LICENSE).
