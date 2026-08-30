# `cmd` Historical Migration and Development Plan

> Historical note: the original migration described a single root module. The
> historical release remains available as a frozen compatibility release, while
> the current source tree is a workspace that publishes commands independently
> as `cli/<command>` modules. See
> `docs/publishing.md` for the current release layout.

Repository: <https://github.com/moonbit-community/cmd>
Module: `mooxCLI/cmd`
Upstream command source: <https://github.com/moonbit-community/moonbit-jq/tree/main/cmd>
Imported baseline: `06a529211343c773d30d2c3aa0231a2456665b7a` (2026-08-25)

## 1. Purpose and scope

`cmd` is a versioned collection of common Unix command-line utilities written
in MoonBit for policy-controlled execution. The repository owns command
implementations, package boundaries, command-facing tests, and policy behavior
that can be expressed through the available runtime APIs.

The project defines neither a policy engine nor a process supervisor. It also
does not promise complete compatibility with every Unix or GNU implementation.
This plan records only the command behavior, requested capabilities, package
layout, and validation maintained in this repository.

### Goals

1. Keep the historical command snapshot reproducible.
2. Expose each command as an independent `cli/<command>` module.
3. Preserve documented stdout, stderr, argument, and exit-code behavior.
4. Prefer Wasm-compatible implementations and policy-visible resource APIs.
5. Add common commands in batches ordered by their requested authority.
6. Ship reproducible command behavior and policy regression tests.

### Non-goals

1. Implement every GNU Coreutils option or every Unix command.
2. Reimplement a policy engine or process supervisor in this module.
3. Forward complete scripts or command lines to an external shell or utility.
4. Provide compatibility packages under historical `bobzhang/<command>` names.
5. Move the MoonJQ parser and AST libraries into this repository.
6. Include `chown` or `kill` until their required runtime primitives and
   policy semantics are part of the supported package scope.

## 2. Module and package architecture

The historical root `moon.mod` defined the frozen compatibility module:

```moonbit
name = "mooxCLI/cmd"
preferred_target = "wasm"
```

Each command directory also has a `moon.mod`, executable `moon.pkg`,
implementation sources, a README, and a generated `pkg.generated.mbti`. The
published module coordinate is:

| Repository path | Package coordinate |
|---|---|
| `commands/cat/` | `cli/cat` |
| `commands/grep/` | `cli/grep` |
| `core/fsops/` | `cli/core/fsops` |

Command implementations do not call same-named executables. The current
workspace keeps shared behavior in the publishable `core` module:

- `core/cli` freezes the option grammar and 48-command catalog.
- `core/fsops` provides bounded path inspection, copying, traversal, and
  deletion helpers for filesystem commands.
- `core/netops` provides streaming HTTP response handling for `curl` and
  `wget`.
- `core/platform` records portable capability boundaries.
- `core/process` describes explicit child cwd, minimum environment, and I/O.
- `core/shell` provides MoonBit lexer, parser, expansion, built-ins,
  redirections, pipelines, and individual process requests for `sh` and `make`.
- `core/stream` provides byte chunks and a line scanner that preserves the
  final-line termination state.
- `tests/testkit` provides the native direct-process test harness and remains
  outside the published `cli/core` module.

The independently published command modules import the `cli/core` module with
packages such as `cli/core/cli`. During local development the workspace binds
that coordinate to `./core`; after publication it resolves from Mooncakes.

The `jq` and `jqlog` packages use the root dependency
`bobzhang/moonjq@0.1.1`. The dependency namespace is independent of this
module's public package namespace.

## 3. Command inventory

### Upstream baseline: 20 commands

```text
base64 cat comm cut false head join jq jqlog nl paste printf sleep sort tail
tr true uniq wc xxd
```

The source snapshot and original package versions are recorded in
`docs/provenance.md`. In the historical release, destination coordinates were
`mooxCLI/cmd/<command>`; the current destination coordinates are
`cli/<command>`.

### Batch 1: read-only commands

```text
echo pwd basename dirname ls grep find cmp printenv test seq sha256sum
```

These 12 packages support native and Wasm targets and are allow-listed. Tests
cover argument parsing, path handling, stdin, binary data, large input,
comparison results, fixed-point sequence formatting, digest validation, and
denied reads.

### Batch 2: filesystem mutation commands

```text
mkdir touch tee cp mv rm rmdir ln
```

These eight packages support native and Wasm targets and are allow-listed. Tests
cover normal operation, documented options, invalid input, nested directories,
streaming input, denied mutations, and symbolic-link safety.

Portable behavior has four deliberate boundaries:

- `ln` creates symbolic links only; hard links require an unavailable runtime
  primitive.
- `mv` uses policy-visible rename and does not fall back to copy-and-delete
  across filesystems.
- `cp` accepts regular files and directory trees, and rejects symbolic-link or
  special-file sources.
- `touch` updates existing regular files without rewriting their contents;
  timestamp changes for directories, links, and special files are not exposed.

### Batch 3: restricted authority

```text
env xargs timeout sh make curl wget chmod
```

