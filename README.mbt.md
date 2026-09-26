# cmd

`cmd` is an integrated collection of command-line utilities implemented in
MoonBit. It provides executable command modules, a shared runtime, and a test
system for preserving GNU/POSIX and command-upstream behavior. Authorization
belongs to the caller or host; commands preserve the caller's environment and
stream semantics.

**0.2.0 is published** as `cli/core` and 47 command modules. The workspace now
contains 59 command modules, including twelve local-only P0 additions awaiting
publication. Linux, macOS and
Windows passed the release source checks, including Linux Native/Wasm pinned
oracle comparisons. Exact-version MoonX acceptance is recorded separately in
the [release evidence](docs/reports/2026-09-21-release-0.2.0/README.md). See the
[support record](docs/compatibility.md), and
[upstream API gaps](docs/async-upstream-gaps.md). This release includes a
persistent line-oriented `sh -i`, real `make -j` scheduling, JSON input framing,
Basic HTTP authentication and cookies. Strict filesystem limits are explicit:
default `cp` and existing-file `touch` cannot be implemented faithfully with
the current public metadata APIs; see ADR-0004.

The current workspace adopts MoonBit 2026-09-20 and async 0.22.4, and corrects curl/wget custom
Cookie plus jar behavior using the two public HTTP header layers. These changes
are not included in published 0.2.0. See the [API recheck](docs/async-upstream-gaps.md)
and the [common-command inventory and proposed priorities](docs/command-coverage.md),
including the current P0 additions and the remaining command-gap inventory.

Releasable commands are available as independent modules under
`cli/<command>`:

```text
MOON_HOME="$HOME/.moon-accounts/cli" moonx cli/base64@0.2.0
MOON_HOME="$HOME/.moon-accounts/cli" moonx cli/grep@0.2.0 -- pattern input.txt
MOON_HOME="$HOME/.moon-accounts/cli" moonx cli/jq@0.2.0 -- -r '.name'
```

## Commands

The repository contains 59 executable commands for local builds. The current
Mooncakes registry exposes 47 of them through MoonX. The local-only commands
`base32`, `cksum`, `expand`, `mktemp`, `realpath`, `rev`, `tac`, `tree`, `unexpand`, `unlink`, `yes` and
`timeout` await publication; `timeout` additionally remains outside the
releasable profile because portable process-group cancellation is not available.

### Text and data

```text
base32 base64 cat cksum cmp comm cut expand grep head join jq jqlog nl paste printf rev
sha256sum sort tac tail tr uniq wc xxd
```

### Files and paths

```text
basename cp dirname find ln ls mkdir mktemp mv realpath rm rmdir tee touch tree
unexpand unlink
```

### Environment and execution

```text
chmod echo env false make printenv seq sh sleep test timeout true wget curl
xargs yes
```

Commands implement their behavior in MoonBit and use explicit runtime APIs for
filesystem, streams, processes, networking, and platform capabilities. They do
not delegate their implementation to a same-named host command.

## Controlled execution

The command set is designed for native and Wasm execution. Under Wasm, commands
can run with explicit policies that limit filesystem access, mutations,
processes, network access, and permission changes.

The caller configures host authorization. Command capability declarations
describe their requirements and do not add a command-level policy. Host-denied
operations fail with a nonzero status; the policy suite checks the resulting
effects independently of command compatibility.

The repository does not yet provide `chown` or `kill`: public owner mutation
and signal sending with observable errors are missing. These are implementation
boundaries; the host remains responsible for authorization.

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
|   |-- runner/           # workspace compat, policy, and oracle runner
|   |-- release_runner/   # exact published MoonX versions
|   |-- cases/            # shared active command contracts and oracle fixtures
|   |-- testkit/          # process test utilities
|   `-- fixtures/         # runner manifests and policy profiles
|-- docs/                 # behavior and provenance documentation
`-- moon.work             # MoonBit workspace manifest
```

The `core` module provides the shared packages used by command implementations.
The `tests` module remains repository-internal and contains no user-facing
command packages.

## Test system

The project combines package tests and two runners sharing a Native testkit:

- MoonBit unit and white-box tests for parsers and shared runtime packages.
- `compat` retains the Native compatibility groups with stable selectable IDs.
- `contract` runs shared per-command input/output/status contracts against
  Native or Wasm artifacts; explicit rejection boundaries are counted separately.
- `policy` executes pre-built Wasm artifacts through `moonrun --policy` and
  verifies allowed and denied resource access.
- `oracle` compares Native and Wasm commands with the pinned upstream image,
  including declared metadata observations. GNU and stress are independent suites.
- `release_runner` validates candidate manifests and checks exact published
  MoonX versions selected by `published-0.2.0.json`; frozen 0.1.x manifests remain
  available for historical replay.
- `scenarios` covers persistent shell input, HTTP auth/cookies, filesystem
  boundaries and process/make lifecycle on both backends in CI. Former standalone
  probes are archived with their assertion migration maps.

Generic filesystem snapshots cover paths, kinds and regular-file bytes;
explicit observers cover mode, fixed timestamps, symlink targets and fixture
link relationships. Missing required observations cannot certify compatibility.
See the
[test entry-point guide](tests/README.md) for coverage and execution limits.

Run the standard local checks from the repository root, serially:

```bash
MOON_HOME="$HOME/.moon-accounts/cli" moon update
MOON_HOME="$HOME/.moon-accounts/cli" moon check --target all --deny-warn
MOON_HOME="$HOME/.moon-accounts/cli" moon test --target all
MOON_HOME="$HOME/.moon-accounts/cli" moon build --target native --release --deny-warn
MOON_HOME="$HOME/.moon-accounts/cli" moon build --target wasm --release --deny-warn
./_build/native/release/build/mooxCLI/cmd-tests/runner/runner.exe --suite compat
./_build/native/release/build/mooxCLI/cmd-tests/runner/runner.exe --suite policy
./_build/native/release/build/mooxCLI/cmd-tests/release_runner/release_runner.exe --manifest tests/release_runner/candidate-0.2.0.json --suite validate
MOON_HOME="$HOME/.moon-accounts/cli" moon info
MOON_HOME="$HOME/.moon-accounts/cli" moon fmt
```

This sequence excludes the Docker oracle, published-package checks and manual
scenario probes; it is not the complete release acceptance suite.

See [Compatibility](docs/compatibility.md) for measured command support and
platform behavior, and [Provenance](docs/provenance.md) for the source of
the imported command implementations.

## License

Licensed under the [Apache License 2.0](LICENSE).
