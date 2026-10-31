# Changelog

This multi-package repository records changes by date. An entry marked
development describes workspace source, not a registry release. Exact
published versions are in [latest.json](tests/release_runner/current/latest.json).
Current technical decisions are in [docs/adr](docs/adr/README.md).

Full historical experiment reports remain in the
[pre-simplification Git version](https://github.com/moonbit-community/cmd/blob/6e7be831cc687386b4e4f62eaad6d4cf7a34318b/CHANGELOG.md).
Their failed, incomplete and platform-limited results keep their original scope.

## 2026-10-31

Development test and benchmark replacement; no publication.

- The first final-cleanup CI run exposed four Windows path-expectation failures
  and two Linux env directory-output differential failures. Complete captures
  show host separator spelling and the oracle's `/work` mount identity. Add
  explicit native-path expectation templates without rewriting observed output;
  declare the existing mount-identity relation for the two env cases. New
  counterexamples retain exact child/control directory, filename, payload,
  terminator and extra-record constraints. Frozen published expectations and
  the original failed CI captures remain unchanged. The follow-up Native
  test-tool run passes all 190 tests, including the two new counterexample tests.

- Final cleanup removes the old pilot/schema2/synthetic benchmark engine and
  unused reserved/disclosure/stability workflows; their source is preserved
  at `8c4efe2`. The active benchmark has one genuine-source Wasm execution path.
  Quality generation and runtime checks share one classifier. Add independent
  false-result test predicates and require the sleep cancellation observer to
  distinguish a waiting child from an immediate-success no-op.
- Correction to the initial audit below: the claimed Darwin mkdir setuid
  incompatibility came from mismatched sandbox contexts and was invalid.
  Same-context native/Wasm controls agree on those bits. A separate sticky-only
  `+t` Darwin creation discrepancy is repaired without changing Linux behavior.
  Default diff now agrees with GNU on the genuine CPython source pair and160
  bounded alignment controls. The documented wc descriptor-metadata boundary
  remains; no package is published by this development update.
- Pre-CI local verification passes 1,723 release-Wasm package tests, 188 Native
  test-tool tests and 2,260 functional checks, with 21 platform skips and zero
  failures. All 652 reviewed finite definitions join fresh execution receipts;
  four retain explicit platform-partial scopes. The 125 real-source comparisons
  check 123 rows and retain exactly two failed wc regular-stdin padding rows,
  with artifact integrity intact. The genuine diff pair now agrees exactly;
  24 same-context mkdir mode pairs agree after the Darwin fix. Seven new exact
  CLI regressions bring the active JSON inventory to 2,194 definitions. The
  remaining index still records 180 new-observer labels, 32 activation-review
  labels and one yes lifecycle feature; these are label counts, not test counts.
  This is finite development correctness evidence, not complete compatibility,
  formal performance or exact-version published acceptance.

Initial replacement audit (its original results and subsequent correction are
recorded separately):

- Replace generated performance matrices and the rg-specific timing launcher
  with one schema-3 real-source engine: 125 rows, 105 reviewed modes, 40 timing
  commands and explicit correctness-only dispositions for ln/make/sh. Pin 31
  complete sources totaling 22,152,148 bytes; enforce 16 MiB per source and
  64 MiB unique bytes without repetition, padding or trimming. Seven former
  synthetic regimes retain finite correctness bindings rather than invented
  real-source timing claims.
- Consolidate 107 duplicate CLI invocations while retaining aliases, oracle
  routes and independent assertions; add 13 activating companions and strengthen
  existing stream, runtime and filesystem expectations. All 2,187 current JSON
  definitions have source-bound exact/typed/finite assertion descriptors.
  Imported rg data preserves all 751 original records/names through 726 unique
  execution groups. Local gates supplement Linux pinned differential checks.
- Independently correct bad supplemental expectations and unsupported benchmark
  arguments exposed by actual execution. Preserve an actual Darwin mkdir
  setuid-directory difference as a failing regression; see ADR-0004. Quality
  descriptors alone do not prove option activation: 180 catalog labels still
  require new scenario evidence, 32 strengthened labels require activation
  review, and one yes lifecycle feature remains. The SHA256 per-line warning
  facet is independently reconciled through exact diagnostics and its actual
  local pass. Historical acceptance is not
  broadened; publication continues to use `moon publish` only.
- Current macOS evidence: 1,722 release-Wasm package tests and 208 Native
  test-tool tests pass; 41 disclosure controls and six CLI failure gates pass.
  The fresh real-source run records all 125 rows: 122 checked and three exact
  native mismatches (two documented wc regular-stdin padding boundaries and
  default-GNU versus minimal diff). Its independent local preflight passes88
  with one platform skip. Full functional execution passes2,253, fails the
  retained Darwin mkdir case and skips20. The uniform cksum A/A control passes
  three workloads through two windows of nine pairs; this is pipeline
  validation, not an improvement or full performance result. Independent final
  readback confirms these scopes. One old diagnostic capture was accidentally
  overwritten/reproduced and is excluded from final evidence; the fresh
  complete run is authoritative. Full compatibility, three-platform, formal
  performance and publication acceptance remain unestablished.

## 2026-10-30

Development cleanup and publication.

- Development evidence reconciliation: repair 83 exact-contract and 23 typed
  scenario registration omissions, narrow mixed-scope claims, and require every
  named binding. Bind actual scenario values to current reviewed descriptors,
  command ownership, complete result streams and the freshly built test driver.
  The subsequent local macOS/Wasm run passes 2,167 functional checks with 19
  skips and zero failures; 113 typed observations cover six executed scenes.
  All 651 reviewed facets pass where applicable; four retain explicit platform
  exclusions. Native test-tool tests pass 179/179 and twelve malformed/stale
  evidence checks reject. Independent readback verifies these identities and
  observations. The [remaining work index](tests/registry/coverage-gaps.md)
  distinguishes 180 catalog labels requiring new activated fixtures/observers,
  33 requiring stronger assertions on existing fixtures, and one supplemental
  `yes` lifecycle feature. These are label counts, not test counts. Full
  compatibility and three-platform, upstream, performance and publication
  acceptance remain unestablished by this development run.

- Further development evidence repair: add 53 independent CLI contracts,
  183 seed variants, 60 complete-source tasks and 14 slow-output controls;
  connect their applicable panels to performance protection. Add an ordinary
  CI proof join for finite reviewed assertions, typed metadata versions,
  source-case identity and complete observation dimensions. Current local
  results are 1,718 release-Wasm package tests, 172 Native test-tool tests,
  and 2,165 functional results with 19 platform skips and zero failures.
  The proof profile executes 545 reviewed facets; 319 catalog labels and
  one supplemental primary operation remain unresolved. New samples exposed
  and repaired unreleased jq grouping/sorting, sh stdin-option and nl padding
  defects. Independent reserved evaluation remains failed at 21/22 because
  GNU-default wc whitespace differs from the documented C-byte profile;
  an explicitly calibrated ordinary replay passes 22/22. Two canonical rev
  rows retain invalid-reference status. No general compatibility, formal
  performance, three-platform or publication acceptance is established;
  package publication remains `moon publish` only.

- Development benchmark repair: connect required command-mode, natural-file,
  fragmented-pipe and original 89-query rg panels to protection and resource
  timing. Verify aliases, freeze actual executables/inputs, retain per-row
  feature observations and fail incomplete or unstable windows. Replace
  self-input/early-exit fixtures with explicit diff, join, comm, csplit, jq and
  codec regimes; compare gzip by decoded content. Previously used evaluation
  files remain explicitly unblinded. Historical results and published
  coordinates are unchanged; this does not establish general performance or
  resource acceptance.

- Development test-evidence repair: reject vacuous assertions and malformed
  selection metadata before platform skips; strengthen one shell stderr
  expectation, including its locally rechecked published coordinate. Add exact
  per-engine regex corpus accounting, orthogonal record/file-size sweeps and
  varied synthetic corpora. Reports explicitly scope timing claims; rename the
  synthetic resource profile while retaining its legacy alias. These changes
  do not retroactively broaden the release results below or establish general
  performance acceptance.

- Published core 0.9.0 and 43 command packages from source commit `4ca0e4d`:
  42 updates and the first rg 0.1.0 release. All 44 uploads and registry builds
  were verified. Thirty-six command coordinates remain unchanged; timeout remains
  local-only. The latest inventory selects 79 commands and independent resolved
  expectations. Core API migrations are explicit; C02 trial proposals remain
  unadopted.
- Source [development CI](https://github.com/moonbit-community/cmd/actions/runs/40984331217)
  passed all three required hosts. Local exact-version MoonX acceptance passed
  2,180 checks (2,048 semantic contract results, 79 startup availability checks
  and 53 boundary results), with 19 skips and zero failures across all 79
  coordinates.
  [Initial startup attempts](https://github.com/moonbit-community/cmd/actions/runs/40985862616)
  stopped while registry assets were queued; full acceptance restarted after all
  builds succeeded. [Three-platform published acceptance](https://github.com/moonbit-community/cmd/actions/runs/40986324873):
  passed Linux (2,369 checks, 16 skips, including 1,531 pinned differential results),
  macOS (2,180 checks, 19 skips) and Windows (2,049 checks, 150 skips), all with
  zero failures. Formal performance acceptance remains unresolved; no broader
  upstream parity is inferred.

- Made HTTP method expectations independent of the implementation, consolidated
  duplicate cases through selectable aliases, and removed redundant assertions
  and duplicate filesystem executions. Retained failure-path coverage.
- Shared HTTP fixtures between current cases and retained cohorts; workspace
  redirects/resume use explicit JSON contracts while frozen published checks
  retain their existing assertions. Removed editorial wording locks.
- Switched benchmark defaults to the latest accepted inventory and corpus.
  Removed retired release archives from the checkout; their complete contents
  remain in Git at 234f960. At that cleanup stage, latest/candidate snapshot
  bytes were unchanged.
  Test cleanup passed 1,706 Wasm tests, 118 tool tests and 2,112 functional
  checks with nineteen skips. All 80 product binaries match the baseline
  rebuilt with the same current toolchain.
- Rg now rejects ineffective --dfa-size-limit values explicitly, with aligned
  help, README, support metadata and command regressions.
- Removed unused matcher helpers, indexing/device-identity branches,
  thread/mmap state, ignore-origin payloads and redundant mode wrappers.
  Narrowed driver types and moved test-only helpers beside their tests.
- Enforced the matcher/searcher-to-driver boundary for production and both
  test import forms. Replaced unreachable success assertions with rejection
  coverage and added complete HTTP upload protection cases.
- Removed the HTTP payload forwarder while preserving wire ownership.
- Simplified ADRs into current decisions and this changelog into dated
  updates; complete earlier reports remain recoverable from Git.

Cleanup commit 6e7be83 passed [three-platform CI](https://github.com/moonbit-community/cmd/actions/runs/40973796440).
Local correctness: 1,707 Wasm tests, 118 test-tool tests and 2,122 functional
checks, with nineteen platform skips. The real-corpus matrix qualified 89/89;
full performance protection remains failed at 159/160 because an unchanged
ln startup control exceeded dispersion limits. This is not published or
mainline acceptance. Dump-loop and core API/async proposals remain pending
in [ADR-0003](docs/adr/0003-streams.md#pending-cleanup-decisions).

## 2026-10-29

Development changes; published coordinates unchanged.

- Added grep whole-record output batching and bounded anchored matching,
  plus rg early Boolean termination and selective cross-chunk regex counts.
- Made search policy, replay, cache preparation and pressure retirement
  explicit. Shared byte-membership/wide-scan mechanisms and column field
  traversal while retaining specialized command loops.
- Bounded reads independently of retained long-record allocation and
  deferred non-raising reverse/capture storage. Fixed tac cleanup-only
  error reporting and retained cancellation cleanup.
- Reduced eager rg metadata work; added progressive regular-file refills
  and plain-record output admission without changing decoder/error order.
- Added strategy/source/test/workload validation and boundary regressions.

Final local correctness passed 1,706 Wasm tests, 118 tool tests and 2,117
functional checks with nineteen skips. The final 89-task real matrix
qualified; a registered confirmation passed 156 protection profiles after
an earlier noisy run. Earlier governance and pilot failures remain failed.
These local measurements do not establish general upstream superiority,
published-coordinate acceptance or formal resource acceptance.

## 2026-10-28

Development changes; no registry release.

- Separated command catalog, checksum/gzip CLI adapters and algorithms.
  Added shared directory mechanisms and typed shell/cache states; removed
  unused forwarding APIs while preserving command-specific policies.
- Moved rg search policy and its matcher adapter into driver. Preserved
  regex dialects, Unicode tables and lower-layer independence.
- Moved 751 imported regex records to fixtures and 44 CLI-equivalent
  printer tests to the common runner, preserving expected values and
  private/injected tests. Restored two missing ignore fixtures.
- Added bounded literal/Boolean counting, lazy tables, prefix rejection,
  exact long-record matching, DFA minimization and adaptive exit probes.
- Batched rg output and reused buffered output for nl/paste/comm.
- Removed the obsolete rg launcher from CI and corrected the Windows
  hidden-attribute test without changing directory filtering.

Selected correctness and affected-command measurements passed, but several
complete performance selections remained unstable or incomplete. Their
results are preserved in the historical ADR; no full-suite or release
acceptance is inferred from these integrations.

## 2026-10-27

- Published documentation/metadata updates for all 78 released commands.
  Reused existing core 0.8.2; rg and timeout remained unpublished. Exact
  command versions and frozen cases are in the latest release manifest.
- Local MoonX acceptance passed 2,094 checks with eighteen skips, plus
  seventeen README examples. [Published acceptance](https://github.com/moonbit-community/cmd/actions/runs/40432031612)
  passed Linux/macOS/Windows with 2,287/2,094/1,961 checks and 15/18/151
  skips, including 1,507 pinned Linux differential results; zero failures.
- Integrated performance PR #60 with the explicit maintainer exception
  for unresolved repeatability. [Actual-main checks](https://github.com/moonbit-community/cmd/actions/runs/40406545144)
  passed; the resource stability failure remained unresolved.
- Continued development with shared byte/buffer/temp-I/O mechanisms,
  adaptive literal matching, lower long-record allocation and specialized
  count, field and reverse-read paths. Removed unused imported rg layers
  and shared chmod/mkdir octal parsing. These later source changes did not
  update the released coordinates or establish formal performance acceptance.

## 2026-10-26

- Migrated required CI to Wasm products on Linux, macOS and Windows, with
  shared workspace/MoonX assertions and Native test tools. Retired daily
  schedules, Native product pairing, change audits and artifact sealing.
  Resource and published acceptance workflows remain manual.
- Added live-stdin metadata checks, bounded test execution and strict
  process/container cleanup and reporting. Reused compilation state.
- Verified all 78 published coordinates in [run 40270955851](https://github.com/moonbit-community/cmd/actions/runs/40270955851):
  Linux/macOS/Windows passed 2,287/2,094/1,961 checks with 15/18/151 skips.
  This validation uploaded no packages.
- Integrated unpublished rg 0.1.0 through PR #58 with pinned algorithms,
  public async I/O, Windows paths and direct-child lifecycle regressions.
  [Actual-main CI](https://github.com/moonbit-community/cmd/actions/runs/40307223749) passed;
  compression, identity, terminal, PCRE2, mmap and parallel-search limits remained.
- Added unpublished byte/count/regex accelerators and manual direct-Wasm
  resource profiles. Known upstream differences and unstable measurements
  remained explicit; no performance acceptance or publication was claimed.
- Consolidated obsolete reports and migration plans into canonical docs.

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