These eight packages are implemented for explicit policy tests and are not in
the default allow-list. `env`, `xargs`, `timeout`, `sh`, and `make` request
individual child processes; `curl` and `wget` request network access; `chmod`
requests permission mutation. Each request is tested under denial and under a
narrowly matching authorization rule.

`sh` and `make` implement their supported language subsets in MoonBit. Parsing,
expansion, dependency control flow, and error handling stay inside the package;
only individual recipe or script commands are passed to the process API.

`chown` and `kill` are research-only capabilities and are absent from the
package tree, policy inventory, test suite, and release artifacts. They must
not be represented as command packages until the required policy-checked
runtime primitives are part of the supported API.

## 4. Test architecture

The test system has four layers, all implemented in MoonBit:

1. MoonBit unit and white-box tests for parsers, helpers, and data handling.
2. `tests/compat` directly starts all 48 native release binaries, checks byte
   output and exit codes, and provides GNU differential and stress modes.
3. `tests/policy` starts Wasm commands under deny and narrow allow policies and
   verifies denied operations have no side effects.
4. The catalog admission checks verify native+Wasm declarations, authority
   tiers, unsafe host paths, direct-child contracts, and the `timeout`
   process-group release gate.

The imported `tests/cram/coreutils.md`, `tests/cram/cli.md`, and `TUTORIAL.md`
remain compatibility examples and migration provenance. They are useful during
manual migration review but are no longer CI execution sources.

Generated interfaces are part of the review surface. `moon info` must leave no
unexpected `pkg.generated.mbti` diff, and `moon fmt` must leave no formatting
diff.

### Required validation

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

These commands use the active MoonBit toolchain and account configuration.

## 5. Migration stages

### Stage 0: freeze provenance (complete)

- Pin the upstream command source to commit
  `06a529211343c773d30d2c3aa0231a2456665b7a`.
- Record the 20 source commands, source versions, tests, and license context.

Acceptance: `docs/provenance.md` identifies the snapshot and destination
module.

### Stage 1: establish the root module (complete, historical)

- Set `name = "mooxCLI/cmd"`, `preferred_target = "wasm"`, and one module
  version in `moon.mod`.
- Consolidate only dependencies required by the command packages.
- The current split supersedes this stage by adding command-level modules and a
  workspace manifest.

Acceptance: all package dependencies resolve from the root module.

### Stage 2: migrate the upstream commands (complete, historical)

- Move each upstream `cmd/<name>/` directory to root `<name>/`.
- Keep the implementation, README, executable package metadata, and generated
  interface.
- Historical examples used `mooxCLI/cmd/<name>`; current examples use
  `cli/<name>`.

Acceptance: all 20 root packages build and retain their documented behavior.

### Stage 3: migrate tests and CI (complete)

- Keep upstream Cram and tutorial files as non-executable provenance.
- Run executable compatibility and policy cases through MoonBit runners.
- Require fixed Linux, macOS 15 arm64, and Windows runner images.
- Require check, formatting, generated-interface, target, compatibility, and
  policy validation.

Acceptance: the complete validation sequence passes with a clean worktree.

### Stage 4: add policy coverage (complete for the current source tree)

- Test permitted and denied file reads and writes under Wasm.
- Verify allow-listed packages do not import process-spawning APIs.
- Keep process, network, and permission-mutation commands in restricted Batch 3.
- Verify restricted commands do not silently substitute another executable for
  their implementation.

Acceptance: the MoonBit policy runner passes and denied operations leave no
observable side effect.

### Stage 5: publish the initial module (complete)

The initial release is `mooxCLI/cmd@0.1.0`. It contains the upstream 20-command
baseline. Expansion batches in the current source tree require a deliberate
versioned release decision and are not published by this documentation change.

## 6. Release and maintenance rules

1. `cli/core` is published before command modules that depend on it.
2. Each `cli/<command>` module has its own version and release notes.
3. Release notes list the commands and policy behavior changed.
4. Generated interfaces, formatted sources, compatibility cases, and policy
   tests are reviewed together with implementation changes.
5. Credentials and machine-local account settings stay outside the repository.
6. The `cat` implementation is accepted as-is; no special repair gate is
   required for it.
7. `chown` and `kill` remain outside the package and release scope.

## 7. Current definition of done

The current source tree is complete when:

- 48 executable modules are present as `cli/<command>` workspace members.
- The 20 upstream commands, 12 Batch 1 commands, and eight Batch 2 commands
  have native+Wasm coverage and the intended policy admission.
- The eight Batch 3 commands have restricted Cram and policy coverage.
- `chown` and `kill` are absent from package, policy, test, and release lists.
- `jq` and `jqlog` continue to use `bobzhang/moonjq` at their `cli/<command>`
  module coordinates.
- `moon check`, `moon info`, `moon fmt`, `moon test`, the compatibility runner,
  GNU differential subset, stress cases, and policy runner pass.
- README, this plan, and provenance describe only the command module's scope.
- `make`, `sh`, and `xargs` are releasable with documented direct-child
  semantics; `timeout` remains unreleased until its process-group cancellation
  contract is implementable without adding another language or FFI.
