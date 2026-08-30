# cmd

`cmd` is a MoonBit implementation and integration repository for command-line
utilities. It collects executable CLI packages, the shared runtime they use,
and the compatibility and policy tests that keep their behavior consistent.

The repository is organized as a Moon workspace rather than one monolithic
package:

- `cli/core` contains the shared command runtime.
- `cli/<command>` contains one independently published executable per command.
- `tests` contains repository-only compatibility, policy, and process-test
  infrastructure.

The intended consumer experience is direct and composable:

```text
moonx cli/base64
moonx cli/grep --fixed-strings pattern input.txt
moonx cli/jq -r '.name'
```

The command modules target MoonBit's policy-controlled execution environment.
They implement their command behavior in MoonBit and use explicit runtime APIs
for filesystem, process, network, stream, and shell operations. They do not
delegate the command implementation to a same-named host utility.

## Command set

The current source tree contains 48 executable command modules.

### Core command set

These commands originate from the upstream `moonbit-jq/cmd` snapshot:

```text
base64 cat comm cut false head join jq jqlog nl paste printf sleep sort tail
tr true uniq wc xxd
```

### Read-only commands

```text
basename cmp dirname echo find grep ls printenv pwd seq sha256sum test
```

### Filesystem commands

```text
cp ln mkdir mv rm rmdir tee touch
```

### Restricted commands

These commands require explicit policy admission because they can start
processes, access the network, or mutate permissions:

```text
chmod curl env make sh timeout wget xargs
```

`cli/timeout` is currently held back from publication while its process-group
compatibility issue is being resolved. The other command modules follow the
`cli/<command>` publication layout.

`chown` and `kill` are intentionally outside the current scope because their
required owner-mutation and arbitrary-process-signalling primitives are not
part of the supported runtime contract.

## Repository layout

```text
cmd/
|-- moon.work                 # workspace manifest
|-- core/                     # publishable module cli/core
|   |-- moon.mod
|   |-- cli/                  # option parsing and command catalog
|   |-- fsops/                # filesystem helpers
|   |-- netops/               # HTTP response helpers
|   |-- platform/             # platform capability boundary
|   |-- process/              # child-process specifications
|   |-- shell/                # bounded shell parsing and execution
|   `-- stream/               # byte and line-stream helpers
|-- commands/                 # independently published executable modules
|   |-- base64/
|   |-- cat/
|   `-- .../
|-- tests/                    # repository-only validation module
|   |-- compat/               # command compatibility runner
|   |-- policy/               # Wasm policy runner
|   |-- testkit/              # native process test harness
|   `-- cram/                 # compatibility examples and provenance
|-- docs/                     # compatibility and release documentation
`-- README.mbt.md
```

Every directory under `commands/` is a module with its own `moon.mod` and an
executable `moon.pkg`. Its filesystem location is an implementation detail;
its public module coordinate is always `cli/<command>`.

`core/` is the only shared published implementation module. The command
manifests depend on `cli/core@0.1.0`; while developing in this repository, the
workspace resolves that coordinate to the local `./core` member. `tests/` has a
separate module manifest so its test harness can import the same public core
packages, but it is never published.

## Runtime and policy model

The shared runtime is split into focused packages:

- `cli/core/cli` provides the common option grammar, command catalog, and
  command-facing types.
- `cli/core/fsops` provides bounded path inspection, traversal, copying, and
  removal helpers.
- `cli/core/netops` provides streaming HTTP response handling.
- `cli/core/platform` records portable capability boundaries.
- `cli/core/process` describes child working directories, environment, and I/O.
- `cli/core/shell` provides the bounded lexer, parser, expansion, built-ins,
  redirections, and pipelines used by `sh` and `make`.
- `cli/core/stream` provides byte chunks and line scanning that preserves final
  line termination state.

Commands that only need input and read access remain in the default admission
tier. Process, network, and permission-mutation commands are explicitly
allow-listed in the restricted tier. Denied operations fail closed with a
nonzero status and do not silently fall back to a host command.

The implementation supports native and Wasm targets where declared by each
package. The `jq` and `jqlog` modules additionally depend on
`bobzhang/moonjq@0.1.1` for their jq parser and AST functionality.

## Development

Install MoonBit, then run the following commands from the repository root:

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

The compatibility runner executes the 48 command implementations against the
repository's behavior cases. The policy runner executes Wasm commands with
explicit resource policies and checks both permitted and denied operations.
Generated `pkg.generated.mbti` interfaces are committed and refreshed by
`moon info`.

When adding or changing a command, update its implementation, `moon.pkg`,
README, generated interface, catalog admission, compatibility cases, and policy
coverage as applicable. Keep command behavior, error output, exit status, and
target declarations under test.

## Publishing

The shared runtime must be published before command modules that depend on it:

```bash
export MOON_HOME="$HOME/.moon-accounts/cli"
moon whoami
moon update
moon -C core publish
moon -C commands/base64 publish
moon -C commands/cat publish
```

Repeat the last command for the command modules to release. Each command is
published independently as `cli/<command>`; the repository root and `tests/`
module are not publishable packages.

After `cli/core` has been published, remove `"./core"` from `moon.work` when
testing only against the registry version. Keep the command manifests' public
dependency coordinate unchanged:

```text
cli/core@0.1.0
```

For account switching, set `MOON_HOME` on each Moon command or export it for
the current shell. Moon credentials are independent of GitHub credentials.
See [docs/publishing.md](docs/publishing.md) for the complete release and
account workflow.

## Project status

The previously published `mooxCLI/cmd@0.1.3` package is the historical
whole-tree release. The current checkout is the split workspace described
above; it should not be republished as a new `mooxCLI/cmd` package.

## License

Licensed under the [Apache License 2.0](LICENSE).
