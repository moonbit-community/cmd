# Changelog

This repository integrates multiple command packages, so changes are recorded
by date and delivery milestone rather than by a single package version.

## 2026-10-28

- Adopted a bounded rg text-output batching improvement: eligible plain
  output with binary detection disabled uses a 256 KiB input buffer.
  Release-Wasm fixed/regex misses take 21-22% less time; matching-line
  output improves 7%, with 192 KiB additional initial buffer capacity.
  Rejected the ineffective unmatched-buffer async bypass and an unsafe
  default-mode enlargement that loses a previously printed binary prefix.
  Default binary-detecting miss performance remains unresolved. Passed
  1,637 Wasm tests, 118 tool tests, 2,117 functional cases (19 skips),
  377 frozen comparisons, 22 resource pairs and all 35 cumulative rg
  profiles. The full gate remains false: 88/89 profiles qualify and the
  unchanged tac stream control is unstable; no qualified slowdown exceeds
  3%. All 80 locally rebuilt artifacts match the measured candidate, and
  only rg changes. Backup `backup/rg-miss-pilot-20261028` preserves the
  preceding source; no development commit, push or publication occurred.
  See [text-output batching](docs/adr/0003-streams.md#rg-text-output-read-batching-2026-10-28).
- Integrated rg's adjacent matching-line spans and skipped unused global Git
  ignore initialization for stdin-only walks. Existing async entrypoints,
  explicit ignore diagnostics and filesystem-root filtering are preserved.
  Ordinary release-Wasm output improves 2.67-2.69x against the preceding
  source; the optimized Wasm comparison is 11-12% faster than pinned upstream
  rg. Passed 1,632 Wasm tests, 118 tool tests, 2,117 functional cases (19 skips),
  377 frozen comparisons, 14 resource pairs and the recovered 80-command,
  124-package dependency audit. All 27 cumulative rg profiles qualify, as do
  all 33 tool/workload measurements in the Wasm-only chart. The complete
  81-workload protection gate remains false: eight profiles are unstable,
  including rg dense regex output and seven unchanged command controls.
  No qualified profile regresses more than 5%; failed windows are retained.
  `backup/rg-spans-adopt-20261028` preserves the prior source; no development
  commit, push or publication occurred. See the
  [adoption record](docs/adr/0003-streams.md#rg-span-and-stdin-preparation-adoption-2026-10-28).
- Adopted the two verified async-output optimizations into local development:
  empty rg print-prefix guards and the shared writer's private synchronous
  buffer append. All 80 rebuilt Wasm artifacts exactly match the previously
  accepted pilot; strict checks, 1,627 Wasm tests and 20 benchmark-tool tests
  pass again. Registered the eight additional rg protection workloads.
  `backup/rg-async-adopt-20261028` preserves tracked and untracked source;
  the normal Git index and HEAD are unchanged. This is local integration,
  without publication or new platform acceptance.
- Isolated the remaining rg output bottleneck and retained an adjacent-match
  span pilot. Complete release-Wasm output falls from 120.25-120.86 ms to
  48.18-48.58 ms without changing public async entrypoints or read sizes.
  Passed 1,631 Wasm tests, 118 tool tests, 2,109 functional cases (19 skips),
  377 frozen-output comparisons and 14 resource pairs. At that checkpoint the
  new pilot was unadopted: the 81-workload protection run had one unstable
  unchanged ln control, and its separate ordinary-output upstream comparison
  was unstable.
  No qualified workload exceeds the 5% slowdown limit; an unchanged tac
  control's 3.59% first-window observation remains listed separately.
  Further diagnostics identify avoidable global-ignore preparation for
  explicit stdin as a concrete target for several remaining miss gaps.
  See [output spans and input preparation](docs/adr/0003-streams.md#rg-output-spans-and-input-preparation-2026-10-28).
- Completed an isolated async-output pilot without changing public interfaces
  or the live product. Skipping empty rg print prefixes and separating the
  private buffered fast path reduces complete release-Wasm time by about 27%
  for rg matching-line output, 19% for replacement output and 9-12% for
  nl/paste/comm. All 79 two-window protection workloads pass; none slows by 3%.
  Passed 1,627 Wasm tests, 118 tool tests, 2,109 functional cases (19 skips),
  377 output comparisons and 14 resource pairs with no temporary residue.
  Under identical additional Wasm optimization, the output gap against pinned
  upstream falls from 3.10-3.15x to 2.26-2.28x; miss workloads remain slower.
  A reviewable patch and full evidence remain in the temporary pilot directory.
  See the [pilot record](docs/adr/0003-streams.md#async-output-hot-path-pilot-2026-10-28).
- Confirmed a pre-existing rg performance gap against pinned upstream MoonBit
  Wasm: matching-line output takes 3.10-3.15x the time and several miss workloads
  cost 22-31% more, despite faster fixed counting. A fresh two-window,
  seven-workload comparison with the architecture-start artifact passes and
  puts the output change since that baseline at only +0.21-0.33%. Thus the
  large gap predates the current architecture reorganization; its precise
  introducing change remains unidentified. Recorded the async output chain
  as a diagnostic target, not a proven complete explanation. Stopped further
  size-driven rg decomposition and recorded the user's acceptance of the
  separate count prototype's 3.76-4.11% empty-input cost without waiving other
  gates. Product sources and artifacts remain unchanged. See the
  [upstream Wasm diagnosis](docs/adr/0003-streams.md#rg-upstream-wasm-gap-and-baseline-diagnosis-2026-10-28).
- Explored rg source footprint and resumable regex line counting in temporary
  MoonBit/Wasm copies. The live rg implementation remains unchanged. The
  inventory puts rg at 40.02% of core plus command implementation lines and
  49.98% of command lines alone. Trials distinguish the memory benefit of
  cross-block boolean state from regressions caused by bypassing prefix or
  inner-literal filters and by additional self-loop dispatch. The final trial
  improves the qualified structured 64 MiB regex miss by 4.14-4.15x and records
  a kernel RSS change from 165.55 to 40.16 MiB. Its 1,632 Wasm tests and 267
  frozen-Wasm differential cases pass; 29 of 30 timing workloads qualify,
  while a short-input state-budget row remains unstable. Empty-input cost
  increases 3.76-4.11%. Failed trials and complete samples are retained, the
  aggregate timing gate remains incomplete, and no prototype is integrated.
  This is not release or platform acceptance. See the
  [experiment and next-step record](docs/adr/0003-streams.md#rg-source-footprint-and-resumable-regex-exploration-2026-10-28).
- Removed rg's separate `grep_regex` package. Driver now owns the private
  search-rule compiler and matcher adapter; regex syntax owns bounded
  inner-literal analysis. Deleted the builder, copied configuration and
  redundant error wrapper, retaining both regex semantics and existing fast
  paths. Production source is reduced by 315 lines after accounting for moves;
  all named tests and their multiplicities are preserved. Matcher-dependent
  pipeline tests move to driver without exporting
  the adapter or introducing reverse dependencies. All 1,626 Wasm package
  tests, 118 tool regressions and 2,109 functional cases pass, with 19 platform
  skips; 268 additional frozen-Wasm comparisons preserve output, diagnostics
  and status. The 79 other command binaries are byte-identical. All 17 rg
  protection workloads pass; the full 71-workload gate retains three unstable
  unchanged controls and is not marked green. The cumulative 17-workload rg
  comparison also passes; nine separate resource pairs preserve approximately
  166 MiB regex / 40 MiB literal-count RSS at 64 MiB, with no temporary residue.
  See the
  [ownership and acceptance record](docs/adr/0003-streams.md#rg-search-compilation-ownership-2026-10-28).
  Local backup: `backup/rg-boundary-20261028` (`c57c488`). No development commit,
  push, publication or remote-platform acceptance is included.
- Integrated rg's large test data with the existing repository test layers.
  Moved all 751 generated regex records into `tests/fixtures/rg` after a
  field-by-field comparison, preserving the three engine drivers and their
  exclusions. Migrated 44 CLI-equivalent printer cases into the ordinary JSON
  contracts and registry, retaining exact output and original-name aliases;
  20 injected printer cases remain package tests. Recovered two missing ignore
  fixtures, including their BOM bytes, into the same fixture tree. The source
  backup is `backup/rg-tests-20261028` (`a708d86`). See
  [ADR-0001](docs/adr/0001-evidence.md#repository-owned-rg-corpus-and-command-contracts)
  for ownership and [fixture provenance](tests/fixtures/rg/README.md) for scope.
  rg's MoonBit sources decrease from 64,475 to 52,230 lines, principally by
  externalizing data and removing repeated CLI-test setup, not by dropping
  corpus cases. Passed 1,626 Wasm package tests, 118 test-tool tests and 2,109
  functional checks (19 skips, zero failures). The 44 package tests now run
  as CLI contracts. All 80 release-Wasm command binaries are byte-identical
  to the starting artifacts. Versions, published records and product behavior
  are unchanged; no commit, push, publication or remote CI ran.

- Implemented the local internal consolidation across the complete 80-command,
  126-package inventory. Separated contracts from parsing and checksum/gzip
  adapters from algorithms, removed unused fetch/platform/process wrappers,
  typed shell continuation and loop state, simplified bytere cache state, and
  gave rg immutable plans/printers plus shared directory mechanisms. Existing
  optimized layouts and distinct regex/Unicode semantics remain. Package and
  command dispositions are in [ADR-0003](docs/adr/0003-streams.md#internal-architecture-consolidation-2026-10-28-local-candidate).
  The complete starting tree is backed up at
  `backup/core-restructure-20261027` (`c7be0eb`); the normal index is preserved.
  Across core and command sources, implementation decreases by 476 lines and
  behavior tests increase by 615 lines; moved files are counted on both sides.
- Adopted independently checked literal-only rg count streaming and shared
  output buffering for nl/paste/comm. Against this round's already optimized
  starting binaries, 64 MiB literal-record counts use 39-42% less time;
  nl/paste/comm workloads improve approximately 16-22x. Literal-count kernel
  peak RSS falls from about 166 to 40 MiB. General regex long records still
  reach about 166 MiB; comm's single resource pair increases by 3.70 MiB.
  These are complete Wasm executions, without MoonX or startup subtraction.
- Passed 1,670 Wasm tests, 118 test-tool tests and both initial/candidate
  functional runs (2,065 passes, 19 skips, no failures each). Compared all
  80 artifacts: 22 changed and 58 remain byte-identical. The cumulative
  71-profile, two-window run preserves outputs/statuses, but only 65 profiles
  qualify for timing. Six unstable rows remain failures; no qualified row
  exceeds 5% slowdown. The 3.17% tac-file observation is listed separately
  despite its identical binaries. The output-state enum trial was reverted;
  failed trials, setup diagnostics and earlier tac noise remain preserved.
  Full timing acceptance, fresh sealed upstream comparison, three-platform CI
  and actual-main validation remain incomplete. No development commit, push,
  publication, dependency update or frozen-release-record change is included.

## 2026-10-27

- Added the local shared high-performance foundation: rg/wc byte kernels,
  borrowed batches plus owned line scanning, bounded output ownership for rg
  and column, and temporary-directory/range-I/O primitives for tac/column/sort.
  Replaced rg path/JSON printer builders with immutable configurations. Fixed
  sort's one-MiB budget degenerating into per-record runs. Added a workload
  registry and fail-closed artifact/fixture validation, documented in AGENTS.md
  and [ADR-0003](docs/adr/0003-streams.md#shared-high-performance-foundation-2026-10-27).
  The source backup is `backup/shared-foundation-20261027` (`592311d`).
  Passed 1,652 release-Wasm tests and 2,065 functional cases (19 skips).
  All 51 two-window profiles preserve results; 50 qualify for timing, with a
  largest slowdown of 3.39% and wc line counting 7.38-8.04% faster. The final
  tac long-record reference fails dispersion/drift, so full timing acceptance
  remains incomplete; all failed experiments are retained without retrying for
  a pass. Ten kernel observation pairs leave no temporary residue, with a
  largest peak increase of 1.05 MiB (3.62%). The repaired sort workload completes
  in 1.096 seconds under the unchanged 20-second deadline and preserves output.
  Sixty of 80 binaries remain identical; the twenty changed commands all have
  profiles. Moving kernels reduces rg's implementation area by 962 lines;
  repository implementation grows by 20 lines overall. Local work remains
  uncommitted and unpublished, without new cross-platform or upstream acceptance.

- Cleaned imported rg scaffolding after repository-wide dependency and duplicate
  scans, starting from local backup `backup/pre-slop-20261027` (`9712a70`).
  Removed unused walker/mmap layers and duplicate color policy, narrowed internal
  APIs, moved test-only adapters beside tests, and shared chmod/mkdir octal parsing.
  Net reduction is 1,852 MoonBit source lines and 369 generated-interface lines;
  rg implementation shrinks by 1,782 lines (5.3%). Preserved generated data,
  regression corpora and previous performance algorithms. All 22 release-Wasm
  workloads pass two nine-pair stability windows; worst slowdown is 0.40%.
  Seventy-seven of 80 command binaries remain byte-identical. Ten paired Darwin
  kernel observations show at most 112 KiB (0.28%) higher peak RSS and no residue;
  the 64 MiB record remains about 166 MiB. Passed 1,643 Wasm tests and 2,065
  functional checks with 19 platform skips. These are local observations, with
  no new Linux/Windows or published-consumer acceptance. Work remains local and
  unpublished. See [ADR-0008](docs/adr/0008-data.md#internal-api-cleanup-2026-10-27).

- Reduced rg long-record memory with smaller geometric buffer growth and
  independent read-request limits. A 64 MiB record drops from about 376 to
  166 MiB kernel peak RSS (56%); the 20 MiB probe retains a 9 MiB increase.
  All 15 old/new workloads pass both stability windows, with structured long
  records improving 1.13x. Six of ten fresh local Rust comparisons qualify;
  single-record scans still take about 8-9x Rust time. Preserved four noisy
  references and initialization diagnostics without accepting new ratios.
  Passed 1,648 Wasm tests, 2,062 functional cases (19 skips), 792 supplemental
  comparisons with one unchanged upstream difference, and four resource
  comparisons with no residue. Work remains local and unpublished. See
  [ADR-0003](docs/adr/0003-streams.md#long-record-capacity-and-read-requests-2026-10-27)
  for the tradeoff and the proposed cross-chunk matcher continuation.
- Continued with exact SIMD prefix-byte lookup in rg, targeting the largest
  observed gap. Long random-letter regex scans improve 1.70-1.72x over the
  preceding local candidate; all ten old/new workloads are stable. Eight of
  nine fresh local Rust comparisons qualify, with the improved workload still
  about 10.6x Rust time. One noisy reference remains unqualified. Passed 1,646
  Wasm tests and 2,062 functional cases (19 skips); all 288 new regex/set cases
  agree with both Wasm baseline and Rust. The existing rg set retains one
  pre-NUL output difference. Empty-input Wasm observations identify a remaining
  29-31 ms full-execution cost for further diagnosis, without subtracting it.
  Resource checks retain zero residue; old/new kernel diagnosis confirms that
  the roughly 376 MiB peak for a 64 MiB single regex record predates this change.
  Approximately 3-5x workloads are lower priority. No release coordinates change.
  See [ADR-0003](docs/adr/0003-streams.md#simd-candidate-byte-sets-2026-10-27).
- Adopted byte-based column table fields, bounded optional field metadata and
  fused rg literal/grep regex count loops in the local candidate. All 27 final
  old/new workloads pass both stability windows: column tables improve about
  1.54x, rg fixed counts 1.15x and grep regex counts 1.09x relative to the previous
  local candidate. All 17 fixed local GNU/Rust comparisons are stable; substantial
  8-18x gaps remain, while approximately 3-5x workloads are now lower priority.
  Rejected the rg general-DFA skip trial for ordinary regex regressions. Passed
  1,644 Wasm tests, 118 tool tests and 2,062 functional cases (19 skips), plus
  1,728 supplemental comparisons with 30 unchanged upstream differences and
  no new regression. Twelve resource comparisons leave no temporary residue;
  14 kernel RSS pairs retain their single-observation scope. Versions and
  published expectations are unchanged; no push, publish or remote CI ran.
  See [ADR-0003](docs/adr/0003-streams.md#byte-fields-and-fused-count-pipelines-2026-10-27).
- Continued the local candidate with block-level rg counts and bounded exact
  SIMD self-loop skips for eligible long grep records. Two nine-pair windows
  pass all 17 old/new workloads: rg fixed counting improves 1.91-1.92x, grep
  long structured scans about 1.16x and long random-letter scans about 2.15x.
  Rg fixed counting remains 3.39-3.42x Rust time; conventional grep regex counts
  retain a roughly 2% regression. Three of 14 upstream reference rows remain
  noisy. Reverted the column field-metadata pilot after tiny rows slowed 53-55%,
  retaining its source and negative measurements. Passed 1,640 Wasm tests,
  118 tool tests, 2,062 functional cases (19 skips), eight resource comparisons
  and 1,632 supplemental comparisons with 30 existing reference differences
  and no new regression. Eight old/new kernel RSS pairs differ by less than
  0.5 MiB; long-record input storage remains unbounded by the DFA budget.
  See [ADR-0003](docs/adr/0003-streams.md#block-counts-and-certified-state-skips-2026-10-27)
  for exact eligibility, expanded binary-count gaps and subsequent experiments.
  Versions and publication expectations are unchanged; no commit, push,
  publication or remote CI run.

- Continued the local performance candidate with bounded column data/index
  ingestion, selective 256 KiB rg count reads and certified zero-prefix tac
  skips. Against the preceding candidate, two nine-pair windows show 2.31x for
  tiny column rows, 1.17x for the 8 MiB table, 1.24-1.26x for rg misses and
  1.63-1.64x for tac multi-byte misses. The latter reaches 2.60-2.61x GNU time;
  rg fixed counts remain 6.51-6.53x Rust time. Retained small control regressions,
  noisy reference rows and the rejected rg short-needle finder pilot.
  Passed 1,634 Wasm tests, 118 tool tests, 2,062 functional cases (19 skips),
  13 resource comparisons and 1,152 supplemental comparisons with three
  unchanged upstream differences and no new regression. Ten paired Darwin
  kernel observations show column's peak increasing about 2-3 MiB.
  See [ADR-0003](docs/adr/0003-streams.md#bounded-ingestion-and-selective-scan-windows-2026-10-27)
  for exact limits and next steps. Package versions, publication expectations
  and remote branches are unchanged; no commit, push, publication or CI run.

- Continued performance work on local main after the documentation release at
  `987cf02`, importing the isolated candidate without changing published
  coordinates. Added synchronous multi-byte KMP batches for tac and bounded
  cached-page table rendering, ASCII conversion and reusable delimiter
  classification for column. Relative to the imported candidate, two stable
  nine-pair windows measured 8.24-8.69x for tac's selected 8 MiB multi-byte
  separators, 3.65-3.66x for column's 8 MiB table, 3.99-4.02x for long rows,
  and 1.54x for tiny rows. GNU tac file reversal is about 2.7x; multi-byte cases
  remain about 4.2-4.5x and one short GNU reference remains noisy. These are
  local direct-Wasm observations, not final Linux performance acceptance.
  Validation passed 1,627 Wasm tests, 118 test-tool regressions, 2,062 functional
  cases (19 skips), and nine resource comparisons. Supplemental comparisons
  retain two existing GNU differences across 768 cases, with no new regression.
  See [ADR-0003](docs/adr/0003-streams.md#local-continuation-after-the-documentation-release-2026-10-27)
  for final-artifact checks, the column replay and remaining limits. No main
  push, new branch, package publication or remote CI was performed.

- Prepared an isolated performance experiment against `2064a16`, outside the
  active release checkout. Selected changes batch rev output and tac byte
  separators, specialize cut projections, pack literal-automaton metadata and
  dispatch rg summary matches synchronously. Stable local old/new windows
  measured 16.51-16.58x for tiny-record rev, 16.33-16.77x for file tac,
  2.40x for 64 MiB rg fixed counting, and 1.78-1.82x for cut's final-field case.
  Selected cut and file-tac workloads reached the 1-3x GNU target; other
  workloads remain above it or noisy. A regex block cache was rejected for
  heterogeneous-input regressions. Final local validation passed 1,618 Wasm
  tests, with 117 tool tests, 2,062 functional cases (19 skips), a subsequent
  54-case tac replay and 16 resource comparisons. Supplemental differential
  checks found no new regression in 432 cases and retained one existing binary
  grep difference. Publication, CI and release manifests are unchanged.
  See [ADR-0003](docs/adr/0003-streams.md#isolated-performance-candidates-2026-10-27).

- Published a MoonX documentation release for all 78 published commands. All
  80 command READMEs now focus on supported scope, options, limitations and
  examples, with links to the capability matrix and ADRs. Corrected misleading
  filesystem help and rg's inherited upstream thread/mmap/terminal claims;
  rg's short version now identifies cli/rg. rg and timeout are excluded from
  this release. Command versions advance independently and core dependencies
  select the existing 0.8.2, whose fetched registry source matches this checkout.
  All 78 uploads returned HTTP 200 and exact non-yanked registry versions.
  Local validation passed 1,612 Wasm tests, 118 test-tool regressions and
  2,062 workspace functional checks with 19 platform skips. The initial Windows
  README regression exposed CRLF-sensitive assertions; normalization fixed the
  test, and [development run 40428496917](https://github.com/moonbit-community/cmd/actions/runs/40428496917)
  passed all three hosts before publication.
  Local exact-version MoonX acceptance passed 2,094 checks (1,963 semantic,
  78 startup and 53 explicit boundary results), with 18 platform skips and zero
  failures. Seventeen additional README examples passed, including nested MoonX,
  copy/create effects and missing-file suppression.
  [Published acceptance run 40432031612](https://github.com/moonbit-community/cmd/actions/runs/40432031612)
  passed Linux (2,287 checks, 15 skips, including 1,507 pinned differential
  results), macOS (2,094 checks, 18 skips) and Windows (1,961 checks, 151 skips),
  all with zero failures. The current `latest.json` and its separate case snapshot
  now bind these accepted coordinates; `published.json` and historical snapshots
  remain unchanged. This release does not establish formal performance acceptance
  or remove the documented unsupported behaviors.

- Integrated performance PR #60 as `6705ea8` after documentation PR #59,
  with the maintainer's explicit exception for unresolved repeatability.
  Final-head checks and [actual-main run 40406545144](https://github.com/moonbit-community/cmd/actions/runs/40406545144)
  passed Linux, macOS and Windows. Failed resource stability remains failed;
  thresholds, published coordinates and frozen expectations are unchanged.
- Promoted the adaptive literal pilot into the unpublished core/grep candidate:
  dense verification can lazily build one bounded automaton, budget exhaustion
  safely resumes shifts, and subsequent sparse inputs keep the shift fast path.
  Added independent span/offset/folding/record regressions, thirteen real-command
  performance workloads and sixteen sampled/kernel resource comparisons.
  Real-command local pairs improved 1 MiB collision inputs by 13.98x–14.63x
  over merged main while preserving sparse throughput. An initial 15% dense
  count regression was corrected; two existing controls retain 2–3% regressions.
  All 26 old/new rows were stable, while five of 26 GNU rows remained noisy and
  several GNU ratios exceeded 3x. These are diagnostic results, not acceptance.
  Local validation passed 1,611 Wasm tests, 117 tool tests, 2,062 functional
  cases (19 skips), and eight resource smoke comparisons; interfaces are unchanged.
  See [ADR-0003](docs/adr/0003-streams.md#adaptive-literal-planner-2026-10-27).

- Cache/control diagnostic 40398697579 completed every window but retained
  unstable empty-input controls and no passing full selection. Input preloading
  is not a selected fix. Added a separate Linux perf null-counter diagnostic
  with finer CPU accounting; ordinary resource acceptance remains unchanged.

- Linux diagnostic run 40395472012 completed all controlled windows but found
  no stable full selection: 17/23 for either observer, 14/23 with settling or
  one-CPU affinity. Retained these rejected approaches and added a cache/control
  phase with separate kernel-counter observations. Stability remains unresolved;
  performance PR #60 was still unmerged at this investigation stage.
- Added an explicit Linux stability diagnostic to investigate the six noisy
  workloads in resource run 40346450167. It compares observer backends, a fixed
  between-arm pause and one-CPU affinity while retaining every sample and the
  same release Wasm commands. This is diagnostic infrastructure, not a stability
  fix or acceptance result. The ordinary resource gate and thresholds are unchanged.

## 2026-10-26

- Extended the manual resource workflow to cover cut/uniq/wc alongside the
  existing commands, including Linux kernel peak RSS. Added a 23-workload
  direct-Wasm performance profile with two independent nine-pair windows and
  explicit dispersion/drift checks. Raw samples and noisy results are retained;
  this does not publish packages or replace formal performance acceptance.
- Extended unpublished core 0.8.2 and grep 0.3.1 with adaptive multi-literal
  search, record-level count skipping and reuse of proven regex suffixes.
  Selected local pairs improved 64 MiB / 16-pattern counts by 4.49x and a
  16 KiB overlapping-span case by 25.44x over wave 3. Broader literal shapes
  improved 1.21x–1.70x; several GNU ratios still exceed the 1–3x exploration
  target. A regressing reverse-DFA skip experiment was removed. Passed 1,604
  Wasm package tests, 117 Native tool tests and 2,062 functional cases with
  19 skips and no failures. The independent GNU set matched 792/796, retaining
  four known empty-pattern differences. [ADR-0003](docs/adr/0003-streams.md#performance-wave-4-candidate-2026-10-26)
  records measurements, bounds, negative evidence and deeper follow-up
  directions. No publication or formal performance acceptance is claimed.
- Extended unpublished core 0.8.2 and grep 0.3.1 with borrowed byte searches,
  paired endpoint DFAs, shared fallback decoding and resumable synchronous span
  emission. Selected local pairs improved original/many-match/long-record spans
  by 3.24x/4.08x/3.64x over wave 2. Original spans remain 3.16x GNU; many-match
  and word-filtered rows are 2.19x and 1.96x. Counting gains are smaller and some
  regex count rows show small regressions. Passed 1,597 Wasm package tests,
  117 Native tool tests and 2,062 functional cases with 19 skips and no failures.
  The independent GNU set matched 684/688, retaining four known empty-pattern
  differences. [ADR-0003](docs/adr/0003-streams.md#performance-wave-3-candidate-2026-10-26)
  records resource bounds, raw evidence and remaining gaps. No publication or
  formal performance acceptance is claimed.
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
