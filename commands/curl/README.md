# curl

Pure-MoonBit curl 8.22 HTTP/HTTPS profile, version **0.2.3**. See the
[support record](../../docs/compatibility.md) for platform verification and
exact-version publication evidence.

Repeated literal `-b` values join with `; `, matching the pinned curl 8.22
request bytes. This differs from the earlier macOS curl 8.7 comparison.

The command streams HTTP/HTTPS responses to stdout or files and supports:

- `-s/-S`, `-f`, `-o`, `-O/-J`, `-L`, `-I`, repeated `-H`, and all documented
  HTTP methods through `-X` (`GET`, `HEAD`, `POST`, `PUT`, `DELETE`, `CONNECT`,
  `OPTIONS`, `TRACE`, and `PATCH`);
- ordered `-d`, `--data-raw`, `--data-binary`, and `--data-urlencode` values,
  including their documented `@file`, empty-value, and binary behavior;
- `-T` file/stdin uploads, multiple sequential URLs, retry controls, redirect
  limits, connect/total/inactivity timeouts, HTTP CONNECT proxies, proxy bypass,
  insecure TLS, and partial-output cleanup.
- `-u/--user user:password` Basic authentication; `-b/--cookie` literal cookie
  values or Netscape input jars, and `-c/--cookie-jar` output jars. A shared jar
  processes every response, including redirects, and matches domain, path,
  expiry and Secure attributes before sending cookies.

Redirect behavior distinguishes ordinary data from upload streams. An explicit
`-X` method remains explicit after a redirect; 301/302/303 can still discard a
`--data-*` body as curl does, while 307/308 and upload streams preserve their
body. Cross-origin redirects remove authorization headers.

The command rejects raw ASCII space, TAB, CR, LF and DEL in an
initial URL path or query with status 3 before connecting, leaving an existing
output file untouched. Already percent-encoded bytes remain encoded. For a
followed Location, a path space becomes `%20`, a query space becomes `+`, and
TAB becomes `%09` in either component. These are the calibrated URL cases;
they do not establish general browser URL normalization.

`--max-redirs -1` is unlimited; zero disables followed hops. Zero for
`--connect-timeout`, `--max-time`, and `--retry-max-time` selects the documented
disabled/default behavior, while `--idle-timeout` must be positive. Timer input
is bounded by the runtime millisecond range.

Network authorization belongs to the caller or host. The command does not
embed an allowlist.

The command returns status 18 for an incomplete fixed-length or
chunked response body, 52 for an EOF before any response bytes, and 56 for other
response-read failures. Connection
setup failures retain status 7. Bytes already written to stdout remain visible;
partial files remain unless `--remove-on-error` selects cleanup after the final
failed attempt. Ordinary `--retry` does not retry these body failures;
`--retry-all-errors` can retry
them. Once a retry is accepted, an already opened regular output file is reset
to empty before the next request, while stdout retains each emitted prefix.
An empty failed retry therefore leaves an empty file rather than the previous
attempt's prefix. Cleanup does not remove the file between retry attempts.
The pure MoonBit HTTP/1 adapter preserves chunk payload before checking its
following CRLF and distinguishes an empty reply from an incomplete header.
The calibrated EOF after a complete 200 status line accepts the complete
header fields and ignores the unfinished field; malformed complete fields and
incomplete status lines still fail.

Ordinary file output opens on the first payload or successful empty completion
and uses 4096-byte buffering. An initial failed empty body leaves an unopened
existing file untouched and does not create an absent file, including with
`--remove-on-error`. After a network error, a buffered tail is flushed if possible;
a secondary flush error
does not replace the earlier network error. The fixed Linux oracle consequently
returns 18 for `/dev/full` with an incomplete body below 4096 bytes, but 23 when
4096 bytes trigger a write failure first. Successful nonempty bodies whose final
flush fails return 23; successful empty bodies create an empty destination.

