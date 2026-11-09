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

## 2026-11-09

Development only.

- Use the standard MoonBit argument parser for `serve`, including generated
  help, attached port values and usage diagnostics for invalid arguments.

- Repair Wget Expires date grammar, short-year mapping, UTC normalization and
  invalid-date ordering with an independent C-locale parser and frozen real
  process controls. Retain Domain/configuration and publication boundaries.

- Repair Wget numeric Cookie expiry parsing, explicit deletion versus retained
  stale entries, permanent zero timestamps and saved integer rounding. Retain
  independent fixed-oracle expectations and separate clock-sensitive controls;
  date/Domain/configuration work and publication remain outstanding.

- Repair Wget URL/option credential precedence, per-hop Basic challenges and
  hostname caching across ports and operands. Correct uncovered 401 exits,
  empty URL usernames and attached authentication booleans with independent
  raw request and binary replay controls; broader #34 work remains open.

- Repair Wget cookie port isolation, persistent jar interpretation, domain-chain
  spelling, quoted attribute extraction and sticky deletion. Verify real request
  fields and saved/reloaded state against finite fixed-oracle expectations;
  complete numeric/date grammar and the remaining #34 work stay open.

- Add a pinned Unicode 15 URL-host converter for workspace curl and wget,
  retaining command-specific input encoding and whole-host fallback. Preserve
  structured host identity across redirects, credentials, cookies and public
  TCP/TLS connections. Full Cookie Domain, IRI and configuration dialects remain
  open under #34; published coordinates are unchanged.

- Repair workspace curl cookie-prefix validation, normalized jar paths, Secure
  origin/overlay rules and host-only replacement identity. Preserve Wget's
  distinct security behavior; complete jar dialects remain open under #34.
  Published coordinates are unchanged.

- Add complete pinned ICANN/PRIVATE cookie suffix admission and Curl's exact
  suffix host-only conversion and original domain case in saved jars. Retain
  case-insensitive identity/overlay checks, Wget's imported-file and rejected-domain
  deletion policies, independent
  raw input and full-list oracle checks; advance oracle PSL data in profile
  revision 2. URL IDNA and the remaining #34 dialects stay open.

- Repair unpublished curl repeated request fields, ordered response fields and
  Basic challenge-list recognition. Replace lossy header observations and the
  misbound Wget Cookie redirect claim with real wire coverage. Retain successful
  network launch, wire and oracle receipts in CI artifacts; #34 remains open
  for its remaining protocol, cookie, configuration and jq work.

## 2026-11-08

Development and publication.
- Repair the unpublished mkdir candidate's standalone build against its declared
  published core dependency after package consolidation. Preserve numeric mode
  grammar and mark find/test examples as unpublished candidates. Publication
  remains separate from development validation.
- Repair unpublished ln recovery diagnostics to retain creation and restoration
  failures together with destination/backup paths. Assert real file states and
  preserve cancellation after committed creation; published packages are unchanged.
- Repair unpublished Wget Basic rejection status to 6 and preserve its ordering
  with HTTP and network failures across URL operands. Retain Curl's HTTP status
  behavior, with wire and CLI regressions. Published coordinates are unchanged.
- Repair unpublished ln/mv numbered backups to advance after the highest valid
  version instead of filling a gap. Preserve old contents, propagate scan errors,
  handle decimal versions beyond machine integers, and refuse competing numbered
  backup replacements in existing mode. Add shared and CLI
  regressions; published packages and frozen expectations remain unchanged.
- Repair unpublished env/make parent-path handling: retain missing components
  and symlink traversal, and resolve each make working-directory change before
  later paths. Add cwd, recipe-selection and no-execution regressions. Published
  coordinates and frozen expectations remain unchanged.
- Refine the unpublished simplification: consolidate small packages and test
  ownership, use direct names, remove redundant error branches and checks, and
  fix Wget's multi-URL exit precedence. Retain independent CLI regressions,
  imported corpora and frozen published expectations. Performance work remains
  deferred; this change does not publish or select new package versions.
