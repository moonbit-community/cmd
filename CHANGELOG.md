# Changelog

Dated delivery summaries. Development changes do not update published packages
until a separate release through `moon publish`.
[ADRs](docs/adr/README.md) own decisions; the
[performance guide](docs/performance/README.md) explains current algorithms.
[Latest published coordinates](tests/release/latest.json)
remain independent of candidate expectations.

Full historical reports, intermediate failures, measurements and corrections
are preserved in the
[pre-consolidation changelog](https://github.com/moonbit-community/cmd/blob/c4ea7795b0eb6e6fd6d0dffa0e7709809569bbb1/CHANGELOG.md)
and [ADRs](https://github.com/moonbit-community/cmd/tree/c4ea7795b0eb6e6fd6d0dffa0e7709809569bbb1/docs/adr).

## 2026-11-05

Development; no publication.

- Add `cli/typst@0.1.0` as a local Wasm candidate: migrate the existing CLI,
  document environment, font/package discovery and watcher; retain the
  typesetting engine as `moonbitlang/typst@0.1.10`. Replace the command's
  platform implementation with released public MoonBit APIs, including binary
  standard streams and output-error propagation.
- Local macOS validation passes all 1,884 Wasm package tests (84 for Typst),
  204 Native tool tests and 2,520 functional checks, with 21 platform exclusions
  and zero failures. Typst checks include metadata without stdin consumption, evaluation/imports,
  PDF file/stdout identity, PNG dimensions, page selection, dependency output,
  output failure and watch recompilation. Retain explicit platform and feature
  boundaries; no full upstream parity or performance claim is made.
- Register 81 local commands while retaining all 79 published coordinates.
  Add the first Typst candidate, pinned Linux Typst 0.15.1 comparisons and an
  explicit untimed performance disposition. Publication and exact-version
  acceptance remain separate gates.
- Update CI to MoonBit `0.10.19+bee578715`, migrate deprecated derive syntax
  while retaining existing trait methods, and use the current string-view API
  in test infrastructure. Full-workspace checks retain `--deny-warn`. Use the
  controlled MoonBit child for allowed-process policy checks on every platform,
  and handle mixed Windows separators when reporting Typst dependencies.
- Keep the sort spill regression's full input, output and cleanup assertions;
  allow 30 seconds for the child to finish within the existing 60-second case
  deadline. Windows passed at 14.27 seconds in PR validation but exceeded the
  former 15-second inner wait on the first main run. This is test scheduling
  headroom, not a product performance result.

## 2026-11-03

Development; no publication.

- Close the 213 finite catalog/primary-operation definition gaps with 224
  additional cases and stronger retained assertions. Review the 44 partial
  facets against current typed observations, including streaming, deadlines,
  retries, request bodies, file effects, metadata and child cleanup.
- Reject unresolved finite obligations, incomplete execution stages and stale
  evidence during acceptance. Preserve existing corpus inputs, product APIs,
  package versions and independent published expectations. Zero finite gaps
  does not establish exhaustive semantics or full upstream parity.
- Local macOS validation passes 1,800 Wasm package tests, 204 Native tool tests
  and 2,498 functional checks, with zero failures and 21 platform exclusions.
  All 865 reviewed claims satisfy their applicable requirements; nine retain
  excluded platform bindings. Required three-platform CI remains separate.

## 2026-11-01

Development and publication.

- Development: unify test orchestration under `tests/run.mbtx`, separate current
  cases, release policy, finite coverage review and generated definitions, and
  move specialized assertions out of the generic harness. Split network,
  permission and resource tools by responsibility; retire overlay manifests,
  duplicate current indexes, backend parameters and old entry paths.
- Development: check every standalone script and generated index in CI. Keep
  run-bound coverage evidence outside committed definitions and preserve
  independent published coordinates and expected-case bytes.

- Publish core 0.9.1 and 26 changed command versions from `c5c016c` after
  [three-platform source CI](https://github.com/moonbit-community/cmd/actions/runs/41294367461).
  Verify all 27 uploads and registry builds; retain 53 command coordinates and
  keep timeout local-only. Updated commands select core 0.9.1.
- Exact-version MoonX acceptance covers all 79 published commands. Local macOS
  passes 2,338 checks with 21 skips; [published CI](https://github.com/moonbit-community/cmd/actions/runs/41295557751)
  passes Linux 2,345/18, macOS 2,338/21 and Windows 2,183/176 (passes/skips),
  all with zero failures. Linux includes 1,553 pinned differential results.
  Promote the independent latest snapshot; these are scoped correctness results.

- Improve byte encoding, numbering, comparison, sequence output, inflate, JSON
  framing, merge consumers, tail, patch, sort and find while retaining their
  specialized failure and fallback contracts.
- Repair rm trailing-separator symlink protection and exact decimal sort keys.
  Stream find/xargs batches, reuse child slots as they finish, distinguish
  launch failures from child exit codes, and await owned children. Release
  discarded tail storage and report both move and backup-recovery failures.
- Stream base32 encoding and adapt rg counting to actual progress, replay and
  record lifetime. Reuse cp preflight/copy logic and remove unreachable branches.
  Add real workloads for previously uncovered ln/test artifacts.
- At `c4ea779`, local validation passes 1,800 Wasm package tests, 198 Native
  test-tool tests and 2,274 CLI checks, with 21 platform skips. Required
  [three-platform CI](https://github.com/moonbit-community/cmd/actions/runs/41277371739)
  passes. Cumulative local timing qualifies 165/171 rows, including all base32,
  rg and cp rows; wc/fmt exact-comparison failures and cat/xargs instability
  keep the full performance gate failed.
- Consolidate ADRs into current decisions and this changelog into dated
  summaries. Add topic-based performance documentation for call paths,
  invariants, resource costs, fallbacks and useful rejected approaches.

## 2026-10-31

Development; no publication.

- Consolidate timing into one schema-3 inventory of complete, hash-pinned genuine
  sources. Retire generated-size timing and command-specific pipelines; retain
  exact assertions, selectable aliases and failed/incomplete windows.
- Bind finite claims to actual scenario receipts and immutable Linux oracle
  routes; separate test-tool platform expectations from Wasm product behavior.
- Adopt sed byte-prefilter/buffered-output work and csplit page/index improvements.
  Packed Huffman/CRC combinations and other unsuccessful trials remain excluded;
  selected gains do not establish complete performance acceptance.
- Correct the invalid mixed-security-context Darwin mkdir comparison, then fix
  the separately reproduced symbolic sticky-bit creation difference. Preserve
  the correction, platform-specific assertions and frozen published expectations.
  Repair repeated-record diff alignment without weakening expected results.

## 2026-10-30

Publication, followed by separate development work.

- Publish core 0.9.0 and 43 command packages from `4ca0e4d`: 42 updates and
  the first rg 0.1.0 release. Verify all 44 uploads/builds; 36 command coordinates
  stay unchanged, giving 79 published commands. Timeout remains local-only.
- Required [source CI](https://github.com/moonbit-community/cmd/actions/runs/40984331217)
  and [published acceptance](https://github.com/moonbit-community/cmd/actions/runs/40986324873)
  pass. Linux/macOS/Windows record 2,369/2,180/2,049 checks and 16/19/150 skips,
  with zero failures; Linux includes 1,531 pinned differential results. Local
  exact-version acceptance passes 2,180 checks with 19 skips. These results do
  not establish full upstream parity or formal performance acceptance.
- Consolidate shared contracts and command adapters, remove unused rg layers
  and HTTP forwarding, and enforce private driver ownership. Keep core API
  trial proposals unadopted and historical release archives recoverable in Git.
- Subsequent development strengthens independent contracts, typed observations,
  proof joins and genuine-source workloads; repairs jq grouping/sorting,
  sh stdin-option parsing and nl padding. These changes and their local checks
  do not broaden the earlier publication's acceptance.

## 2026-10-29

Development; no publication.

- Improve rg policy selection, bounded Boolean counting, probe replay, plan/cache
  reuse, deferred tables, read-ahead and matched-record output.
- Preserve dialect and fallback boundaries. Selected measurements pass, while
  incomplete or unstable full selections remain unqualified.

## 2026-10-28

Development; no publication.

- Consolidate catalog/adapters and filesystem traversal; keep rg command policy
  private to driver and prevent lower-layer reverse imports.
- Move large corpora and equivalent CLI cases into shared fixtures/registries,
  preserving package-private tests and making missing fixtures fail.
- Improve progressive search reads and output batching. Retain failed full
  performance selections and rejected wrapper-removal trials in history.

## 2026-10-27

- Publish documentation/metadata updates for all 78 released commands using
  existing core 0.8.2. Rg and timeout remain unpublished.
  [Published acceptance](https://github.com/moonbit-community/cmd/actions/runs/40432031612)
  passes all three hosts with zero failures.
- Integrate performance PR #60 with the explicit maintainer exception for
  unresolved repeatability; [actual-main checks](https://github.com/moonbit-community/cmd/actions/runs/40406545144)
  pass. The resource stability failure remains unresolved.
- Continue unpublished byte/buffer/temp-I/O, adaptive matching and long-record
  work. These later changes do not update released coordinates or establish
  formal performance acceptance.

## 2026-10-26

- Move required CI to Wasm products on Linux/macOS/Windows and Native test tools.
  Share workspace/MoonX assertions, bound execution and require cleanup.
  Retire daily schedules, Native product pairing, change audits and sealing;
  resource and published acceptance workflows remain manual.
- Verify all 78 published coordinates in
  [run 40270955851](https://github.com/moonbit-community/cmd/actions/runs/40270955851).
  This validation uploads no packages.
- Integrate unpublished rg 0.1.0 through PR #58 with pinned algorithms, public
  async I/O and direct-child regressions; [actual-main CI](https://github.com/moonbit-community/cmd/actions/runs/40307223749)
  passes. Compression, identity, terminal, PCRE2, mmap and parallel limits remain.

## 2026-10-25

- Add stable/merge/seeded-random sort, exact fixed-ABI formatting, paragraph/tab
  controls and selected command options. Stream rev, index csplit/column on disk,
  spool tac and bound sort runs/fan-in; these budgets are not RSS caps.
- Publish core 0.8.0 and 76 changed command versions; curl/wget retain 0.2.3.
  Subsequently publish core 0.8.1, column/rev/tac 0.1.4, csplit/diff 0.2.1,
  split 0.1.3 and sort 0.2.3 after PR #56 checks. The other 71 versions and
  existing dependency declarations stay unchanged in that follow-up.
- Final local exact-MoonX validation covers all 78 commands: 2,135 cases,
  22 skips and zero failures. It does not establish new cross-platform or
  formal direct-Wasm performance acceptance.

## 2026-10-24

- Add pure DEFLATE cost-based encoding and Reader gzip decoding with preserved
  error prefixes. GNU roundtrips/selected size checks do not imply byte identity
  or performance acceptance.
- Expand BRE/ERE, capture handling, streaming grep and sed execution; retain
  grammar and non-C-locale limits.
- Reuse copy/scanner buffers, specialize wc counters and cache external-sort
  keys. Add diff reconstruction/directory modes, patch offset/fuzz and selected
  C-byte text options; unsafe existing patch replacement still rejects.

## 2026-10-23

- Fix Docker oracle cancellation ownership and fail uncertain cleanup.
  Actual-main C0 passes; the earlier timeout cause remains unconfirmed.
- Harden the then-current change-coverage mechanism, subsequently retired by
  the 2026-10-26 CI decision.

## 2026-10-20

- Publish core 0.7.0 and curl/mv/wget 0.2.3 with async 0.22.5; retain the other
  75 coordinates. Add explicit HTTP framing, transfer profiles and sink lifetime.
- Retain Windows Wasm link-move/backup rejections; the Native fix is insufficient.
  [Published acceptance](https://github.com/moonbit-community/cmd/actions/runs/39409393072)
  passes on three hosts with pinned Linux comparison for the selected 95 cases.

## 2026-10-18

- Publish core 0.6.0 and 78 metadata patch versions with shared help/version
  behavior. [Published acceptance](https://github.com/moonbit-community/cmd/actions/runs/39045905149)
  passes on three hosts; its original closed-stdin captures do not prove unread
  live input.
- Repair test lifecycle ownership, startup, listener observation, historical
  expectation separation and failure reporting.

## 2026-10-12

- Audit all 79 then-local command READMEs and metadata paths with Native/Wasm
  probes. Keep published coordinates and older expectations separate.

## 2026-10-11

- Publish core 0.3.0 and sixteen new 0.1.0 commands: csplit, diff, expr, fmt,
  fold, gunzip, gzip, hexdump, md5sum, od, patch, sed, sha1sum, sha512sum,
  split and zcat, retaining explicit filesystem/algorithm boundaries.
- Publish core 0.4.0 and column/date/strings/which 0.1.0, bringing publication to
  78 commands. Follow with core 0.5.0 and affected patches for semantic repairs,
  retaining unchanged coordinates.
- Complete the selected 841-case fidelity release with
  [three-platform MoonX acceptance](https://github.com/moonbit-community/cmd/actions/runs/38140928875)
  and Linux comparison. Timestamp cases run serially; the earlier atime cause
  remains unconfirmed.

## 2026-10-10

- Implement the second pure MoonBit command batch and shared checksum, byte-regex
  and gzip components. Retain explicit patch inode/mode replacement boundaries.

## 2026-09-27

- Publish 0.1.1 for base32, cksum, expand, mktemp, realpath, rev, tac, tree,
  unexpand, unlink and yes after three-platform checks and exact-MoonX acceptance.

## 2026-09-26

- Publish those eleven commands at 0.1.0, bringing the inventory to 58.
  Keep core 0.2.0 and unchanged commands. Record async 0.22.4 metadata,
  process and terminal boundaries.

## 2026-09-21

- Publish core 0.2.0 and 47 command versions after three-platform source checks,
  exact-MoonX acceptance and pinned Linux comparison.
- Consolidate the shared testkit and migrate 240 legacy invocations to JSON
  contracts, retaining unsafe filesystem operations as tested rejections.

## 2026-09-20

- Add persistent pipe shell sessions, concurrent make scheduling, complete
  environment inheritance, Basic authentication and cookies.
- Repair stream/JSON/filesystem behavior while retaining identity, mode,
  timestamp, process-group, exec and terminal boundaries. Evidence is local
  development validation before the following publication.

## 2026-09-19

- Audit published MoonX behavior, separating semantic defects, missing public
  APIs and unsupported profiles; use observations for subsequent regressions.

## 2026-09-06

- Repair descending seq, sh diagnostics and jqlog terminal newlines. Cover
  echo/false/jqlog/seq/sleep/true 0.1.5 and build the pure MoonBit exact-version
  release runner with shared fixtures, effect assertions and failure reporting.
- Publish compatible sh 0.1.7 after correcting the sh -s positional expectation;
  final cross-platform and pinned-oracle run 34015767486 passes. Version 0.1.6
  is not promoted. Timeout stays outside the 47-command published manifest.

## 2026-09-05

- Deliver JSON, make/xxd, filesystem and command-local compatibility subsets
  with explicit API limits; expand the then-current manifest to 48 commands
  and 176 semantic cases.
- Consolidate nine ADRs, correct pinned-oracle edge cases and remove stray
  duplicate interface artifacts. Historical Native/Wasm three-platform
  [CI](https://github.com/moonbit-community/cmd/actions/runs/33964497821) passes.

## 2026-09-04

- Deliver HTTP, text/environment, find/xargs and shell compatibility slices in
  pure MoonBit; unify support records, oracle expectations and host policy tests.

## 2026-09-03

- Establish measured Wasm command support, stream/binary/error cleanup and
  descriptor-follow tail behavior, retaining explicit support boundaries.

## 2026-09-02

- Add pinned Docker upstream comparison and distinguish observed compatibility,
  implementation boundaries and validation scope.

## 2026-08-26—2026-08-30

- Establish publishable command modules, shared core and command inventory.
  Add initial read/filesystem/restricted commands with host-owned authorization;
  timeout remains local-only.
