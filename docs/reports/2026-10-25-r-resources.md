# R streaming and resource candidates

Date: 2026-10-25. Source candidates: column/rev/tac 0.1.4, csplit 0.2.1,
split 0.1.3 and sort 0.2.3; diff also changes its internal record storage.
These R changes are not published.
Dependency versions remain unchanged. This report records implementation and
local evidence for [stage R / issue #32](https://github.com/moonbit-community/cmd/issues/32),
before its three-platform PR and coverage checks.

## Implementation

R1 reuses earlier work rather than introducing another scanner, codec or run
engine. Gzip's incremental codec comes from
[PR #47](https://github.com/moonbit-community/cmd/pull/47); the shared matcher and
streaming grep come from [PR #49](https://github.com/moonbit-community/cmd/pull/49).
The shared scanner, incremental strings and prepared-key external sort from
[PR #50](https://github.com/moonbit-community/cmd/pull/50) retain their existing
contracts. The scanner retains its unread tail instead of copying it for every
record. Strings retains only the unqualified prefix shorter than its selected
minimum, then streams the remainder of a qualified run. The
[stream observations](2026-10-24-stream-hotpaths.md) preserve the
earlier development measurements. A 64 KiB block is a transfer size, not an
input-size limit.

R2 changes resource ownership and access paths:

| Command | Current resource contract |
| --- | --- |
| rev | Retains one scanner record and one reversed record buffer, with 64 KiB input/output buffers. Memory grows with the longest record. The fixed Linux C profile accepts ASCII/NUL and rejects a non-ASCII record before writing it, preserving earlier records. |
| split | Byte/line modes stream. Unknown-size total-partition modes spool input; line-byte mode spools its pending prefix, bounded by the selected byte ceiling. Ordinary outputs use one live file handle. Round robin retains O(visited pieces) names/state. |
| csplit | Consumes one immutable input snapshot and a disk index of 64-bit line boundaries. Two caches are at most 64 KiB each. Disk use is input bytes plus eight bytes per boundary, including the initial entry. Regex searches retain the current line; created fragment paths remain in memory for cleanup. |
| tac | Fixed separators use backward 64 KiB reads with bounded separator overlap, then copy selected ranges in blocks, including long records. Stdin/nonregular input is spooled. Regex mode also spools, then retains a contiguous input view for the existing matcher. Nominal regular-file extents are probed before backward reads; inconsistent pseudo files use the stream path. |
| column | Reads all operands once into a displayed-record snapshot, computes widths, then formats from that snapshot. Two disk files hold displayed bytes plus sixteen index bytes per retained record. Memory includes the longest record, table widths and bounded page caches. Wide grids choose at most 256 pages per cache: 16 MiB of record pages and 1 MiB of index pages, allocated on demand. |

Split round-robin filters intentionally retain one live pipe and shell task
per visited piece, plus filter-owned children and buffers. This preserves the
existing live-input behavior and is not a constant-resource mode. Named regular
file reads in split/tac do not promise a snapshot under concurrent mutation.
Csplit numeric pattern/offset parsing and individual regex-line indices retain
signed 32-bit limits. Tac regex retains O(input) memory and signed 32-bit matcher
indices; a paged/seekable matcher is the condition for lifting that limitation.

R3 adds `-S/--buffer-size`, repeated `-T/--temporary-directory` and
`--batch-size`. The default accounted sorting-data budget is 64 MiB; merge
fan-in is at most sixteen. Accounting includes payload/key bytes, entry/key
slots, sequence IDs and reserved merge buffers. Active or oversized records,
retained unique keys and allocator/GC overhead remain additional storage, so
this is not an RSS limit. A single oversized record is accepted. Run generation
and heap merging preserve stable ordering, first unique representatives and
prepared random keys across merge rounds. Selected temporary parents remain
untouched except for invocation-owned child paths. The sixteen-input fan-in
bounds simultaneous merge inputs, not the total count of temporary runs;
run/file counts grow with input size and the selected budget. `0%` selects the minimum
budget; nonzero percentages reject before input/output effects because released
public APIs do not expose physical-memory capacity. No guessed capacity or host
helper substitutes for that API.

Diff now borrows line `BytesView` slices and reuses unchanged comparison keys
instead of copying every input record. Comparison classes and edit reconstruction
retain the earlier O(N+M) auxiliary-space design for N/M input records. Both
complete inputs, record descriptors, transformed keys where necessary and edit
results remain resident;
the complete command is not constant-memory. The resource fixture uses 4096-byte
diff records and changes one byte, avoiding a quadratic edit workload without
claiming a worst-case time bound.

The current support authority is [the compatibility record](../compatibility.md)
and [ADR-0003](../adr/0003-streams.md#r-streaming-and-temporary-storage-contracts).
Command READMEs/help, catalog capabilities, current case expectations and candidate
coordinates follow these changes. Frozen published expectations are preserved.

## Correctness and failure effects

All-target checking and Native/Wasm release builds pass locally. Focused package
results are:

| Package | Native passed | Wasm passed |
| --- | ---: | ---: |
| rev | 5 | 5 |
| tac | 8 | 8 |
| split | 8 | 8 |
| csplit | 6 | 6 |
| column | 12 | 12 |
| sort | 25 | 25 |
| diff | 12 | 12 |
| Shared catalog | 8 | 8 |

The integrated paired selection records 943 passing report rows across contracts,
scenarios and backend comparisons, plus two explicit Windows-only case exclusions
on this macOS host. Exclusions are not passing observations, and row counts do not
establish coverage completeness. These are local correctness results, not
independent GNU parity or a statistical speed verdict. Package/build
logs are under `/private/tmp/cmd-r-local-validation-20261025/`; paired evidence is
under `test-reports/r-paired-20261025/`.

Policy tests deny temporary writes for column/csplit/tac and exercise real sort
spilling under a read-only host policy. Denials fail without sorted/formatted
stdout or csplit fragments; the existing small in-memory sort path remains
allowed. Temporary directories use exclusive creation and owner-only files
where supported. Cleanup removes only invocation-owned paths.

Focused regressions cover sort temporary-parent failure, truncated run records,
partial temporary-entry writes and named merge output before source spooling;
rev/tac/column output failures retain the actual prefix without replaying failed
buffered writes. Csplit input failure and observed cancellation remove its owned
snapshot/index directory before returning, with no fragments. The cancellation
case waits until input bytes and the index really exist before canceling.
Input-spool failure in tac emits no output for that operand; column preserves
completed records after an input failure and continues later files. Csplit's
existing `-k` contract preserves completed/partial fragments after splitting has
begun; without `-k`, its own fragments are removed.

Near-2-GiB/4-GiB arithmetic and paged-index cases run without allocating giant
in-memory fixtures. Tac also reads an actual sparse file beyond 4 GiB on POSIX;
Windows is explicitly excluded because the public API cannot mark that fixture
sparse, and the test must not allocate a physical 4 GiB file there.

A real full-filesystem `ENOSPC` event has not been observed. Injected partial
writes and policy/open failures are evidence for their own paths, not substitutes
for an `ENOSPC` observation. Runtime-observed cancellation can unwind and clean
up; SIGKILL, machine failure and unavailable recoverable-signal behavior carry
no unconditional cleanup guarantee.

## Resource observations

The final local direct-Wasm observer completes all fifty command/size rows.
All rows match expected status and named-file effects. Ordinary output bytes
agree with the reference; gzip agrees after decompression rather than requiring
the same compressed bitstream. All candidate rows leave zero owned temporary
entries. Diff returns its expected
status 1; the other commands return 0. Earlier partial or terminated runs are
not combined with this matrix. Measurements use macOS arm64 and the same release
Wasm launcher for each command. Displayed values are rounded; retained summaries
contain the original measurements.

| Profile | Workload | Completion and exact result |
| --- | --- | --- |
| records | All ten selected commands at 8/64/512 MiB; varying ASCII record keys, 80-byte records except diff's 4096 bytes | 30/30 exact comparisons pass |
| long | Independent 64 MiB single-record input; one unbroken ASCII token | 10/10 exact comparisons pass |
| heldout | Independent 8 MiB mixed 7/89/4097/65537/128-byte records; binary markers on byte profiles, ASCII rev/diff and text-mode grep | 10/10 exact comparisons pass |
| kernel RSS | Seven changed commands at 8/64/512 MiB, in separate completed direct-Wasm calls using macOS `/usr/bin/time -l` | 21/21 expected-status and cleanup checks pass; kernel peaks observed |

The records profile has these elapsed times and 512 MiB resource observations.
Temporary storage columns report sampled logical/allocated MiB and the maximum
sampled count of temporary files, excluding output fragments.

| Command | Wasm seconds, 8 / 64 / 512 MiB | Reference seconds, 512 MiB | First output seconds, 512 MiB | Sampled RSS MiB, 512 MiB | Sampled temporary MiB, logical / allocated | Temporary files |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| rev | 0.116 / 0.825 / 6.975 | 14.660 | 0.014 | 20.80 | 0.00 / 0.00 | 0 |
| strings | 0.127 / 0.881 / 7.226 | 7.186 | 0.012 | 26.39 | 0.00 / 0.00 | 0 |
| split | 0.022 / 0.056 / 0.316 | 0.123 | 0.110 | 23.91 | 0.00 / 0.00 | 0 |
| csplit | 0.334 / 2.515 / 19.862 | 0.653 | 19.627 | 23.66 | 563.20 / 564.44 | 2 |
| tac | 0.388 / 3.026 / 23.203 | 0.605 | 0.295 | 27.89 | 512.00 / 512.00 | 1 |
| column | 1.533 / 12.516 / 100.842 | 66.537 | 37.284 | 23.53 | 608.00 / 625.44 | 2 |
| sort | 0.308 / 4.501 / 44.175 | 3.617 | 34.830 | 34.67 | 1151.90 / 1168.34 | 32 |
| grep | 0.101 / 0.675 / 5.918 | 0.574 | 0.028 | 33.03 | 0.00 / 0.00 | 0 |
| gzip | 0.330 / 2.601 / 21.113 | 1.826 | 0.008 | 25.17 | 0.00 / 0.00 | 0 |
| diff | 0.136 / 1.034 / 8.024 | 0.254 | 8.017 | 1569.42 | 0.00 / 0.00 | 0 |

For the separate 64 MiB single-record profile:

| Command | Wasm / reference seconds | First output seconds | Sampled RSS MiB | Sampled allocated temporary MiB |
| --- | ---: | ---: | ---: | ---: |
| rev | 1.261 / 1.795 | 1.223 | 274.94 | 0.00 |
| strings | 0.415 / 0.932 | 0.011 | 25.34 | 0.00 |
| split | 0.057 / 0.016 | unobserved | 0.19 | 0.00 |
| csplit | 2.652 / 0.061 | 2.630 | 407.11 | 64.07 |
| tac | 2.662 / 0.066 | 2.619 | 27.23 | 64.00 |
| column | 7.397 / 0.768 | 7.358 | 627.97 | 64.94 |
| sort | 0.301 / 0.042 | 0.264 | 144.16 | 0.00 |
| grep | 0.085 / 0.426 | 0.050 | 0.19 | 0.00 |
| gzip | 1.136 / 0.097 | 0.008 | 24.33 | 0.00 |
| diff | 3.646 / 0.302 | 3.575 | 1371.47 | 0.00 |

Long records expose the retained record/matcher costs in rev, csplit, column
and diff; their small-record RSS observations must not be generalized to this
case. A short process may finish between samples: a 0.19 MiB RSS lower bound
does not represent its peak, and unobserved named-file first output does not
mean that output was absent. The held-out profile's complete per-command timing,
memory, disk and exact comparisons remain in its retained summary.

Separate completed macOS kernel peak-RSS calls report these MiB values. They
cover the seven changed commands on fixed records, not the long/held-out inputs;
those two profiles retain sampled lower bounds. Strings, grep and gzip have
sampled resource rows above, without new kernel peak rows in this supplement.

| Command | 8 MiB input | 64 MiB input | 512 MiB input |
| --- | ---: | ---: | ---: |
| split | 23.28 | 23.89 | 24.38 |
| csplit | 21.73 | 23.34 | 23.98 |
| tac | 25.73 | 27.44 | 28.06 |
| column | 22.55 | 23.80 | 23.80 |
| sort | 32.84 | 34.63 | 34.95 |
| rev | 18.77 | 20.23 | 20.70 |
| diff | 48.75 | 218.80 | 1560.36 |

The ten commands are rev, strings, split, csplit, tac, column, sort, grep, gzip
and diff. The observer compares exact bytes, status and named-file effects;
gzip is decoded by the fixed native observer after timing. It records first
observed output, elapsed time, sampled child RSS, temporary logical/allocated
disk and residual owned entries. RSS/disk samples are lower bounds; they are
not replaced with guessed peaks. Separate kernel peak-RSS calls retain their
own workload and result identity rather than being presented as the same timed
sample. First-output timing includes process launch and pipe observation;
named-file first output is polled. Input generation and output comparison are
outside the timer.

Raw final reports use `/private/tmp/cmd-r-final-{records,long,heldout,kernel-rss}-20261025/`.
Compact [records](2026-10-25-r-resources/records/summary.jsonl),
[long-record](2026-10-25-r-resources/long/summary.jsonl) and
[held-out](2026-10-25-r-resources/heldout/summary.jsonl) summaries retain every
row, with their adjacent measurement metadata. The separate
[kernel-RSS summary](2026-10-25-r-resources/kernel-rss/summary.jsonl) records the
twenty-one peak observations. The Linux CI resource step repeats all three
functional/resource profiles after the sealed oracle fixture steps and adds
twenty-one separate peak-RSS calls for the seven changed commands through
`--kernel-rss linux`. That Linux path is implemented but remains unverified
until CI runs. Its exported native reference uses host system
libraries; that observation does not replace sealed-container upstream parity.
The repository observer limits each direct invocation to fifteen minutes and
the CI resource step to 120 minutes. Failed profiles remain failures while later
profiles run;
an overall timeout can retain an incomplete matrix.

A separate 8 MiB wide-grid column fixture improved from 23.6835 seconds to
1.82309 seconds after adapting the bounded index/data page caches to interleaved
grid cursors. Complete output bytes agree on that same fixture. This is a
development comparison, not the required statistical 1.5x performance gate.

## Remaining delivery

Three-platform PR checks and `coverage-audit` are pending. Issue #32 can close
after the selected functional stage passes its authorized integration gates;
this report does not record that closure in advance. These R candidates have
not been published, and the 2026-10-25 published baseline remains separate.

The full 79-command/core hotspot review, complete benchmark matrix and formal
direct-Wasm 1.5x acceptance remain unfinished. Final coordinated publication and
exact published-consumer acceptance are separate later work. No overall
performance target, unrestricted GNU compatibility or new registry release is
claimed by these resource observations.
