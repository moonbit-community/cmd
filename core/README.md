# cli/core

Shared runtime packages used by the independently published command modules.
Version **0.6.0** adds a package-version argument to the public gzip runner,
standardizes checksum help/version output, and exposes standalone metadata
options in the shared command catalog. Version **0.5.0** added checked 64-bit TZif/POSIX timezone
conversion and a public-AST jq string-slice adapter, using released MoonJQ 0.2.0.
It retains the shared incremental MD5/SHA-1/SHA-512, C-byte regular-expression
adaptation and gzip stream codecs. Earlier command packages continue to use
their published core-compatible versions.

The unpublished workspace candidate targets **0.8.0**. Its line scanner
reuses a 64 KiB read buffer and searches only unconsumed bytes.
Only a record spanning reads needs accumulation; returned lines own their bytes.
The comm, cut, head, join, jq, nl, paste, sed, sort, uniq and xxd candidates select
this core coordinate for that implementation.
Cp selects the same coordinate for reusable 64 KiB new-file copying. Mv also
selects core 0.8.0, but moves entries with rename and has no copy-and-delete
fallback.

`gzipops.encode` accepts an optional `level` argument, defaulting to six, for
the private pure MoonBit 32 KiB LZ and stored/fixed/dynamic Huffman encoder.
Levels one through nine control search effort; existing callers retain the
default. Input is processed in 64 KiB chunks with bounded history.
`gzipops.decode_reader` streams gzip envelopes and DEFLATE through 64 KiB
input/output buffers and bounded Huffman tables. The output buffer also retains
the last 32 KiB needed for backreferences, avoiding a separate history copy. Existing
`decode(Bytes, ...)` callers retain their supplied bytes. The G1 report records
GNU interoperability and selected size results; performance acceptance remains
pending. Only changed command packages select this new core coordinate.

The same candidate parses C-byte BRE/ERE patterns once in `bytere`. `find`
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
See the [development report](../docs/reports/2026-10-24-s-matcher-sed.md).

Published **0.7.0** uses async **0.22.5**.
It added public `EmptyReplyFailure`, `PartialBodyFailure`, `ReceiveFailure` and
`RewindFailure` classifications,
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
verification; full HTTP parity is not claimed. Candidate
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
installed host implementation, so the candidate `mv` retains a Windows Wasm
link-rename boundary until that host and its link/referent behavior are verified.
No host program or native stub implements a command workaround.
