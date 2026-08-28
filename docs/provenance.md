# Migration Provenance

This record identifies the upstream command snapshot and the package scope of
`mooxCLI/cmd`. It does not define runtime policy or external integration
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
| Destination module | `mooxCLI/cmd` |
| Initial destination version | `0.1.0` |
| Initial release status | `mooxCLI/cmd@0.1.0` published |

The snapshot is pinned so that a partial migration cannot change underneath
the implementation. A later upstream sync must be a separate reviewable
change.

## Upstream command scope

The fixed snapshot contains 20 command directories. Source package names and
versions are provenance only; every destination package belongs to
`mooxCLI/cmd`.

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
requests have dedicated Cram and policy smoke coverage.

`chown` and `kill` are not destination packages. They are absent from the
source tree, policy inventory, test suite, and release artifacts because their
required owner-mutation and arbitrary-process-signalling primitives are not in
the supported runtime API.

## Test and dependency provenance

The command-facing test artifacts are:

| Artifact | Purpose |
|---|---|
| `tests/compat/main.mbt` | Direct execution, byte comparison, GNU differential, and stress cases |
| `tests/policy/main.mbt` | Wasm resource, mutation, process, network, and permission policy cases |
| `tests/cram/coreutils.md` | Upstream Unix-style compatibility provenance |
| `tests/cram/cli.md` | `jq` and `jqlog` compatibility provenance |
| `TUTORIAL.md` | `jq` documentation and migration examples |
| `tests/cram/batch1.md` | Read-only migration examples |
| `tests/cram/batch2.md` | Filesystem mutation migration examples |
| `tests/cram/batch3.md` | Restricted authority migration examples |

The `jq` and `jqlog` entry points depend on
`bobzhang/moonjq@0.1.1`. MoonJQ parser and AST tests remain in that dependency;
this repository records only the executable command boundary.

## Destination rules

- One root `moon.mod` names the module `mooxCLI/cmd`.
- Commands live directly under root directories such as `cat/` and `grep/`.
- Command-level `moon.mod` files and compatibility coordinates are not kept.
- Generated `pkg.generated.mbti` files are produced by `moon info`.
- The `cat` implementation is imported without a migration-specific repair
  gate.
