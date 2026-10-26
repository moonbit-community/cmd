# Changelog

This repository integrates multiple command packages, so changes are recorded
by date and delivery milestone rather than by a single package version.

## 2026-10-26

- Extended the same unpublished performance candidates with synchronous record
  visitors, block rejection, synchronous count scans, flat DFA transitions and
  precomputed span closures. Final local pairs improved short-record cut/uniq
  by 4.96x/2.41x and 64 MiB regex counting by 2.67x over wave 1. Their selected
  GNU ratios are 2.84x, 2.52x and 2.89x; span extraction remains 10.33x.
  Passed 1,584 Wasm package tests, 117 Native tool tests and the full functional
  suite (2,062 passes, 19 skips, zero failures). The independent local comparison
  matched 242 of 244 GNU cases; two empty-pattern grep differences also occur in
  wave 1. See [ADR-0003](docs/adr/0003-streams.md#performance-wave-2-candidate-2026-10-26)
  for bounds, evidence and remaining work. No package was uploaded, and these
  diagnostic measurements do not establish formal performance acceptance.
- Prepared the unpublished first performance wave in `core 0.8.2`,
  `cut/uniq/wc 0.2.3` and `grep 0.3.1`: immutable record batches, synchronous
  output accumulation, SIMD line/word counting, compact span worklists and a
  bounded lazy DFA with conservative literal rejection. Published coordinates
  and snapshots remain unchanged. Updated prospective direct-Wasm performance
  limits to 3.0x per the current target; historical verdicts remain unchanged.
  Local macOS checks passed 1,579 Wasm package tests, 117 Native tool tests and
  the full functional run (2,062 passes, 19 explicit skips, zero failures).
  Selected nine-pair measurements and the remaining short-record/regex gaps are
  recorded in [ADR-0003](docs/adr/0003-streams.md#performance-wave-1-candidate-2026-10-26).
  These observations do not establish three-host, published-consumer or formal
  performance acceptance. No package was uploaded.
- Migrated development CI to release Wasm commands on Linux, macOS and Windows,
  with shared workspace/MoonX assertions and Native test tools. Removed the
  daily schedule, Native product pairing, change-coverage audits and source/
  artifact sealing. Resource observations and published acceptance run manually.
- Added metadata stdin-preservation checks, strict cleanup/report failures,
  bounded package-test execution and retained cancellation diagnostics. Reused
  compilation state and parallelized independent pinned-oracle build stages.
- Verified all 78 published coordinates on three platforms in
  [run 40270955851](https://github.com/moonbit-community/cmd/actions/runs/40270955851),
  including the complete pinned Linux comparison. Linux/macOS/Windows recorded
  2,287/2,094/1,961 passes and 15/18/151 explicit platform skips, with no failures.
  This validation uploaded no packages.
- Recorded a preliminary cold CI run at `635f355`: Linux 13:35, macOS 5:48,
  Windows 12:44 and 32:07 total runner time. These release-tool observations do
  not establish a controlled cold/warm result for the later debug-tool setup.
- Integrated the unpublished `cli/rg@0.1.0` candidate and catalog-only
  `cli/core@0.8.2` through PR #58. Retained pinned rg.mbt algorithms and Unicode
  data while replacing system access with public async APIs. Added Windows
  path handling and direct-child pipe cancellation/diagnostic-drain regressions.
  Effective compressed search rejects; stdin/terminal/file-identity limits,
  PCRE2, real mmap and parallel search remain explicit boundaries.
- Updated all three CI workflows to MoonBit `0.10.17+d971670cd` with matching
  core. Local rg integration recorded 1,566 passing workspace Wasm package
  tests and 117 passing Native harness tests; these are dated observations,
  not publication or complete ripgrep compatibility claims.
- Passed all three actual-main development checks for the rg integration in
  [run 40307223749](https://github.com/moonbit-community/cmd/actions/runs/40307223749)
  at `65b4b7e`, following PR run 40304444558. This did not publish rg or lift
  its documented input, engine and compression boundaries.
- Consolidated implementation and release reports into this changelog. Removed
  obsolete planning, provenance and rg migration documents, the deferred
  compression experiment and its one-time reporting tools. Refreshed the support
  record, upstream pins and nine canonical ADRs from source and Git history;
  cleared accumulated local test reports. No package versions or dependencies
  changed in this documentation cleanup.

## 2026-10-25

- Added stable/merge/seeded-random sorting, exact fixed-ABI numeric formatting,
  paragraph margins/prefixes and shared tab grids. Expanded selected split,
  csplit, byte-display, checksum, path, layout, environment, prompt and pipe-error
  options while retaining operation-specific public-API rejections.
- Reworked rev into record streaming, csplit/column into indexed disk snapshots,
  and tac into backward block reads with spooled fallback. Added sort memory/
  temporary-directory/fan-in controls and shared byte views in diff. Accounted
  budgets are not RSS caps; tac regex and diff retain whole-input storage.
- Published core 0.8.0 and 76 changed command versions after the README/help
  review; curl/wget retained 0.2.3. The local 2,127-case exact-MoonX run had
  zero failures, with boundaries and platform skips reported separately.
- Subsequently published core 0.8.1 and column/rev/tac 0.1.4, csplit/diff 0.2.1,
  split 0.1.3 and sort 0.2.3 after PR #56's platform checks. The other 71 command
  versions and all dependency declarations remained unchanged.
- Verified all 78 latest command coordinates locally through exact MoonX:
  1,875 semantic passes, 186 availability observations, 52 boundary results,
  22 platform skips and zero failures across 2,135 cases. Ten supplemental
  find/test/yes checks completed functional observations for all 78 commands.
  These local releases did not establish new cross-platform or formal
  direct-Wasm performance acceptance.

## 2026-10-24

- Added a pure DEFLATE encoder with 32 KiB history, stored/fixed/dynamic block
  cost selection and levels 1–9. Added Reader-based gzip decoding with shared
  buffers, Huffman lookup tables and preserved prefixes on CRC/truncation errors.
  GNU roundtrips and selected size checks passed; encoder byte identity and
  formal performance acceptance were not claimed.
- Added parsed BRE/ERE matching, GNU repeated-capture selection and streaming
  grep consumers. Sed gained hold space, branches, groups, multiline and text
  instructions. The local matcher comparison matched 1,095 applicable GNU
  cases, with three oracle faults classified separately; full grammar and
  non-C locale compatibility remain outside that evidence.
- Reused 64 KiB copy/scanner buffers, selected wc counters and streaming strings
  output. External sort caches comparison keys and uses bounded-fan-in runs.
- Added diff comparison/directory workflows and linear auxiliary reconstruction;
  patch gained offset/fuzz matching, mixed hunk results and new reject files.
  Existing-file mode-preserving patch writeback remains unavailable.
- Added cut complements, uniq groups, comm totals, join headers/automatic fields
  and wc total policies under the fixed C-byte profile. Updated the benchmark
  contract to direct release Wasm, separating MoonX launcher cost.

## 2026-10-23

- Fixed cancellation ownership for Docker oracle containers and made uncertain
  cleanup an infrastructure failure. Actual-main C0 validation completed;
  the cause of the earlier mainline timeout remained unconfirmed.
- Hardened the then-current change-coverage system for source content, checkout
  conversion, additions and shared producers. This mechanism was retired by
  the 2026-10-26 CI decision; its historical passes are not current gates.

## 2026-10-20

- Published core 0.7.0 and curl/mv/wget 0.2.3 using async 0.22.5; the other 75
  command coordinates were unchanged. Added explicit HTTP wire/framing and
  command-specific retry, cookie, URL and output-lifetime behavior.
- Retained Windows Wasm source-link move and destination-link backup rejections
  before prompting or mutation; the Native dependency fix did not establish a
  fixed Wasm host.
- Passed exact-version acceptance on Linux, macOS and Windows plus pinned Linux
  comparison in [run 39409393072](https://github.com/moonbit-community/cmd/actions/runs/39409393072).
  The selected release covered 95 case IDs, not the later roadmap stages.

## 2026-10-18

- Completed the metadata release of core 0.6.0 and 78 command patch versions:
  standalone help/version now use the shared output contract. Exact-source and
  three-platform published acceptance passed, including Linux differential
  checks in [run 39045905149](https://github.com/moonbit-community/cmd/actions/runs/39045905149).
  The original closed-stdin captures did not prove unread live input.
- Repaired test lifecycle ownership, platform listener observation, exact-version
  startup, historical-manifest separation and failure reporting. Preserved
  platform exclusions and avoided treating missing evidence as success.

## 2026-10-12

- Audited all 79 then-local command READMEs and standalone metadata paths.
  Native and Wasm probes each passed 79 commands; published coordinates and
  their older metadata expectations remained separate until release.

## 2026-10-11

- Published core 0.3.0 and sixteen new 0.1.0 commands: csplit, diff, expr, fmt,
  fold, gunzip, gzip, hexdump, md5sum, od, patch, sed, sha1sum, sha512sum,
  split and zcat. Three-platform source checks and exact-MoonX verification
  retained explicit filesystem and algorithm boundaries.
- Published core 0.4.0 and column/date/strings/which 0.1.0, bringing the published
  inventory to 78 commands. Final local acceptance recorded 447 semantic passes,
  81 availability observations, 23 boundary results and three skips in 554 cases.
- Repaired strings/column/which semantics, TZif/calendar handling, jq slices,
  ln/mv/ls option effects, cookie handling and seq buffering. Published core
  0.5.0 and the affected command patches; unchanged coordinates were retained.
- Completed the 841-case fidelity release selection with three-platform MoonX
  acceptance and Linux comparison in
  [run 38140928875](https://github.com/moonbit-community/cmd/actions/runs/38140928875).
  Timestamp-sensitive cases run serially; the earlier concurrency-related atime
  cause was not established. Repository documentation and issues use English.

## 2026-10-10

- Implemented the second pure MoonBit command batch and shared checksum,
  byte-regex and gzip components. Verified patch inode/mode effects and retained
  explicit refusal of unsafe existing-file replacement before publication.

## 2026-09-27

- Published 0.1.1 updates for base32, cksum, expand, mktemp, realpath, rev, tac,
  tree, unexpand, unlink and yes after three-platform checks. Exact-version
  MoonX acceptance kept availability and boundary observations separate.

## 2026-09-26

- Published the first 0.1.0 versions of those eleven commands, bringing the
  published inventory to 58. Core remained 0.2.0; unchanged commands were not
  republished. The async 0.22.4 audit retained explicit metadata, process and
  terminal API boundaries.

## 2026-09-21

- Published core 0.2.0 and 47 command versions after Linux/macOS/Windows source
  checks. Exact-version MoonX acceptance and the pinned Linux oracle retained
  separate semantic, boundary, availability and platform-skip results.
- Consolidated fixtures, process execution and byte/effect assertions in the
  shared testkit, migrated 240 legacy invocations to JSON contracts, and kept
  unsafe filesystem operations as tested rejections.

## 2026-09-20

- Added persistent pipe-based shell sessions and concurrent make dependency
  scheduling, complete environment inheritance, Basic authentication and cookie
  state. Corrected stream, JSON and filesystem fidelity without host delegation.
- Retained explicit limits for file identity/mode/timestamp operations,
  process groups, exec and terminal control. Local candidate tests were
  development evidence before the following publication.

## 2026-09-19

- Audited actual published MoonX command behavior and separated observed
  semantic defects from missing public runtime APIs and unsupported profiles.
  Those observations supplied regressions for the subsequent fidelity work.

## 2026-09-06

- Fixed two-operand descending `seq`, synchronized version metadata for the
  affected commands, sanitized `sh` rejected-syntax diagnostics, and enforced
  single-terminal-newline `jqlog` help/error output.
- Added the pure-MoonBit published-version Runner with exact-version MoonX
  invocations, shared loopback HTTP fixtures, manifest validation, failure
  classification, filesystem snapshots, and Markdown/JSONL reports.
- Added P0 regression coverage for `echo`, `false`, `jqlog`, `seq`, `sleep`,
  and `true` at `0.1.5`, plus the compatible `sh` follow-up staged at `0.1.7`.
- Added release-manifest, published differential, and cross-platform smoke CI
  jobs. `timeout` remains local-only and is excluded from the 47-command
  published manifest.
- Published-version verification corrected an erroneous `sh -s` expectation:
  POSIX/dash keeps the invocation name as `$0` and the first operand as `$1`.
  The compatible follow-up `cli/sh@0.1.7` is published and passed the final
  pinned-oracle, differential, smoke, stress, and cross-platform CI run
  `34015767486`; `0.1.6` is not promoted.

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
- Consolidated architecture decisions into nine canonical ADRs. Stage history
  was initially archived separately and consolidated here on 2026-10-26.
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
