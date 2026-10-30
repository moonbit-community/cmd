# cli/core

Shared runtime packages used by the independently published command modules.

## 0.9.0 API changes

Version **0.9.0** introduces the source API migrations below. Commands select
their core dependency independently; upgrading core does not require updating
an unaffected command. Accepted coordinates and release evidence are recorded
in the repository's release inventory and changelog.

The version boundary makes the package ownership changes explicit for consumers
of published `0.8.2`:

| Previous API | 0.9.0 migration |
| --- | --- |
| `cli` catalog functions, capability and command-contract types | Import `cli/core/contracts`; `cli/core/cli` retains argument parsing and diagnostics. |
| `checksum.run`, `checksum.run_cksum` | Import `cli/core/checksum/cli`; `checksum` owns digest algorithms and `digest_reader`. |
| `gzipops.help`, `gzipops.run` | Import `cli/core/gzipops/cli`; codec entrypoints remain in `gzipops`. |
| `netops.fetch*`, `FetchOptions`, `FeedbackMode`, `NetOpError` | Use `transfer`, `transfer_options` and typed `TransferError`; callers own command feedback and exit-status policy. |
| `process.pipe`, `redirect_from_file`, `redirect_to_file` | Use the released `moonbitlang/async/process` APIs directly. |
| Redundant platform capability probes and stream-specific terminal wrappers | Use the applicable released filesystem/process APIs and `platform.is_terminal(StandardStream)`. `is_terminal` and `terminal_output_enabled` are synchronous; terminal discovery remains unavailable. |
| Exposed `LineScanner` storage fields | Construct with `LineScanner::new` and consume with `next`; the scanner now wraps `RecordReader`. |

The deprecated `cli.warn_stdin_wait` warning helper is also removed. These source
breaks separate command policy from reusable mechanisms and remove forwarding
APIs with no independent contract. Command-specific algorithms continue to own
matching, formatting, ordering and resource policies.

## Shared mechanisms

| Package/API | Contract | Current consumers |
| --- | --- | --- |
| `contracts` | Capability types and command catalog, separate from argument parsing. | Workspace validation runner. |
| `fswalk` | Directory-handle ownership and explicit kind/size observations; no implicit pruning, sorting or extra metadata queries. | rg, find, tree and grep. |
| `checksum/cli`, `gzipops/cli` | Command record formats, options, diagnostics and execution. Parent packages own algorithms and streams. | The five checksum commands and gzip/gunzip/zcat. |
| `bytesearch` | Allocation-free byte scans/counts and reusable literal filters over explicit ranges; callers keep pattern storage unchanged while a finder uses it. | rg search/regex/line buffers, wc line counting; `stream.count_byte` retains its immutable-view entrypoint. |
| `stream.RecordReader` / `RecordBatch` | At most 1 MiB per read; synchronous record visitation over immutable storage. Retained views keep their backing block alive. | cut, uniq, rev, column and other bulk readers. |
| `stream.LineScanner` | An owned-record facade over the same parser, retaining 64 KiB reads. Use it when records survive the current batch. | sort, join, comm, head, jq, nl, paste and existing scanner clients. |
| `stream.BlockWriter` | Fixed output capacity; private storage cannot be reused during an awaited write. Failure/cancellation consumes the pending queue and poisons further writes; a deferred flush cannot replay a partial prefix. | rg stdout, column snapshot streams, nl, paste and comm. |
| `tempio.Directory` | Exclusive creation, invocation-owned cleanup, idempotent close after success. Close files before the directory. Cleanup failures propagate; each command chooses error precedence. | tac, column and sort. |
| `tempio.copy_range` | Exact positional extent copy with caller-owned scratch storage, 64-bit file offsets and completion before buffer reuse. A short extent is an error. | tac reverse output. |

`BlockWriter.write_slice` borrows a fixed-array span until the call returns;
callers must not mutate it during that interval. Small writes are copied into
private storage, large writes bypass it after draining. `flush` does not close
the destination. These APIs do not make line length or process RSS bounded.

