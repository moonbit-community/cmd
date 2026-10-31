# ADR-0005: Pure MoonBit HTTP Transfer Profiles

Status: Accepted
Date: 2026-09-05
Updated: 2026-10-30

## Decision

Use the public async Client for connection, TLS and configured proxy setup,
then its released passthrough API for project-owned HTTP/1 request serialization
and response framing. Keep transfer state in pure MoonBit; never delegate
product behavior to host curl/wget or private transport APIs.

The public default is StrictProfile. Curl and Wget explicitly choose their
own profiles because authentication, EOF, retry and output effects differ.
HttpWire owns request payload framing, timeouts and write errors; callers do
not add forwarding layers with no remaining responsibility.

## Wire and failure contracts

- Complete origin headers, payload and framing before reading the response.
  Classify request-write, response-header and response-body failures separately.
  Proxy CONNECT remains a connection-stage operation.
- Validate final header names and CR/LF-free values, including generated Cookie
  fields, before serialization. Preserve repeated final Set-Cookie fields and
  their order separately from ordinary header lookup; interim fields do not
  enter the cookie jar.
- Default Accept-Encoding to identity unless explicitly supplied. Preserve
  content-coded bytes; Content-Length and Range offsets describe that encoded
  representation. Do not implicitly decode gzip responses.
- Preserve body bytes delivered before later framing failure. Completed sink
  writes are a lower bound if a Writer call fails, because its partial extent
  is unknown. Preserve the primary error during a secondary flush/cleanup error.
- Bound protocol lines to 64 KiB, cumulative response headers to 1 MiB, fields
  per block to 1024, interim responses to 128 and trailer fields to 1024.
  Header rejection precedes output opening; trailer rejection retains body
  prefixes. These are selected-profile limits, not missing-API claims.

Bodyless and close-delimited responses have separate successful controls.
EOF before any response-header byte is an empty reply. Both command profiles
accept EOF after a complete 200 status line while collecting headers, subject
to already parsed framing; other malformed/incomplete responses remain errors.
StrictProfile rejects incomplete headers and fixed/chunked premature EOF.

## Command-specific behavior

| Concern | Curl profile | Wget profile |
| --- | --- | --- |
| Initial URL target | Reject raw space/TAB/CR/LF/DEL in path/query before connection, status 3 | Percent-escape these bytes; preserve existing escapes |
| Redirect Location | Spaces become %20 in path and + in query; TAB becomes %09 | Spaces become %20 in both; TAB becomes %09 |
| Explicit Basic credentials | Initial-origin scope by default; custom Authorization has its own routing | Explicit --user/--password spans origins; without --auth-no-challenge each new origin first challenges |
| Explicit cookies | Literal/custom Cookie stays initial-origin scoped; emit jar and explicit fields separately | Explicit field replaces outgoing jar cookies and follows origins, without disabling response storage |
| Body failures | Empty reply 52, partial body 18, receive error 56, write failure 23 | Fixed truncation/malformed framing fail; exhausted network retries return 4 |
| Chunk EOF | Incomplete payload or framing fails | Payload/trailer EOF is accepted; next-size-line or post-payload-CRLF EOF fails |
| Retry input | --retry-all-errors may retry consumed stdin with an empty body; replay-required redirect fails with RewindFailure/65 | StdinBody is not retried |

Cookie storage retains domain/path/Secure/expiry and response-order updates.
Malformed Max-Age and overflow have explicit distinct policies: curl can delete
on nonnumeric values and cap positive overflow at 400 days; Wget ignores
nonnumeric replacement and treats numeric/overlong overflow differently.
Cookie ordering remains profile-specific. The exact wire regressions are the
authority; these rules do not establish browser cookie policy, full jar
serialization, PSL/IDNA or cross-scope duplicate-cookie parity.

## Output and retry ownership

Curl ordinary file output opens lazily on the first payload or successful
completion. An initial empty failure leaves an unopened existing destination
unchanged; successful empty output creates it. File buffering uses 4096 bytes.
A network failure remains primary if flushing its buffered tail also fails.
Stdout prefixes are already visible and do not inherit file-reset semantics.

An accepted retry resets an opened regular file before the next request.
Remove-on-error applies to the opened selected file after final failure, not
between attempts. Curl -O -J exclusively creates a valid server-selected name
on eligible 2xx/3xx responses and retains that name across retries. Existing
selected names fail unchanged. Calibrated 404/500 responses use ordinary lazy
URL-derived output; -f rejects before transfer output opens.

Wget observes the actual selected output and delivered offset. Resumed 206
responses must match Content-Range before writing and finish with the declared
span. A 200 fallback skips retained prefix bytes; a shorter complete known-length
response leaves that prefix intact. A 416 completes without transfer output
opening; explicit -O initialization is a separate earlier file effect.

Wget -c --content-disposition without -O first resolves the filename through
HEAD, then derives the GET resume offset from that selected file. Preserve
HEAD/GET order and the chosen name across retries. Direct callers cannot append
an old prefix to a newly selected different file without resolving ownership.

Owned sinks close on success, failure and observable cancellation. Path-based
retry reset does not guarantee descriptor/inode continuity under concurrent
replacement; lifting that limit needs public handle truncation/identity and
adversarial tests. Cancellation cleanup alone does not establish GNU signal,
buffered-tail or remove-on-error parity.

## Remaining work and verification

General ordered duplicate request headers are command-policy work, not blocked
by the wire adapter. Wider authentication, cookie-jar and method/redirect
combinations require explicit wire and file-effect regressions; see
[issue #34](https://github.com/moonbit-community/cmd/issues/34). Descriptor/path
race guarantees remain under [ADR-0004](0004-filesystem.md).

Use raw loopback fixtures, package failures and actual command scenarios for
framing, retries, Range, filenames and output prefixes. Compare against the
immutable curl/Wget oracle and validate exact published coordinates separately.
Old host probes and passing parser tests do not establish full command parity.

Implementation: [wire](../../core/netops/http_wire.mbt),
[serialization](../../core/netops/http_wire_request.mbt),
[transfer](../../core/netops/transfer.mbt),
[sink lifetime](../../core/netops/transfer_sink.mbt),
[network scenarios](../../tests/network_scenarios/).