With `-O -J`, a valid Content-Disposition filename on a 2xx/3xx response selects
exclusive file creation before body delivery. An existing selected filename returns 23 and
remains untouched; a newly created file can remain empty after body failure.
The calibrated 404/500 responses ignore that filename and use ordinary lazy
URL-derived output; `-f` returns 22 without opening a transfer file.
Retries keep the first server-selected filename even if a later response changes
or omits Content-Disposition. `--remove-on-error` removes an opened selected
file only after the final failed attempt; a successful retry keeps its result.

Retry reset uses the released path-based file-open APIs. It does not prove that
the pathname still refers to the same descriptor or inode if another process
replaces it. Descriptor-based truncation and public file identity remain a
separate [filesystem boundary](https://github.com/moonbit-community/cmd/issues/10),
not a prerequisite for the implemented retry algorithm. These behaviors still
require current Native/Wasm command and fixed-oracle acceptance checks.

A redirect that must resend an already consumed stdin upload fails with status
65. A separate `--retry-all-errors` attempt can upload the now-empty stdin;
it does not replay the original bytes. File bodies remain reopenable.
With `-sS`, each failed transfer attempt still writes its error to stderr even
when a later retry succeeds with status 0. Plain `-s` suppresses those errors.
Fixed-length truncation reports the missing byte count using the structured
transfer context. HTTP status retries without `-f` do not invent a status-22
error diagnostic merely because the internal retry mechanism uses an error.

Request fields generated from literal or stored cookies receive the same header
validation as explicit fields. CR/LF in a Cookie value is rejected before any
request bytes are written, with status 2 and no transfer output file opened.

Malformed response Set-Cookie fields without `=` are ignored for cookie
storage without failing an otherwise complete body. A nonnumeric Max-Age deletes
the matching stored cookie in the curl profile. Positive decimal overflow instead
retains the new cookie under the profile's 400-day lifetime cap; lifetimes beyond
the cap round their capped expiry to the nearest minute. Outgoing cookies sort
by descending path, domain and name byte length, then newer creation first;
replacement preserves creation order. Repeated fields are processed in response
order. Header observations retain the final response's Set-Cookie
field names, values and order separately from parsed storage, with HTTP
optional whitespace normalized. Interim response cookies are not retained.
These corrections require fresh Native/Wasm and fixed-oracle acceptance; they
do not establish byte-for-byte cookie-jar serialization parity.

Requests default to `Accept-Encoding: identity` and preserve an explicitly
supplied header. Response content-coding bytes are written unchanged, so gzip
responses retain their encoded byte counts and framing checks. Automatic
decompression and `--compressed` are not supported.

Protocol metadata limits and supported response framing are documented in the
[shared transfer profile](../../core/netops/README.md). They are project support
choices and can be extended through the existing released transport APIs.

This remains a bounded HTTP transfer profile, not full curl compatibility.
Non-HTTP protocols, HTTP/2 negotiation, config files, non-Basic authentication,
interactive password prompts, exact native progress and diagnostic bytes,
and the rest of curl's option surface are not claimed. Cookie files use the
Netscape format; importing raw Set-Cookie header files, a public-suffix database,
IDNA, and curl's HTTP-localhost Secure-cookie exception are not implemented.
These are command implementation gaps, not limitations of async's public
cookie parser. Like curl, cookie-jar write failures do not change the transfer
exit status (verbose-mode warnings are not implemented).

The command supports a custom `-H 'Cookie: ...'` together with
matching stored cookies as two separate request fields, with stored cookies
first. This correction has been included since 0.2.1; historical 0.2.0 is unchanged. Literal `-b` cookies
can be combined with stored cookies and preserve curl's ordering. Explicit
custom Cookie headers and literal `-b` data are scoped to the initial origin,
matching curl 8.22. Jar cookies are selected again for the
destination.

## Standalone metadata

Standalone `--version` prints exactly `curl 0.2.3` followed by one
newline. Standalone `--help` starts with `Usage: curl`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
