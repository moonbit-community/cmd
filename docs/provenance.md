# Migration Provenance

This file records the fixed source snapshot and the scope of the first
`mooxCLI/cmd` migration. It is intentionally separate from implementation and
is updated when a new upstream snapshot is selected.

## Source snapshot

| Field | Value |
|---|---|
| Source repository | <https://github.com/moonbit-community/moonbit-jq> |
| Source directory | [`cmd/`](https://github.com/moonbit-community/moonbit-jq/tree/main/cmd) |
| Imported commit | `06a529211343c773d30d2c3aa0231a2456665b7a` |
| Commit date | 2026-08-25 |
| Commit subject | `Add bobzhang/true, false, cat, and sleep (#26)` |
| Destination repository | <https://github.com/moonbit-community/cmd> |
| Destination module | `mooxCLI/cmd` |
| Initial destination version | `0.1.0` |
| Initial release status | `mooxCLI/cmd@0.1.0` published |

The source snapshot is pinned so that upstream changes cannot silently alter a
partially completed migration. Later upstream changes must be imported as a
separate, reviewable synchronization.

## Command scope

The fixed snapshot contains 20 command directories. The source package name and
version are recorded for traceability; they are not retained as destination
module identities. All destination packages belong to `mooxCLI/cmd`.

| Command | Source module | Destination package | Source version | Target |
|---|---|---|---:|---|
| `base64` | `bobzhang/base64` | `mooxCLI/cmd/base64` | 0.1.0 | native + wasm |
| `cat` | `bobzhang/cat` | `mooxCLI/cmd/cat` | 0.1.0 | native + wasm |
| `comm` | `bobzhang/comm` | `mooxCLI/cmd/comm` | 0.1.0 | native + wasm |
| `cut` | `bobzhang/cut` | `mooxCLI/cmd/cut` | 0.1.0 | native + wasm |
| `false` | `bobzhang/false` | `mooxCLI/cmd/false` | 0.1.0 | native + wasm |
| `head` | `bobzhang/head` | `mooxCLI/cmd/head` | 0.1.1 | native + wasm |
| `join` | `bobzhang/join` | `mooxCLI/cmd/join` | 0.1.0 | native + wasm |
| `jq` | `bobzhang/jq` | `mooxCLI/cmd/jq` | 0.1.1 | native + wasm |
| `jqlog` | `bobzhang/jqlog` | `mooxCLI/cmd/jqlog` | 0.1.0 | native only |
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

## Test and CI scope

The first migration imports these command-facing upstream artifacts without
redesigning their test framework:

| Artifact | Purpose |
|---|---|
| `tests/cram/coreutils.md` | End-to-end tests for the Unix-style commands |
| `tests/cram/cli.md` | `jq` CLI input, output, filter, log, and exit-code tests |
| `TUTORIAL.md` | Executable jq CLI documentation and regression coverage |
| `.github/workflows/check.yml` | Moon check, info, format, target tests, and Cram CI |

The upstream `ast/` and `parser/` library tests are outside this repository's
command migration scope. The `jq` and `jqlog` packages continue to depend on
the external `bobzhang/moonjq@0.1.1` module.

## Destination layout rules

The destination has one root `moon.mod` named `mooxCLI/cmd`:

- Each command is copied to a root directory such as `cat/` or `head/`.
- Each command keeps an executable `moon.pkg`, implementation, README, and
  generated interface.
- Command-level `moon.mod` files from the source are discarded.
- No `moon.work` is introduced to combine command modules.
- Module dependencies are declared once in the root `moon.mod`.
- User-facing coordinates use `mooxCLI/cmd/<command>`.

The `cat` implementation is imported as-is. It has no migration-specific bug
fix requirement.

## Publishing prerequisite

The module is published as `mooxCLI/cmd`. The configured `mooxCLI`
publishing-account setup is complete for the current maintainer. Account
selection details and credentials are intentionally kept outside the
repository and are not recorded here.

The initial release status is recorded above. Later release executions remain
local operator actions and are not tracked in this provenance record.
