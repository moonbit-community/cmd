# `cmd` Migration and Development Plan

> Status: Stages 0-5 complete for the fixed upstream snapshot
>
> Repository: <https://github.com/moonbit-community/cmd>
>
> Published module: `mooxCLI/cmd`
>
> Upstream source: <https://github.com/moonbit-community/moonbit-jq/tree/main/cmd>
>
> Proposed import baseline: `06a529211343c773d30d2c3aa0231a2456665b7a`
> (2026-08-25)

## 1. Context

MoonSeek is building a harness on top of Moonrun. A parent process can be
restricted by a Moonrun policy, but a child process that does not inherit the
same effective policy may gain additional host authority and invalidate the
parent sandbox restrictions.

The `cmd` project does not implement the Moonrun policy engine. It provides a
single, versioned distribution of auditable, Wasm-first command-line utilities
so the harness can reduce its dependency on host commands and uncontrolled
native child processes. Moonrun and `moonx` remain responsible for propagating
and enforcing policy throughout the execution chain.

The first project milestone is to migrate the existing commands and their test
system from `moonbit-community/moonbit-jq`. The long-term work is to port the
additional common commands required by MoonSeek.

## 2. Goals and scope

### 2.1 Initial milestone

1. Import all 20 existing commands from the upstream `cmd/` directory.
2. Import the command-related Cram tests, executable documentation, and CI
   checks with the implementations.
3. Publish all commands from one module, `mooxCLI/cmd`.
4. Expose commands as executable packages directly under the repository root;
   for example, `cat/` becomes `mooxCLI/cmd/cat`.
5. Preserve existing CLI behavior, stdout, stderr, and exit codes.
6. Make this repository the maintenance source for the migrated commands.

### 2.2 Long-term goals

1. Add common Unix-style commands according to actual MoonSeek requirements.
2. Let the harness control tools through a pinned module version and a package
   allow-list.
3. Prefer Wasm execution and runtime-visible APIs for filesystem, environment,
   and other external access.
4. Apply stricter admission and integration testing to commands that write
   files, use the network, or create child processes.

### 2.3 Non-goals

1. The initial milestone will not implement all GNU Coreutils commands or all
   options of each migrated command.
2. This repository will not implement or duplicate the Moonrun policy engine.
3. The initial milestone will not add a shell, command interpreter, or generic
   host-command forwarding facility.
4. The new module will not provide compatibility wrappers for
   `bobzhang/<command>` coordinates.
5. The mechanical import will not rewrite command implementations that already
   work.
6. The MoonJQ parser, AST, and library unit tests will not move here. The `jq`
   and `jqlog` packages will depend on the published `bobzhang/moonjq` module.

## 3. Architecture decisions

### 3.1 One module with multiple executable packages

The repository has one root module:

```moonbit
name = "mooxCLI/cmd"
```

Each command directory at the repository root is an executable package inside
that module. For `cat`, the mapping is:

| Item | Upstream | After migration |
|---|---|---|
| Source directory | `cmd/cat/` | `cat/` |
| Module | `bobzhang/cat` | `mooxCLI/cmd` |
| Executable package | Module root package | `mooxCLI/cmd/cat` |
| `moonx` invocation | `moonx bobzhang/cat` | `moonx mooxCLI/cmd/cat` |

Consequences:

- The repository contains only the root `moon.mod`.
- The imported per-command `moon.mod` files are removed.
- A `moon.work` file is not required to combine command modules.
- Each command retains its own `moon.pkg`, source, README, and generated
  interface.
- Module dependencies from the upstream command modules are consolidated into
  the root `moon.mod`.
- All commands share the same `mooxCLI/cmd` version.

### 3.2 Publishing account and ownership

The module and all executable packages are published through the `mooxCLI`
Mooncakes account. The project is currently maintained by one person, so this
plan does not define multi-maintainer approval or shared publishing access.

Before publishing:

1. Verify that the root `moon.mod` name is `mooxCLI/cmd`.
2. Verify that the module version matches the intended Git tag.
3. Complete all check, test, Cram, and package-content validation.
4. Confirm that the worktree is clean and the package comes from a committed
   revision.
5. Confirm that the configured `mooxCLI` publishing account is selected
   locally.
6. Keep publishing tokens, account-selection details, and local credentials
   out of the Git repository.

Publishing-account setup is complete for the current maintainer. The local
account-selection procedure is intentionally omitted from public
documentation.

