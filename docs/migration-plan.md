# `cmd` Migration and Development Plan

> Status: The initial release stages are complete. The current source tree has
> 48 command packages: Batches 1-2 are allow-listed and Batch 3 is restricted.

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

1. Keep every command in one module, `mooxCLI/cmd`.
2. Expose commands as root packages such as `mooxCLI/cmd/cat`.
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

The root `moon.mod` is the only module definition:

```moonbit
name = "mooxCLI/cmd"
preferred_target = "wasm"
```

Each command directory has an executable `moon.pkg`, implementation sources,
a README, and a generated `pkg.generated.mbti`. The package path is the module
name followed by the directory name:

| Repository path | Package coordinate |
|---|---|
| `cat/` | `mooxCLI/cmd/cat` |
| `grep/` | `mooxCLI/cmd/grep` |
| `internal/fsops/` | private implementation package |

Command implementations do not call same-named executables. Shared behavior is
private and lives under `internal/`:

- `internal/fsops` provides bounded path inspection, copying, traversal, and
  deletion helpers for filesystem commands.
- `internal/netops` provides streaming HTTP response handling for `curl` and
  `wget`.
- `internal/shell` provides MoonBit lexer, parser, expansion, built-ins,
  redirections, pipelines, and individual process requests for `sh` and `make`.

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
`docs/provenance.md`. Source module names are provenance only; destination
coordinates are always `mooxCLI/cmd/<command>`.

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

The test system has four layers:

1. MoonBit unit and white-box tests for parsers, helpers, and data handling.
2. Cram command tests in `tests/cram/` for executable behavior, output, and
   exit codes.
3. Wasm policy smoke tests in `tests/policy/check-wasm-policy.sh` for denied
   and permitted filesystem access and mutation side effects.
4. Restricted Batch 3 policy tests in
   `tests/policy/check-third-batch-policy.sh` for process, network, and
   permission requests.

The imported `tests/cram/coreutils.md`, `tests/cram/cli.md`, and `TUTORIAL.md`
remain the regression baseline. Local batch files extend that baseline:
`batch1.md` has read-only commands, `batch2.md` has filesystem mutations, and
`batch3.md` has restricted authority commands.

Generated interfaces are part of the review surface. `moon info` must leave no
unexpected `pkg.generated.mbti` diff, and `moon fmt` must leave no formatting
diff.

### Required validation

```bash
moon update
moon check --target all --deny-warn
moon info
moon fmt
moon test --target all
moon cram test tests/cram TUTORIAL.md
sh tests/policy/check-wasm-policy.sh
sh tests/policy/check-third-batch-policy.sh
```

The repository-local `AGENTS.md` supplies the machine-specific Moon home for
these commands. That local account configuration is not part of this plan.

## 5. Migration stages

### Stage 0: freeze provenance (complete)

- Pin the upstream command source to commit
  `06a529211343c773d30d2c3aa0231a2456665b7a`.
- Record the 20 source commands, source versions, tests, and license context.

Acceptance: `docs/provenance.md` identifies the snapshot and destination
module.

### Stage 1: establish the root module (complete)

- Set `name = "mooxCLI/cmd"`, `preferred_target = "wasm"`, and one module
  version in `moon.mod`.
- Consolidate only dependencies required by the command packages.
- Remove command-level module files and do not add a `moon.work` file.

Acceptance: all package dependencies resolve from the root module.

### Stage 2: migrate the upstream commands (complete)

- Move each upstream `cmd/<name>/` directory to root `<name>/`.
- Keep the implementation, README, executable package metadata, and generated
  interface.
- Rewrite public examples to `mooxCLI/cmd/<name>`.

Acceptance: all 20 root packages build and retain their documented behavior.

### Stage 3: migrate tests and CI (complete)

- Keep the upstream Cram and tutorial structure.
- Add the root package paths to executable test commands.
- Require check, formatting, generated-interface, target, and Cram validation.

Acceptance: the complete validation sequence passes with a clean worktree.

### Stage 4: add policy coverage (complete for the current source tree)

- Test permitted and denied file reads and writes under Wasm.
- Verify allow-listed packages do not import process-spawning APIs.
- Keep process, network, and permission-mutation commands in restricted Batch 3.
- Verify restricted commands do not silently substitute another executable for
  their implementation.

Acceptance: both policy scripts pass and denied operations leave no observable
side effect.

### Stage 5: publish the initial module (complete)

The initial release is `mooxCLI/cmd@0.1.0`. It contains the upstream 20-command
baseline. Expansion batches in the current source tree require a deliberate
versioned release decision and are not published by this documentation change.

## 6. Release and maintenance rules

1. One module version covers all command packages in a release.
2. A command fix increments the module patch version; a compatible command or
   feature addition increments the minor version.
3. Release notes list the commands and policy behavior changed.
4. Generated interfaces, formatted sources, Cram cases, and policy tests are
   reviewed together with implementation changes.
5. Credentials and machine-local account settings stay outside the repository.
6. The `cat` implementation is accepted as-is; no special repair gate is
   required for it.
7. `chown` and `kill` remain outside the package and release scope.

## 7. Current definition of done

The current source tree is complete when:

- 48 executable packages are present directly under the root module.
- The 20 upstream commands, 12 Batch 1 commands, and eight Batch 2 commands
  have native+Wasm coverage and the intended policy admission.
- The eight Batch 3 commands have restricted Cram and policy coverage.
- `chown` and `kill` are absent from package, policy, test, and release lists.
- `jq` and `jqlog` continue to use `bobzhang/moonjq` without changing the
  public `mooxCLI/cmd/<command>` coordinates.
- `moon check`, `moon info`, `moon fmt`, `moon test`, both policy scripts, and
  the complete Cram suite pass.
- README, this plan, and provenance describe only the command module's scope.
