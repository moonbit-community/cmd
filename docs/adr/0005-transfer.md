# ADR-0005: Pure MoonBit HTTP Transfer Profile

Status: Accepted
Date: 2026-09-05
Updated: 2026-10-26
Revision: Own HTTP/1 framing through the released passthrough API and apply explicit command profiles for URL targets, response cookies, EOF, file buffering, retry reset and selected-filename lifetime in the accepted async 0.22.5 stage 0 subset.

Delivery validation update (2026-10-26): [ADR-0001](0001-evidence.md) and the
[Wasm CI migration](../ci-wasm-migration.md) define current acceptance. Future
regressions and boundary unlock conditions below require Wasm on applicable
hosts and exact-version MoonX acceptance; Native command runs and backend
pairing are retired. Dated Native observations retain their historical scope.

## Target and decision

Implement curl/wget HTTP/HTTPS with public async APIs. Basic auth, cookie selection/persistence and redirect state are project responsibilities. Collect repeated Set-Cookie fields separately from the ordinary header map. Preserve command-specific credential challenge/redirect rules and cookie domain/path/Secure/expiry behavior within the documented subset.

## Stage 0: response failures and retry output

Stage 0 publishes core 0.7.0 and curl/wget 0.2.3. The
[release summary](../../CHANGELOG.md#2026-10-20) records exact main-source
Native/Wasm gates, sealed-oracle comparisons and local/published MoonX results.
The implementation uses async 0.22.5 and a project-owned pure
MoonBit HTTP/1 wire adapter. A fresh public `Client` establishes the connection,
TLS and configured proxy tunnel, then enters its released passthrough mode
before the origin request. The project serializes that request and parses its
response through public byte reads and writes. This is project implementation
work using existing APIs, with no host-command fallback or private transport
access. Core 0.7.0 adds `EmptyReplyFailure`, `PartialBodyFailure`,
`ReceiveFailure` and `RewindFailure` to the public transfer error model.
The public `TransferProfile` selects `StrictProfile` by default; the command
callers explicitly select `CurlProfile` or `WgetProfile`. In the strict profile,
fixed-length or chunked premature EOF is a partial-body failure; other
response-read errors are receive failures. The command profiles preserve the
specific fixed-oracle differences below rather than imposing strict failure on
responses that the corresponding tool accepts. Connection setup and
request-write failures retain their separate classification. Ordinary
close-delimited responses and HEAD/204/304 responses require successful controls
and must not become partial failures merely because the connection closes.

`TransferFailureContext` records the processing phase, response framing and
fixed expected length, reader-delivered bytes and completed sink-write bytes.
Skipping an existing resume prefix does not count as a new output write.
An output failure that occurs first keeps its distinct kind; a failed Writer call sets
`write_outcome_uncertain` because the public API cannot report its partial
write count. This makes the completed-write count an explicit lower bound on
that path, instead of asserting that an unsuccessful call had no file effects.
Curl's final buffered-file flush after an earlier network failure preserves
that primary failure even if the flush also fails, while recording the uncertain
write outcome. The error kind does not imply that no secondary write was tried.

The adapter completes request headers, payload and framing before reading origin
response headers. Request-write and body-length failures identify `Request`;
header-read failures identify `ResponseHeaders`. No combined-phase uncertainty
is needed for those origin operations. Proxy CONNECT establishment still uses
async's high-level client path and retains connection-stage classification;
finer proxy response diagnostics are separate project work rather than a claim
that the public byte APIs are unavailable.

The final persistent and per-request fields are validated before serialization,
including generated Cookie fields. Invalid names and CR/LF values are rejected
before writing request bytes. This applies the existing explicit-header input
validation to generated fields; it is not a missing-API boundary or a claim of
GNU handling for malformed cookie input. Raw TCP and command regressions observe
the rejected bytes and unchanged output separately.

Initial request-target validation precedes connection. The calibrated curl
profile rejects raw ASCII space, TAB, CR, LF and DEL in the path or query with
status 3 and leaves an existing output file unchanged. Wget instead emits
uppercase percent escapes and succeeds on the complete-response controls.
Existing encoded bytes remain encoded. Followed Location spaces become `%20`
in curl paths and `+` in curl queries; Wget uses `%20` in both. TAB becomes
`%09` in both components for both commands. These cases are explicit command
policies, not a general URL-normalization claim or an upstream API blocker.

Response observation retains every final Set-Cookie field separately from
parsed cookie storage, preserving field-name capitalization, value text,
attribute order and repeated-field order after HTTP optional-whitespace
normalization. Interim response fields do not enter final observations or the
jar. Both command profiles ignore fields without `=` without failing the body.
For nonnumeric Max-Age, curl deletes the matching stored cookie, whereas Wget
ignores that replacement and retains the old cookie. Positive decimal overflow
instead retains curl's replacement under its 400-day lifetime cap; only
lifetimes exceeding that cap round the capped expiry to the nearest minute.
Wget expires matching cookies for numeric overflow below 32 digits and discards
overlong replacements. The strict profile discards unparseable replacements as
a project choice. Repeated fields update storage in response order. Curl sends
cookies by descending UTF-8 path/domain/name byte length, then newer creation
first, preserving creation on replacement. Wget uses descending domain/path
byte length and ascending name/value byte order. These rules do not establish
byte-for-byte jar serialization, port-qualified saved-domain parity or complete
cross-scope duplicate-cookie compatibility; those remain within issue #34.
Malformed response-cookie handling remains separate from final outgoing-field
CR/LF validation above.

The fixed URL/cookie and ordering/overflow probes established expectations for
these cases. Historical Native/Wasm and sealed-oracle results remain in Git,
including raw request bytes, connection counts, final bodies and existing-output
effects. Current registered Wasm and exact-MoonX checks preserve these contracts;
published status comes from exact-version acceptance, separately from probes.

An owned output sink closes on every exit from its private scope, including
task cancellation. This lifetime guarantee does not define GNU signal behavior,
buffered-tail delivery, or remove-on-error cleanup under cancellation; those
failure-effect contracts remain part of the resource stage.

Requests without an explicit `Accept-Encoding` use `identity`; explicit caller
values remain unchanged. The wire adapter preserves content-coded bytes without
implicit decoding. Output bytes, Content-Length checks and
retry Range offsets consequently use the encoded representation, including
gzip-coded responses. No decompression option is added. The previous implicit
gzip path removed Content-Length and delivered decoded bytes, which hid known
wire framing and made those bytes unsafe as encoded Range offsets. Fixed-length
gzip success/truncation fixtures check the actual byte counts and retained
output on both default and explicit-header paths.

The published curl maps empty replies to status 52, partial bodies to status 18
and other receive failures to 56. Its ordinary file destination opens on the
first payload or successful completion, so an initial empty failed body does
not create, truncate or remove an unopened destination, including with
`--remove-on-error`.
A successful empty response still creates its selected output. File writes use
a 4096-byte buffer: a write failure reached before a network failure returns 23;
a short buffered tail after a partial-body failure is flushed while preserving
18 if that flush also fails. Successfully flushed tails remain observable.
This buffering profile is limited to file output; stdout buffering/error
precedence has not been calibrated by these cases. Bytes already delivered to
stdout remain visible. Once the command accepts a retry, it resets an already
opened regular file to empty before the next request. If that retry then fails
without payload, the file remains empty rather than retaining the earlier
attempt's prefix. An unopened ordinary destination retains its lazy behavior.
`--remove-on-error` cleans up an opened selected file only after final failure,
not between attempts; a successful retry keeps its result. Ordinary `--retry`
does not retry these body failures, while `--retry-all-errors` can. A reset file
and repeated stdout prefixes have distinct observable effects. With `-sS`, each
failed attempt keeps its error diagnostic even if a later retry succeeds.
Fixed-length truncation reports the missing byte count from the structured response context; internal
HTTP-status retries without `-f` do not manufacture error 22 diagnostics.

For curl `-O -J`, a valid Content-Disposition filename on a 2xx/3xx response
causes exclusive creation before body delivery. An existing selected filename fails with status 23 and
stays unchanged. A newly created selected file can remain empty after a body
failure; it is subject to final-failure cleanup when requested. Retries retain
the first server-selected filename even when a later response changes or omits
that header. These are curl-specific output decisions; the strict and Wget
profiles retain their own existing rules. The calibrated 404/500 responses ignore
Content-Disposition and use ordinary lazy URL-derived output; `-f` rejects them
with 22 before transfer output opens. The status-selection observations are
retained historically in `cmd-curl-cd-status-oracle-1`; current registered Wasm
and pinned-oracle cases validate the implementation. A probe alone is not
published acceptance.

The fixed curl 8.22 observations in `cmd-curl-retry-empty-oracle-1` and
`cmd-curl-retry-lifecycle-oracle-1` retain streams, request sequences and file
bytes, including the empty file observed before the retry response. They define
the expected lifecycle; registered Wasm command and pinned-oracle comparisons
remain the current regression path. Retry reset is implemented with
released path-based open operations. Public descriptor truncation and file
identity are still absent, so reset does not guarantee the same descriptor or
inode after concurrent pathname replacement. This narrower boundary remains in
[#10](https://github.com/moonbit-community/cmd/issues/10). Lifting it requires
released handle-based truncation/identity support and adversarial path-replacement
tests; it does not block the ordinary retry algorithm.

Wget accepts EOF while reading an announced chunk's remaining payload,
including zero payload bytes, and while reading trailers. It still fails on EOF
while reading the next chunk-size line or the CRLF after a completed chunk.
Malformed framing and fixed-length truncation remain failures. Exhausted
network retries return 4. These are explicit Wget-profile decisions matching
the calibrated fixtures; `StrictProfile` and `CurlProfile` retain chunk EOF
failures. Wget tracks the delivered offset and actual selected output path.
`OutputStarted` reports that path and response offset; resumed 206
responses must have a matching Content-Range before writing, and a completed
body must match the declared byte span even when it is chunked or close
delimited without Content-Length. Bodyless responses never require replaying
a retained prefix. If a server replies
200 instead, Wget uses `resume_skip_existing` to discard the already delivered
prefix and retain stdout or earlier URL output in a shared `-O` file. A complete
known-length 200 response shorter than that retained prefix succeeds and leaves
the prefix unchanged. The shared Wget-profile transfer treats 416 as successful
completion without opening its destination, independently of Content-Range
metadata or whether resume was requested. An ordinary named output is therefore
preserved; explicit `-O` still performs the command's existing aggregate-file
creation/truncation before any request. Those effects require separate file
observations. A mismatched 206 Content-Range is a receive failure and
returns 4 after retries. This does not establish that the remote prefix has
remained unchanged. Wget does not retry a `StdinBody`. Curl's
`--retry-all-errors` may retry after consuming stdin and send an empty body on
the next attempt, as the fixed curl oracle does; this is not a replay of the
original bytes. A curl redirect that requires replay of already uploaded stdin
instead fails with request-phase `RewindFailure` (status 65); an empty original
upload does not require rewinding. Redirect and authentication rewind behavior
retain their own wire cases and must not be inferred from retry results.

For ordinary GET with `-c --content-disposition` and no explicit `-O`, Wget first
makes a bodyless HEAD request without an automatic Range header; explicitly
supplied headers remain in effect. It selects the response filename,
then reads that selected file's size for the subsequent GET; an unrelated
URL-derived file cannot supply the resume prefix. The selected name stays fixed
across GET retries. An unexpected unrequested 206 during name discovery fails
before either candidate path is changed. Registered cases observe HEAD/GET order,
Range offset and both files; fixed-oracle command acceptance is still required.
The lower-level transfer API continues to reject a different Content-Disposition
path when a caller directly asks to retain or append an existing prefix. Such
callers must first resolve the destination and its own offset, rather than
skipping bytes from another file. Broader method/redirect combinations require
their own wire and filesystem cases.

Header rejection occurs before transfer output creation; Wget's explicit `-O`
initialization remains a separate earlier effect. EOF before any origin response
header byte is an empty reply. Strict transfer rejects incomplete headers.
Both command profiles accept EOF while collecting headers after a complete 200
status line, while any already parsed framing fields still govern body
completion. The calibrated `200 OK` plus unfinished `Content-Len` fixture thus
completes with zero bytes; it is not a claim that every incomplete response
succeeds. Other incomplete or malformed headers remain receive failures.
The parser exposes chunk payload before checking the following CRLF,
next chunk or trailers, so delivered bytes remain observable when later framing
fails. Complete trailers and bodyless/close-delimited responses remain separate
success controls. Actual Native/Wasm command and immutable-oracle evidence
is recorded for these implemented contracts; neither header distinction nor
chunk payload preservation is blocked on a new async API.

Untrusted protocol metadata is bounded: protocol lines are limited to 64 KiB,
cumulative response headers to 1 MiB, fields to 1024 per header block, interim
responses to 128 and trailer fields to 1024. Oversized metadata is a receive
failure; header rejection precedes output opening, while trailer rejection
retains already delivered body bytes. Registered wire fixtures cover each
limit and its effects. These limits define a bounded profile, not complete
HTTP compatibility or an upstream API limitation.

The existing command path still collects ordinary request fields in maps;
arbitrary ordered repeated request headers remain unimplemented. The project
wire adapter can serialize such fields, so lifting that restriction requires
project option/redirect semantics and fixed-oracle wire tests, tracked in
[#34](https://github.com/moonbit-community/cmd/issues/34), rather than a new
upstream header-list API. The previously supported separate Cookie fields and
repeated response Set-Cookie behavior remain required regression contracts.

The raw loopback fixture, command scenarios and package tests cover fixed and
chunked truncation, malformed chunks, bodyless/close-delimited controls, file
retention/cleanup, retries, Range requests and output-name reuse. Registration or
a passing focused parser probe does not certify command parity: retain Native,
Wasm, fixed curl/Wget oracle and exact published-consumer results with their
real statuses, output files and wire requests. Stage 0 published these profiles
in core 0.7.0 and curl/wget 0.2.3; those commands still request that core
coordinate even though the workspace core has advanced.
The dated cookie/authentication evidence below retains its original baseline.

## Alternatives and compatibility cost

Reject host curl/wget delegation, own FFI and permanent exclusion of implementable protocol state. Explicit Basic credentials use a command-specific scope: the public transport defaults to the initial origin, while Wget selects all origins for `--user/--password`. Custom authorization headers retain their separate redirect behavior. Applying curl's scope to Wget was rejected because it changes authenticated redirects despite the caller supplying explicit credentials. Basic auth tests do not imply all protocols, authentication mechanisms, browser cookie policy or exact progress bytes.

## Current authentication and cookie routing

Wget `--user/--password --auth-no-challenge` supplies explicit Basic
credentials on every selected request, including cross-origin redirects.
Without it, each unchallenged origin first supplies a Basic challenge.
Challenge state is per origin within one transfer; GNU's hostname-level
reuse across ports or separate operands is not claimed. Curl's literal
cookies and custom Cookie headers remain scoped to the initial origin;
stored cookies are selected for each destination.

Curl emits matching jar cookies and an explicit Cookie field separately.
Wget's `ReplaceStored` policy makes its explicit field replace outgoing
jar cookies without disabling response storage, and forwards that explicit
field across origins. This is independent of Authorization routing. The
project HTTP/1 adapter now serializes these fields; the older two-map async
transport was an implementation step, not a requirement for a new public
header-list API. General ordered duplicate request fields remain project
work under the contract described above.

Historical curl 8.7.1 host probes are not the pinned curl 8.22.0 oracle.
Cookie prefix rules, PSL/IDNA, arbitrary authentication mechanisms and full
jar serialization remain outside the selected profile. The fixed raw-wire
fixtures distinguish header validation, response-cookie storage and later
request bytes. No host curl/wget or private transport implementation is used.

## Versions and evidence

The source trail starts with the 0.2.0 cookie repair (`1841411`) and
continues through the public-passthrough adapter (`68b2010`), retry output
lifetime (`00d3df3`) and URL/cookie calibration (`0bb2d54`). Stage 0 exact
publication and three-platform acceptance are summarized under 2026-10-20
in CHANGELOG.md. Current wire/package and command scenarios remain the
executable assertions; those historical results do not cover future changes.

## Revisit when

Extend additional protocol/auth/cookie behavior with direct upstream fixtures; new APIs alone are not evidence of implemented behavior.

## Source review (2026-10-26)

Current sources are [HTTP wire framing](../../core/netops/http_wire.mbt), [request serialization](../../core/netops/http_wire_request.mbt), [transfer state](../../core/netops/transfer.mbt), [sink lifetime](../../core/netops/transfer_sink.mbt) and [command scenarios](../../tests/network_scenarios/). Profile, cookie, header, retry and sink regressions live in core/netops alongside these files.
