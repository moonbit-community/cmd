# `cmd`

Common Unix command-line utilities implemented in
[MoonBit](https://www.moonbitlang.com/) for policy-controlled execution.

This repository provides one MoonBit module, `mooxCLI/cmd`, containing
executable packages such as `mooxCLI/cmd/cat` and `mooxCLI/cmd/head`. The
commands are intended for use by the MoonSeek harness through
[moonx](https://github.com/moonbitlang/moon/blob/main/docs/dev/reference/moonx.md)
and [Moonrun](https://github.com/moonbitlang/moon/tree/main/crates/moonrun).

## Status

The repository currently contains 48 root executable packages: the 20-command
upstream snapshot plus three locally implemented expansion batches. The initial
commands and their CLI test suite were migrated from
[`moonbit-community/moonbit-jq`](https://github.com/moonbit-community/moonbit-jq/tree/main/cmd).

The initial migration covers:

```text
base64  cat    comm  cut    false  head  join  jq     jqlog  nl
paste   printf sleep sort   tail   tr    true  uniq   wc     xxd
```

The first read-only expansion batch adds:

```text
echo  pwd  basename  dirname  ls  grep  find  cmp  printenv  test  seq  sha256sum
```

The filesystem mutation batch adds:

```text
mkdir  touch  tee  cp  mv  rm  rmdir  ln
```

The restricted high-authority batch currently provides:

```text
env  xargs  timeout  sh  make  curl  wget  chmod
```

These packages are implemented for explicit policy experiments but are not in
the default MoonSeek allow-list. `env`, `xargs`, `timeout`, `sh`, and `make`
require exact `process.allow` rules for every external child. `sh` and `make`
parse and execute their own languages in MoonBit and support native and Wasm;
they never delegate a complete script to a host interpreter. Network commands
require an explicit network policy, and `chmod` requires an explicit
permission-mutation policy. `chown` and `kill` are intentionally absent from
this repository's package inventory while their runtime primitives are studied
separately.

See the [migration and development plan](docs/migration-plan.md) for the
architecture, migration stages, test strategy, and security acceptance work.
Stages 0-5 are complete for the initial release. Expansion batches 1 and 2 are
allow-listed after policy testing; the retained third batch has restricted
admission and dedicated policy tests. No new release is being published in this
change.

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
- Avoid delegating command behavior to same-named host executables. The `sh`
  and `make` packages implement their parsers and execution control flow in
  MoonBit; only individual recipe commands use policy-visible process APIs.

## Security model

The command implementations are designed to run under Moonrun policy
enforcement. Filesystem, environment, network, and process access must remain
visible to the runtime policy.

This repository supplies auditable command implementations; Moonrun and
`moonx` remain responsible for policy enforcement and policy inheritance across
the execution chain. Commands that can create child processes or expand
authority require dedicated policy integration tests before they can enter a
default harness allow-list. The Wasm allow-list and policy checks live under
`tests/policy/`; CI verifies that file reads and writes are denied or allowed
according to the supplied policy, checks that denied mutations leave no
filesystem side effects, and ensures command packages do not import
process-spawning APIs unless the command is explicitly classified as a
restricted process command. Restricted process and network policy tests live in
`tests/policy/check-third-batch-policy.sh`.

An explicit process rule authorizes the guest's spawn request; it does not by
itself sandbox an arbitrary host child. Until MoonSeek starts children through
a policy-aware inherited boundary, restricted process commands remain outside
the default allow-list. Scoped process rules also authorize the logical program
name rather than the executable eventually selected through `PATH`, so default
policy profiles must avoid unrestricted name-based process launches.

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
sh tests/policy/check-third-batch-policy.sh
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
must repeat the validation process before publication. The removed `chown` and
`kill` experiments are not part of any release.

## License

Licensed under the [Apache License, Version 2.0](LICENSE).
