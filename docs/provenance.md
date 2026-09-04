# Migration Provenance

This record identifies the upstream command snapshot and the command scope of
the `cmd` repository. It does not define runtime policy or external integration
behavior.

## Source snapshot

| Field | Value |
|---|---|
| Source repository | <https://github.com/moonbit-community/moonbit-jq> |
| Source directory | [`cmd/`](https://github.com/moonbit-community/moonbit-jq/tree/main/cmd) |
| Imported commit | `06a529211343c773d30d2c3aa0231a2456665b7a` |
| Commit date | 2026-08-25 |
| Commit subject | `Add bobzhang/true, false, cat, and sleep (#26)` |
| Destination repository | <https://github.com/moonbit-community/cmd> |
| Destination module namespace | `cli` |
| Initial destination version | `0.1.0` |

The snapshot is pinned so that the implementation does not change underneath
the repository. A later upstream sync must be a separate reviewable change.

## Upstream command scope

The fixed snapshot contains 20 command directories. Source package names and
versions are provenance only. The implementations are integrated into the
current `cli/<command>` command modules.

| Command | Source module | Destination package | Source version | Target |
|---|---|---|---:|---|
| `base64` | `bobzhang/base64` | `cli/base64` | 0.1.0 | native + wasm |
| `cat` | `bobzhang/cat` | `cli/cat` | 0.1.0 | native + wasm |
| `comm` | `bobzhang/comm` | `cli/comm` | 0.1.0 | native + wasm |
| `cut` | `bobzhang/cut` | `cli/cut` | 0.1.0 | native + wasm |
| `false` | `bobzhang/false` | `cli/false` | 0.1.0 | native + wasm |
| `head` | `bobzhang/head` | `cli/head` | 0.1.1 | native + wasm |
| `join` | `bobzhang/join` | `cli/join` | 0.1.0 | native + wasm |
| `jq` | `bobzhang/jq` | `cli/jq` | 0.1.1 | native + wasm |
| `jqlog` | `bobzhang/jqlog` | `cli/jqlog` | 0.1.0 | native + wasm |
| `nl` | `bobzhang/nl` | `cli/nl` | 0.1.0 | native + wasm |
| `paste` | `bobzhang/paste` | `cli/paste` | 0.1.0 | native + wasm |
| `printf` | `bobzhang/printf` | `cli/printf` | 0.1.0 | native + wasm |
| `sleep` | `bobzhang/sleep` | `cli/sleep` | 0.1.0 | native + wasm |
| `sort` | `bobzhang/sort` | `cli/sort` | 0.1.0 | native + wasm |
| `tail` | `bobzhang/tail` | `cli/tail` | 0.1.1 | native + wasm |
| `tr` | `bobzhang/tr` | `cli/tr` | 0.1.0 | native + wasm |
| `true` | `bobzhang/true` | `cli/true` | 0.1.0 | native + wasm |
| `uniq` | `bobzhang/uniq` | `cli/uniq` | 0.1.0 | native + wasm |
| `wc` | `bobzhang/wc` | `cli/wc` | 0.1.0 | native + wasm |
| `xxd` | `bobzhang/xxd` | `cli/xxd` | 0.1.0 | native + wasm |

## Local expansion scope

The following packages were implemented directly in this repository. All
currently declare native and Wasm support.

### Batch 1: read-only

`echo`, `pwd`, `basename`, `dirname`, `ls`, `grep`, `find`, `cmp`, `printenv`,
`test`, `seq`, and `sha256sum` are allow-listed after command and denied-read
tests.

### Batch 2: filesystem mutation

`mkdir`, `touch`, `tee`, `cp`, `mv`, `rm`, `rmdir`, and `ln` are allow-listed
after mutation, denial, and symbolic-link safety tests.

### Batch 3: restricted authority

`env`, `xargs`, `timeout`, `sh`, `make`, `curl`, `wget`, and `chmod` are kept
outside the default allow-list. Their process, network, and permission
requests have dedicated policy-controlled coverage in the unified runner.

`chown` and `kill` are not destination packages. They are absent from the
source tree, policy inventory, test suite, and release artifacts because their
required owner-mutation and arbitrary-process-signalling primitives are not in
the supported runtime API.

## Test and dependency provenance

The command-facing test artifacts are:

| Artifact | Purpose |
|---|---|
| `tests/runner/compat.mbt` | Native execution, byte comparison, GNU differential, and stress cases |
| `tests/runner/policy.mbt` | Wasm resource, mutation, process, network, and permission policy cases |
| `tests/runner/main.mbt` | Unified suite dispatch, strict differential cases, and fixture isolation |
| `tests/fixtures/runner/cases.json` | Machine-readable semantic compatibility contract |
| `TUTORIAL.md` | `jq` documentation and migration examples |

The `jq` and `jqlog` entry points depend on
`bobzhang/moonjq@0.1.1`. MoonJQ parser and AST tests remain in that dependency;
this repository records only the executable command boundary.

## Current structure

- Command implementations live under `commands/`, one executable module per
  command.
- Shared runtime packages live under `core/`.
- Compatibility, policy, and process tests live under `tests/`.
- Generated `pkg.generated.mbti` files are produced by `moon info`.
- The `cat` implementation is imported without a migration-specific repair
  gate.
