# ADR-0003: Streams, Ownership and Bounded Search

Status: Accepted
Date: 2026-09-05
Updated: 2026-10-30

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

## 0.9.0 release candidate

The 2026-10-30 candidate selects `cli/core@0.9.0` because the current source
changes public APIs from published 0.8.2. Catalog types and functions move from
`cli` to `contracts`; checksum and gzip command entrypoints move to
`checksum/cli` and `gzipops/cli`, leaving algorithms and codecs in their parent
packages. Netops fetch wrappers, process I/O forwarding wrappers, redundant
platform probes and `cli.warn_stdin_wait` are removed. Callers use the shared
transfer API or the released async filesystem/process APIs directly.

`platform.is_terminal` and `terminal_output_enabled` become synchronous;
automatic terminal detection remains unavailable. `LineScanner` now wraps
`RecordReader`, changing its exposed storage fields while retaining `new` and
`next`. The [core migration table](../../core/README.md#090-release-candidate)
records the source replacements. The version boundary makes these ownership
and function-type changes explicit for downstream consumers.

The selected release contains 43 changed commands, including the first `rg`
release at 0.1.0, based on direct source changes or changed runtime-package
reachability. Thirty-six published commands retain their existing pins;
`timeout` remains local-only. Registry upload and exact-version MoonX acceptance
are pending. Earlier validation below retains its recorded scope and does not
establish acceptance of these candidate coordinates.

The C02 visibility, deprecation and `Session::finish` proposals remain unadopted.
The release version change does not add those API changes to the candidate.

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
| Private teddy_max_literals, Algorithm::hex_length and gzipops/cli.help | Real same-package consumers, no dependent callers and absent at these coordinates in published 0.8.2. An isolated visibility trial passed strict checking with all 80 command binaries identical. The visibility change remains deferred; the 0.9.0 candidate separately documents migration of old gzipops.help to gzipops/cli.help. |
| Deprecate platform.is_cross_device_error, native_separator and accepts_separator | First has no current caller; the others have only local test callers. All are published. Choose a compatibility policy before removal; local non-use cannot prove external non-use. |
| Make Session::finish synchronous | No async operation or shared callable contract requires async. Trial passed strict checking and 1,707 Wasm tests, but changes the published function type and sh/make/split binaries. Requires a deliberate core API revision and performance checks. |

Retain catalog validation, gzip decoding, cookie serialization, header lookup
and timezone decoding APIs with actual consumers. The audit covered eighteen
functions/constants with no dependent-package use, not every public field/type.
All C02 trial edits were restored. C03's document-growth issue is addressed by
this decision-focused layout and immutable history links.

## Validation status and history

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
