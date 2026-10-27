# ADR-0003: Preserve Streams and Caller Locale

Status: Accepted
Date: 2026-09-05
Updated: 2026-10-27
Revision: Define R-stage streaming, snapshot, bounded wide-grid caches, temporary-storage and failure effects while retaining explicit matcher, metadata and signal limits.

Documentation profile update (2026-10-27): command READMEs describe invocation,
supported options and user-visible limitations; implementation details remain in
this ADR and the capability matrix. rg help now describes single-threaded reads,
unavailable mmap/PCRE2/device metadata and explicit terminal formatting rather
than inheriting upstream capability claims. Both version spellings identify
cli/rg. This changes documentation/metadata, not search support: rg remains an
unpublished candidate excluded from this release. Capability boundaries can
only be lifted with the public APIs and execution evidence specified below.

Delivery validation update (2026-10-26): [ADR-0001](0001-evidence.md) and the
[Wasm CI migration](../ci-wasm-migration.md) define current acceptance. Future
regressions and boundary unlock conditions below require Wasm on applicable
hosts and exact-version MoonX acceptance; Native command runs and backend
pairing are retired. Dated Native observations retain their historical scope.

## Target and decision

### Adaptive literal planner (2026-10-27)

PR #60 merged as `6705ea8` after the maintainer explicitly accepted unresolved
repeatability for that integration. Its final head passed all three development
checks; actual-main run [40406545144](https://github.com/moonbit-community/cmd/actions/runs/40406545144)
also passed Linux, macOS and Windows. Documentation PR #59 was merged first.
The exception does not turn failed resource stability into a pass, change the
5% dispersion / 10% drift rules, or authorize publication. Original observations
and the unsuccessful observer/cache/CPU interventions remain historical evidence.

The next candidate promotes the isolated literal-planner pilot into the shared
pure-MoonBit matcher. Long literals begin with the two-byte shift plan. Within
a 4096-byte progress window, at least 256 candidate verifications and more than
four candidates per progressed byte can request a bounded automaton. Switching
occurs only after every candidate at the current start has failed; the automaton
resumes at the next start. Hashes and counters never establish a match.

The compiled set owns its pattern array and lazily caches at most one automaton.
The existing 4096-byte pattern and 1024-state budgets remain. If construction
exceeds its state budget, the current scan resumes safely with shifts and no
later scan retries construction. Subsequent inputs start with shifts even when
the automaton is cached, retaining the sparse-input fast path. No input view or
record-dependent result is retained across calls. Accepted spans return directly;
the internal handoff uses a negative start that never escapes the public API.

The shift table has 16 KiB of integer payload. A cached automaton adds at most
2,105,344 bytes for transitions and terminal lengths, plus byte classes, owned
pattern references, temporary construction maps and object overhead. This is an
algorithmic table bound, not a process RSS cap. Public signatures and command
options are unchanged; the packages remain unpublished core 0.8.2 / grep 0.3.1.

The exploratory driver adds thirteen real grep workloads: shared/diverse-first
collision families at 64 KiB, 256 KiB and 1 MiB, sparse inputs at 1/64 MiB, a
collision-to-sparse sequence, dense hits and a construction-budget fallback.
All previous 23 manual performance workloads remain. The separate literal
resource profile adds sampled and kernel RSS observations for both collision
families, sparse input and failed construction, including output/status/effects,
timeouts and residual temporary entries. Ordinary timing does not enable RSS
observation. Detailed results and remaining limits are recorded with the
candidate's validation; Linux stability remains a separate unresolved question.

Deeper follow-ups are reducing the duplicated terminal-length table without
adding a hot-loop division, and bounded block-transfer summaries for repeated
regex suffix states. Neither is selected: require independent sparse/dense and
large-alphabet measurements, cache-exhaustion checks and a bounded memory model
before changing those engines.

Local macOS arm64 validation compares real release-Wasm grep against frozen
merged-main `6705ea8` and, separately, the existing GNU grep 3.12 build. Each
comparison has two windows of one warmup plus nine alternating pairs, including
runtime initialization, I/O and exit. All 26 workloads (thirteen new and thirteen
existing grep controls) passed exact status/stdout/stderr comparison in both
windows. All 26 old/new comparisons met the unchanged stability formulas; only
21/26 GNU comparisons did, with five noisy millisecond-scale reference rows.
Those failed windows are retained and were not retried.

| Workload | New / old median ms, first window | Old/new speedup, both windows |
| --- | ---: | ---: |
| Shared-first collisions, 1 MiB | 32.23 / 459.23 | 14.25x / 14.63x |
| Diverse-first collisions, 1 MiB | 33.36 / 466.39 | 13.98x / 14.26x |
| Shared-first sparse, 64 MiB | 47.81 / 47.81 | 1.00x / 1.01x |
| Diverse-first sparse, 64 MiB | 47.96 / 47.86 | 1.00x / 1.01x |
| Collision prefix then sparse, 64 MiB | 50.03 / 52.00 | 1.04x / 1.05x |
| Dense hits, approximately 1 MiB | 19.17 / 20.31 | 1.06x / 1.06x |
| Trie-budget fallback, 64 KiB | 42.30 / 42.65 | 1.01x / 1.00x |

The first integrated variant allocated an extra result object per hit. It
retained collision gains but slowed the existing many-pattern and dense count
controls by about 15%. Returning the existing span directly removed that
regression from dense counts (under 0.5% in both final windows). Many-pattern
and short-pattern controls still show about 2–3% regressions; these small paired
observations do not establish their general significance. The original rejected
variant and its full windows remain alongside the refined result.

This does not achieve every 1–3x GNU target: final shared/diverse collision
ratios are about 7.7–8.0x / 12.9x; budget fallback is about 23–24x. Sparse
64 MiB ratios are about 2.7x / 0.93x. Faster relative-to-old execution is not
equivalent to GNU parity or a Linux stability correction. Raw reports, immutable
Wasm copies, hashes and scripts are indexed under
`test-reports/adaptive-literal-20261027/`; the complete local working evidence
remains in `/private/tmp/cmd-adaptive-20261027/`.

Local validation passed 1,611 release-Wasm package tests, 117 Native tool tests,
and 2,062 functional cases with 19 explicit skips. Eight sampled resource smoke
comparisons passed status/output/effects with no timeouts or residual temporary
entries. Sampled RSS is only a lower bound; Linux kernel observations and the
expanded full CI profile are separate checks. Generated public interfaces are
unchanged. No package was published or frozen expectation rewritten.

### Stability investigation (2026-10-27)

Linux resource run 40346450167 passed 95 resource comparisons and the exact
outputs of both 23-case performance windows, but six workloads failed the
unchanged 5% dispersion or 10% drift thresholds. GNU cut samples exhibit an
order-associated timing difference in both windows; this does not identify
its physical cause or explain every Wasm-side failure. At this investigation
stage the merge was conditional on complete development and resource results;
the later, explicitly scoped integration exception is recorded above.

The explicit `stability-diagnostic` profile compares the existing observer,
a Native observer, a fixed between-arm pause and single-CPU affinity while
keeping the candidate Wasm and inputs fixed. These are diagnostic interventions,
not adopted execution settings. Preserve every original and diagnostic sample;
do not use an intervention's completion status as stability acceptance. Select
a correction only after the observations support it, then require the complete
resource profile with the existing thresholds and fresh final-head checks.

The first controlled Linux x64 run, 40395472012 at 87dc76b, completed every
window but produced only 17/23 stable cases for either observer and 14/23 for
either settling or one-CPU affinity. None is a selected correction. A second
diagnostic phase tests equal input preloading and adds minimal direct-Wasm
controls plus separate per-invocation kernel counters. Counter wrappers and
their coarse CPU-time resolution remain diagnostic only. Preserve the original
short-input workloads and complete process timing; changing sample units or
averaging away single-process variation would require a separate acceptance
decision, not a stability fix.

The second run, 40398697579 at 8fcdad5, completed the 25-case cache/control
selection, but Native control and preloading each passed only 16/25 stability
rows, and GNU-time observation passed 15/25. Empty-input Wasm `true` itself
showed 11.9% between-window drift. This establishes a contribution outside
text-processing workloads without attributing it uniquely to the runtime or
host. Input preloading is not adopted. The Linux-only `cpu` diagnostic adds
`perf stat --null` accounting, with no PMU permission changes, to distinguish
CPU consumption from elapsed variation. Its wrapper overhead and child CPU
accounting are explicitly separate from unchanged acceptance measurements.

### Performance wave 4 candidate (2026-10-26)

This extends unpublished core 0.8.2 and grep 0.3.1, with wave-3 commit
`d9107de` as the frozen comparison. Command options, help, catalog contracts,
published coordinates and published expectations are unchanged. Measurements
remain direct release Wasm through `moonrun`, including runtime initialization,
I/O and exit, with no MoonX timing or startup subtraction.

Grep compiles four or more fixed patterns into one `LiteralSet` when word/whole
filters are absent. Nonempty sets have at most 4096 total literal bytes. If the
shortest literal has at least three bytes, a 4096-entry table skips on hashed
two-byte suffixes of the shortest prefix, then verifies complete candidate
literals. The conservative shifts follow the multiple-pattern method in
[Wu and Manber, TR 94-17](https://cs.arizona.edu/sites/default/files/TR94-17.pdf).
Hash collisions reduce skips or add verification work; they cannot establish
a match. Shorter patterns select a byte-class Aho-Corasick table with at most
1024 states and 257 classes, including the other-byte class. Transition and
accepted-length tables together use at most 2,105,344 bytes of integer payload;
construction maps and object overhead are additional. Longer-pattern sets do
not construct this trie. Empty or over-budget sets retain per-pattern search.

`LiteralSet.find_span` preserves earliest-start, longest-end selection.
`find_any` stops after a verified occurrence without resolving longest ties.
For delimiter-free patterns it cannot skip an earlier matching record, so the
count path uses it to find a record and skip its remaining hits. Inversion
counts complete records minus matched records; incomplete tails retain the
record path. Case folding retains per-record matching, and word/whole filters
retain the original fixed matcher. The public API adds only the opaque literal
set and its construction, occurrence, span, boolean and delimiter queries.

Long-record regex endpoint queries now skip a region only after proving that
every consumed byte leaves the forward DFA in the same state. If that region
reaches the record end, one constant-size certificate records the state, suffix
start and acceptance. Later queries reaching the same state inside that suffix
can reuse its result. The certificate belongs to one immutable record, supports
resumed or decreasing start offsets, and is never shared between records.
Selection starts at 4096 remaining bytes; actual self-loop skips require at
least 64 remaining bytes. Ordinary short searches retain the scalar endpoint
loop. Cache exhaustion still reruns the current query through the existing
fallback. This handles a concrete repeated-suffix case without claiming a
general linear-time bound for ambiguous regex enumeration.

Final local macOS arm64 observations use pinned local GNU 9.11/3.12 builds,
regular-file stdin, captured stdout, one warmup and nine alternating pairs.
All 15 final rows passed exact status/stdout/stderr comparison. Candidate and
GNU columns are median milliseconds; speedup comes from a separate paired
comparison against wave 3, rather than dividing across different runs.

| Workload | Candidate | GNU | GNU ratio | Wave-3 speedup |
| --- | ---: | ---: | ---: | ---: |
| 16 fixed patterns, count, 8 MiB | 26.74 | 4.90 | 5.46 | 2.39x |
| Same patterns, count, 64 MiB | 91.05 | 28.59 | 3.18 | 4.49x |
| Same patterns, spans, 1 MiB | 21.03 | 3.50 | 6.00 | 1.32x |
| 16 fixed patterns, miss, 8 MiB | 20.71 | 6.16 | 3.36 | 1.50x |
| Four short patterns, count, 64 MiB | 81.75 | 22.54 | 3.63 | 1.42x |
| Four dense patterns, count, 64 MiB | 96.00 | 28.11 | 3.42 | 1.21x |
| 16 distributed prefixes, miss, 64 MiB | 76.16 | 38.83 | 1.96 | 1.70x |
| `a\|a.*z`, spans, 8 KiB of `a` | 16.05 | 45.19 | 0.36 | 7.60x |
| Same expression, 16 KiB of `a` | 18.13 | 172.61 | 0.11 | 25.44x |
| Regex spans, 8 MiB / 1 MiB records | 83.04 | 19.91 | 4.17 | 1.09x |
| Original regex spans, 1 MiB | 29.44 | 9.32 | 3.16 | 0.98x |
| Many regex spans, 1 MiB | 32.71 | 14.64 | 2.23 | 0.98x |
| Single fixed count, 64 MiB | 60.01 | 18.27 | 3.28 | 1.00x |
| Regex count, 64 MiB | 104.85 | 35.68 | 2.94 | 1.00x |
| Regex miss, 8 MiB | 18.58 | 2.35 | 7.92 | 0.98x |

The 16-pattern hit set contains `absent0` through `absent14` and `gamma`;
the miss set replaces `gamma` with `absent15`. Additional short, dense and
distributed-prefix rows prevent conclusions from resting on that shape alone.
Exact arguments and reproducible corpora are in `tests/benchmark/explore.mbtx`.
The `a|a.*z` rows expose repeated suffix scans in both the previous candidate
and GNU, and do not represent all regex workloads. Short span/miss rows show
about 2% regressions in the final pairs; this small window does not establish
their significance. The candidate Wasm grows from 421,685 to 434,882 bytes.

Two rejected approaches constrain the next design. Aho-Corasick alone improved
the original 64 MiB multi-pattern count from 405 to 133 ms, but regressed the
8 MiB miss from 31 to 33 ms. Selecting two-byte shifts for longer patterns
improved both. Applying self-loop skipping to the reverse start bitmap made
long records worse, about 125 versus 89 ms, so that experiment was removed.
The retained forward skip gives a modest long-record gain; reusing its proven
suffix gives the much larger overlapping-match gain. `reverse-trial.mbt` and
the raw intermediate reports preserve the negative experiment.

The next deeper candidates are bounded block-transfer summaries for forward
states that revisit non-self-looping suffixes, and a literal planner that can
switch from shifts to an automaton when verification collisions become dense.
These remain unimplemented: require independent collision-heavy, sparse/dense
and record-size scaling measurements, preserved leftmost-longest/offset/error
semantics, and explicit memory bounds before selecting them. A universal
automaton or universal skip strategy is not supported by this wave's results.
The general long-record and small-input gaps above remain outside the 1–3x
exploration target; further work needs a measured scan/I/O breakdown.

Validation passed 1,604 release-Wasm package tests, 117 Native tool tests and
2,062 functional cases, with 19 explicit skips and zero failures. The expanded
independent GNU comparison matched 792 of 796 cases. All four mismatches are
the existing empty-pattern `grep -v -c` difference, reproduced with frozen
wave-3 Wasm; the GNU-equivalence run remains failed. New cases cover both
literal plans, folded/word/whole/NUL options, partial and cross-buffer records,
resumed views, hash collisions, trie-budget fallback, earliest endpoint versus
earliest start, and interleaved suffix searches on different records.

Raw reports, source patch, executable/corpus hashes, frozen artifacts, scripts
and stage durations are indexed by
`test-reports/performance-wave4-evidence/manifest.json`. Final rebuilt Wasm is
byte-identical to the measured artifact. These are diagnostic observations,
not formal 105-pair/p95/confidence acceptance, sealed Linux parity, Linux/Windows
validation, pipe-throughput/RSS acceptance or published-consumer acceptance.
No package was uploaded; the original checkout remains unchanged.

### Performance wave 3 candidate (2026-10-26)

This extends unpublished core 0.8.2 and grep 0.3.1 from wave 2, retaining the
pure MoonBit and direct release-Wasm measurement boundaries. No MoonX timing or
startup subtraction is used. The frozen comparison commit is `340b356`.

`RecordMatcher.search_bytes` borrows a record and returns resumed byte offsets.
The package-level `search_bytes` constructor shares fallback text conversion
across patterns. Literal searches use bytes directly. Other eligible span
searches use a reverse unanchored DFA to mark every feasible start, then an
anchored forward DFA to select the longest endpoint at the earliest start.
The start/end separation is related to the paired automata described by
[Rust regex-automata](https://docs.rs/regex-automata/0.4.18/regex_automata/dfa/regex/struct.Regex.html).
Here the reverse pass records all feasible starts to preserve GNU
leftmost-longest selection: in `a.*z|b` on `abz`, the earlier `a` start wins even
though the `b` alternative accepts sooner.

Each DFA has at most 256 states and 256 byte classes; eligible programs have at
most 256 instructions and no assertions or backreferences. Cache exhaustion
disables the pair and reruns the current query through the retained span engine.
Word/whole filters use the span plan, and assertion/reference/large-program
fallbacks share one lazily decoded record. Each eligible search retains a bitmap
of `floor(record_bytes / 64) + 1` 64-bit words. Aggregate bitmap storage grows
with record size and pattern count. This is not an RSS cap. The reverse pass is
reused across resumed searches, but forward longest-match searches can revisit
suffixes for ambiguous patterns; no general linear-time enumeration claim is
made. Literal and nullable searches preserve empty spans and progress rules.

Grep's span emitter resumes a record after its 64 KiB output threshold. Both
matching and output accumulation run synchronously inside buffered input;
only refill and output flush cross async boundaries. Output storage follows a
flush block plus the largest emitted match/prefix, without accumulating the
expanded output of all matches in a long record. Binary decisions, offsets,
partial input-error records and failed-write non-replay remain covered. A
single fixed literal count can locate matching records directly and skip repeat
hits in the same record; case/word/whole filters and literals containing the
record delimiter retain the record path.

Final local macOS arm64 observations use the same GNU 9.11/3.12 builds, one
warmup and nine alternating pairs with exact status/stdout/stderr comparison.
Input is a regular file and stdout is captured. Times are median milliseconds:

| Workload | Candidate | GNU | Ratio |
| --- | ---: | ---: | ---: |
| grep -Eo '[0-9]{4}.*gamma', 1 MiB | 28.62 | 9.06 | 3.16 |
| grep -Eo '[a-z]+', 1 MiB / many matches | 31.73 | 14.45 | 2.19 |
| grep -o alpha, 1 MiB | 21.32 | 6.21 | 3.43 |
| regex spans, 8 MiB / 1 MiB records | 89.88 | 19.81 | 4.54 |
| grep -wEo '[a-z]+', 1 MiB | 59.52 | 30.29 | 1.96 |
| grep -Eo 'a?', 1 MiB | 64.32 | 66.13 | 0.97 |
| grep -Fc alpha, 8 MiB | 20.90 | 3.59 | 5.82 |
| same fixed count, 64 MiB | 59.70 | 18.00 | 3.32 |
| regex count, 64 MiB | 104.90 | 35.45 | 2.96 |
| regex miss, 8 MiB | 18.04 | 2.35 | 7.69 |

Separate final pairs against wave 2 measured 3.24x for the original span row,
4.08x for many matches, 2.00x for literal spans, 3.64x for long records, 1.87x
for word-filtered spans and 3.85x for nullable spans. Fixed counts improved
1.06x/1.24x at 8/64 MiB. Regex counting did not improve: the 64 MiB pair was
104.48 versus 103.48 ms, and the miss pair 18.52 versus 17.47 ms. The candidate
Wasm also grew from about 388 to 412 KiB. These observations do not isolate the
cause of the small counting regressions.

The staged experiment is useful evidence: byte views alone took 94.56 versus
93.41 ms on the original span workload, so removing conversion was insufficient.
The endpoint pair reduced it to 37.85 ms; synchronous output accumulation then
reduced it to about 31.81 ms, and buffered-record emission to about 28.68 ms.
An overlapping test/measurement attempt is excluded; the output-accumulation
figure uses the later serialized run. The next experiments should target
revisited endpoint suffixes on long records, word-aware endpoint states, and
multi-literal block search. Their additional gains are unverified. Benchmark
both sparse and dense matches and record-size scaling before broadening any
engine selection; increasing buffers or removing conversions alone has not
resolved these gaps.

Validation passed 1,597 release-Wasm package tests, 117 Native tool tests and
the full functional suite (2,062 passes, 19 explicit skips, zero failures).
The independent local GNU set matched 684 of 688 cases. The four mismatches
are the existing empty-pattern `grep -v -c` output difference, reproduced with
wave-2 artifacts on all four inputs. No new mismatch appeared in that set.
Additional regressions cover earliest-start versus earliest-end selection,
resumed offset views, all byte values, cache exhaustion with retained searches,
shared fallback conversion, multi-pattern span selection, NUL prefixes and
input/output failures. Package interface changes are limited to the new byte
search entry points and opaque `RecordSearch` type.

Raw reports, executable/corpus hashes, frozen Wasm artifacts, scripts and stage
durations are indexed by `test-reports/performance-wave3-evidence/manifest.json`.
Reproduction uses the extended `tests/benchmark/explore.mbtx` and the retained
`/private/tmp/cmd-perf-wave3-20261026` lab. These are selected diagnostic medians,
not formal 105-pair/p95/confidence acceptance, sealed Linux parity, three-host
validation or published-consumer acceptance. No package was uploaded.

### Performance wave 2 candidate (2026-10-26)

This extends the same unpublished coordinates from wave 1. Product code and
diagnostic orchestration remain pure MoonBit. Direct release-Wasm launch-to-exit
timing includes runtime initialization, I/O and exit; MoonX is not measured.

`RecordBatch.each_while` invokes a synchronous consumer until its output needs
flushing. It avoids a RecordView/Option result per record and checks the first
four bytes before setting up a delimiter search. Cut selects its byte or field
consumer once per input, writes singleton byte selections directly, and stops
field traversal after the last selected field. Existing equal-delimiter and
empty-selection compatibility paths remain separate. Uniq reuses unchanged key
views. Output flushing stays asynchronous, with the same partial-write and
input-error behavior as wave 1.

Grep checks a conservative mandatory literal once per buffered block. Only
complete records can be rejected; inversion and context disable this path.
Refill still inspects binary input and retains incomplete tails. Offsets and
record numbers advance with a word-at-a-time delimiter count bounded by the
BytesView, including its start offset. Count consumers process the remaining
complete records synchronously without record objects or async continuations.

The deeper engine changes are lazy construction and a flat DFA transition table:
the current state is a row offset, removing object lookup and multiplication
from each byte transition. At most 256 subsets and 256 byte classes occupy the
table; the existing program/state limits and fallback remain. A separate lazy
span plan precomputes epsilon closures for assertion-free, reference-free
programs of at most 256 instructions. It reuses ordered integer worklists and
preserves leftmost-longest selection, including resumed, word and whole-record
search. Closure storage is quadratic in program size, bounded by 256 squared
entries, plus worklists. Literal patterns keep their literal path; assertions,
backreferences and larger programs keep the existing engines. This is an
allocation/work bound, not measured RSS acceptance.

Final local macOS arm64 diagnostic medians use the same GNU 9.11/3.12 builds,
regular-file stdin, captured stdout, one warmup and nine alternating pairs per
row, with exact status/stdout/stderr comparisons:

| Workload | Candidate ms | GNU ms | Ratio |
| --- | ---: | ---: | ---: |
| cut -b 1-8, 8 MiB / 80-byte records | 16.21 | 4.93 | 3.29 |
| cut -f 1,3, same input | 33.37 | 9.86 | 3.38 |
| cut -b 1, 8 MiB / 2-byte records | 69.10 | 24.32 | 2.84 |
| uniq, 8 MiB / 80-byte records | 23.78 | 14.82 | 1.60 |
| uniq, 8 MiB / 2-byte records | 257.51 | 102.37 | 2.52 |
| uniq -c, 8 MiB / identical records | 16.09 | 7.82 | 2.06 |
| grep fixed count, 8 MiB | 22.16 | 3.81 | 5.82 |
| grep fixed miss, 8 MiB | 16.51 | 2.10 | 7.86 |
| grep -Ec '[0-9]{4}.*gamma', 1 MiB | 16.29 | 2.17 | 7.52 |
| same regex count, 64 MiB | 103.15 | 35.64 | 2.89 |
| grep regex miss, 8 MiB | 17.47 | 2.32 | 7.54 |
| grep -Eo span extraction, 1 MiB | 94.98 | 9.19 | 10.33 |

Separate final pairs against frozen wave-1 artifacts measured 4.96x for short
cut records, 2.41x for short uniq records, 2.67x for the 64 MiB regex count,
2.34x for regex rejection and 1.39x for span extraction. Normal cut and uniq
improved about 1.36x. Incremental prototypes attribute useful additional gains
to the synchronous count loop (about 274 to 131 ms), then the flat DFA table
(about 131 to 102 ms). Precomputed span closures reduced the span workload from
about 129 to 94 ms. These observations support engine/data-layout specialization
beyond simply increasing the input buffer.

Validation passed 1,584 release-Wasm package tests, 117 Native test-tool tests,
and the full functional suite (2,062 passes, 19 explicit skips, zero failures).
The span oracle matrix compares the new matcher with the retained tagged
engine, across resumed starts and word/whole filters. New regressions cover
visitor stop/resume, retained views, offset byte counts and cross-block filtering.
An independent 244-case local GNU comparison covers binary/NUL data, long
records, inverse/context output, groups and backreferences: 242 match exactly;
two retain an existing difference for empty-pattern `grep -v -c` (candidate
prints `0`, GNU 3.12 exits without stdout; both exit 1). Both mismatches reproduce
with the frozen wave-1 artifact. No new mismatch appeared in that set, but this
is not a full GNU parity pass. Lifting that difference requires a separate
early-exit/stdin-preservation contract and pinned three-host regressions.

The next measured bottleneck is span extraction: it remains over 10x GNU even
after closure precomputation. A byte-view span engine that avoids intermediate
String conversion and an endpoint-oriented search plan are candidates for the
next experiment, not established gains. Fixed-string search also still scans
records after a positive block filter; a block search that locates candidate
records once, including multiple patterns, should be tested separately. Ordinary
cut remains slightly above 3x. These extensions must preserve leftmost-longest,
binary/context/early-exit semantics and the retained fallback engines, then pass
held-out workloads before acceptance. Short-command timing is not corrected by
subtracting startup, and an observed median below 3x is not a formal pass.

`tests/benchmark/explore.mbtx` reproduces paired measurements. Wave-2 scripts,
raw reports, artifact hashes and validation logs are retained in
`test-reports/performance-wave2-evidence/manifest.json`; the prototype workspace
is `/private/tmp/cmd-perf-wave2-20261026`. There is no formal 105-pair result,
sealed Linux parity, Linux/Windows validation, publication or exact-version
consumer acceptance for this change. Published manifests remain frozen.

### Performance wave 1 candidate (2026-10-26)

The implementation target is direct release-Wasm elapsed time within 1-3x of
fixed GNU/Rust counterparts, excluding MoonX resolution/launch costs. Runtime
startup, command I/O and exit remain timed. This supersedes the prospective 1.5x
performance threshold, not historical verdicts or correctness acceptance.

Cut and uniq consume immutable record batches with synchronous byte-view
processing and 64 KiB output thresholds. Reads are at most 1 MiB; only split
records are assembled. Views may retain their backing block. Storage follows
the largest input/output record, delimiter expansion and a few blocks, not all
records. Failed flushes consume their queue before the write, so deferred
cleanup cannot replay a partially written prefix. Input errors flush completed
output without manufacturing an EOF record. Cut's special equal-delimiter and
empty-selection behavior is preserved. Wc uses 16-byte SIMD newline and C-space
masks with a carried word-boundary bit; display-width requests retain scalar
counting. Both -m and -c continue to count bytes.

Grep separates boolean acceptance from leftmost-longest span extraction. A
conservative mandatory literal can reject a record; an assertion-free program
of at most 256 instructions can use a lazy byte-class DFA capped at 256 subsets.
Cache exhaustion disables that cache and reruns the current record through the
span engine. Assertions, word/whole filters and backreferences keep existing
acceptance rules. Span-only Thompson searches retain ordered starts in reusable
integer worklists. Captured searches keep distinct tag states. Buffered grep
records are consumed synchronously while its existing refill path preserves
binary detection, byte offsets, partial-error records and early exits.

These decisions draw on the buffer/consume separation in
[Rust BufRead](https://doc.rust-lang.org/std/io/trait.BufRead.html) and the
specialized engines and scratch state described by
[regex-automata](https://docs.rs/regex-automata/latest/regex_automata/meta/index.html).
All implementation and orchestration here remain pure MoonBit.

Local macOS arm64 observations use GNU coreutils 9.11 and grep 3.12 built with
`-O3`, one warmup and nine alternating pairs, exact output/status/stderr checks,
regular-file stdin and captured stdout. Representative medians, in milliseconds:

| Workload | Candidate | GNU | Ratio |
| --- | ---: | ---: | ---: |
| wc -l, 64 MiB | 19.32 | 9.53 | 2.03 |
| wc -w, 64 MiB | 23.09 | 56.97 | 0.41 |
| cut -b 1-8, 8 MiB / 80-byte records | 23.01 | 4.86 | 4.73 |
| uniq, same records | 33.48 | 14.91 | 2.25 |
| grep -Ec '[0-9]{4}.*gamma', 1 MiB | 20.94 | 2.13 | 9.84 |
| same grep expression, 64 MiB | 276.61 | 34.95 | 7.91 |
| grep regex miss, 8 MiB | 41.49 | 2.14 | 19.40 |
| grep -Eo span extraction, 1 MiB | 129.59 | 9.07 | 14.28 |
| cut, 8 MiB / 2-byte records | 343.34 | 21.41 | 16.04 |
| uniq, same short records | 621.49 | 101.29 | 6.14 |

The earlier buffer-only prototypes took about 86 ms for cut and 91 ms for uniq.
Fresh paired comparisons against the original release artifacts measured about
84x/61x improvements for cut/uniq, 5.6x/7.3x for wc line/word counting, and 34x
for the 1 MiB regex count.
The compact regex worklist took about 92 ms on the 1 MiB regex row before DFA
and buffered iteration. Required-literal rejection reduced the regex miss from
83 to 41 ms. The word SIMD path is a further change beyond the newline pilot.
Increasing record reads from 64 KiB to 1 MiB had only a small effect; it does not
resolve the short-record bottleneck. These are diagnostic medians, not a formal
performance pass, Linux oracle parity or a publication claim.

The next experiments should fuse scanning, selection and output for dense short
records; skip nonmatching blocks with safe literal candidates before record
materialization; and accelerate span endpoints without changing leftmost-longest
or backreference behavior. A bigger buffer alone is not sufficient. Gate any
extension on held-out short/long/duplicate/binary inputs, errors and cancellation,
followed by three-host Wasm correctness and qualified performance sampling.
Reproduction uses `tests/benchmark/explore.mbtx`; raw local evidence is retained
under `/private/tmp/cmd-perf-lab-20261026/`, with final manifests and hashes.
Published manifests remain frozen; candidate coordinates are core 0.8.2,
cut/uniq/wc 0.2.3 and grep 0.3.1. No package was uploaded.

### rg migration candidate (2026-10-26)

The rg module retains its reader/sink algorithms and makes actual reads, sink
writes, directory advancement and stdout flushing asynchronous. It does not
load ordinary files or accumulate search stdout as an async workaround. Existing
multiline and sorted traversal retain their explicit larger storage paths.
The removed `-z` adapter survives only in Git history; no decoder/resource claim
applies to the candidate. Unavailable stdin kind is an explicit status-2 search
boundary, with explicit paths and `-` covered by portable contracts. Automatic
terminal presentation chooses plain output; it is not reported as a successful
terminal query. Lift these limits only after public APIs and three-host Wasm
regressions exist. Evidence and remaining checks: [rg support profile](../../docs/compatibility.md#rg-candidate).

Preserve byte streams, final newlines and partial output. Set LC_ALL=C explicitly in differential fixtures; inherit caller locale in real commands. C-byte collation tests do not certify non-C behavior. Keep bounded sort and descriptor-follow tail as declared subsets.

## Alternatives and compatibility cost

The shared core 0.8.0 line scanner owns one 64 KiB read buffer, tracks the
unconsumed range and uses the public single-byte search operation. It does not
rescan an accumulated prefix or copy the remaining chunk for each line. Only
cross-chunk records accumulate; returned lines own their bytes before refill.
Storage follows the largest record encountered plus a block, rather than the
number of records. The existing constructor/next calls and delimiter behavior
remain; the generated structural interface records the new state.

Plain cat copies reuse a 64 KiB buffer across operands. Wc computes only selected
counters. Its published implementation follows the frozen C byte profile: both -c and
-m count every byte, including malformed UTF-8, with no decoder or pending
sequence state. The earlier UTF-8 counter observations remain historical.
Strings retains a candidate prefix only until the requested minimum, then
streams its printable continuation with 64-bit input offsets.
Head batches record/byte/header output and flushes completed output on input
errors. Shared new-file copying uses a reusable 64 KiB buffer; this changes
neither replacement preflight nor filesystem capability decisions.
Sort prepares comparison keys once, carries stable sequence IDs through disk
runs and merges at most sixteen inputs. Its default 64 MiB budget counts
record/key payloads, bookkeeping and reserved buffers; active/oversized records
and runtime allocation overhead remain explicit additional costs. Preserve
first-representative unique behavior and error cleanup before raising the budget
or widening options; require measured RSS before claiming a memory cap.
These implementations were published on 2026-10-25 with package and command
regressions. Their release does not establish formal performance acceptance.

Rev selects the fixed Linux C-locale util-linux 2.40 profile. It reverses
ASCII/NUL records without decoding and rejects a record containing a non-ASCII
byte before writing it. Completed records remain on stdout, their count appears
in the diagnostic, and later named inputs continue. PR #54's pinned Linux
Native/Wasm observation for `o6-rev-invalid-c-byte` establishes that behavior;
the older macOS provider's high-byte acceptance is not Linux parity.

Reject universal newline normalization, whole-output trimming and forced locale. Command substitution removes trailing LF only, preserving spaces and embedded newlines. Grep separators require requested context; base64 -w0 emits no newline. Full locale-aware comparisons remain unverified.

## O1 selected text options

The published 0.2.2 commands add cut complements/output delimiters, uniq
member/group output, comm column delimiters/totals, join ASCII-folded keys/
headers/automatic output fields, and wc total policies. Cut keeps distinct
adjacent explicit spans when an output delimiter makes their boundary visible.
Uniq retains only its current key and pending record; member output does not
buffer an entire duplicate group. Comm/join retain their streaming merge and
current equal-key runs. Default disorder diagnostics preserve the GNU output
prefix and continuation; explicit order checking stops early. Join's automatic
field counts freeze on the first record, and explicit output lists accumulate.

Wc total-only output has no per-input rows, names or padding. Opened inputs keep
their observed counters after a read error, and later inputs still run. Numeric
alignment for named files uses public kind/size metadata; standard input uses
the seven-column stream layout for multiple counters. Exact GNU alignment for
a regular file redirected to stdin is not claimed: released async 0.22.5 exposes
Input.fd but no public descriptor kind/size query or fd-to-File borrowing API.
Lift that layout limit only when such a public API and Native/Wasm regular-file/
pipe/partially-consumed/repeated-stdin regressions exist. This does not prevent
total-only output or named-file counting. Do not import internal event-loop
metadata functions or add host-process workarounds.

## O2-O4 sort, paragraphs and tab stops

Sort preserves sequence IDs for stable ties and first representatives. Random
ordering caches MD5(seed16 || transformed key), then the effective key for hash
ties, within the existing run format and accounting. Explicit sources consume
exactly sixteen bytes; an ineffective random-source option does not open its
source. A public random seed supplies ordinary `-R`. Merge assumes its inputs
are already ordered, as GNU does; it does not validate or repair them. This
corrects the optimization plan's earlier wording about merge validation.
Fatal errors use GNU status 2, including failed temporary-file creation. The
host policy regression retains the blocked-write diagnostic and empty stdout;
its earlier status-1 expectation belonged to the pre-O2 generic error handler.
Input read diagnostics are scoped to reads, so spool failures retain their
actual operation instead of being labeled input failures.

Ordinary named output consumes all inputs before truncating an existing file,
including an input alias. New output creation and late-read failures retain
their observed ordering. Existing streaming merge output retains the narrower
identity/error-effects limit in ADR-0004. No arbitrary PRNG shuffle, path-name
identity check or content hash substitutes for GNU behavior.

Fmt reuses its paragraph optimizer with first/continuation indentation and
prefix metadata. Split mode takes precedence over crown mode, then tagged
mode. Tagged paragraphs retain continuation indentation across paragraphs;
prefix spaces affect matching, and unmatched EOF records preserve their bytes.
Paragraph buffering and locale widths remain separate resource/profile work.

Expand and unexpand share one tab-stop parser and cursor. Repeated lists
accumulate; `/N` extends the absolute grid and `+N` extends from the last fixed
stop. Trailing zero suffixes follow GNU's no-extension behavior. Signed 64-bit
stops, backspace and ordinary CR columns remain byte operations. Unexpand's
first-only policy overrides explicit/all-by-tabs policy regardless of order.

Selected GNU cases and named package regressions supply Native/Wasm evidence;
private development observations remain distinct from committed PR/main,
formal performance and publication acceptance.

## Published split, display and pipe profiles

Split uses bounded reads and owned spools for total-dependent layouts. Byte,
line-aligned and round-robin selection preserve empty partitions, elision,
suffix state and completed files on later failure. `--filter` supplies each
piece through a public pipe to the existing pure MoonBit Session, with `$FILE`
in its environment. Actual signal termination remains separate from an
ordinary exit 141; this adds no host-shell fallback or new shell language.
GNU 9.11's undefined alphabet indexing for hexadecimal FROM=a-f is outside the
parity domain; the workspace deliberately uses mathematical base-16 names.

Csplit's suffix descriptor compiles one selected integer conversion, flags,
width, precision and literal percent. Suppress-matched applies to the adjusted
split boundary, including repeated and negative-offset patterns. Rev and tac
process operands in order without invented separators. Tac compiles GNU Emacs
C-byte regexes and selects rightmost start/longest end, with explicit progress
for nullable separators. The R resource contracts below distinguish fixed
separators from the matcher path's whole-input storage.

Od decodes the frozen Linux amd64 float profile, including binary16, bfloat16,
binary32/64, x87 Extended80 and binary128, through the shared numeric package.
Its strings and traditional offset/label paths retain their own termination,
radix and option-conflict rules. Hexdump compiles custom formats into a small
format representation; raw `%c`/`%s` bytes, partial elements, multiple formats,
address/final-address units, iteration and explicit `_L` colors are observed
against util-linux 2.40. Automatic color behavior on an interactive terminal is
unclaimed without a public terminal query. Undefined/nonterminating upstream
format combinations are not golden contracts.

Forward hexdump stdin skip now reads/discards and preserves the equivalent
named-file display. This is a selected extension: the fixed util-linux 2.40
pipe path reports Illegal seek. The former boundary ID is a positive
oracle=false case, not a GNU-pipe parity claim. Xxd likewise reads/discards
forward stdin positions and uses public size/read-at for wide named-file seeks.
Backward/end-relative stdin requires a public seekable input; new output files
support reverse backpatching, while existing outputs retain ADR-0004's limit.
Cmp byte notation and strings output separators preserve C byte names and
unterminated accepted strings without a complete output buffer.

Tail `-z` selects NUL record boundaries while preserving final terminators,
positive origins, byte mode and ordinary multi-file headers. Tee's explicit
warn/warn-nopipe/exit/exit-nopipe and `-p` policies classify real public pipe
errors and preserve observed later-sink and prefix effects. The test scenarios
actually close stdout's pipe reader; their observations are status, stderr and
file type/content, not captured stdout. Default tee cannot restore GNU SIGPIPE
termination because the released runtime ignores it and exposes no public
restore/raise operation. It reports the registered exact status-2 rejection
with the created sink empty, rather than inventing signal status -13. Lift
this boundary only after a released signal API and actual Native/Wasm
closed-pipe termination/prefix/cleanup comparisons pass.

Selected cases, package tests, generated mktemp relationships and real
closed-pipe scenarios retain these published profiles. Current delivery checks
run them through Wasm and exact-version MoonX as applicable. They do not certify
RSS bounds or the formal direct-Wasm performance targets.

## R streaming and temporary-storage contracts

The R release published column/rev/tac **0.1.4**, csplit **0.2.1**, split
**0.1.3**, sort **0.2.3** and core **0.8.1** on 2026-10-25. Dependency
coordinates were unchanged. The changelog records local MoonX acceptance and
the later three-platform replay separately from resource/performance claims.

Rev consumes and validates one record, then reverses ASCII/NUL bytes into one
record-sized output buffer. Its storage is O(64 KiB + longest record); a late
input failure retains completed output. It does not retain all input records.

Split streams byte/line modes. Total-size layouts use a regular file's observed
size or an owned spool; a live regular file is not an immutable snapshot.
Line-byte mode spools its pending record prefix instead of accumulating an
arbitrarily long line. Round-robin ordinary outputs close after each record;
their name/state entries remain O(visited pieces). Round-robin filters retain
one live pipe and shell task per visited piece, plus any child/filter-owned
resources; they do not claim a fixed process or memory bound. Completed files
remain after a later read, write, suffix or filter error.

Csplit first records a single input snapshot and a disk index of 64-bit line
boundaries. It retains two caches of at most 64 KiB each, a current regex line
and the created-output paths required for cleanup. Disk use is input bytes
plus eight bytes per boundary, including the initial entry. Numeric pattern
and offset parsing, and a single regex line's matcher indices, retain their
existing signed 32-bit limits. Input or spool failure precedes output creation;
later failures remove owned fragments unless `-k` keeps completed or partial
outputs. A paged index avoids claiming O(records) offsets are bounded memory.

Tac searches fixed separators backwards on opened regular files using 64 KiB
blocks and separator overlap; selected byte ranges are copied in blocks.
Storage is O(block + separator length), including a very long record. Standard
input, nonregular files and regex mode use an owned disk spool. No output for
that operand begins until its spool succeeds. A regular file's concurrent
mutation is not a snapshot guarantee. Regex mode retains O(input) memory in
addition to its spool because the shared matcher requires a contiguous byte
string with signed 32-bit indices. Preserve arbitrary separator spans and
nullable progress rather than silently restricting overlap. Lift this memory
limitation only with a shared matcher API over paged/seekable input and matching
Native/Wasm arbitrary-span, anchor, overlap and nullable-separator regressions.

Column consumes all operands once into a displayed-record snapshot, computes
global widths and then formats from that snapshot. Disk use is displayed bytes
plus sixteen bytes per retained record, across two temporary files. Memory
retains the longest record, global table-width vector and fixed I/O buffers.
Table and small-grid caches retain at most 1 MiB of record pages and 64 KiB of
index pages. Grid caches select sixteen to 256 pages from the output column
count to avoid thrashing interleaved cursors; their fixed upper limits are
16 MiB of record pages and 1 MiB of index pages, allocated only as read.
The first output follows the attempted input pass. Late input errors preserve
complete records and continue with later files; temporary-write failure aborts
before formatting.
An output error may leave an emitted prefix. Reopening mutable source files
for the second pass and retaining a complete output string were rejected.

Sort's `-S/--buffer-size` selects its accounted data budget, defaulting to
64 MiB; unsuffixed values use KiB. `-T/--temporary-directory` selects temporary
locations and may repeat. `--batch-size` selects the merge fan-in within the
implementation's maximum of sixteen inputs. Active/oversized records and
runtime allocation overhead remain separate from the budget, which is not an
RSS limit. Nonzero percentage buffer sizes reject before input/output effects; `0%`
uses the minimum budget without a capacity query. Released
public APIs do not expose physical-memory capacity. Lift this rejection only
when that query exists and percentage rounding, overflow and Native/Wasm
behavior are verified; guessed constants or a host child are not substitutes.

Csplit, column and tac's spooled modes require temporary-filesystem write
access. The catalog declares FileWrite for these commands as well as sort and
split. Spool directories are created exclusively and their files use mode
0600 where supported. Deferred cleanup owns only those invocation paths and
runs on success, ordinary failure and runtime-observable cancellation. Neither
SIGKILL nor a machine failure can guarantee unwinding. Package regressions and
registered command/policy cases target exact bytes, effects, long records and
wide-offset arithmetic; final resource observations and platform acceptance
must report the workloads actually run rather than infer a process RSS cap.

## Versions and evidence

The current core line scanner, command buffers and spools are checked by
package tests, `tests/cases/<command>.json` and shared stateful scenarios.
The 2026-10-24/25 changelog records their implementation and publication.
Use current Wasm and exact-MoonX checks; former two-backend observations
retain their dated scope and are not required delivery backends.

## Revisit when

Add locale profiles only when implementation and oracle evidence cover them; never rewrite the caller environment to hide a gap.

## Migrated text and binary profiles

The target remains each command's selected upstream behavior. Current
coordinates are in `tests/release_runner/current/latest.json`; package and
CLI assertions live alongside the implementation. These decisions do not
reinterpret accepted flags or certify every upstream option.

| Commands | Choice and reason | Rejected alternative and compatibility cost | Evidence and condition for expansion |
| --- | --- | --- | --- |
| rev, tac | Ordered operands; rev retains one ASCII/NUL record and tac reads fixed separators backwards with bounded block/overlap storage. Tac's GNU Emacs matcher preserves nullable progress. | Rev rejects non-ASCII records before output. Tac regex retains O(input) memory and a spool until a paged/seekable matcher interface is implemented and verified; neither command claims multibyte-locale decoding. | `rev.json`, `tac.json` and package regressions cover current source; pinned Linux O-stage observations and older releases remain distinct evidence. |
| expand, unexpand, fold | C-byte columns, explicit tab stops and control-byte rules; fold preserves input bytes and uses space breaks only when requested. Deterministic byte contracts require no terminal discovery. | Reject UTF-8 replacement decoding and assuming one code point occupies one display column. Non-C widths remain unimplemented; fold handles tabs/backspace/CR in column mode. | Their JSON contracts and fold package tests; expand locale claims only after wide/combining/malformed input and tab/control interactions pass the selected upstream oracle. |
| od, hexdump | Concatenate operands and preserve partial words, duplicate blocks and final offsets; the published O7 implementation adds the frozen Linux float ABI, strings/legacy offsets and custom hexdump format/color units. | No host delegation or inferred native ABI. Forward stdin skip is a documented read/discard extension; backward positioning needs a seekable input. | `od.json`, `hexdump.json`, numeric/format package tests and fixed-provider Native/Wasm development observations; PR/main and publication remain separate. |
| fmt | Width/goal paragraph optimization, crown/tagged margins and prefix selection with C-byte indentation and sentence spacing; no file rewrite. | Do not substitute fold or discard long words. Paragraph storage and non-C display widths remain separate work. | Current `fmt.json`, named regressions and O3 GNU margin/prefix/tab/EOF observations; PR/main and formal resources remain separate gates. |
| strings | Streaming C-byte scanning, GNU d/o/x offsets, last -o/-t selection, seven-column padding, TAB, filename prefixes, s/S encodings and selected output separators. | Reject b/l/B/L before input until wide decoding is implemented. No BFD/FFI or host fallback; locale/object sections remain project work. | Binutils 2.44 JSON and package contracts plus selected separator/cross-block development observations. Wide modes require endian/minimum-length/offset/invalid-input differentials. |
| column | Default vertical/-x grid and global -t layout use one indexed disk snapshot; retained caches and the current record replace whole-input/output buffers. | Temporary writes are required. GNU/Linux C-locale non-ASCII bytes are escaped; non-ASCII delimiters reject. Automatic terminal discovery and full Unicode widths remain separate capabilities. | Current spool/layout package regressions and command contracts; historical util-linux 2.40 evidence remains in the [repair summary](../../CHANGELOG.md#2026-10-11). Add terminal discovery only with public APIs and expand locale widths against versioned Unicode/locale data. |

The [changelog](../../CHANGELOG.md#2026-10-11) summarizes the original follow-up
audit; full observations remain in Git history.

`seq` streams without an arbitrary ten-million-record cutoff. Counting records
is unnecessary for separator placement; a boolean avoids both that semantic
limit and eventual counter overflow. Keep the explicit 4096-character numeric
operand bound and exponent/scale range -4096..4096 to bound BigInt allocation;
README/help and rejection contracts describe them. Arbitrary-precision input
growth remains project work, not async work. Remove these bounds only with
measured resource behavior and pre-output error tests; do not weaken normal
sequence output to enforce a test runner's budget.
The over-cap stress probe exposed the cost of two unbuffered writes per record.
Use the released public `io.BufferedWriter` with a 64 KiB buffer and an explicit
final flush. This bounds extra storage and preserves output bytes; partial
buffer visibility follows normal buffered CLI output. Per-record syscalls and
buffering the complete sequence were rejected. Retain the large-record-count
stress gate and ordinary separator/fraction/error contracts when changing this.
The second column review also compares controls and ANSI color sequences against
util-linux 2.40: table widths ignore complete control + `[` ... `m` sequences,
while the default grid retains its printable-character width rule. Output bytes
are preserved; this is not terminal detection or automatic color generation.
The [support record](../compatibility.md) tracks current profiles without
turning known defects into positive compatibility claims.

## Source review (2026-10-26)

Buffer/scanner and external-sort work is `1ffa967`; text options are `5dbe51d`/`2e867a3`; the snapshot/reverse-read changes are `87ca302`. Current sources: [stream.mbt](../../core/stream/stream.mbt), [sort](../../commands/sort/external.mbt), [csplit snapshot](../../commands/csplit/snapshot.mbt), [column spool](../../commands/column/spool.mbt), [tac](../../commands/tac/) and [rev](../../commands/rev/). Their package tests and JSON contracts retain the exact resource/error boundaries above.
