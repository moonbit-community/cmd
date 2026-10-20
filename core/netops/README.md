# Internal network helpers

This package contains the shared HTTP streaming path for `curl` and `wget`.
It does not invoke a host network executable. Network access remains visible
to the configured network policy.

The `transfer` state machine parses HTTP/HTTPS URLs without using private
runtime APIs, resolves relative redirects according to RFC 3986, closes every
hop, detects loops, strips sensitive headers across origins, and streams both
request and response bodies. Connection setup, request writes, response
headers, and each response read have separate inactivity checks; a successful
chunk resets the phase timer, while an optional total deadline spans all
redirects. In the default `StrictProfile`, premature fixed-length or chunked EOF is a `PartialBodyFailure`;
other response-read failures are `ReceiveFailure`, distinct from connection
setup failures. An EOF before any response bytes is `EmptyReplyFailure`.
An incomplete header is recorded separately from body truncation, before output
creation. `CurlProfile` and `WgetProfile` accept the calibrated EOF after a
complete final 200 status line, retaining complete header fields and discarding
the unfinished field. Incomplete status lines and malformed complete fields
still fail. These candidate classifications require the fixed-oracle checks.

`WgetProfile` also accepts EOF while an announced chunk still has undelivered
payload, including zero payload bytes, or while reading trailers. EOF before a
chunk-size line or inside its payload CRLF remains an error. `StrictProfile`
and `CurlProfile` require complete chunk framing. These explicit command
policies reproduce the fixed curl 8.22.0/Wget 1.25.0 observations.

The private HTTP/1 wire adapter enters the released client's public passthrough
mode immediately after connection setup, retaining its TCP, TLS, proxy CONNECT
and trust configuration. Project code serializes requests and incrementally
parses response headers and fixed, chunked or close-delimited bodies. Chunk
payload is delivered before checking its following CRLF, so a malformed or
missing terminator cannot erase already delivered bytes. Proxy CONNECT setup
still uses the upstream client's header parser; exact proxy-handshake error
classification is separate project work. No private API or host fallback is used.
Before writing request bytes, the adapter validates the final persistent and
per-request fields, including generated Cookie fields. Invalid names and CR/LF
in values are rejected; literal cookie data cannot inject another header.

Request-target handling runs before connection for the initial URL.
`CurlProfile` rejects raw ASCII space, TAB, CR, LF and DEL in paths and queries;
the curl command reports status 3 and preserves existing output. `WgetProfile`
uses uppercase percent escapes for those bytes. Existing percent-encoded bytes
remain encoded. For followed Location values, curl encodes path spaces as
`%20` and query spaces as `+`; Wget uses `%20` in both. Both encode TAB as
`%09`. These calibrated cases do not imply general browser URL normalization.

`TransferError.context` records connection, request, response-header,
or response-body phase. Request completion and response parsing are separate
operations with unambiguous failure phases.
Body failures include framing (bodyless, fixed length,
chunked or close delimited), reader-delivered bytes and completed sink-write
bytes. Fixed-length framing carries the expected length. Discarded resume
prefixes count as received but not committed. If a write fails, the context
marks its outcome uncertain: the public Writer API does not report any bytes
written before that failing call, so the committed count is a lower bound in
that case. Immediate sink failures retain `OutputFailure`. If an earlier
network failure is followed by a failed buffered-tail flush, that earlier kind
remains primary and `write_outcome_uncertain` records the secondary write
failure; the completed-write count remains a lower bound.

`CurlProfile` defers ordinary file creation until the first payload or successful
empty completion and buffers file output in 4096-byte blocks. An initial failed
zero-byte body therefore leaves an unopened absent or existing destination
untouched, including with cleanup enabled. After a network error, an already
opened file receives any buffered tail if possible. A block write that fails before EOF is an output
failure; a final-tail failure does not replace an earlier network failure.
This calibrated file policy does not change stdout buffering. Other profiles
retain immediate file creation and writes.

For a `CurlProfile` file destination with Content-Disposition selection enabled,
a valid server filename on a 2xx/3xx response instead opens with exclusive creation before body
delivery. An existing selected path fails with `OutputFailure` without changing
it; a new selected file may remain empty after a body failure. `OutputStarted`
reports the opened path. Other response statuses ignore Content-Disposition and
use ordinary output selection; enabled HTTP failure policy rejects before opening
output. This rule does not change the strict or Wget profiles.

