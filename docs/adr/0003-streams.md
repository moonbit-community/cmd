# ADR-0003: Streams, Ownership and Bounded Search

Status: Accepted
Date: 2026-09-05
Updated: 2026-11-01

## Decision

Audit correction (2026-11-01): sort `-n` must preserve arbitrary decimal-prefix
precision. The former Double conversion collapsed distinct large integers and
fractions; previous performance evidence does not establish that semantic
contract. Global keys use borrowed decimal ranges with an exact small-integer
fast path. Prepared fields store sign, integer length and canonical digits in
temporary runs. Cached storage grows with numeric precision and is accounted
by the existing entry budget. Independent ordering, equality, stable/unique,
check and forced disk-run regressions govern the repair. Previous timing
verdicts do not qualify this revision. General-numeric mode remains separate;
published expectations are frozen.

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

## Over-tenfold command pilots (2026-11-01)

The post-CI inventory selected cmp, seq, gunzip, zcat, jq, join, comm, tail,
sha1sum, sort, cp, find and patch, including unstable observations above 10x.
rg is explicitly excluded by the user. Baseline `de243c8` and all 80 optimized
artifacts were frozen before editing in
`/private/tmp/cmd-performance-deep-20261101/B0`. These are local development
pilots, without publication or new remote CI acceptance.

Retain independently qualified phases: quiet cmp compares byte spans and stops
at the first mismatch; bounded Int64 seq renders synchronous output batches;
inflate decodes buffered symbols synchronously with explicit cross-flush match
tails; jq scans each input chunk synchronously; join batches complete output
records; comm borrows immutable records and merges until an I/O boundary;
tail uses byte-search counts and owned input chunks; patch keeps the full source
in the byte domain; sort caches only explicit numeric fields that require
general decimal conversion; find coalesces each output record. Preserve skips,
limits, integer overflow, fallback conversion, framing, exact bytes, order
diagnostics, output-failure and cleanup contracts in the named regressions.

Incremental windows qualify A (6/6 rows), B (9/9), C (12/12), D's patch and
find subsets (5/5), and E's sort and comm subsets (7/7). D and E as complete
panels **failed**. D's decimal sort and several digest controls drifted; E's
digest controls and copy-source samples remained unstable. Never substitute
their promising medians for a pass. The E sort revision avoids rescanning an
already rejected integral prefix; the E comm revision replaces per-record
async calls with a synchronous merge. These are separate implementations,
not retries of an unchanged failed candidate.

SHA-1 reusable schedules, direct block input and fixed round groups showed
source-file gains but could not qualify every changed checksum artifact.
Restore the original checksum implementation; retain the independent block
boundary tests and both failed panels. cp 256 KiB and 128 KiB buffers showed
source-file gains but did not qualify. Its read-owned-buffer variant changed
25 artifacts, including correctness-only ln, so was rejected before timing.
Restore the original 64 KiB copy. E's checksum controls are not new adoption
claims. No qualified 3-5% slowdown is accepted in these incremental panels;
sort's ordinary numeric rows show roughly 1-2% costs, recorded separately from
the decimal gain. No peak-RSS improvement is inferred from allocation changes.