MoonBit module naming and publishing rules are documented in the
[official module documentation](https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html).

### 3.3 No compatibility coordinate in the new module

README files, examples, and user-facing commands in this repository use
`mooxCLI/cmd/<command>`. Historical `bobzhang/<command>` coordinates appear
only in provenance records and do not remain as compatibility entry points.

Examples after publication:

```bash
moonx mooxCLI/cmd/cat -- README.md
moonx mooxCLI/cmd/head -- -n 10 README.md
```

### 3.4 `jq` and `jqlog` dependency boundary

This repository owns the `mooxCLI/cmd/jq` and `mooxCLI/cmd/jqlog` executable
entry points. Their jq implementation remains an external dependency; it does
not need to move or change namespace.

The root `moon.mod` declares:

```moonbit
import {
  "bobzhang/moonjq@0.1.1"
}
```

The `jq/moon.pkg` and `jqlog/moon.pkg` files then import
`bobzhang/moonjq`. Depending on a personally published module does not change
the clean `mooxCLI/cmd/<command>` interface presented by this repository.

### 3.5 `cat` migrates without a fix gate

The current `cat` implementation has no known defect that must be fixed as
part of this migration. It will be imported as-is together with its existing
multi-file concatenation and binary-transparency tests.

### 3.6 Wasm-first, not Wasm-only

- The root module keeps `preferred_target = "wasm"`.
- Packages that currently support `native+wasm` retain both targets.
- The harness defaults to Wasm commands and must not silently fall back to
  native execution.
- `jqlog` supports both native and Wasm execution and is included in the
  default MoonSeek allow-list. Its file reads remain subject to Moonrun policy.

### 3.7 One version lifecycle

The complete `mooxCLI/cmd` module uses one SemVer:

- The first release is `mooxCLI/cmd@0.1.0`.
- Users may pin that module version while selecting a package, for example
  `moonx mooxCLI/cmd/cat@0.1.0`.
- Fixing any command increments the module patch version.
- Adding a backward-compatible command or feature increments the minor version.
- Release notes identify the commands affected by each module release.

## 4. Import inventory

The import should use commit
`06a529211343c773d30d2c3aa0231a2456665b7a` as a fixed snapshot so upstream
changes cannot alter the migration midway.

| Command | Upstream module | New package | Upstream version | Targets |
|---|---|---|---:|---|
| `base64` | `bobzhang/base64` | `mooxCLI/cmd/base64` | 0.1.0 | native + wasm |
| `cat` | `bobzhang/cat` | `mooxCLI/cmd/cat` | 0.1.0 | native + wasm |
| `comm` | `bobzhang/comm` | `mooxCLI/cmd/comm` | 0.1.0 | native + wasm |
| `cut` | `bobzhang/cut` | `mooxCLI/cmd/cut` | 0.1.0 | native + wasm |
| `false` | `bobzhang/false` | `mooxCLI/cmd/false` | 0.1.0 | native + wasm |
| `head` | `bobzhang/head` | `mooxCLI/cmd/head` | 0.1.1 | native + wasm |
| `join` | `bobzhang/join` | `mooxCLI/cmd/join` | 0.1.0 | native + wasm |
| `jq` | `bobzhang/jq` | `mooxCLI/cmd/jq` | 0.1.1 | native + wasm |
| `jqlog` | `bobzhang/jqlog` | `mooxCLI/cmd/jqlog` | 0.1.0 | native + wasm |
| `nl` | `bobzhang/nl` | `mooxCLI/cmd/nl` | 0.1.0 | native + wasm |
| `paste` | `bobzhang/paste` | `mooxCLI/cmd/paste` | 0.1.0 | native + wasm |
| `printf` | `bobzhang/printf` | `mooxCLI/cmd/printf` | 0.1.0 | native + wasm |
| `sleep` | `bobzhang/sleep` | `mooxCLI/cmd/sleep` | 0.1.0 | native + wasm |
| `sort` | `bobzhang/sort` | `mooxCLI/cmd/sort` | 0.1.0 | native + wasm |
| `tail` | `bobzhang/tail` | `mooxCLI/cmd/tail` | 0.1.1 | native + wasm |
| `tr` | `bobzhang/tr` | `mooxCLI/cmd/tr` | 0.1.0 | native + wasm |
| `true` | `bobzhang/true` | `mooxCLI/cmd/true` | 0.1.0 | native + wasm |
| `uniq` | `bobzhang/uniq` | `mooxCLI/cmd/uniq` | 0.1.0 | native + wasm |
| `wc` | `bobzhang/wc` | `mooxCLI/cmd/wc` | 0.1.0 | native + wasm |
| `xxd` | `bobzhang/xxd` | `mooxCLI/cmd/xxd` | 0.1.0 | native + wasm |

