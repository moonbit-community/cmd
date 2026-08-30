# cmd

`cmd` is an integrated collection of command-line utilities implemented in
MoonBit. It provides executable command modules, a shared runtime, and a test
system for compatibility and policy-controlled execution.

Each command is available as an independent module under `cli/<command>`:

```text
moonx cli/base64
moonx cli/grep pattern input.txt
moonx cli/jq -r '.name'
```

## Commands

The repository currently contains 48 executable commands.

### Text and data

```text
base64 cat cmp comm cut grep head join jq jqlog nl paste printf sha256sum
sort tail tr uniq wc xxd
```

### Files and paths

```text
basename cp dirname find ln ls mkdir mv pwd rm rmdir tee touch
```

### Environment and execution

```text
chmod echo env false make printenv seq sh sleep test timeout true wget curl
xargs
```

Commands implement their behavior in MoonBit and use explicit runtime APIs for
filesystem, streams, processes, networking, and platform capabilities. They do
not delegate their implementation to a same-named host command.

## Controlled execution

The command set is designed for native and Wasm execution. Under Wasm, commands
can run with explicit policies that limit filesystem access, mutations,
processes, network access, and permission changes.

Commands that only read input use the default admission tier. Commands that
spawn processes, access the network, or change permissions require explicit
authorization. Denied operations fail with a nonzero status and are tested to
leave no unintended side effects.

The repository intentionally does not provide `chown` or `kill`, because the
required owner-mutation and arbitrary-process-signalling capabilities are not
part of the current controlled runtime contract.

## Structure

```text
cmd/
|-- core/                 # shared command runtime
|   |-- cli/              # option parsing and command catalog
|   |-- fsops/            # filesystem helpers
|   |-- netops/           # network helpers
|   |-- platform/         # platform capability boundary
|   |-- process/          # child-process specifications
|   |-- shell/            # shell parsing and execution
|   `-- stream/           # byte and line-stream helpers
|-- commands/             # one executable module per command
|-- tests/
|   |-- compat/           # command compatibility runner
|   |-- policy/           # Wasm policy runner
|   |-- testkit/          # process test utilities
|   `-- cram/             # compatibility examples
|-- docs/                 # behavior and provenance documentation
`-- moon.work             # MoonBit workspace manifest
```

The `core` module provides the shared packages used by command implementations.
The `tests` module remains repository-internal and contains no user-facing
command packages.

## Test system

The project uses four complementary test layers:

- MoonBit unit and white-box tests for parsers and shared runtime packages.
- A native compatibility runner that executes every command and checks stdout,
  stderr, and exit status.
- A Wasm policy runner that verifies allowed and denied resource access.
- GNU differential and stress modes for selected compatible behavior and large
  inputs.

Run the complete local validation from the repository root:

```bash
moon update
moon check --target all --deny-warn
moon test --target all
moon build --target native --release --deny-warn
moon run --target native tests/compat -- --bin-root _build/native/release/build
moon run --target native tests/policy -- --root .
moon info
moon fmt
```

See [Compatibility](docs/compatibility.md) for the supported command dialect
and platform behavior, and [Provenance](docs/provenance.md) for the source of
the imported command implementations.

## License

Licensed under the [Apache License 2.0](LICENSE).
