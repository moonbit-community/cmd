# ADR-0003: Streams, Ownership and Bounded Search

Status: Accepted
Date: 2026-09-05
Updated: 2026-10-31

## Decision

Dependencies flow from command adaptation to domain implementation to runtime
mechanisms and algorithms. Keep one cli/core module. Share a mechanism when
at least two actual consumers need the same contract; catalog validation is a
legitimate consumer even when no command links it. Keep dialects, traversal
policy, error ordering and specialized loops with their owners.

Preserve exact bytes, terminators, operand order and partial output. Do not
normalize newlines, trim complete output or rewrite the caller's locale to hide
a gap. A borrowed buffer may be used only within its valid synchronous scope;
records that outlive a refill must own their storage. Completed output is
flushed on input failure where the command contract requires it. Failed output
writes poison the writer and are never replayed during cleanup.

## Genuine-source performance and local regression evidence (2026-10-31)

Use one schema-3 inventory, `tests/benchmark/real.json`, for every timed
command. Command-specific timing launchers and generated performance matrices
are retired. Admit only complete, provenance-recorded and hash-checked real
files, bounded to 16 MiB per source and 64 MiB unique source bytes. Preparation
and encoding remain outside timing. A named mode or facet cannot prove an
input feature or internal fast path: validate actual observations and the
reviewed invocation policy, then calibrate complete effects against the native
reference outside old/new timing. Native references are test tools, never
product implementations or immutable-oracle parity by themselves.

Every selected command runs independent local boundary contracts before
timing. Preserve exact streams, filesystem and process effects, original case
aliases and frozen published expectations. Consolidate identical stimuli only
after combining their independent assertions; fail stale quality descriptors,
duplicate stimuli, empty diagnostic assertions and unwired dynamic observers.
The Linux differential suite supplements this local gate.

The declared scope is 43 commands: 40 have real-source timing, while ln, make
and sh retain correctness-only witnesses. Seven former synthetic regimes keep
explicit correctness bindings without a real-source timing replacement. Lift
these limitations only with bounded genuine sources and reviewed invocations;
do not manufacture workload coverage through generated inputs or labels.
Existing synthetic resource/stability investigations remain explicitly scoped
diagnostics and cannot qualify performance protection. Failed or unstable
windows remain evidence; no automatic retries or sample removal qualify them.
Publication continues to use `moon publish`; this decision adds no packaging,
registry operation, platform acceptance or performance result.

## Package ownership

| Package | Responsibility and retained boundary |
| --- | --- |
| cli | Argument parsing and ordered diagnostics; no catalog or authorization policy |
| contracts | Capability and command records consumed by validation tools |
| platform | Honest capability queries; no character-device substitute for terminal detection |
| process | Execution context, environment and direct-child lifecycle; command statuses remain local |
| fsops / fsops/mode | Shared filesystem policy and the chmod/mkdir octal parser; symbolic modes and ordered effects remain local |
| fswalk | Directory-handle lifetime, observed kinds and requested sizes; callers own sorting, pruning and links |
| stream | Borrowed batches, owned record scanning and buffered output ownership |
| tempio | Exclusive temporary directories, retryable cleanup and exact range copies; callers own spool formats |
| bytesearch | Reusable byte kernels, including distinct fixed-array SIMD and immutable-view operations |
| bytere | C-byte regex semantics, explicit cache states and bounded accelerators with full-query fallback |
| checksum | Digest algorithms and incremental state; checksum/cli owns records, files and command diagnostics |
| gzipops | Codec state, history and Huffman tables; gzipops/cli owns options and command execution |
| shell | Typed incomplete-input and loop-control state; sh, make and split own orchestration |
| netops | One transfer execution path with separate request, response, redirect and output responsibilities |
| numfmt | Input profiles, exact numeric values, rounding and formatting for printf, seq, od and hexdump |
| time_zone | Checked TZif parsing and timestamp conversion for date and diff |
| jq_filter | Public-AST adaptation for jq/jqlog, preserving assignment paths |
| quoting / tabstops | Byte-specific quoting and shared parsed tab grids; callers retain their dialects |