Upstream versions are provenance only. After migration, all commands use the
single `mooxCLI/cmd` module version starting at `0.1.0`.

## 5. Target architecture

```text
cmd/
|-- moon.mod                        # name = "mooxCLI/cmd"
|-- README.mbt.md
|-- base64/
|   |-- moon.pkg                    # executable package
|   |-- main.mbt
|   |-- README.md
|   `-- pkg.generated.mbti
|-- cat/
|   |-- moon.pkg                    # mooxCLI/cmd/cat
|   |-- main.mbt
|   |-- README.md
|   `-- pkg.generated.mbti
|-- head/
|-- jq/
|-- jqlog/
|-- ...
|-- tests/
|   `-- cram/
|       |-- coreutils.md            # imported Unix-style command tests
|       `-- cli.md                  # imported jq CLI tests
|-- docs/
|   |-- migration-plan.md
|   |-- provenance.md               # source revision and license record
|   `-- jq-tutorial.md              # imported executable jq tutorial
`-- .github/workflows/
    |-- check.yml                    # imported baseline CI
    `-- policy.yml                   # added after the policy interface settles
```

### 5.1 Root module

The root `moon.mod` owns the module name and version, repository metadata,
default target, and all module-level dependencies needed by the command
packages. Based on the current upstream implementation, the initial dependency
set includes at least:

```moonbit
import {
  "bobzhang/moonjq@0.1.1",
  "moonbitlang/async@0.21.0",
  "moonbitlang/x@0.5.1",
}
```

The migration must verify dependencies against the actual package imports and
must not retain unused dependencies mechanically.

### 5.2 Command packages

Each root command directory contains an executable `moon.pkg`. Commands do not
reuse behavior by invoking one another as executables, and they do not delegate
to same-named host commands through `PATH`.

For example, `cat/` uses MoonBit and Moonrun-visible stdin, stdout, and file
APIs instead of executing `/bin/cat`. External resource access therefore stays
inside a boundary the runtime can observe and restrict.

The initial migration does not create a shared utility package. A private
shared package may be introduced later only when stable, meaningful duplication
exists across several commands.

### 5.3 Execution path

```text
MoonSeek harness
    -> allow-listed mooxCLI/cmd/<command>@<version>
    -> moonx
    -> Moonrun with inherited policy
    -> Wasm executable package
    -> policy-authorized filesystem, environment, network, or process access