Keep fused wc counts, rg/grep prefilters, cut ranges, rev reversal, tac reverse
blocks, column page caches and sort runs specialized. Shared ownership must not
introduce an asynchronous call per byte/record into an existing synchronous
fast path. rg and core regex engines retain their distinct matching semantics.

The [stream ADR](../docs/adr/0003-streams.md#input-and-output-mechanisms)
records adoption and limits. The executable [protection registry](../tests/benchmark/protection.json)
connects shared boundaries to command workloads; see its [runner instructions](../tests/benchmark/PROTECTION.md).

The [internal consolidation decision](../docs/adr/0003-streams.md#package-ownership)
records source API breaks, consumer migrations and retained specializations.

## Earlier versions and runtime mechanisms

Version **0.6.0** adds a package-version argument to the public gzip runner,
standardizes checksum help/version output, and exposes standalone metadata
options in the shared command catalog. Version **0.5.0** added checked 64-bit TZif/POSIX timezone
conversion and a public-AST jq string-slice adapter, using released MoonJQ 0.2.0.
It retains the shared incremental MD5/SHA-1/SHA-512, C-byte regular-expression
adaptation and gzip stream codecs. Earlier command packages continue to use
their published core-compatible versions.

Version **0.8.0** provides the stream and matcher implementation below. Its
line scanner reuses a 64 KiB read buffer and searches only unconsumed bytes.
Only a record spanning reads needs accumulation; returned lines own their bytes.
The comm, cut, head, join, jq, nl, paste, sed, sort, uniq and xxd modules select
this core coordinate for that implementation.
Cp selects the same coordinate for reusable 64 KiB new-file copying. Mv also
selects core 0.8.0, but moves entries with rename and has no copy-and-delete
fallback.

Version **0.8.1** updates the public command catalog for the R resource work:
column, csplit and tac declare temporary-file writes, and sort lists its
buffer-size, temporary-directory and batch-size options. Runtime APIs and
command dependency coordinates remain unchanged.

The earlier **0.8.2** candidate introduced the restricted `rg` command contract and four
performance waves. `stream.RecordReader` returns batches with synchronous record
iteration and immutable byte views; only split records are assembled. Reads are
at most 1 MiB, and retained storage follows a block plus the longest record.
`stream.flush_buffer` consumes queued bytes before writing, preventing a failed
partial write from being retried during deferred cleanup. The original
`LineScanner` API remains available. `RecordBatch.each_while` visits views without
per-record result objects and pauses after a consumed record for output flushing.
`stream.count_byte` counts bytes in offset views using bounded word loads.

Version **0.9.0** adds
`bytere.RecordMatcher.count_records(BytesView, Byte)`. It returns an optional
pair `(matching_records, complete_records)` for separator-terminated records;
an incomplete tail is left to the caller. A declined or exhausted DFA returns
`None`, requiring ordinary matching of the entire block. It shares the existing
matcher limits and does not apply whole-word or whole-record filters. Published
acceptance results are recorded in the repository changelog.

Version **0.9.0** also introduces `fsops/mode.parse_octal_mode(String)` for
chmod and mkdir. It accepts octal digits with an optional `0o`/`0O` prefix,
rejects empty or non-octal input, and limits permissions to `0o7777`.
Symbolic-mode interpretation remains command-specific.

`bytere.Pattern.record_matcher()` creates consumer-owned boolean search state.
Its `required_literal()` exposes a conservative rejection filter; an empty
literal provides no rejection guarantee. The byte DFA is initialized on demand,
uses a flat transition table and avoids decoding ordinary byte records. The
cache allows at most 256 subsets for programs of at most 256 instructions.
Word/whole filters and cache exhaustion use span search. Assertion-free,
reference-free span programs of at most 256 instructions precompute epsilon
closures and reuse integer worklists. Other span searches and captured searches
retain the existing engines and register rules. Scratch state belongs to the
record matcher; a span plan has at most 256 squared closure entries.
`RecordMatcher.search_bytes()` borrows a record and exposes resumed byte spans.
The package-level `search_bytes()` shares fallback text conversion across
multiple patterns. Eligible unfiltered spans use a reverse DFA to mark feasible
starts, followed by an anchored forward DFA for the longest endpoint. Each DFA
has at most 256 states; exhaustion reruns the current query through the span
engine. Start bitmaps retain about one bit per input byte per eligible pattern.
Word/whole filters, assertions, references and larger programs retain their
respective fallback paths. Literal byte searches avoid conversion as well.
For long records, forward endpoint queries skip proven self-loop transitions
and reuse a proven suffix within that immutable record. This does not provide
a general linear-time enumeration bound. `LiteralSet` compiles nonempty literal
sets within 4096 total bytes: two-byte shifts when all literals have at least
three bytes, otherwise a byte-class Aho-Corasick table with at most 1024 states.
`find_span` selects the leftmost-longest match; `find_any` returns an occurrence
without resolving longest ties. Grep uses the latter only for record counting.
Earlier source notes recorded cut/uniq/wc 0.2.3 and grep 0.3.1, alongside rg,
as unpublished candidates selecting that stage of the core. Those descriptions
retain their historical scope. Current adoption and limits are in
[the stream ADR](../docs/adr/0003-streams.md#search-ownership-and-execution).

`gzipops.encode` accepts an optional `level` argument, defaulting to six, for
the private pure MoonBit 32 KiB LZ and stored/fixed/dynamic Huffman encoder.
Levels one through nine control search effort; existing callers retain the
default. Input is processed in 64 KiB chunks with bounded history.
`gzipops.decode_reader` streams gzip envelopes and DEFLATE through 64 KiB
input/output buffers and bounded Huffman tables. The output buffer also retains
the last 32 KiB needed for backreferences, avoiding a separate history copy. Existing
`decode(Bytes, ...)` callers retain their supplied bytes. The G1 report records
GNU interoperability and selected size results; performance acceptance remains
pending. Command modules retain their declared core coordinates.

Core 0.8.0 parses C-byte BRE/ERE patterns once in `bytere`. `find`
retains `Hit` captures; `find_span` returns offsets without allocating capture
strings and omits capture state when no backreference can observe it. Ordinary
expressions use ordered Thompson threads. Capturing searches retain distinct
tag states; backreferences use an explicit stack and can require exponential
resources. The optional `grep_syntax` selects GNU grep's literal malformed-ERE
interval and unmatched-right-parenthesis rules; the default retains sed's
stricter grammar. `ignore_case` expands ASCII literals/classes before class
negation and compares backreferences without changing captured output bytes.
No matching-step limit is imposed. Repeated nullable captures use GNU candidate
selection: candidate spans determine the endpoint, followed by capture-register
restoration. Counted repeats, nested captures and multiple references are covered
by independent GNU comparisons. `is_match` retains candidate pruning without
restoring output registers, as GNU csplit and sed regex addresses do.
See the [development summary](../CHANGELOG.md#2026-10-24).

Core 0.8.0 retains async **0.22.5** and the transfer profile introduced in
version **0.7.0**, including public `EmptyReplyFailure`, `PartialBodyFailure`,
`ReceiveFailure` and `RewindFailure` classifications,
`OutputStarted` path/offset observations, and `resume_skip_existing` for callers
that retain an already delivered prefix. Public `TransferProfile` defaults to
`StrictProfile`; command callers select `CurlProfile` or `WgetProfile` for the
fixed oracle's differing EOF and output behavior. `TransferFailureContext` records the
transfer phase, known response framing, bytes exposed by the reader and bytes
from completed output writes. A failed write marks its additional effects as
uncertain because the public writer cannot report a partially completed write.
The pure MoonBit HTTP/1 adapter uses a fresh public client's passthrough mode
after connection/TLS/proxy establishment. It completes origin request writes
before parsing headers, distinguishes `Request` from `ResponseHeaders`, detects
an empty reply and delivers chunk payload before later framing validation.
Proxy CONNECT remains on async's high-level connection path. Ordinary repeated
request-header option semantics remain project work; no new byte or list API
is required to implement them. Protocol lines are bounded to 64 KiB, cumulative
headers to 1 MiB, fields to 1024 per block, interim responses to 128 and trailer
fields to 1024, with explicit rejection regressions.
The command profiles also distinguish request-target handling: curl rejects
raw ASCII space/TAB/CR/LF/DEL in initial paths and queries before connecting,
while Wget percent-encodes them. Encoded bytes remain encoded. Redirect spaces
use curl's path `%20`/query `+` policy or Wget's `%20` policy; TAB uses `%09`.
Final Set-Cookie fields retain their names, values and order for response
observers, separately from parsed cookie storage and with HTTP optional
whitespace normalized. Both commands ignore fields without `=`. Nonnumeric
Max-Age deletes the matching curl cookie but leaves Wget's old cookie intact;
positive decimal overflow retains curl's replacement under its 400-day cap,
whereas Wget expires the matching cookie for numeric overflow below 32 digits.
Cookie ordering is profile-specific; the shared transfer documentation records
the ordering and expiry bounds without claiming cookie-jar byte parity.
Ordinary curl file output opens on first payload or successful completion and uses a
4096-byte buffer. A network failure remains primary if flushing its pending
tail also fails; the context still records uncertain write effects. An earlier
file write failure remains an output failure. Stdout buffering is outside this
calibrated file profile. Valid Content-Disposition names on 2xx/3xx responses in
`CurlProfile` instead create exclusively before body delivery, preserving an existing selected path
on failure. The curl command resets an opened regular file before an accepted
retry, retains its selected filename and applies requested cleanup only after
final failure. Path-based reset does not guarantee retained descriptor/inode
identity under pathname replacement; see the [transfer profile](netops/README.md).
Both command profiles accept EOF after complete 200
status and unfinished headers, retaining already parsed framing checks. Wget
also accepts EOF in chunk payload or trailers, but rejects missing chunk-size
or completed-chunk separators. Its 416 handling does not open transfer output
regardless of Range metadata or resume state; command-level aggregate-file
initialization remains separate. A complete known-length 200 shorter than an existing
resume prefix preserves it. These command profiles leave strict default behavior intact.
Curl redirects that must replay already uploaded stdin report `RewindFailure`
in the request phase; a separate retry-all attempt can read the now-empty stdin.
Header and chunk-edge contracts require fresh execution and fixed-oracle
verification; full HTTP parity is not claimed.
Native/Wasm, fixed-oracle and published-consumer acceptance requires separate
evidence in the [support record](../docs/compatibility.md).

This module is published as `cli/core` and is an implementation dependency for
`cli/<command>` modules. The portable filesystem layer exposes file-kind and
regular-file-size reads, atime/mtime/ctime timestamps, access checks, and
symbolic-link creation on Native/Wasm. It also centralizes nanosecond comparison,
age buckets, update/backup decisions, and preflighted copy traversal. Permission
reads, arbitrary timestamp setters, hard links, readlink, special-file creation,
remain unavailable in both the historical async 0.22.4 baseline and the current
async 0.22.5 dependency. POSIX EXDEV classification uses the
actual host platform; it does not provide metadata-preserving cross-device
copying. Existing-file copy overwrite is rejected, and new-file copying must
explicitly select `--no-preserve=mode`.

Async 0.22.5 repairs Native Windows rename of symlinks/junctions. Wasm uses the
installed host implementation, so `mv` retains a Windows Wasm
link-rename boundary until that host and its link/referent behavior are verified.
No host program or native stub implements a command workaround.
