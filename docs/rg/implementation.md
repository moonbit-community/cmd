# rg integration ledger

Updated: 2026-10-26

The delivery is the `cli/rg@0.1.0` migration candidate and a passing, mergeable
PR. Merging, publishing and published-coordinate MoonX acceptance are outside
this task. The user explicitly deferred performance acceptance and subsequently
deferred all compressed search: effective `-z`/`--search-zip` rejects with status
2, while the compression construction is preserved outside the workspace.

## Fixed inputs and scope

| Input | Revision or coordinate |
| --- | --- |
| Refreshed cmd base | `22a61d10c798861e33c60d89410add815cf588f2` |
| rg.mbt 0.2.0 | `2727c25819b00ddd1a0e9b24f9cb683931d64edf` |
| ripgrep semantic reference | `3fce3b5bb0236da2df6d99672afb8a719642eca7` |
| Public system dependencies | async 0.22.5, x 0.5.5 |
| Archived compression source | bikallem/compress `89e8a942e6d88c369aa6517a1f8b3c4030ec0670` |
| Archived gzip adapter dependency | moonbit-community/flate 0.9.0 |
| Candidate coordinates | rg 0.1.0, catalog-only core 0.8.2 |

The attached plan predates the current CI migration. Current AGENTS.md retires
the C1 declaration/audited-push wrapper; normal protected-branch PR checks apply.
Wasm remains the product acceptance target. The requested supplemental Native
tests and direct backend observations are retained as additional evidence.
The original workspace was clean when inspected: the thirteen interface edits
mentioned by the plan were absent. Work is isolated in `codex/rg-integration`.

The CLI account was verified as `cli`. The registry returned no `cli/rg` module;
core's version inventory ends at 0.8.1, with 0.8.0 already occupied. Thus 0.8.0
was not reused; 0.8.2 is an unpublished candidate. No unchanged command version
or dependency was bumped. `current/latest.json`, `current/published.json` and
historical release records retain their frozen meanings.

## Implementation and boundaries

The root entrypoint delegates asynchronously and returns the driver's status.
Matcher, regex, Unicode/encoding tables, glob, ignore, searcher and printers are
module-private imports. Actual filesystem reads, directory advancement, readers,
sinks, writes and user preprocessing use released public async APIs. Ordinary
search does not read whole files or accumulate stdout; multiline/sorted paths
retain their original materialization. Stderr uses the inherited diagnostic
payload storage. Direct children are reaped; process-tree cleanup is not claimed.

The adapter exposes unavailable capabilities explicitly. Search without paths
cannot infer stdin and exits 2, explaining how to use a path or `-`. `--files`
retains its own cwd default. Automatic terminal presentation is plain; explicit
presentation controls remain available. Device/inode identity, redirected-stdout
identity, readlink, creation time and raw-byte paths are not fabricated.
`--one-file-system` and creation-time sorting reject. Canonical realpath handles
followed directory loops and followed-file sizes. OS diagnostics preserve public
runtime messages. The source's single-threaded, no-real-mmap and no-PCRE2
boundaries remain. Executable contracts and unlock conditions are in the
[support record](../compatibility.md#rg-candidate) and canonical ADRs
[streams](../adr/0003-streams.md), [filesystem](../adr/0004-filesystem.md),
[process](../adr/0006-process.md) and [data](../adr/0008-data.md).

[`experiments/rg-compression`](../../experiments/rg-compression/README.md) preserves
the decoders, fixtures, tests, source inventory, hashes and former CLI source.
It is not a member of moon.work or a dependency of cli/rg. Its known incomplete
format support is recorded there. `-z`, `--search-zip` and `-zz` have mandatory
rejection regressions; an explicit later disabling flag keeps parser precedence.

## Source and test disposition

| Index | Purpose |
| --- | --- |
| [source-inventory.tsv](source-inventory.tsv) | Every tracked source input, original SHA-256, destination and disposition |
| [package-tests.tsv](package-tests.tsv) | Every original package test file, including rewritten public-API system tests and archived compression tests |
| [options.tsv](options.tsv) | Every imported long option and inherited/deferred/API boundary |
| [upstream-tests.tsv](upstream-tests.tsv) | Every fixed ripgrep test ID and host/backend observer disposition |
| [upstream-observation.jsonl](upstream-observation.jsonl) | Per-backend unmodified integration-harness observations |
| [runtime contracts](../../tests/cases/rg.json) | Explicit byte/status/diagnostic expectations and selected sealed-oracle comparisons |
| [runtime index](../../tests/registry/registry.json) | Case bindings, metadata probe and candidate selection |

Original package test identities are retained. Async expected-panic cases use
portable child observers as well as synchronous panic assertions, because an
uncaught panic aborts an async runtime. System tests replace old FFI/WASI/host
program assumptions with public-API assertions and pure MoonBit process fixtures.
The old optional compression smoke becomes a mandatory rejection contract; its
original integration source remains in the archive. No missing decoder/tool is
treated as a compatibility pass.

Generated tables are frozen imports; upstream host generators are excluded.
Original author and third-party notices are retained in the command module.
One-time adaptation scripts are preserved as
[migration source records](migration-tools/README.md). Current tools use `.mbtx`.

## Validation and interpretation

The unmodified source passed 1,069 Native and 1,019 Wasm package tests with the
current local PATH toolchain (MoonBit 0.10.17). These are baseline observations.
Current local validation includes 1,565/1,565 workspace Wasm package tests,
1,074/1,074 rg Native tests and 117/117 Native test-tool regressions. The 34 rg
CLI contracts, separate metadata stdin-preservation probe, 26 direct backend
contracts and candidate generator passed.
The complete local functional run records 2,062 passes, zero failures and 18
explicit platform skips, including all 80 metadata probes. Imported fixture
bytes are protected from checkout newline conversion by `.gitattributes`.
The local 0.10.17 interface printer spells 32-bit aliases `Int32`/`UInt32`;
new interfaces use CI 0.10.15's equivalent `Int`/`UInt` spelling. The thirteen
unrelated existing-interface spelling diffs are excluded from this migration.

Test reports are retained by the normal CI artifact workflow; local logs are outside
the repository. Hosted checks use the repository's pinned 0.10.15 toolchain.

The unchanged fixed Rust integration harness ran separately against Native and
Wasm candidates with distinct temporary roots. Each selected 323 host-applicable
cases: 183 observer passes, 133 explicit-input API boundary differences and seven
deferred compressed-search differences. All 349 source IDs remain mapped;
host-cfg exclusions are labeled. Assertions that only require nonzero output or
skip for unavailable host tools are not upgraded into positive feature evidence.
An earlier shared-scratch run was invalidated and is not used by these indexes.
Explicit-path variants exercise the underlying algorithms without changing the
upstream test IDs or counting boundary failures as upstream passes.

The Linux oracle recipe pins the ripgrep source archive and Rust distribution
SHA-256, uses Cargo.lock, and adds rg to the version inventory. A local Docker
daemon was unavailable. Linux differential acceptance therefore requires the
current hosted run's sealed final image digest, inventory and source hashes;
local host binaries and unsealed recipes are not parity evidence. The final PR's
ubuntu-24.04, macos-15 and windows-2025 checks are the authoritative hosted result.
Performance, compression acceptance, merge and publication remain outside this
candidate's acceptance scope.