- Prepare an unpublished repository simplification candidate: move validation
  metadata out of core, reduce implementation-only APIs and unreachable rg/Typst
  adapter states, merge identical tests, and remove redundant buffering work.
  Preserve CLI contracts, imported corpora and frozen published expectations.
  [ADR-0003](docs/adr/0003-streams.md#repository-simplification-dispositions)
  records ownership and the maintainer's decision to defer performance
  qualification and optimization to a separate stage. Required three-platform
  [development CI](https://github.com/moonbit-community/cmd/actions/runs/42459222677)
  passes the implementation; no package is published by this change.
- Integrate the serve candidate with the subsequent diagnostics, shell/make and
  filesystem work. Preserve both sets of command contracts and the independent
  published snapshots; serve remains unpublished among 82 local modules. Isolate
  macOS scenario fixtures from background indexing while retaining exact
  timestamp preservation checks.
- Develop issue #29 candidates find 0.2.6, mkdir 0.2.7 and test 0.2.4:
  repair metadata size/time predicates, standalone test argument precedence,
  find action/error ordering and postorder snapshots, and honest mkdir parent
  permission/Windows setter boundaries. Add real special-file, sparse-file,
  time/reference, partial-effect and Windows metadata contracts. Three-platform
  development, exact-version publication acceptance and final independent audit
  remain pending; the published coordinates below are unchanged by preparation.
- Extend the finite shell/make language profile with arithmetic side effects,
  backticks, expanded here-documents, standard-stream aliases, loop levels,
  printf/test, variable/export recursion, secondary expansion and SHELLSTATUS.
  Preserve named/default export policy, recipe expansion/environment phases,
  contextual syntax rejection, complete EOF continuation and unexpected
  child-output failures without replay. Existing POSIX FIFO jobservers retain
  exact token ownership/return; descriptor pipes, Windows semaphores and server
  creation remain explicit API boundaries.
- Publish core 0.9.5, make 0.2.8, sh 0.2.9 and split 0.1.10 from `273ea9f`
  after [actual-main development CI](https://github.com/moonbit-community/cmd/actions/runs/42425407212)
  and independent audit. Apply the POSIX trailing-slash directory requirement
  to every file predicate and both timestamp operands, including the macOS 15
  file-link gap found after the size repair. Verify all four successful uploads,
  registry builds and package checksums. Retain the other 77 coordinates:
  80 published commands among 81 local modules, with timeout local-only.
- [Exact MoonX acceptance](https://github.com/moonbit-community/cmd/actions/runs/42426809418)
  passes all 80 coordinates: local macOS 2,984/0/31, Linux 2,993/0/28,
  macOS 2,984/0/31 and Windows 2,734/0/281 (pass/fail/platform exclusions).
  Independently audit all receipts, the fixed Linux oracle and all six required
  oracle scenarios. Freeze 2,850 definitions, including 380 F31 cases: retain
  all 2,802 previous IDs with six metadata output updates and 48 additions.
  The new POSIX cases pass on Linux/macOS and have explicit Windows exclusions;
  the existing Windows path regression passes. Each development platform passes
  1,994 Wasm product tests and 205 Native test-tool tests. Isolated make/split
  sources pass 44/8 Wasm tests; all three consumers exercise the uploaded core.
  Sh has no package tests of its own.
- Earlier core 0.9.2, 0.9.3 and 0.9.4 releases retain their dated coordinates,
  counts, exclusions and upload failures in the
  [preceding release record](https://github.com/moonbit-community/cmd/blob/273ea9ff3e0f045189cb3f3f5837d63c297b6c8c/CHANGELOG.md#2026-11-08).
  Later independent audits found size, export and raw-path omissions; earlier
  successful finite acceptance did not establish those missing behaviors.
  Current receipts establish finite correctness, not full GNU/POSIX parity or
  formal performance acceptance.

## 2026-11-07

Development and publication.

- Repair the finite diagnostic and extension profile for issue #22: preserve
  Base32/Base64 failure prefixes and canonical padding, apply rmdir's actual
  removal/ignore policy, honor echo's POSIX environment, and preserve option
  values and literal operands during alias normalization. Correct ordinary
  usage statuses, name project aliases, reject private parser keys, and match
  jq's file-mode flag semantics. Sort/tac protect owned temporary cleanup
  against their existing published core interfaces, including cancellation.
- Publish tree 0.1.6 with name-only, non-following link entries in text, JSON and
  HTML. Dangling/cyclic links no longer abort a normal listing; `-d` selects real
  child directories while retaining explicit operands. Selected-link sizes and
  target-dependent colors retain explicit rejection contracts.
- Publish 46 changed command coordinates from `847e66a` after
  [three-platform development CI](https://github.com/moonbit-community/cmd/actions/runs/42377993139)
  and independent source/receipt audit. Keep core 0.9.1 and the other 34 command
  coordinates unchanged: 80 published commands among 81 local modules, with
  timeout local-only. Verify every upload, registry build and package checksum;
  retain the failed tail transport attempt before its verified successful retry.
  Exact coordinates and 2,470 independently frozen definitions were recorded in
  [latest.json](https://github.com/moonbit-community/cmd/blob/20772c0/tests/release/latest.json)
  and [latest-cases.json](https://github.com/moonbit-community/cmd/blob/20772c0/tests/release/latest-cases.json).
- Exact-version MoonX acceptance passes all 80 coordinates: local macOS has
  2,609 passes, zero failures and 28 platform exclusions;
  [published CI](https://github.com/moonbit-community/cmd/actions/runs/42379717812)
  has Linux 2,618/0/23, macOS 2,609/0/28 and Windows 2,427/0/210
  (pass/fail/platform exclusions). Linux includes the fixed upstream oracle,
  all four Linux-only oracle scenarios and 126 F17 differential cases. Each
  platform's development checks pass 1,899 Wasm and 204 Native test-tool tests;
  isolated sort/tac packages pass 34/14 Wasm tests against core 0.9.1/0.9.0.
  These receipts do not establish full upstream parity or formal performance
  acceptance; older releases retain their dated evidence in Git.

## 2026-11-06

Development; no publication.

- Add the local `cli/serve@0.1.0` candidate: static GET/HEAD, MIME types,
  index.html, canonical root checks and launcher-supplied Wasm policy. Keep
  directory listings and SPA/upload features out of scope. Concurrent hostile
  path replacement remains an explicit public-API boundary. Published coordinates
  are unchanged.

- Upgrade workspace modules, standalone test tools and the rg child fixture to
  `moonbitlang/async@0.22.7`. Keep one dependency baseline and update the active
  compression-review descriptions and touch diagnostic to match. Existing
  command support boundaries and published coordinates remain unchanged.
  Preserve sort's empty random-source diagnostic across host error-code changes
  by rejecting that operand before opening it.
- Follow the official `latest` toolchain and core in development, published
  acceptance and resource workflows. Retain resolved-version logs and include
  them in compilation cache keys. The former 0.10.19 host fails restricted-policy
  standard-stream initialization after the async upgrade; latest includes the
  acquired-handle file-kind fix.
- Expose existing cleanup guarantees as `nocancel` and protect temporary-file
  cleanup. Keep ln/mv destination rollback cancellable after a committed mutation,
  with a regression preserving the moved file and backup. Keep output flushes
  cancellable under backpressure, with local warning declarations and a serial/parallel paste
  cancellation regression. A deterministic atomic-commit regression catches
  the previously leaked temporary file on cancellation. Strict checks retain
  every other warning.
- Launch rg's process fixtures with Moon's `--quiet` so dependency build notices
  do not contaminate the fixture's stderr. Preserve the exact stream/status and
  cancellation assertions while isolating build-tool notices.
- Standard local macOS validation on latest passes 1,886 Wasm package tests,
  204 Native tool tests and 2,520 functional checks, with 21 platform exclusions
  and zero failures. Strict product/tool/script checks, architecture, generated
  index consistency, coverage proofs, interfaces and formatting pass.

## 2026-11-05

Development and publication.

- Publish the first `cli/typst@0.1.0` from `c3f5973` after
  [three-platform main validation](https://github.com/moonbit-community/cmd/actions/runs/41952232874).
  Verify the upload and registry build. Migrate the CLI, document environment,
  font/package discovery and watcher while retaining the external
  `moonbitlang/typst@0.1.10` engine. The pure MoonBit Wasm adapter uses public
  APIs for binary standard streams and output-error propagation.
- Exact-version MoonX acceptance covers all 80 coordinates. Local macOS passes
  2,361 checks with 21 platform exclusions; [published CI](https://github.com/moonbit-community/cmd/actions/runs/41957907959)
  passes Linux 2,368/18, macOS 2,361/21 and Windows 2,206/176 (passes/skips), all
  with zero failures, including seven pinned Typst 0.15.1 evaluation comparisons.
  Promote only Typst and its 21 cases; preserve the previous 79 coordinates and
  frozen expectations. Timeout remains local-only among 81 modules. Local first
  downloads timed out; official prebuild bytes were SHA-256 verified and cached
  before the successful MoonX run. No workspace-built Wasm replaced the release.
- Development validation passes 1,884 Wasm package tests (84 for Typst), 204
  Native tool tests and 2,520 local macOS functional checks, with 21 platform
  exclusions and zero failures. Typst assertions cover metadata without stdin
  consumption, evaluation/imports, PDF file/stdout identity, PNG dimensions,
  pages, dependency output, output failure and watch recompilation. Retain
  explicit feature/platform limits and an untimed disposition; this does not
  establish full upstream parity or performance acceptance.
- Update CI to MoonBit `0.10.19+bee578715`, migrate deprecated derive syntax
  while retaining existing trait methods, and use the current string-view API
  in test infrastructure. Full-workspace checks retain `--deny-warn`. Use the
  controlled MoonBit child for allowed-process policy checks on every platform,
  and handle mixed Windows separators when reporting Typst dependencies.
- Keep the sort spill regression's full input, output and cleanup assertions;
  allow 30 seconds for the child to finish within the existing 60-second case
  deadline. Windows passed at 14.27 seconds in PR validation but exceeded the
  former 15-second inner wait on the first main run. This is test scheduling
  headroom, not a product performance result. Published watch tests now stop
  the console group, await stream EOF and verify Windows working-directory
  release; the initial direct-wrapper cancellation failed cleanup and was not
  counted as acceptance.

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
