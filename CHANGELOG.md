# Changelog

This repository integrates multiple command packages, so changes are recorded
by date and delivery milestone rather than by a single package version.

## 2026-09-06

- Fixed two-operand descending `seq`, synchronized version metadata for the
  affected commands, sanitized `sh` rejected-syntax diagnostics, and enforced
  single-terminal-newline `jqlog` help/error output.
- Added the pure-MoonBit published-version Runner with exact-version MoonX
  invocations, shared loopback HTTP fixtures, manifest validation, failure
  classification, filesystem snapshots, and Markdown/JSONL reports.
- Added P0 regression coverage for `echo`, `false`, `jqlog`, `seq`, `sleep`,
  and `true` at `0.1.5`, plus the corrected `sh` release at `0.1.6`.
- Added release-manifest, published differential, and cross-platform smoke CI
  jobs. `timeout` remains local-only and is excluded from the 47-command
  published manifest.
- Published-version smoke found and fixed a POSIX `sh -s name arg` positional
  parameter regression; `cli/sh@0.1.6` is pending publication before the
  published gate can be promoted.

## 2026-09-05

- Delivered P6 JSON CLI modes and the bounded `jqlog` contract.
- Delivered P7 `make` and `xxd` compatibility slices, including explicit
  rejection of jobserver parallelism and negative/end-relative seeks.
- Delivered the maximum pure MoonBit Native/Wasm filesystem subset for
  `test`, `find`, `ls`, `cp`, `mv`, `chmod`, `ln`, and `touch`.
- Delivered P9 command-local compatibility closure across text, path, checksum,
  status, filesystem, and fixed-C-locale byte commands.
- Expanded the unified manifest to 48 commands and 176 semantic cases; P9
  contributes 35 cases.
- Corrected pinned-oracle edge behavior for `cmp`, `tr`, `paste`, and Windows
  `pwd`.
- Consolidated architecture decisions into nine canonical ADRs and archived
  stage history under [`docs/reports/`](docs/reports/README.md).
- Removed stray `pkg.generated 2.mbti` artifacts; standard
  `pkg.generated.mbti` files remain authoritative.
- Verified fresh Native/Wasm artifacts locally and reconciled the complete
  Ubuntu/macOS/Windows plus pinned-oracle CI matrix in
  [run 33964497821](https://github.com/moonbit-community/cmd/actions/runs/33964497821).

## 2026-09-04

- Delivered P1 bounded HTTP/HTTPS profiles for `curl` and `wget`.
- Delivered P2/P3 `grep`, `env`, `sort`, `uniq`, `wc`, `head`, and `tail`
  extensions under the fixed byte-oriented contract.
- Delivered P4 bounded `find`/`xargs` workflows with explicit child policy.
- Delivered P5 restricted POSIX shell grammar without host-shell delegation.
- Replaced the mixed legacy test systems with the unified `compat`, `oracle`,
  and `policy` runner.

## 2026-09-03

- Added the first measured Wasm command-support record and stabilized shared
  stream behavior, binary fixtures, and HTTP test cleanup.
- Added tail follow behavior with the portable descriptor-follow boundary.

## 2026-09-02

- Established pinned upstream baselines and the Docker-backed differential
  oracle harness.
- Defined the evidence rule that separates native semantics, upstream
  differential results, and Wasm authorization.

## 2026-08-26—2026-08-30

- Established the command package repository and migrated read-only,
  filesystem-mutation, and restricted command batches.
- Split commands into publishable modules and removed the legacy command tree.
- Defined the harness-owned policy boundary and retained `timeout` as
  local-only until portable process-group cancellation exists.
