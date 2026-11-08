# Streams and Record Storage

## Read once, process available records synchronously

[RecordReader](../../core/stream/records.mbt) requests up to 1 MiB of immutable
bytes, finds complete records and returns a batch. Records wholly within a
chunk are views; a record spanning reads uses an owned accumulation buffer.
`RecordBatch::each_while` continues synchronously until exhaustion or an output
boundary. [LineScanner](../../core/stream/stream.mbt) uses the same mechanism
with 64 KiB reads and an owned-record interface.

This removes per-record I/O scheduling and unnecessary copies. Retaining a small
view can retain its whole backing chunk, and the longest record can still grow
without a fixed bound. EOF emits a nonempty unterminated tail once; a read error
does not manufacture a final record. Borrowed mutable spans have a shorter
lifetime than these immutable views and cannot survive an async refill.

## Output admission and failure

[BlockWriter](../../core/stream/output.mbt) owns a fixed buffer, in-flight state
and a failed state. A synchronous admission either accepts the complete event
or changes nothing. The command retains a declined record until the async
write completes, then updates its own numbering, uniqueness or selection state.
Draining consumes pending bytes before writing, so cleanup cannot replay a
partially accepted write. Commands still choose when output must become visible.

Public span admission validates the range and active/failed state before any
buffer mutation. Its async continuation enters the slow path without an
intervening suspension, so that private path uses the established checks.
Actual awaited writes still set active/failed state and retain cancellation
cleanup; this does not treat changing I/O state as a static precondition.

Od and hexdump retain separate input loops and synchronously feed views of their
read buffers into command-owned row state. The rendered string owns its output
before the next awaited write or refill. Xxd and transfer output copy directly
into owned `Bytes` when ownership is needed, without an intermediate array copy.
Read bounds follow the allocated buffer's length. These source changes do not
by themselves establish a measured speedup or reduced peak RSS.

| Consumer | Work kept synchronous | Boundary that remains command-owned |
| --- | --- | --- |
| [nl](../../commands/nl/numbering.mbt) | Cached record admission and coalesced number/record output | Sections, blank groups, number advancement and empty-input allocation |
| [sed](../../commands/sed/execute.mbt) | Cached records, address-free selection and coalesced output | Flush before external input, completion or a later script error; n/N and append ordering |
| [join](../../commands/join/output.mbt) | Complete joined-record output | Duplicate-key products, unpaired records and separators |
| [comm](../../commands/comm/merge.mbt) | Merge already available immutable records until I/O is needed | Ordering diagnostics, column selection and ownership across refills |
| [rg](search.md) / grep | Complete record or span admission | Match accounting, context, early stop and explicit line buffering |

Coalescing can allocate one extra record-sized buffer. Removing that allocation
is not automatically faster: the recorded separate-fragment sed trial regressed
and was restored. A future change must preserve the same visibility and failed-
write assertions and qualify both hit and miss workloads.

## Tail suffix retention

[TailWindow](../../commands/tail/window.mbt) stores immutable chunks in a deque,
with a start offset and delimiter count. Byte mode removes the excess prefix;
line mode also reserves a selected slot for an unfinished final record. Boundary
search starts from the side requiring fewer delimiter crossings, avoiding a
near-full rescan for a small suffix. Output visits retained spans without joining
them into another full copy.

Discarding a deque entry first clears its backing reference because vacated
slots otherwise retain storage. Payload follows the selected suffix plus at
most one partially retained backing chunk; a selected long line is unbounded.
Regular-file stdin cannot acquire a seek implementation through the current
public Reader interface. Keep named-file seeking distinct from streaming input.

The first repaired suffix loop passed correctness but regressed timing because
it scanned from the wrong end. Its replacement and the accepted small local
cost are recorded in [ADR-0003](../adr/0003-streams.md#known-limits-and-tradeoffs).
Use the `real-tail-*` rows and private window/lifetime regressions together.

## Indexed temporary storage

| Owner | Algorithm and storage | Important limit |
| --- | --- | --- |
| [csplit](../../commands/csplit/snapshot.mbt) | One data snapshot and signed 64-bit line offsets; synchronous newline/index-page encoding and cached record matching | Disk holds input plus eight bytes per boundary; bounded pages do not bound the longest regex record or cleanup paths |
| [column](../../commands/column/spool.mbt) | Snapshot displayed records once, retain widths and bounded data/index pages | Longest record and width state remain; field-plan caches are admitted only when their bounded cost is worthwhile |
| [tac](../../commands/tac/reverse_fixed.mbt) | Reverse fixed-separator scans in 64 KiB blocks with overlap; spool nonseekable input first | Regex reversal still retains contiguous input and has signed 32-bit matcher indices |
| [sort](ordering.md) | Accounted runs and bounded merge fan-in | Active oversized records and runtime storage remain outside the budget |
| [split](../../commands/split/) | Direct streaming where layout permits; owned spools for total-dependent or long-pending layouts | Round-robin path state and filter sessions grow with visited pieces |

Csplit caches both index and data pages, so complete cached records can be
tested without another read or string conversion. Negative offsets still need
the snapshot; GNU's retained-input architecture is not a replacement for that
contract. A cached fragment-copy trial passed its gate but showed too little
benefit to adopt. Revisit it only with a demonstrated copying bottleneck.

Temporary ownership and cleanup live in [core/tempio](../../core/tempio/).
Spool setup, output creation, completed pieces and failure cleanup have distinct
effects; a generic rollback policy would be incorrect. Csplit removes owned
pieces unless `-k`; split retains completed pieces. Close handles before removal
and preserve cleanup-only failures.

## Verification routes

Use `bounded-output`, `nl-record-output`, `sed-record-output`,
`csplit-page-processing`, `column-table-plans` and `tac-spool` in
[protection.json](../../tests/benchmark/protection.json). Test fragmented and
unterminated records, exact cache/page boundaries, producer waiting for output,
failed writes, later read errors and cancellation. Keep ordinary and longest-
record workloads separate; counted allocations do not establish peak RSS.