```

The `cmd` repository supplies controlled command implementations and auditable
artifacts. Moonrun and `moonx` enforce and propagate policy. Neither side alone
solves the complete child-process authority problem.

## 6. Test strategy

### 6.1 Import the existing test system

The initial migration does not replace the upstream test framework. It imports:

- `tests/cram/coreutils.md`, covering 18 Unix-style commands through end-to-end
  CLI tests.
- `tests/cram/cli.md`, covering `jq` input, output, filters, log mode, and exit
  codes.
- The executable jq tutorial as both documentation and CLI regression coverage.
- The GitHub Actions checks for typing, warnings, formatting, generated
  interfaces, all supported targets, and Cram tests.

Only structural changes are made to the imported tests:

- Build executables from the new root package directories.
- Change README and tutorial invocations to `mooxCLI/cmd/<command>`.
- Adjust the executable tutorial path.
- Keep existing stdout, stderr, and exit-code expectations unchanged.

The MoonJQ library tests under upstream `ast/` and `parser/` do not move here.
They remain the responsibility of `bobzhang/moonjq`; this repository keeps only
the `jq` and `jqlog` CLI integration boundary.

### 6.2 Baseline CI

The imported CI validation sequence is:

```bash
moon update
moon check --deny-warn
moon info
git diff --exit-code
moon fmt
git diff --exit-code
moon test --target all
moon cram test tests/cram TUTORIAL.md
```

| Check | Purpose |
|---|---|
| `moon check --deny-warn` | Type-check every package and reject warnings |
| `moon info` plus clean diff | Require generated interfaces to be committed |
| `moon fmt` plus clean diff | Require formatted sources to be committed |
| `moon test --target all` | Run MoonBit tests for all package-supported targets |
| `moon cram test` | Validate real CLI arguments, output, and exit codes |

### 6.3 Post-migration test additions (Complete for fixed snapshot)

The following fixed-snapshot additions are included:

1. Add a direct `jqlog.exe` success case; upstream currently tests
   `jq.exe --logs` but does not directly run `jqlog.exe`.
2. Add Moonrun Wasm policy smoke coverage for denied and allowed file reads,
   including `jqlog`.
3. Add policy allow-list and static child-process checks.
4. Keep the upstream input-sensitive `head`, `tail`, and `sort` Cram cases.

`cat` retains the existing multi-file and binary-transparency coverage,
including input containing `0x00` and `0xff`. It has no additional fix gate.

### 6.4 Policy integration direction

Policy tests supplement rather than replace the imported Cram tests. The fixed
snapshot uses `tests/policy/check-wasm-policy.sh` with the stable Moonrun
policy interface. Its required semantics are:

| Scenario | Expected result |
|---|---|
| Policy permits a file read | Command succeeds with correct output |
| Policy denies a file read | Non-zero exit and no content disclosure |
| Policy denies a file write | Non-zero exit and no target-file side effect |
| Policy restricts environment access | Only permitted environment data is visible |
| Wasm execution fails | Harness does not silently fall back to native |
| A future command creates a child | Child authority does not exceed the effective parent policy |

Commands that can launch arbitrary children do not enter the default allow-list
until Moonrun policy inheritance and the corresponding tests are stable.

## 7. Migration stages

### Stage 0: Freeze the import baseline

Work:

- Freeze upstream at `06a529211343c773d30d2c3aa0231a2456665b7a`.
- Record the 20 commands, two Cram files, and CI configuration.
- Mark the local publishing-account setup complete without recording local
  account-selection details.

Acceptance: record the source revision and scope in `docs/provenance.md`.

### Stage 1: Prepare the root module

Work:

- Keep `name = "mooxCLI/cmd"` in the root `moon.mod`.
- Consolidate dependencies from the upstream command modules.
- Keep `version = "0.1.0"` and `preferred_target = "wasm"`.
- Do not create `moon.work` or retain per-command `moon.mod` files.

Acceptance: the root module resolves every dependency required by the imported
packages.

### Stage 2: Mechanically import 20 command packages (Complete)

Work:

- Copy upstream `cmd/<command>/` into root `<command>/`.
- Remove each copied command-level `moon.mod`.
- Retain and adjust each `moon.pkg` for the new module path.
- Retain implementation sources and command README files.
- Change examples to `mooxCLI/cmd/<command>`.
- Regenerate `pkg.generated.mbti` with `moon info`; do not edit it manually.

This stage changes module and package boundaries, not command behavior.

Acceptance:

- All 20 root command packages exist.
- Every package is executable and retains its upstream target declaration.
- Except for provenance and the `bobzhang/moonjq` dependency, user-facing
  documentation no longer uses old command coordinates.
- `moon check --deny-warn` and `moon info` pass.

### Stage 3: Import tests and CI (Complete)

Work:

- Import `tests/cram/coreutils.md`, `tests/cram/cli.md`, and the executable jq
  tutorial.
- Import and clean up `.github/workflows/check.yml`.
- Ensure Cram can find every executable built from the root package directories.
- Preserve upstream test expectations.

Stages 1 through 3 belong in one migration pull request. Separate commits are
useful for review, but an intermediate commit with expected red CI must not be
merged into `main` alone.

Acceptance: all of the following pass and leave no generated or formatting
diff:

```bash
moon check --deny-warn
moon info
moon fmt
moon test --target all
moon cram test tests/cram TUTORIAL.md
```

Local runs must follow the repository's `AGENTS.md` tooling rule for Moon home
selection; that machine-specific setting is intentionally not repeated here.

### Stage 4: Integrate with MoonSeek security controls (Complete for fixed snapshot)

Work:

- Add Moonrun smoke tests for Wasm commands.
- Add minimum policy allow and deny integration cases in
  `tests/policy/check-wasm-policy.sh`.
- Promote `jqlog` to the native+Wasm allow-list after verifying its Wasm build
  and policy-controlled file reads.
- Verify commands do not delegate to same-named host executables.

Acceptance: test results distinguish ordinary CLI behavior, Wasm execution,
and policy behavior. The fixed snapshot's smoke suite is
`tests/policy/check-wasm-policy.sh`; it verifies both denied and allowed file
reads under Moonrun's Wasm policy mode.

### Stage 5: Publish the first module release (Complete)

The first complete module release has been published through the `mooxCLI`
account after completing the checklist in Section 3.2:

The published module release is:

```text
mooxCLI/cmd@0.1.0
```

Users select commands by package path:

```bash
moonx mooxCLI/cmd/cat@0.1.0 -- README.md
moonx mooxCLI/cmd/jq@0.1.0 -- -r '.name' data.json
```

A registry release cannot be rolled back like a Git commit. Defects require a
new `mooxCLI/cmd` SemVer release.

## 8. Future command priorities

After the existing commands move, new work is ordered by authority risk rather
than command popularity alone.

### Batch 1: Read-only, no child process (Complete)

```text
echo
pwd
basename
dirname
ls
grep
find
cmp
printenv
test
seq
sha256sum
```

All 12 commands are implemented as root executable packages, support native
and Wasm targets, and are admitted to `tests/policy/allow-list.txt`. The Cram
suite covers their documented CLI surface and the policy smoke suite exercises
denied and allowed reads for `cmp`, `grep`, `ls`, `find`, and `sha256sum`.

### Batch 2: Filesystem mutation

```text
mkdir
touch
tee
cp
mv
rm
rmdir
ln
```

### Batch 3: High authority or child processes

```text
env (command-execution mode)
xargs
timeout
sh
make
curl/wget
chmod/chown
kill
```

Batch 3 waits for mature policy inheritance and integration tests. It is not
accelerated merely to increase the number of available commands.

Every new command is a root `<name>/` executable package with a README,
generated interface, Cram behavior tests, target declaration, and security
admission status.

## 9. Risks and controls

| Risk | Severity | Control |
|---|---|---|
| Publishing from the wrong Mooncakes account | High | Verify the configured `mooxCLI` account and module `mooxCLI/cmd` before publishing |
| One module version covers every command | Medium | Release notes identify every affected command |
| Dependency omissions or conflicts after consolidation | Medium | Keep dependencies in root `moon.mod` and run full check/test validation |
| A child process bypasses parent policy | High | Exclude such commands until inheritance and tests are ready |
| `jqlog` Wasm file access bypasses policy | High | Exercise denied and allowed reads under Moonrun policy |
| Mechanical migration changes behavior | Medium | Avoid implementation rewrites and reuse upstream Cram expectations |
| Upstream changes during migration | Medium | Import a fixed commit and review later syncs separately |
| Wasm only compiles but is never executed | Medium | Add Moonrun Wasm smoke and policy tests after import |
| Compatibility scope is unclear | Medium | Document supported options and known differences per command |

## 10. Definition of done

The existing-command migration is complete when:

- The root module is `mooxCLI/cmd` and no `moon.work` combines command modules.
- All 20 commands live directly under the repository root as executable
  packages.
- Command directories contain no independent `moon.mod` files.
- User-facing coordinates are consistently `mooxCLI/cmd/<command>`.
- `bobzhang/moonjq` remains the normal external dependency of `jq` and `jqlog`.
- `cat` is imported with its current implementation and tests, with no extra
  fix requirement.
- Both upstream Cram files and the command-related CI are imported and passing.
- `moon check --deny-warn`, `moon info`, `moon fmt`,
  `moon test --target all`, and `moon cram test` all pass.
- All commands in the default MoonSeek allow-list, including `jqlog`, support
  native+Wasm execution and policy-visible resource access.
- The `mooxCLI` publishing-account setup is complete outside the repository;
  local account-selection details are not committed.
- The first artifact, `mooxCLI/cmd@0.1.0`, has been published, with commands
  selected by package path.
- `moonbit-community/cmd` is the maintenance source for subsequent command
  changes.

## 11. Settled scope decisions

1. `jqlog` supports native+Wasm execution and is included in the default Wasm
   allow-list. Its file-read behavior is covered by the policy smoke suite.
2. Future commands that use filesystem access require native and Wasm policy
   smoke cases before entering the default allow-list.

The module name, root package layout, publishing account, MoonJQ dependency,
and `cat` treatment are settled by this plan.