The curl command retains that actual path across attempts and disables further
Content-Disposition selection after opening it. Before an accepted retry, it
resets an opened regular file to empty; later changed or missing headers cannot
redirect output to another name. Curl passes per-transfer cleanup as false and
performs requested cleanup only after final failure, preserving a successful
retry's result. The shared `FileOutput.remove_on_error` option still controls
cleanup for its individual transfer; other callers retain that existing API
behavior. Ordinary initial empty failures must remain separate from empty
failures after a previous attempt opened and reset the file.

Reset uses released path-based open APIs. It cannot guarantee that a replaced
pathname still identifies the original descriptor or inode. Public handle-based
truncation and identity, plus path-replacement regressions, are the unlock
condition for that narrower [#10 boundary](https://github.com/moonbit-community/cmd/issues/10);
ordinary file retry is implemented without waiting for those APIs. Current
Native/Wasm command and fixed-oracle acceptance remains required.

Without a caller-supplied `Accept-Encoding`, requests explicitly use `identity`.
Caller-supplied values are preserved. The wire adapter does not decode content,
so output, failure counts, Content-Length and Range offsets
refer to encoded representation bytes. A gzip-coded response remains gzip
bytes even when its header was explicitly requested; this API does not add
automatic decompression or a compression option.

Protocol metadata is bounded to 65536 bytes per CRLF line, 1 MiB of cumulative
response headers, 1024 header or trailer fields per block, and 128 informational
responses before the final response. Exceeding a limit is a receive failure;
trailer failures retain the already delivered body. HTTP/1.0 and HTTP/1.1 are
accepted. Transfer-Encoding supports chunked and overrides Content-Length.
Unsupported transfer codings, invalid header names and invalid framing fail
explicitly. These are project support choices, not missing async capabilities.

Redirect rewriting is adapter-controlled so curl can preserve an explicit
method while retaining its distinct data/upload body rules, and Wget can use
its normal POST rewrite rules. Redirect count zero, finite limits, unlimited
curl traversal, loops, and cross-origin authorization stripping are exercised
against deterministic local fixtures.

Destinations support stdout, discard, truncate, append/resume, numbered
collision files, `Content-Disposition`, 304 preservation, and optional cleanup
after a partial transfer. `TransferErrorKind` separates URL, protocol, proxy,
TLS, timeout, HTTP status, input, and output failures so Wget and curl can keep
their distinct exit statuses and diagnostics. Progress events carry status,
headers, known length, and received bytes; commands decide whether and how to
render them.

The workspace candidate emits `OutputStarted` after opening the actual output
path, including a numbered collision or Content-Disposition name. Wget retains
this path and the delivered offset across retries. A resumed 206 response must
declare a matching Content-Range before the output is opened, and its completed
body must match that range's byte span even without Content-Length. Callers opting
into `resume_skip_existing` keep their existing prefix when a server ignores
Range with 200: those response bytes are read and discarded before appending
the remainder. This also preserves previous URL output in an aggregate file
or stdout, without seeking or truncating either stream. The default transfer
option retains the existing restart behavior for file outputs.
Bodyless responses, including HEAD and 204, do not consume a retained prefix
or compare it with the metadata-only Content-Length.
In `WgetProfile`, a complete known-length 200 response shorter than the retained prefix
also succeeds without replacing it. A 416 response succeeds without opening or
changing output, independently of resume state or Content-Range metadata,
matching the fixed GNU observations. Invalid resumed 206 ranges remain a
receive failure before output mutation. These rules do not alter the strict
profile's protocol errors or generic HTTP status policy.
Command-level output preparation, such as Wget's explicit `-O` initialization,
can occur before `transfer` and is outside this no-mutation response branch.

These candidate contracts require the current package, CLI, backend-pair and
fixed-oracle checks; implementation does not establish published acceptance.

The legacy `fetch` and `fetch_with_options` entry points remain source
compatible and retain the original 30-second default. New command adapters use
`transfer_options` directly.

`CookieJar` receives parsed cookies separately from the wire adapter's retained
final Set-Cookie fields. Stores survive redirects and separate transfers;
request selection enforces host/domain and path boundaries, expiration and
Secure. The strict profile retains longer-path-first ordering. Netscape files preserve HttpOnly and session
state. A public-suffix database, IDNA and browser cookie-prefix rules remain
project work, not async API blockers. Response events preserve final Set-Cookie
field-name capitalization, values, attribute order and repeated-field order,
with HTTP optional whitespace normalized. Informational response fields do
not leak into those observations or cookie storage.

The command profiles ignore Set-Cookie fields without `=` without failing a
complete response body. Nonnumeric Max-Age deletes the matching stored cookie
for curl, while Wget ignores the replacement and preserves its old cookie.
Positive decimal overflow keeps curl's replacement under its 400-day lifetime
cap. Only lifetimes exceeding that cap round the capped expiry to the nearest
minute. Wget expires matching cookies for numeric overflow below 32 digits;
overlong attributes discard the replacement. The strict profile discards
unparseable Max-Age replacements as a project choice.
Repeated fields update storage in response order. Retained response fields
remain observable even when cookie storage ignores them.

Curl sends cookies by descending UTF-8 path, domain and name byte length, then
newer creation first; replacement retains the original creation order. Wget
uses descending domain and path byte length, then ascending name and value byte
order. Registered tests distinguish these profiles with subsequent request
bytes and fixed-clock expiry boundaries. This does not claim byte-for-byte jar
serialization or complete cross-scope duplicate-cookie compatibility.

Basic credentials are scoped to the initial origin. Callers choose preemptive
authentication or a single challenge retry; cross-origin redirects do not
forward those credentials. A challenge retry reopens file bodies, but refuses
to replay an already consumed stdin body.
`CurlProfile` also reports `RewindFailure` when a redirect would resend stdin
after payload was uploaded. A separate command retry starts a new transfer and
can send the now-empty stdin, matching the calibrated curl retry behavior; it
does not reproduce the original upload.

The current workspace serializes persistent headers and per-request
headers as separate layers. `CustomCookieMode::SeparateFields` sends stored
cookies before the explicit Cookie field (curl); `ReplaceStored` sends only the
explicit field while continuing to receive cookies (wget). Wget also enables
`custom_cookie_cross_origin`; curl leaves it disabled, independently of Basic
credential scope. This corrects the
0.2.0 rejection without new FFI. It does not
provide arbitrary ordered repeated headers: each layer is still a map. Extending
ordinary repeated-field semantics is project work, tracked separately by #34.
Parsed cookie storage does not replace the separately retained response fields.

## Reproducing the CLI checks

The workspace `network-auth-cookie` scenario starts a pure MoonBit loopback
HTTP server and invokes real workspace curl/wget artifacts. It checks
Basic request bytes, Wget's initial unauthenticated request and retry, literal
and redirect cookies, repeated `-b`, Netscape persistence, session cookies,
jar file permissions, stored-plus-literal cookie ordering, and upstream's
non-fatal jar-write behavior, separate curl Cookie fields and wget's explicit-field
override. A raw TCP core regression observes the individual fields and redirect
origin handling.

```sh
MOON_HOME="$HOME/.moon-accounts/cli" moon build --target native --release
MOON_HOME="$HOME/.moon-accounts/cli" moon build --target wasm --release
./_build/native/release/build/mooxCLI/cmd-tests/runner/runner.exe --suite scenarios --case network-auth-cookie --backend native
./_build/native/release/build/mooxCLI/cmd-tests/runner/runner.exe --suite scenarios --case network-auth-cookie --backend wasm
```

Linux CI also registers `--suite oracle --case network-auth-cookie-oracle`,
which compares both backends with the pinned curl 8.22.0/Wget 1.25.0 container,
including jar permissions. Local candidate contracts do not establish that
gate passed. The former probe is archived with the 2026-09-21 test evidence.

The 2026-09-20 local oracles were Apple curl 8.7.1 and GNU Wget 1.25.0 on
macOS, with `LC_ALL=C`. These checks do not establish a Linux curl 8.22
compatibility claim or validate a published `moonx` package version.