Remaining limits: tail cannot seek regular-file stdin through the released
public Reader API; cp retains identity/permission preflight and public copy
boundaries; find retains explicit metadata queries and traversal ordering.
Changing these requires a public API or independently validated semantic
implementation, not host delegation. Buffered inflate follows the six-byte
input bound documented by
[zlib 1.3.1 inffast](https://github.com/madler/zlib/blob/v1.3.1/inffast.c);
seq uses command-owned digit batches, informed by
[GNU seq](https://github.com/coreutils/coreutils/blob/master/src/seq.c).
Neither imports an external implementation into the pure MoonBit product.

The C snapshot temporarily omitted two existing comm tests during editing;
both original tests were restored unchanged and all 17 selected tests passed
before further work. Preserve that snapshot and correction evidence. Final
acceptance must use the restored corpus, all changed-artifact workloads and
the cumulative comparison against B0. Fresh native ratios are separate from
old/new Wasm gains; neither establishes general upstream parity.

Final retained candidate F qualifies all **38/38** cumulative workloads across
all **12 changed command artifacts**, with all 80 artifact identities checked.
Both windows satisfy stability, drift and the 5% slowdown limit. New/old time:
large quiet cmp 0.0132-0.0292, million-integer seq 0.0471-0.0474, compressed
inflate 0.0594-0.1070 (stored blocks remain controls), jq 0.4129-0.5511,
join 0.2346-0.2354, comm 0.4929-0.4942, large-input tail 0.7382-0.7492,
fractional sort 0.4790-0.4804, and large-source patch 0.1772-0.1826.
find improvements are only 0.9644-0.9924. The largest qualified timing cost is
1.9% on ordinary numeric sort; no 3-5% cost is accepted. Small patch and
fragmented tail retain substantially smaller benefits or unchanged time.

Fresh native comparison completes **44/44** workloads, but only **20/44**
qualify; the other 24 fail stability or inter-window drift. Its overall panel
is failed and is not repeated unchanged. Stable examples include large equal
cmp at 4.50-4.57x, fixed-literal gunzip at 3.97-4.22x, member decoding at
3.39-3.72x, and jq at 2.54-7.65x depending on mode. Unchanged cp source copying
is 10.45-10.75x; this is a fresh observation, not an adopted copy optimization.
Do not infer a native ratio by multiplying an earlier ratio by a Wasm gain.

Validation: 1,776 release Wasm tests, 60 Native benchmark-observer tests,
2,260 CLI checks (2,203 semantic passes), 21 platform skips and zero failures;
strict checking, formatting, interfaces and architecture pass. The changed cmp
help expectation and its reviewed quality hash are synchronized; published
expectations remain unchanged. No public interface changed. Compact evidence,
including failed D/E panels, all samples and oracle records, is retained at
`/Users/winter/.codex/visualizations/2026/10/31/01a18ff6-bbc5-7b90-8147-4ac7a03d76e3/performance-deep-20261101/README.md`.
These generic protection-threshold panels are not a formal 105-pair result,
the full protection wrapper, cross-platform CI or publication acceptance.

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

Differential execution preserves the independent local assertion stage. Its
typed receipt binds the original case digest, completion verdict and full local
observation dimensions after exact, file and runtime checks actually finish.
Finite proof joining requires both that receipt and a complete differential
pass. An oracle-only case, missing receipt or generic result label cannot
substitute for the reviewed local contract; historical missing receipts remain
unqualified.

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

### Performance integration and complete package inventory (2026-11-01)

Commit `d12f317` integrates the retained sed/csplit, base32/base64/nl and
sort/diff implementations. Its required Linux, macOS and Windows checks passed
in [run 41246902641](https://github.com/moonbit-community/cmd/actions/runs/41246902641).
The earlier failed timing windows and rejected numeric-cache candidates retain
their dated verdicts below; committing the source does not change those results.

The requested post-CI survey accounts for all 80 packages: 54 timing commands,
three existing correctness-only dispositions, and 23 explicit not-timed reasons.
The single schema-3 inventory grows to 162 rows and 128 mode contracts covering
133 argument/preparation/status combinations. All existing 130 rows remain.
The same 33 genuine sources and 31,450,998 unique bytes are reused. No product
code changes in this inventory expansion; all 80 artifacts are checked against
the frozen CI-passed source.

The added commands are chmod, cmp, cp, fmt, hexdump, ls, mv, od, patch, rm,
seq, tee, xargs and xxd. Permission measurements explicitly observe resulting
modes. Patch preparation uses a frozen native diff outside timing to derive
the actual changes between complete CPython/SQLite releases; applying the patch
must reproduce the complete target bytes independently of native agreement.
Xargs uses the same frozen native printf child and includes child-launch cost.
Seq is an explicit argument-driven output operation: the genuine empty stdin
file is transport, not a source-throughput claim. Source copies/collections
remain complete; generated-size inputs and synthetic edits are still excluded.

The finite Python file collection does not establish massive-directory behavior.
Same-filesystem mv is a rename operation, not byte-copy throughput. Short tools,
waiting tools, unsupported ordinary operations and missing fair references have
individual dispositions rather than invented ratios. In particular, jqlog has
no same-command upstream oracle, touch lacks existing-file timestamp updates,
and yes needs a byte-bounded consumer with a reviewed cancellation relation.
Future coverage must preserve local contracts, exact effects, frozen references
and all-package accountability before removing any of these limitations.

The added-command untimed calibration passes 31 of 32 genuine invocations.
The complete Shakespeare `fmt -w 72` row differs from fixed GNU output in line
wrapping and remains a failing correctness control; it must not receive a
qualified ratio or be removed to improve the survey. The RFC formatting row
passes. All 63 benchmark/registry regressions and the unchanged-product hash
check pass. The initial baseline launcher used the wrong direct artifact layout;
its missing-file failure is retained, followed by a fresh `cli/` layout run.

### Sort input/comparison and diff byte/script pilots (2026-11-01)

B6 freezes the preceding retained tree and all 80 Wasm artifacts at
`/private/tmp/cmd-performance-sort-diff-20261101`; every artifact matches the
preceding round's final verification. Sed, csplit, encoders, nl, rg and shared
core stay unchanged. The user's approximately five-times-native target guides
prioritization, not an assumed fixed Wasm overhead or a relaxed timing gate.

The inventory adds complete same-file release pairs for diff: CPython's JSON
encoder 3.13.0/3.14.0 and SQLite's amalgamation 3.50.3/3.50.4. Their frozen GNU
unified output has five and eleven hunks respectively. Add an airport seventh
field numeric sort control beside the first field integer IDs, so an integer
shortcut is also measured on natural fractional keys. Whole-record and explicit
field numeric ordering also run on the complete SQLite source with a 4 MiB
spill budget, guarding the interaction between prepared keys and run storage.
There are now 130 rows,
33 complete sources and 31,450,998 unique source bytes. These are finite genuine
workloads; neither the old synthetic diff shapes nor a Moonseek call-frequency
distribution becomes qualified. No generated edits, timing padding, new runner,
startup subtraction, repeated warm process or sample filtering is introduced.

- Sort consumes existing immutable record batches in a synchronous admission
  loop. The pending overflow entry remains owned across spill/compaction and
  keeps its sequence number. Maximum source read request grows from 64 KiB to
  1 MiB; peak RSS is not measured. The first phase qualifies at 0.7280–0.7300
  of B6 lexical time, 0.8872–0.8905 for integer keys and 0.8906–0.8918 for spill.
- A subsequent sort candidate parses at most fifteen integer digits directly
  with exact Double intermediates and decodes complete cached run entries in
  a synchronous loop. Fractional/long-number conversion, run format, exact
  refill failure, reservations and temporary ownership stay unchanged. This
  candidate fails: lexical time costs 5.47% in one window. Its integer/spill
  gains and 2.55–2.65% decimal cost do not offset that failure.
- The revised sort plan selects untransformed byte ordering once per invocation,
  retaining general key comparison and stable/reverse ties. Against the preceding
  passing batch phase, all four rows qualify: lexical 0.8945–0.8980, integer
  0.8620–0.8626 and spill 0.6823–0.6827. The decimal row costs **3.30–3.71%**,
  accepted as a scoped local tradeoff below 5%, not noise or a speedup. Lift
  this cost by avoiding duplicate prefix scans while retaining exact conversion
  behavior and rerunning the complete integer/decimal controls.
- Diff tests byte equality after accepting both operands, uses byte searches
  for NUL/newline, and appends original patch record bytes without a text round
  trip. A first candidate has three qualified rows but fails the unrelated
  module row's dispersion/drift; it is not adopted as a qualified batch.
- Revised diff scripts trim identical outer records while retaining requested
  context and absolute line offsets. Comparison keys, flags and edit objects
  cover the retained domain; the existing Myers search, repeated-anchor discard
  and alignment rules remain. All four B6 comparisons qualify: equal source
  0.1473–0.1498, SQLite revisions 0.5396–0.5429, Python revisions 0.9337–0.9346,
  and unrelated modules 0.8826–0.8864. Byte output, Unicode labels, missing
  terminators, context and reconstructed edit scripts have independent witnesses.

The formatted pre-cache candidate qualifies all eight then-registered cumulative
rows against B6: lexical sort 0.6530–0.6531, integer sort 0.7670–0.7679,
decimal sort 0.9900–0.9971, spill sort 0.6059–0.6066; equal diff 0.1566–0.1576,
Python revisions 0.9434–0.9476, SQLite revisions 0.5464–0.5495 and unrelated
modules 0.8936–0.8968. Native comparison qualifies seven rows: sort lexical
6.32–6.41 times, integer 6.92–7.33, decimal 14.53–14.56 and spill 5.50–5.61;
diff equal 2.00–2.04, Python revisions 7.51–7.74 and SQLite revisions 5.50–5.51.
The unrelated-module native row fails reference dispersion and stays unqualified.

Three subsequent numeric-cache trials are rejected and restored from the
pre-cache source archive. Inline cache fields improve decimal time by about
56% but cost 9–10% on integer keys and 47% on spill. Reusing prepared-key bytes
removes those fields but eagerly preparing global numeric keys costs 31–32%
on whole-record numeric spill. Restricting caching to explicit numeric fields
improves decimal time by 53–54% and numeric-field spill by 19–20%, but its
integer control fails dispersion (7.55%) and inter-window drift (about 19–22%).
That batch is not accepted and is not rerun unchanged to manufacture a pass.
The final tree retains the earlier passing implementation and all added
genuine workload controls. A future cache trial must qualify the complete six
sort rows, preserve raw global numeric allocation behavior and exact conversion,
and establish stable independent windows before adoption. Failed sources,
artifacts and samples remain recoverable beside the retained snapshot.

After restoring that implementation, all 80 artifacts exactly match the
pre-cache final artifacts. Final validation passes 1,759 release-Wasm tests,
2,260 functional checks (21 skips, zero failures), 652 reviewed finite claims,
and the 30-strategy architecture inventory. The expanded final cumulative panel
qualifies **9/10 rows**, including all six sort controls: lexical time falls
34.56–34.91%, integer 22.53–22.67%, lexical spill 39.34–39.41%, numeric-field
spill 29.65–29.72% and whole-record numeric spill 17.42–18.33%. Decimal time
falls only 0.20–1.47%; it remains a priority. Diff equal and SQLite revision
time fall 83.63–83.71% and 44.60–45.02%, respectively. Unrelated-module time
falls 9.79–10.67%. The Python revision row fails W0 candidate/reference MAD
(5.71%/9.84%) and reference drift (12.94%); the complete final batch therefore
**does not pass**. Earlier qualified evidence is retained with its own scope,
not substituted for the final failure. No unchanged retry is performed.

The expanded final sort/native panel qualifies four of six rows: integer
6.80–6.86 times native time, decimal 13.61–14.20, numeric-field spill
9.92–10.12 and whole-record numeric spill 5.81–6.14. Lexical and lexical-spill
native comparisons fail reference dispersion (up to 9.98% and 11.25%). Their
earlier qualified ratios remain dated observations, not new acceptance.
Diff's native evidence is reused only because its artifact is identical; the
earlier unrelated-module failure remains. The retained tree is a local candidate
with qualified per-row gains and an unresolved final performance gate. Evidence
and failed guards are retained at `performance-sort-diff-20261101/README.md` in
the thread's visualization folder; the full source/artifact archive remains in
the raw directory above. The next work should target decimal/field-numeric sort
and small-file diff costs while preserving these wider controls.

The pinned GNU coreutils 9.11 `fillbuf`/numeric comparison and diffutils 3.12
`find_identical_ends` implementations informed batching, byte comparison and
edge-domain reduction. No host implementation enters the product. Small-file
process startup and larger-file comparison work remain separate observations;
these pilots do not establish AI integration, upstream parity, all-command
performance, resource acceptance, remote CI or publication.

### Encoding, numbering and sort output pilots (2026-11-01)

The next local batch leaves sed at its accepted practical target of roughly
five times native time and leaves rg to its separate optimization work. This
is a prioritization decision, not a fixed Wasm or MoonBit overhead claim. B5
preserves the current source and all 80 artifacts, including the preceding
uncommitted sed/csplit improvements, at
`/private/tmp/cmd-performance-other-20261101`. Its hashes match the preceding
round's final verification. The real-source inventory and all timing gates are
unchanged; no synthetic timing inputs or new command-specific runner are used.

The fresh native baseline qualifies sort at 9.85–12.43 times native time, nl
at 11.18–11.23 and base64 source encoding at 24.54–25.91. Base32's observed
39.80–43.80 source ratio and both small binary controls fail stability; retain
those failures rather than using their ratios as qualified ranking evidence.

- Base64 encodes complete three-byte groups directly into byte arrays. It
  retains at most two carry bytes across the existing 64 KiB reads, preserves
  wrap columns, and writes complete quanta before the next read. StringBuilder,
  character conversion and whole-chunk Array copies leave the encoding loop.
  Both incremental rows qualify: source time is 0.2067–0.2093 of B5; the small
  binary control is 0.9747–0.9886. Decoding is unchanged.
- Base32 first replaces character/string intermediates with direct byte output
  and chunk copies for wrapping, following the alphabet and bit-group layout
  in the pinned GNU coreutils 9.11/gnulib source. Whole-input acceptance is
  retained. Initial source time is 0.6627–0.6687 of B5. Using public 64 KiB reads
  adds a further reduction to 0.8719–0.8743 of that candidate, while its small
  binary control costs 1.36–1.57% (roughly 0.1 ms), a separately recorded local
  tradeoff. Complete five-byte groups subsequently move into a compact kernel
  with quantum-aligned 65,535-byte windows; final padding and arbitrary wrapping
  remain outside it. That phase qualifies at 0.2079–0.2117 of the preceding
  source time, with binary ratios 0.9969–1.0066. No interior window adds padding.
- Nl uses the existing immutable RecordReader batches, retains section/blank
  grouping state, and coalesces each numbered record for synchronous BlockWriter
  admission. A declined record remains owned until its ordinary write completes;
  only then does its number advance. Source time is 0.2449–0.2460 of B5. Its
  maximum read request changes from 64 KiB to the existing RecordReader's 1 MiB;
  coalescing also adds transient record storage. Peak RSS is not measured.
- Sort coalesces record plus LF/NUL and admits in-memory sorted output in a
  synchronous loop. Merge output uses the same command-owned admission state.
  First unique representatives commit only after output admission/completion.
  Comparators, sort algorithms, prepared keys, run format, run budgets, merge
  fan-in and temporary cleanup stay unchanged. All three incremental rows
  qualify: lexical 0.7816–0.7875, numeric 0.8995–0.9025 and spill 0.9007–0.9008.

Reject a separate base32 bounded-write trial: source time increases 0.74–0.78%
and the binary control 0.49–0.83%, with no measured benefit. Its complete source,
tests and passing-but-negative panel remain archived. An isolated diagnostic
using the registered source measures base32 encoding at 165 ms on the first
call and 23 ms on each of two subsequent calls in one process. This motivated
the compact kernel; it does not establish a particular runtime cause or replace
fresh-process timing. Diagnostic code is removed from product tests. RFC vectors,
frozen 0..255 byte expectations, group/read boundaries, arbitrary wrap columns,
late read failures, failed output prefixes and stateful numbering/sort tests
remain private correctness witnesses, not generated performance inputs.

Review catches eager nl blank-prefix allocation on empty input; the retained
version allocates it only when needed, with a large-width empty-input regression.
That correction's incremental panel fails candidate/reference drift at
13.84%/14.57%, so it does not establish a qualified incremental speed effect.
The corrected final candidate instead receives its own complete cumulative
comparison against the actual B5 baseline; all eight required rows pass. Source
encoding uses 0.1225–0.1236 of B5 time for base32 and 0.2096–0.2106 for base64;
nl uses 0.2458–0.2468; sort lexical uses 0.7848–0.7897 and numeric/spill
0.9008–0.9094. Base32's small binary row is 0.9999/1.0280: retain and record
the second window's 2.80% cost separately, rather than calling it a gain or
discarding it as noise. The other binary control is 0.9607–0.9706.

The first combined native panel is invalidated by an agent edit to
`tests/benchmark/protection.json` during timing. Its identity failure and
unstable rows remain preserved and supply no qualified native claim. The final
corrected source and policy remain unchanged throughout their fresh panels.
Final native evidence has intact identities but qualifies only four of eight
rows: nl at 2.674–2.675 times native time and sort at 8.90–9.80. Base32 source
observes 4.91–5.20 but candidate drift is 10.61%; base64 observes 4.51–5.13 but
reference drift is 15.19% and first-window reference MAD is 9.00%. Both small
binary native controls also fail stability. These observations approach the
practical target but do not establish a qualified native-ratio result.

Final validation passes strict checking/building, all 1,753 release-Wasm tests
and 2,260 functional checks (21 platform skips, no failures). The finite reviewed
profile passes 652 claims; the architecture inventory validates 80 commands and
29 strategies. Generated interfaces remain unchanged. Final source and all 80
artifacts are sealed as `retained`, with exactly base32/base64/nl/sort changed
from B5; the other 76, including sed/csplit/rg and all codec commands, are
identical. Full raw evidence remains at the path above, and a compact bundle
is retained in the thread's `performance-other-20261101` directory. No remote
CI, publication, full all-command timing, immutable-oracle parity or resource
acceptance is implied. Sort's remaining qualified gap is the next priority;
its numeric key reparsing and asynchronous temporary-run reads need separate
experiments before any further algorithm or resource claim.

### Cache-local loops and encoding-table pilots (2026-10-31)

These local trials start from the integrated `7c9d1d2`, with complete B4 source
and all 80 Wasm artifacts saved at
`/private/tmp/cmd-performance-sync-loops-20261031`. The schema-3 inventory,
genuine sources, independent contracts and two-window gates remain unchanged.
rg and shared bytere/stream implementations are outside this batch.

Retain two command-local improvements as qualified local candidates:

- Csplit scans newlines and encodes each index page synchronously, returning
  before the first boundary that needs another page. A checked eight-byte slot
  admits the standard library's little-endian UInt64 store. Input still reaches
  the data spool before its index; signed offsets, incomplete final records,
  failures and cleanup retain their previous contracts. GNU coreutils 9.11's
  `record_line_starts` similarly locates newlines within an owned buffer; its
  in-memory line-index architecture is not transplanted. The final source row
  uses 0.2962–0.3103 of B4 time, a 69–70% reduction.
- Sed admits complete records from its immutable input cache synchronously and
  directly selects commands without addresses. Empty append queues need no
  async call. Owned, coalesced output records use the existing BlockWriter
  synchronous admission; rejected writes retain bytes and newline state until
  the ordinary async path completes. The existing interpreter handles address
  lookahead, hold spaces, branching and multiline commands. The two final rows
  use 0.6381–0.6426 and 0.5591–0.5689 of B4 time: about 36% less for identifier
  substitution and 43–44% less for misses. No workload-specific patterns,
  alternate interpreter or public API are introduced.

Keep the earlier failed stages: csplit scan-only observed large gains but
candidate drift was 10.1826%; sed cache-only missed the identifier stability
gate, including 12.2630% reference drift. The later variants change actual
encoding/output mechanisms rather than retrying unchanged failed windows.

The compression trials remain outside retained product code. GNU gzip 1.14's
`longest_match` motivates endpoint rejection and grouped comparison, but that
variant costs 2.09–2.61% on compression despite all nine rows qualifying, so it
is rejected. This is a measured cost, not a benefit or an accepted tradeoff.
[zlib 1.3.1](https://github.com/madler/zlib/blob/v1.3.1/trees.c) instead motivates
direct length/distance symbol maps. A pure MoonBit 256-byte length table and
512-byte split distance table preserve every legal symbol, exhaustively checked
for all 256 lengths and 32,768 distances. Compression uses 0.7672–0.7708 of B4
time, but only eight of nine rows qualify: gunzip stored's first-window
candidate MAD/median is 5.4047%. Archive this promising experiment and restore
the delivered codec. The earlier buffered decoder remains excluded as well.
A sandbox setup attempt failed before any timing samples; its empty reports
remain separate from the subsequent host-permitted run.

The separate native panel qualifies sed at 5.34–5.56 times native time for hits
and 4.10 for misses; the experimental gzip encoder is 4.18–4.20 times native.
Csplit observes 1.80–1.86 but fails native-reference dispersion at 5.1783% in
the first window. These are current scoped comparisons, not general throughput
or immutable Linux parity. The native sed executable hash matches the previous
round, but its present 35–36 ms differs from that round's unstable 65–71 ms;
do not infer a Wasm regression or attribute the cross-run change to an unmeasured
host cause. This round adds no remote CI, RSS or publication acceptance.

Final local validation passes strict Wasm checking/building and all 1,743
release-Wasm tests. Functional validation records 2,260 passes, 21 platform
skips and no failures; the finite reviewed profile passes all 652 claims without
establishing general compatibility. The architecture inventory validates 80
commands and 26 strategies. Generated interfaces remain unchanged. All 80
final Wasm hashes are checked against frozen sources: sed matches the qualified
sync-output phase, csplit matches the qualified word-encoding phase, and the
other 78 match integrated B4. The full all-command protection run is not repeated;
selected timing covers every changed command artifact. A compact local evidence
bundle is retained in the current thread's `performance-sync-loops` directory,
with complete raw windows and recovery archives at the path above.

### Adopted integration scope (2026-10-31)

The delivery branch includes only the qualified sed and csplit implementations
from the trials below. Sed retains coalesced buffered output, chunk scanning,
immutable byte spaces and negative-only mandatory-literal filtering. Csplit
retains bounded index pages, cached synchronous scans and one byte matcher per
control. Their existing independent regressions and strategy registrations
remain part of ordinary development validation.

The buffered DEFLATE decoder, packed Huffman tables and contiguous CRC8 changes
are excluded from delivery: the cumulative codec gate remains incomplete.
`core/gzipops` is restored to `55de9ec`; experimental sources and artifacts
remain in the dated local trial archives, with an additional complete source
and Git-ref recovery bundle in
`/private/tmp/cmd-adopted-integration-20261031`. The following trial narratives
retain their historical source, correctness and measurement scope. They do not
describe current codec implementation or establish remote CI, publication or
general performance acceptance. Adoption of that codec still requires the
unchanged complete timing gates and applicable correctness checks.

### Local performance pilots after the corpus migration (2026-10-31)

These unreleased trials start from `55de9ec`. The complete source archive and
all 80 release-Wasm baselines were saved before editing under
`/private/tmp/cmd-performance-pilots-20261031`. Measurements use the existing
schema-3 inventory, its native correctness calibration and independent local
contracts. The inventory, thresholds and published expectations are unchanged;
rg is outside this optimization batch.

- `gzipops` owns a synchronous compressed-block loop, shared by gzip, gunzip
  and zcat. Its six-input-byte and 258-output-byte admission bounds follow the
  maximum DEFLATE token, as described in
  [zlib 1.3.1](https://github.com/madler/zlib/blob/v1.3.1/inffast.c).
  Only required input bytes are consumed. Refills, partial-token decoding,
  output flushes, trailer ownership, CRC and error-prefix delivery retain the
  existing decoder. Private regressions exercise the full 48-bit token,
  1/5/6/7-byte feeds, maximum distance, overlapping copies, output capacity,
  invalid symbols and failed writes. Rust's
  [miniz_oxide 0.8.9](https://github.com/Frommi/miniz_oxide/blob/0.8.9/miniz_oxide/src/inflate/core.rs)
  additionally illustrates packed Huffman tables; that representation change
  is a possible later experiment, not part of this pilot.
- `csplit` keeps its input spool and signed 64-bit index. It encodes 64 KiB
  index pages synchronously, then matches records directly when both boundary
  entries and the complete text already belong to its existing caches.
  Cross-page and long records use the original path. No file-sized memory
  index, new public API or shared command framework is introduced. Temporary
  cleanup, negative offsets, byte regex semantics and output ordering remain
  command-owned. GNU coreutils 9.11 `src/csplit.c::record_line_starts` is a
  useful comparison for block-local indexing; its retained input buffers do
  not replace this implementation's bounded-memory spool contract.
- `sed` combines a record's separator, text and terminator into one write.
  Each existing emit still completes before execution continues. Append
  queues, n/N lookahead and flush points are unchanged. This is a general
  output operation, independent of the script or input text. It temporarily
  needs one additional record-sized byte buffer; this is a design cost, not
  a measured RSS result.

The decoder's first prototype is **superseded**. A later boundary review found
that an exactly full fast-path output buffer needed flushing before the next
symbol. The new end-to-end regression reproduced the first prototype's trap;
the corrected caller flushes before decoding continues. This is a defect found
and corrected during the pilot, not a defect attributed to the original
baseline. The first two-window run was also **not qualified**: four of nine rows
passed, including compression (0.998/1.003 candidate/baseline ratios), zcat
fixed literals (0.0634/0.0631), and gunzip/zcat concatenated members
(0.0845–0.0936). Other rows exceeded dispersion or drift limits; the gunzip
stored row also observed 1.206 in its first window. Dynamic decoding observed
0.125–0.131, but that gain does not waive unstable rows. A separate identical
old-artifact A/A run passed three of four rows and again failed stored decoding
on dispersion/drift. It diagnoses insufficient timing stability for that
control, without turning the failed candidate run into a pass.

The csplit index-page phase passed both windows at 0.907/0.904 relative to the
original artifact. The cache phase passed at 0.864/0.862 relative to that
preceding phase. The pre-format cumulative artifact passed at 0.780/0.775;
the formatted artifact receives a separate final comparison because its hash
changed. Sed's two existing substitution rows passed at 0.568–0.574 relative
to the original artifact, with unchanged results and retained write boundaries.
The final formatted csplit artifact passed at 0.788/0.787. The corrected
decoder panel qualified five of nine codec rows: compression 0.994/0.987,
gunzip dynamic 0.109/0.111, gunzip fixed literals 0.0654/0.0655, zcat fixed
literals 0.0637/0.0639, and zcat members 0.0857/0.0849. Zcat dynamic, gunzip
members and both stored rows failed dispersion or drift checks. Gunzip stored
observed 1.267 in the second window while its baseline drift was 35.3%; no
regression-free conclusion is justified for that row. The complete corrected
panel remains **failed** (six of ten including csplit). No small timing loss
has been accepted in this batch. These are selected-workload observations, not full protection, formal
105-pair sampling, immutable-oracle parity, resource, CI or release acceptance.
The decoder remains an experimental candidate until every required row is
stable and qualifies. All failed windows remain available for review.

Final local validation passed 1,732 release-Wasm package tests and 2,260 full
functional checks, with 21 platform skips and zero failures. The functional
receipt/proof checks and architecture inventory passed; generated interfaces
did not change. The initial sandbox-denied network/process test failures are
retained separately from the successful test run with the required local
facilities available. Exactly gzip, gunzip, zcat, csplit and sed artifacts
changed; the other 75 baseline artifacts are identical. No version, frozen
published expectation or release coordinate changed.

The final native-reference panel completed all 12 rows; eight satisfied
correctness/stability and four codec rows remained unstable. Stable observed
candidate/native ratios were 95–110 for sed, 6.61–6.66 for csplit, 5.39–5.42
for compression, 2.65–2.70 for zcat dynamic decoding and 4.66–4.74 for gunzip
fixed-literal decoding. These are complete process times on the registered
sources, including Wasm startup. This establishes a remaining local gap, not
immutable-oracle parity or a general speed ranking. Sed therefore remains the
largest measured priority in this batch despite its improvement.

Further exploration should separate remaining costs before changing algorithms:
packed decode entries versus CRC/copy work in gzipops; spool and output-file
costs versus record conversion in csplit; output transport versus substitution
and unchanged-record allocation in sed. A buffered sed writer would require
explicit error and n/N ordering analysis. No pattern-specific shortcut or new
generated timing corpus is justified by these trials.

### Adoption and deeper local pilots (2026-10-31)

The follow-up adopts the qualified sed record coalescing and csplit index/cache
changes above. Their complete source and all 80 Wasm artifacts are preserved
as B1 under `/private/tmp/cmd-performance-followup-20261031`, independently of
the original `55de9ec` recovery set. Each subsequent change receives a separate
comparison with its preceding phase on the unchanged genuine-source inventory.
The first round's failed windows remain failed historical evidence.

- Sed now uses the existing bounded `BlockWriter`. GNU sed 4.9's
  [output_line and flush_output](https://github.com/mirror/sed/blob/v4.9/sed/execute.c)
  illustrate why a record output call need not mean an external write: normal
  stdio output is buffered, with explicit flushing for unbuffered mode. Our
  implementation retains command-owned boundaries: flush before an external
  input read/open, on completion, and before propagating a later script error.
  It reuses the writer's failed-write consumption rule. Private tests cover a
  producer waiting for prior output, partial-write failure before a script or
  input failure, n/N, append queues and unterminated output. Both registered
  rows pass at 0.179–0.187 of B1 time (593–614 ms versus 3.25–3.34 s).
- Csplit's first follow-up tries borrowing an already cached page for fragment
  copying. Its 0.984/0.992 ratios pass the no-regression gate but do not establish
  a material benefit, so that change is **not adopted**. Its source, tests and
  measurements remain in the isolated `csplit-copy` evidence.
- Csplit instead scans consecutive eligible cached records in one synchronous
  loop, stopping at the first match or uncached record. This passes at
  0.976/0.974 of B1. One existing `RecordMatcher` per control then eliminates
  byte-to-string conversion where its established Boolean paths apply, while
  retaining span fallback for assertions/backreferences and the original
  uncached-record path. This next phase passes at 0.896/0.907 of synchronous
  scanning (473–477 ms versus 526–528 ms). Binary/empty/unterminated records,
  page/index boundaries, BRE assertions, alternatives and backreferences have
  private regression witnesses. No bytere implementation or rg source changes.
- The decoder follows the compact-entry principle in
  [miniz_oxide 0.8.9](https://github.com/Frommi/miniz_oxide/blob/0.8.9/miniz_oxide/src/inflate/core.rs):
  the low nine bits hold a symbol, higher bits hold its length. This pilot uses
  a flat Int32 table with negative offset/width entries for the existing second
  level; it does not copy miniz's tree traversal or change the nine-bit main
  width. Zero remains invalid. Canonical EOF decoding and minimum necessary
  reads stay intact. Tests cover every code length through 15, partial prefixes
  and preserved following bits across four main-table widths. The nine-row
  incremental panel passes completely: fixed literals use 0.948–0.965 of B1
  time, dynamic decoding 0.969–0.988, and zcat members 0.953–0.959. Gunzip
  members are 1.007/0.940, so no uniform gain is claimed for that row.

The packed-table panel has one qualified small cost: gunzip stored decoding is
0.996/1.035 of B1 (39.5/42.1 ms versus 39.7/40.7 ms). The incremental review
accepts this 3.48% observation within the existing 5% limit, separately from
the gains and from unqualified timing noise. Stored blocks do not use Huffman lookup; this
does not establish a table-induced causal regression. No RSS claim is made.
The incremental pass alone does not retroactively qualify the original decoder
candidate; cumulative original-artifact validation remains a separate gate.

The final cumulative comparison completes all 12 selected rows with intact
artifacts: **10 pass and two fail**, so the combined panel is not qualified.
Sed passes at 0.0973–0.1064 of original time (about 9.4–10.3 times faster);
csplit passes at 0.6864/0.6882 (about 31% less time). These changes are locally
adopted. Codec compression remains 0.999/1.002, dynamic decoding is
0.1102–0.1119, fixed literals 0.0607–0.0639 and concatenated members
0.0858–0.0888. All seven non-stored codec rows pass. Gunzip stored remains
unqualified because the first-window baseline MAD is 5.0046%. Zcat stored
observes 1.0512/1.0237; its first-window candidate/reference MAD values are
5.1715%/6.2601%. Neither failure is rounded into a pass or waived because the
other side is unstable. The complete decoder, including packed tables, stays
an **experimental local candidate**, not an adopted regression-free change.
It remains separately recoverable from the source archives and phase patches.
Lift this disposition only with a diagnosed stability window or an independently
validated implementation change, followed by all required rows qualifying.

Final local validation passes 1,739 release-Wasm package tests and 2,260
functional checks, with 21 platform skips and zero failures. The functional
proof checks and architecture inventory pass; generated interfaces do not change.
No full protection run, formal 105-pair result, resource claim, three-platform
CI, exact-version MoonX check or publication is implied.

The subsequent native comparison completes 12 rows, seven stable and five
unqualified. Stable candidate/native observations include sed substitution miss
at 11.63–11.89, csplit at 5.04–5.08, compression at 5.41, zcat dynamic at
2.26–2.51 and gunzip fixed literals at 3.78–4.05. Sed substitution hit is
10.68/11.82 but unqualified because native drift is 10.47%; the other four
unqualified rows are codec observations. This narrows the remaining priorities
without claiming native parity. Sed still converts byte records to strings and
back, including unchanged output; a future representation trial must retain
hold/pattern-space ownership and n/N rather than special-case the measured
substitution scripts. The 80-artifact read-back confirms exactly five changed
commands and 75 unchanged artifacts, with each final artifact equal to its
measured incremental phase. The experimental codec changes remain explicit in
that five-command count.

Further source reading identifies two decoder candidates, not measured gains.
[zlib 1.3.1 CRC](https://github.com/madler/zlib/blob/v1.3.1/crc32.c) uses multiple
interleaved CRC chains with word tables to reduce serial dependence; its own
comments tie word width and chain count to measured processor behavior. Our
`push`, `append` and `copy_match` still update CRC one byte at a time. A pure
MoonBit block-CRC trial must preserve CRC coverage for partial/error output and
test-only decoding, then measure the existing stored/compressed rows separately.
[inflate_fast](https://github.com/madler/zlib/blob/v1.3.1/inffast.c) separates
history-window and current-output copies, and records several attempted
optimizations that were slower. It is a source of bounded hypotheses, not a
reason to assume native tuning transfers to Wasm. Csplit still owns the
bounded-memory spool contract; GNU's retained line buffers are not a drop-in
replacement for arbitrary negative offsets. These directions remain unadopted.

### Byte ownership and CRC follow-up (2026-10-31)

This round preserves the preceding final source and all 80 artifacts as B2 in
`/private/tmp/cmd-performance-byte-crc-20261031`. It uses the same real-source
inventory and unchanged correctness, dispersion, drift and slowdown gates.
Csplit and rg implementations are unchanged in this round. Earlier failed
panels retain their verdicts.

Sed follows the byte-buffer ownership model illustrated by
[GNU sed 4.9's line and hold spaces](https://github.com/mirror/sed/blob/v4.9/sed/execute.c),
within this command's existing C-byte semantics. Its first phase scans each
immutable input chunk for LF and uses one growable buffer for spanning records,
instead of pushing every byte into a temporary array. Both registered rows
qualify at 0.901–0.912 of B2 time. The next phase retains immutable byte views
in pattern/hold spaces and decodes text only when an operation needs it. Content
changes create a new space; the cached text alone can mutate. Unchanged
substitutions retain their original representation. Compared with the scan
phase, identifiers qualify at 0.685/0.686 and misses at 0.633/0.637. These are
general record and ownership paths, not recognizers for the benchmark scripts.

A view owns its immutable backing bytes across refills; it never refers to a
reused mutable read buffer. A small held record may retain one whole 64 KiB input
chunk. Spanning records use an owned growable buffer, rather than an array of
retained fragments. These are design costs, not measured RSS results. Private
regressions cover all byte values, fragmented and unterminated records, numeric
addresses without decoding, hold exchange/copy, N/P/D, long-record refills,
identical substitutions and occurrence selection. Existing append ordering,
input/output failures and replacement-error checks remain intact.

The pure MoonBit CRC trial derives eight byte-position tables from the existing
reflected IEEE polynomial. An independent bitwise recurrence checks arbitrary
states, offsets, short tails and segmented updates. The tables contain 8 KiB
of UInt32 entries, excluding container overhead. This is slicing by eight,
not zlib's interleaved-chain implementation or a hardware CRC path. Zlib's
[processor-dependent table/chain discussion](https://github.com/madler/zlib/blob/v1.3.1/crc32.c)
and crc32fast's [portable block baseline](https://docs.rs/crc32fast/1.5.2/crc32fast/)
motivate measurement; they do not establish a Wasm benefit.

Two complete CRC variants are rejected and preserved independently:

- Applying block CRC after every expanded match qualifies seven of nine rows,
  but dynamic decoding regresses by 10.0–13.7%, exceeding the unchanged 5% gate.
- Deferring all decoder CRC to output-buffer flushes qualifies only four of
  nine rows. Dynamic decoding still regresses by 7.5–10.0%. Stored controls
  and gunzip members additionally fail stability; the first gunzip stored
  window has 16.6%/30.1% candidate/reference MAD. Fixed-literal gains of
  7.5–10.5% cannot compensate for the failed rows.

The narrowed candidate applies block CRC only to already contiguous encoder
chunks and stored-block spans. Compressed literals and overlapping match
expansion retain the previous fused byte/CRC loop. No length threshold or
workload-specific detection is introduced. Mixed scalar/block sequences,
test-only output, failed writes without replay, full-buffer reuse and final
tails are checked against the independent bitwise recurrence. All nine
incremental rows qualify: stored decoding uses 0.787–0.824 of B2 time,
concatenated members 0.854–0.890 and compression 0.975/0.980. Dynamic decoding
uses 0.976–1.003; fixed literals use 0.978–1.009. No 3–5% qualified cost is
accepted in this phase. Cumulative qualification remains a separate gate.

Further reading of crc32fast's
[portable baseline](https://github.com/srijs/rust-crc32fast/blob/master/src/baseline.rs)
(moving branch inspected on 2026-10-31) shows sixteen byte-position tables,
four-way loop unrolling, explicit little-endian word assembly and scalar tails.
Wider slicing is a future candidate, not a measured gain or a reason to restore
the rejected separate CRC pass. Sed's remaining regex paths still decode text;
a future byte prefilter must preserve executed-pattern history, replacement
error precedence, captures and empty-match semantics before any throughput claim.

The final original-artifact comparison completes all 12 rows with intact
artifacts: **11 pass and one fails**. Sed qualifies at 0.06243–0.06306 for
identifiers and 0.05594–0.05650 for misses, about 16–18 times faster than the
original `55de9ec` artifacts. Csplit remains qualified at 0.6897–0.6910.
Compression qualifies at 0.9786–0.9802, dynamic decoding at 0.1087–0.1142,
fixed literals at 0.06144–0.06442, members at 0.07386–0.07605 and gunzip stored
at 0.8214/0.8475. Zcat stored is faster in both windows (0.7913/0.8940), but
candidate medians of 35.249/39.354 ms drift by **11.0039%**, above the unchanged
10% limit. Every within-window MAD qualifies; that does not waive between-window
drift. The independent contiguous-CRC implementation change and its nine-row
incremental pass do not convert this failed cumulative panel into a pass.

Adopt the two new sed phases locally. Retain the complete codec, including the
narrowed CRC change, as an **experimental local candidate**. Lift that status
only after diagnosing the remaining stability condition or validating another
implementation change, then qualifying all required rows. Do not silently
repeat the same candidate's failed window. No qualified 3–5% timing cost is
accepted in this round; instability is recorded separately from any regression.

Local validation passes 1,745 release-Wasm package tests and 2,260 functional
checks, with 21 platform skips and zero failures. All 652 reviewed finite
definitions join applicable execution receipts; existing catalog gaps remain.
The architecture inventory passes and generated interfaces do not change.
Read-back verifies all 80 artifacts and their measured phase identities. Four
commands change from B2; cumulatively sed/csplit/gzip/gunzip/zcat change from
the original artifacts and the other 75 remain identical. No full protection,
formal 105-pair, resource, CI, MoonX or publication acceptance is established.

The separate final native comparison completes 12 rows, five stable and seven
unqualified. Stable candidate/native ratios are 4.69–4.81 for csplit,
5.28–5.32 for compression, 2.34–2.45 for dynamic decoding and 2.96–3.06 for
gunzip members. Sed identifiers observe 7.01–7.06 and misses 5.59–5.95, but both
fail native dispersion and remain observational. Native gunzip stored also
drifts by 12.82%; other codec controls retain their failed dispersion verdicts.
These observations do not waive the independent cumulative zcat stored failure
or establish native parity.

### Byte prefilter and CRC layout exploration (2026-10-31)

The next batch freezes the preceding source and all 80 command artifacts as B3
under `/private/tmp/cmd-performance-prefilter-crc16-20261031`. Earlier sed work
remains adopted; the complete codec retains its experimental disposition until
its outstanding gates are satisfied. The inventory and thresholds are unchanged.

A same-artifact zcat diagnostic completes all four rows with intact identities.
Dynamic and fixed rows qualify; stored and members fail. Stored reference drift
is 13.90%, with second-window candidate/reference MAD of 9.68%/8.16%; members
has 10.40%/6.01% MAD and a 1.0522 ratio in that window. Identical code cannot
explain these as a source-change regression. The observation demonstrates
measurement variability, without identifying its host/runtime cause or waiving
the previous failed cumulative comparison. It is not an acceptance retry.

Sed now prepares the existing bytere mandatory literal once per explicit
expression and can reject a raw byte space before text conversion. It does not
replace full matching or capture extraction. Pattern history is resolved and
replacement references are validated before rejection; text-only spaces,
uncertain/short literals, captures, backreferences, nullable expressions and
multiline operations retain the established engine. This follows the layered
rejection principle in [GNU sed 4.9 regexp.c](https://github.com/mirror/sed/blob/v4.9/sed/regexp.c),
whose superset/DFA checks precede full regex search. No GNU DFA code is copied,
and no bytere or rg implementation changes. Both incremental rows qualify:
identifiers use 0.789–0.802 of B3 time and misses 0.735–0.744.

Two further implementation variants are rejected and separately recoverable:

- Writing pattern bytes and separators separately through the existing
  BlockWriter removes a temporary record allocation but costs 3.14/3.56% on
  identifiers and 4.96/5.36% on misses. The second miss window exceeds 5%.
  Restore coalesced records; no small cost from this rejected phase is adopted.
- Sixteen-byte slicing, motivated by
  [crc32fast's portable baseline](https://github.com/srijs/rust-crc32fast/blob/master/src/baseline.rs),
  keeps scalar CRC fused with compressed expansion but enlarges the tables to
  16 KiB. Its first stored window is stable and regresses 52–62%; second-window
  observations regress 56% while reference dispersion also fails. Only three
  of nine rows qualify. Wider slicing is not adopted. The independent bitwise
  tests now include 32 offsets and additional 16/32/64-byte boundaries.

The Rust [table definition](https://github.com/srijs/rust-crc32fast/blob/master/src/table.rs)
is a contiguous static array, unlike MoonBit's nested heap arrays. This motivates
a separate controlled layout trial at the preceding eight-byte width and 8 KiB
payload size, keeping the original fused expansion loop. These moving Rust
sources were inspected on 2026-10-31 and are research references, not immutable
oracles. The flat eight-table phase completes all nine rows, with only three
qualifying. Stored observations use 0.859–0.985 of B3 time, but both stored
rows fail dispersion; dynamic and member rows also fail stability, including
12.36% reference drift for zcat members. This does not qualify a layout benefit.
Restore B3's nested eight-table implementation and preserve both CRC experiments
separately. Retain the expanded correctness assertions. No new codec artifact
is adopted, and its earlier failed cumulative gate remains unchanged.

Final local correctness passes 1,749 release-Wasm tests and 2,260 functional
checks, with 21 platform skips and zero failures. The 652 reviewed finite
definitions join applicable receipts; catalog gaps remain. Strict checking,
architecture validation of 26 strategies and unchanged generated interfaces
pass. Artifact read-back verifies all 80 commands: only sed differs from B3,
and all codec artifacts equal their retained B3 state. Cumulatively five
commands still differ from original `55de9ec`, with 75 unchanged; that includes
the previous experimental codec. Cumulative timing in this batch selects sed
only, rather than retrying unchanged failed codec artifacts.

The cumulative sed panel qualifies both rows in both windows. Identifiers take
312.6–315.8 ms versus 6.137–6.144 s, ratios 0.05093–0.05140 (about 19.5 times
faster). Misses take 258.9–260.1 ms versus 6.085–6.123 s, ratios
0.04229–0.04275 (about 23.5 times faster). Candidate drift is 1.04%/0.46% and
all dispersion gates pass. Locally adopt the byte prefilter on top of the
preceding sed changes. This does not establish general-script throughput,
resource, full protection, formal timing, CI or published-coordinate acceptance.

The final native sed comparison completes both rows with intact artifacts, but
both fail dispersion. Identifiers observe 4.54–4.91 times native time and
misses 3.87–4.07. These remain unqualified observations; they do not establish
native parity or replace the passing original-Wasm comparison.

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
- The genuine CPython JSON-module pair initially exposed default-versus-minimal
  diff alignment: both scripts reconstructed the complete right file, but
  default GNU selected different anchors. The final 2026-10-31 correction
  applies the sparse repeated-anchor discard rule before Myers search.
  Default GNU output now agrees on that pair and 160 bounded independent
  normal/unified/context controls; small-input reconstruction/minimality tests
  remain. No input-specific dispatch, output normalization, GNU `--minimal`
  substitution or general performance/parity claim is introduced.
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
At that repair stage, the resource `heldout` name was retained only as a legacy
alias for `mixed-synthetic`; it had no blind-holdout status. The separate
natural-corpus, transport, option, host and resource matrices then still required
execution. The 2026-10-31 genuine-source replacement and final cleanup above
supersede those active inventories and remove that alias. Neither the historical
repair nor removal establishes general performance acceptance or broadens
supported command behavior. Preserve failed/noisy and historical evidence.

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