Command loops remain distinct where ownership differs: cat/head/tail/tee/join
have different stopping and output rules; comm/nl/paste share buffering but not
merge, numbering or delimiter state. A universal command framework would add
policy plumbing without demonstrated reuse. Generated Unicode tables, imported
corpora and meaningful published APIs are not dead code merely because a
runtime-only usage scan finds no dependent caller.

## 0.9.0 release

The 2026-10-30 release selects `cli/core@0.9.0` because the current source
changes public APIs from published 0.8.2. Catalog types and functions move from
`cli` to `contracts`; checksum and gzip command entrypoints move to
`checksum/cli` and `gzipops/cli`, leaving algorithms and codecs in their parent
packages. Netops fetch wrappers, process I/O forwarding wrappers, redundant
platform probes and `cli.warn_stdin_wait` are removed. Callers use the shared
transfer API or the released async filesystem/process APIs directly.

`platform.is_terminal` and `terminal_output_enabled` become synchronous;
automatic terminal detection remains unavailable. `LineScanner` now wraps
`RecordReader`, changing its exposed storage fields while retaining `new` and
`next`. The [core migration table](../../core/README.md#090-api-changes)
records the source replacements. The version boundary makes these ownership
and function-type changes explicit for downstream consumers.

The release uploaded 43 command packages, including the first `rg` release at
0.1.0, based on direct source changes or changed runtime-package reachability.
Thirty-six published commands retain their existing coordinates; `timeout`
remains local-only. All 44 uploads and registry builds were verified. Source
commit `4ca0e4d` passed all three required development checks; local exact-version
MoonX acceptance passed 2,180 checks with 19 skips and zero failures across all
79 coordinates. The [release summary](../../CHANGELOG.md#2026-10-30) records
these results and three-platform published acceptance.
Earlier validation below retains its original scope and does not certify these
new coordinates.

The C02 visibility, deprecation and `Session::finish` proposals remain unadopted.
The release version change does not add those API changes to this release.

## Search ownership and execution

Rg's driver owns private search policy and its concrete matcher adapter.
Regex syntax and automata stay in internal/regex; reusable byte mechanisms stay
in core/bytesearch. Matcher and searcher must not import driver, including
through black-box or white-box tests. Adapter-dependent integration tests live
with driver; private capacity tests retain a local test matcher. The
[architecture check](../../tests/architecture.mbtx) validates production and
test boundaries and the source/test/workload strategy registry.

Immutable input, search and output plans are separate from mutable statistics,
buffers and caches. Searcher owns streaming-discard eligibility, read capacity,
sink delivery priority and fresh versus replayed input. The line buffer owns
prefix commitment. Begin, binary transition, EOF, read-error and sink-stop
ordering must remain observable. Driver argument types and test-only helpers
stay private; unsupported indexing has rejection paths rather than dormant
execution state. Thread/mmap syntax retains its documented no-op behavior.

Core BRE/ERE/Emacs selection and rg leftmost-first matching are not interchangeable.
Keep ordinary engines as semantic fallbacks. Fast paths require explicit
eligibility and equivalence tests, not pattern resemblance. Current mechanisms:

- Bounded literal plans, adaptive shift/AC handoff and exact byte-membership
  probes avoid repeated verification while preserving offsets and captures.
- Boolean record machines may discard input only after eligibility is known.
  Cross-chunk state and endpoint replay remain in specialized loops; byte
  kernels do not own whole-command policy.
- Repeatedly unproductive lazy-DFA pressure retires the cache and restarts the
  original query through PikeVM. Unicode quits are not cache pressure.
- NFAs compile eagerly to preserve syntax/size errors and group metadata.
  Non-raising reverse/capture storage is prepared once on demand.
- Optional tables are prepared only when needed, preserving their original
  values, ordering and explicit-option error timing.

### Limits and fallback

Equal numeric values do not imply shared policy. Construction limits bound
accelerator setup; profitability thresholds select among equivalent paths.
Neither is a total process-memory limit.

| Owner | Limit or policy | Fallback / constraint |
| --- | --- | --- |
| rg driver | 4 KiB minimum block, 256 KiB ordinary block; eight density samples in 4 KiB | Ordinary verifier or wide plan |
| rg literal cursor | 4 KiB eligible literal; at most length minus one retained suffix | Buffered matcher outside eligibility |
| rg searcher | 64/256 KiB nominal reads; 1 MiB grown-record request cap | Retained long-record allocation is separate |
| rg Boolean automata | 512 NFA states, 256 DFA states, 65,536 transition entries | Existing regex engine on construction failure |
| rg minimizer | 65,536 work components, 32 rounds | Original transition rows |
| rg wide scan | 64-byte probe, 32-byte sparse-exit threshold | Exact transition loop |
| bytere literal set | 4,096 literal bytes, 1,024 AC states; 4 KiB/256-check density window | Shift plan or ordinary matcher |
| bytere record DFA | 256 NFA/DFA states, eight skip plans, 256-byte acceleration entry | Span engine on exhaustion |
| rg lazy DFA | Three pressure clears with fewer than ten searched bytes per constructed row | Retire for engine lifetime; productive windows reset accounting |
| column field plan | 64 KiB total, 128 rows, at most one eighth of row bytes; 1 KiB entry threshold and 12-byte entries | Scan fields directly; still compute display widths |

The general rg compiler's fixed 10,000-state limit is not a byte budget.
`--dfa-size-limit` rejects after numeric validation because no byte-accounted
cache implements it. Enable it only with real budget accounting, fallback and
execution-level boundary regressions.

## Input and output mechanisms

The core line scanner reuses a 64 KiB input buffer and scans only unconsumed
bytes. Cross-chunk records accumulate; returned records own their bytes.
Storage follows the largest encountered record plus a block, not record count.
Cat/copy reuse block buffers; wc computes only selected counters. Strings
retains only its minimum-length candidate before streaming the continuation.

Rg regular-file buffering separates physical refills from decoder requests.
Eligible files start at 64 KiB and grow only after a full physical read, using
at most 1 MiB per worker. Short reads are not EOF; cached bytes precede a
retained read error. Stdin, preprocessors, nonregular files and explicit early
exits keep their own read path. This buffer bound excludes decoder, record,
matcher and output storage. Directory entries cannot be assumed regular merely
because the public entry says they are not directories.

Rg plain output can admit a complete record atomically to the existing 64 KiB
writer after match extraction, replacement and statistics. Declining admission
changes no output or counters. Styled, multiline, oversized and explicitly
line-buffered records retain ordered handling. Grep selects execution mode
once and commits complete records with their accounting; its input cursor,
context state and binary/error behavior remain separate.

## Streaming and temporary storage

| Command | Storage and failure contract |
| --- | --- |
| rev | One validated ASCII/NUL record plus buffers. Reject non-ASCII before emitting that record; retain completed output and continue later operands. |
| sort | Prepare keys once; preserve stable ties and first unique representatives. Default 64 MiB accounted budget and at most sixteen merge inputs exclude oversized active records and runtime overhead. Ordinary output consumes sources before truncating an existing destination. |
| split | Stream independent byte/line layouts; use observed regular-file size or owned spools for total-dependent layouts. Line-byte mode spools long pending prefixes. Keep completed pieces after later failure. |
| split round-robin | Ordinary outputs close per record, but path state grows with visited pieces. Filter mode retains one pipe/session per visited piece and does not claim a fixed process bound. |
| csplit | One input snapshot and 64-bit boundary index; disk is input bytes plus eight bytes per boundary. Two caches are at most 64 KiB each, plus the current regex line and cleanup paths. Pre-output spool failures leave no pieces; later failures remove owned fragments unless -k. |
| tac | Fixed separators use backward 64 KiB blocks and overlap on regular files. Stdin/nonregular/regex input is spooled before output. Regex additionally retains O(input) contiguous storage with signed 32-bit matcher indices. |
| column | Snapshot displayed records once; disk is displayed bytes plus sixteen bytes per record. Retain longest record, widths and bounded pages. Table caches cap at 1 MiB data/64 KiB index; grid maxima are 16 MiB/1 MiB, allocated on demand. Late read errors preserve completed records; spool failure precedes formatting. |

Temporary directories are exclusively created and owned files use mode 0600
where supported. Cleanup closes handles before removal, preserves the primary
error, reports cleanup-only failure and runs under observable cancellation.
It cannot guarantee unwinding after SIGKILL or machine failure. A live regular
file is not an immutable snapshot. Accounted budgets are never advertised as
RSS caps. Resource profiles and assertions remain in the existing
[benchmark registry](../../tests/benchmark/protection.json) and command tests.

## Known limits

- C-byte behavior is intentional: wc -c/-m both count bytes; non-C widths,
  locale collation and automatic terminal discovery require separate work.
  Command substitution strips trailing LF only. Base64 -w0 adds no newline.
- Wc cannot infer regular-file stdin alignment without descriptor kind/size
  APIs. Sort rejects nonzero percentage budgets without a public physical-memory
  query; 0% uses its minimum budget.
- Genuine CPython JSON-module inputs expose a diff comparison-policy boundary:
  the product's valid minimal script exactly matches fixed GNU diffutils 3.12
  `--minimal`, while GNU's default heuristic emits a longer valid script.
  Both independently reconstruct the complete right file. The configured
  exact-default-GNU benchmark remains failed; do not normalize its output or
  reinterpret the mismatch as a performance regression. Qualifying a different
  reference profile requires an explicit reviewed policy and fresh evidence.
- Tac regex needs a paged/seekable matcher before its O(input) storage can be
  removed. A long repeated-input difference for overlapping fixed separator
  `aa` remains documented; optimization does not establish full GNU parity.
- Seq has no arbitrary output-record cap, but numeric operands retain the
  documented 4096-character and -4096..4096 exponent/scale bounds.
- Hexdump forward stdin skip uses read/discard, an explicit extension over the
  pinned util-linux pipe behavior. Backward/end-relative stdin needs seek support.
- Tee's explicit output-error modes use observed pipe errors. Default SIGPIPE
  parity needs public signal restore/raise support; do not invent signal status.
- Filesystem identities, terminal behavior, process groups and compression
  boundaries remain in ADR-0004/0006/0008 and the support record.

Expand these profiles only with the relevant public API or sound algorithm,
positive and failure regressions, and applicable Wasm/oracle evidence.

## Pending cleanup decisions

**C01 — dump loops:** keep the two owner-local 16-line readers for now. Eight
CLI probes confirmed different zero-limit opening, over-skip and empty-input
effects; rendering and finalization also differ. Sharing the loop would add
state/callback plumbing. A narrower allocation trial may inspect slice
materialization, but the source expression does not prove an extra allocation.
Any replacement first needs injected short-read, EOF, budget and output-failure
coverage in addition to the existing format cases.

**C02 — core API:** the following changes remain proposals, not adopted code.

| Candidate | Decision evidence and next condition |
| --- | --- |
| Private teddy_max_literals, Algorithm::hex_length and gzipops/cli.help | Real same-package consumers, no dependent callers and absent at these coordinates in published 0.8.2. An isolated visibility trial passed strict checking with all 80 command binaries identical. The visibility change remains deferred; the 0.9.0 release separately documents migration of old gzipops.help to gzipops/cli.help. |
| Deprecate platform.is_cross_device_error, native_separator and accepts_separator | First has no current caller; the others have only local test callers. All are published. Choose a compatibility policy before removal; local non-use cannot prove external non-use. |
| Make Session::finish synchronous | No async operation or shared callable contract requires async. Trial passed strict checking and 1,707 Wasm tests, but changes the published function type and sh/make/split binaries. Requires a deliberate core API revision and performance checks. |

Retain catalog validation, gzip decoding, cookie serialization, header lookup
and timezone decoding APIs with actual consumers. The audit covered eighteen
functions/constants with no dependent-package use, not every public field/type.
All C02 trial edits were restored. C03's document-growth issue is addressed by
this decision-focused layout and immutable history links.

## Validation status and history

### Test-evidence repair (2026-10-30 development)

Compatibility fixtures reject vacuous empty substring assertions, unknown
comparison/platform metadata and contradictory file expectations. Validation
precedes platform exclusion; malformed metadata cannot become a successful
skip. The shell `set -e; false; printf no` case now requires exact empty stderr.
The same explicit correction strengthens the independent expectation for
published `cli/sh@0.2.4`, after a local exact-version MoonX probe returned status
1 with empty stdout/stderr. Its script, status and coordinate are unchanged;
the earlier acceptance result did not establish an exact stderr assertion for
this case. This is a test correction, not a product or release change.
Fifteen redundant empty-content fields on expected-absent tee paths were also
removed in current and independent published fixtures. The previous checker
ignored those fields; exact absence checks remain and now have an explicit
regression against unexpectedly created empty files.

Regex corpus drivers check expected compilation and exact executed/rejected/
excluded partitions; a disappearing parseable case cannot silently reduce
engine coverage. Existing imported corpus values remain unchanged.

Benchmark records separate total bytes and record width, retain explicit
synthetic controls, and add versioned varied text, duplicate runs and valid
JSONL. Reports distinguish selected-workload evidence from general acceptance.
The resource `heldout` name is retained only as a legacy alias for
`mixed-synthetic`; it has no blind-holdout status. The natural-corpus, transport,
option, host and resource matrices still require separate execution. These
repairs do not establish general performance acceptance or broaden supported
command behavior. Preserve failed/noisy and historical evidence.

Lift the remaining representativeness limitation only with independently
selected natural data and a reserved holdout, immutable corpus/query identities,
equivalent status/bytes/effects and all required timing/resource windows. A
synthetic-only pass or fixture count cannot lift it.

Local repair validation passed 1,711 Wasm package tests, 132 Native test-tool
tests and architecture checks. The complete applicable Wasm functional runner
passed 2,112 checks with nineteen platform skips and zero failures. An
independent read-only agent reviewed the final diff, found one incorrect `yes`
output-sink label, and confirmed its per-row correction and regression; final
recheck reported no remaining actionable finding. The 400-row scaled matrix
was structurally validated, not fully timed. Required three-platform CI and
sealed Linux upstream comparison remain separate from these local results.

### Benchmark execution and corpus repair (2026-10-30 development)

The subsequent evidence extension adds183 three-seed mode variants,60 complete
source tasks across all36 measured commands and14 bounded slow-output rows.
Nine additional immutable ordinary sources include real C, Unicode properties,
HTTP specification, license registry, CSV relationships and Japanese text.
Actual seed bytes/key files, join/comm overlap, source-derived csplit boundaries,
split reassembly/counts, codec decoding and independent JSON counts are checked.
Slow-output delays, consumption, process completion and direct-child cleanup
remain inside the interval. Combined panels reject duplicate IDs and split
leakage before selecting commands. Invalid native rev calibration fails the
reference row and cannot qualify a ratio.

The complete-source comparison exposed nl's unnumbered-line prefix defect;
the unreleased implementation now replaces both number and separator bytes
with spaces. Exact blank/custom/UTF8-separator cases accompany the real source.
These are unreleased correctness changes, not updated published coordinates.

`tests/proofs` accounts for every live catalog label and selected primary
operations. Independent finite reviews bind exact contracts to actual fresh
Wasm results, selected assertion definitions, current metadata versions and
observation dimensions. Partial/unreviewed facets remain explicit; metadata,
platform skips and case counts cannot prove general command compatibility.
The ordinary workspace CI executes this bounded profile, while exact published
acceptance keeps separate frozen expectations. The reservation policy requires
independent new source selection after candidate/tool/policy freeze and checks
identities again after evaluation. Once disclosed, data becomes ordinary for
later candidates. None of this revives the retired push audit wrapper or adds
release packaging; package publication remains `moon publish` only.

The independently selected reserved evaluation used complete IANA tzdata2025b
Europe/table files and a Kubernetes v1.33.2 OpenAPI schema: 22 tasks across 16
commands, selected after the candidate/tool/policy freeze. It remains failed
at 21/22. GNU-default `wc -w` returned 30494 versus 30492 for the documented
C-byte profile; GNU with `POSIXLY_CORRECT=1` and the host C-byte observer both
confirmed 30492. The reference calibration now applies explicitly to native
wc only, with actual environment overrides recorded. Original inputs, args,
selection hashes and failure captures were preserved. After disclosure the
ordinary replay passed 22/22; it is not a new blind success. Both scalar and
vector-boundary A0-as-nonseparator CLI assertions accompany this distinction.
The host environment remains partly inherited and is labeled nonhermetic;
this local comparison does not substitute for the immutable Linux oracle.

The final local bounded proof profile executed 545 finite facets with 319
catalog labels and one primary-operation supplement still unresolved. It
does not qualify every spelling, every input, every platform or every behavior
behind a catalog label. The final independent review confirmed 2165 functional
passes/zero failures/19 skips, retained platform exclusions as unqualified,
and verified that the failed reservation and ordinary replay remain distinct.
Formal timing windows and three-platform execution remain separate obligations.

The subsequent registration and scenario reconciliation closes 83 exact-contract
and 23 typed-scenario registration omissions. Every named binding is required;
the generator cannot silently discard an unreviewed companion and retain a
broader activation. Mixed-scope activations are narrowed, with additional
facets retained explicitly. A shadowed `ls -L` invocation is replaced by
identical nonempty directory-link fixtures under `-LdF` and `-PdF`. Serial
`make -k`, HTTP preauthentication and wget one/two-attempt controls distinguish
their selected effects; numeric delay and other unobserved effects remain open.

The current CI controller builds the Native test driver between equal assertion
source snapshots. Actual Wasm receipts bind complete selected definitions,
command ownership, frozen expected/observed values and whole-result hashes and
counts to that build and execution. Scene success alone cannot qualify a
catalog label. Missing, duplicate, wrong-command, altered, stale or hidden-failure
evidence rejects; twelve real negative-pipeline executions confirm rejection.
This binds test assertions and does not restore the retired push audit wrapper.

The subsequent local macOS/Wasm run passes 2167 functional checks with zero
failures and 19 skips, including 113 typed assertions in six scenes. All 651
reviewed facets pass where applicable; 647 are qualified without exclusions and
four retain five explicitly excluded platform companion bindings. Native test
tools pass 179 tests. Two independent read-only reviews verify source/build,
definition/result identities and observations. The [remaining work index](../../tests/registry/coverage-gaps.md)
contains 180 catalog labels requiring new activated fixtures or observers, 33
requiring independent or structured assertions on existing fixtures, and one
supplemental `yes` stream-lifecycle feature. These are labels, not missing
implementations or test counts. Forty-four partial-facet reminders are separate
and add no unresolved labels. Full catalog qualification and general semantic
exhaustiveness remain false. New platform execution, immutable-oracle comparison
and formal timing remain separate obligations.

The subsequent benchmark audit found that adding the scaled manifest had not
changed the protection or resource timing entry points. Their older synthetic
profiles were still the only measured inputs. The earlier test repair and
review above therefore do not establish benchmark representativeness.

Protection and resource performance now invoke the same required panels:
explicit command modes and independent size/data-shape combinations, complete
natural files with frozen SHA-256 identities, fragmented stdin pipes, and the
unchanged original 89 rg queries. The latter retains all 1,729 original input
identities and compares complete status/output with a frozen native ripgrep.
All applicable panels must finish both nine-pair windows, with per-side
MAD/median at most 5% and between-window drift at most 10%. Baseline-Wasm
comparisons additionally require every row's slowdown at most 5% in each
window. Missing, duplicate, partial, incorrect or unstable rows cannot pass.
Synthetic aliases are verified against their full concrete workload identity
and timed once; counts are not estimates of usage frequency.

Named-file diff inputs are distinct copies; sparse and distributed edits have
explicit modes. Join/comm inputs contain shared and unpaired keys, and join
also exercises duplicate-key products. Csplit splits repeated interior
boundaries. Jq covers filters, slurp aggregation, sorting/grouping, deep escaped
values and records crossing 64 KiB. Ordinary mixtures give short records 80%
of input bytes, with cyclic and clustered order controls; long-record controls
remain separately identifiable. Decode modes include stored, literal/fixed,
dynamic, concatenated-member, overlapping and full-window-distance streams.
Gzip equality is decoded content equality, including the legacy protection
stream row. Search prefilter misses no longer claim to exercise DFA work;
private matcher and fragmented-counter tests validate the route controls.

Reports observe actual byte/record distributions and hashes outside timing,
including both generated named files. Inputs, runtime, candidate/baseline Wasm
and native reference/observer executables have pre/post identity checks. New
schema-1 measurements are retired; retained historical reports remain readable.
New timing requires explicit direct-Wasm artifacts; the unfrozen published
MoonX launch/cache timing path rejects before invocation or report creation.
Published MoonX correctness baselines remain available separately.
The external 88-scenario exploratory report used the same pathname twice for
its two equal-diff rows. Those rows measure identity/startup shortcuts and provide
no content-comparison throughput evidence; the historical report is unchanged.

The natural evaluation files were already available during development and
are explicitly not a blind holdout. Pipe rows cover bounded producer writes
and stdin backpressure; regular-file stdout does not cover a slow output
consumer. Resource diff/csplit now execute the content and interior-boundary
regimes with source identities and fragment checks; historical RSS observations
retain their original scope. Other new timing modes do not establish equivalent
resource acceptance. A future
general claim still needs an independently reserved holdout, applicable hosts,
resource observations and sealed upstream evidence. This repair changes test
tools and private regressions, not command support or published coordinates.

Local execution retained 190 representative rows: 186 compared successfully,
two jq grouping-order rows exposed the evaluator gap in ADR-0008, and two rev
rows exposed the local macOS util-linux reference's record-boundary defect.
All 21 natural/evaluation and 20 pipe rows compared successfully. The ordinary
resource smoke passed four rows; its long-record selection passed six rows,
including both restored legacy controls. These are bounded correctness checks,
not complete resource qualification. Wasm tests passed 1,713, Native tests 1,871,
and the functional runner passed 2,112 checks with nineteen skips.

A real two-window cksum probe additionally exposed an incorrect assumption
about the producer's optional-field JSON encoding. The panel parser now reads
actual FunctionalRow serialization and tests that producer directly. Its fresh
run admitted the stable 8 MiB row and rejected the 64 MiB row for dispersion and
drift, with artifact identities intact. Both failed whole-panel attempts remain
failed; this round establishes no complete timing pass.

Cleanup commit `6e7be83` passed the required three-platform
[CI run](https://github.com/moonbit-community/cmd/actions/runs/40973796440).
Local correctness passed 1,707 Wasm tests, 118 test-tool tests and 2,122
functional checks, with nineteen platform skips. Only rg/curl/wget binaries
changed from the corrected-contract baseline.

The final real-corpus comparison qualified 89/89 rows. Full performance
protection remains **failed at 159/160**: byte-identical ln startup controls
exceeded the dispersion limit. All registered changed-command rows qualified.
Single-pair RSS observations are not resource acceptance. This is PR-candidate
evidence, not mainline or published-coordinate acceptance.

The [complete pre-simplification record](https://github.com/moonbit-community/cmd/blob/6e7be831cc687386b4e4f62eaad6d4cf7a34318b/docs/adr/0003-streams.md)
retains A01-A12 findings, probe outcomes, baseline identities, failed windows,
accepted small timing costs and resource observations, including the historical
grep RSS increase. Rejected variants and incomplete gates retain their original
verdicts. Future optimization must freeze a fresh baseline and follow the
protection protocol; no broad speed or memory claim follows from this cleanup.
