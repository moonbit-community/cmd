# ADR-0005: Pure MoonBit HTTP Transfer Profiles

Status: Accepted
Date: 2026-09-05
Updated: 2026-11-08

## Decision

Use public async Client connection, TLS and proxy setup, then its released
passthrough API for pure MoonBit HTTP/1 serialization and framing. HttpWire
owns request payloads, timeouts and write errors. The public default is
StrictProfile; curl and wget explicitly select their distinct policies.
Do not delegate to host tools or add responsibility-free forwarding layers.

## Wire and failure contracts

- Complete origin request headers, payload and framing before reading the
  response; proxy CONNECT remains connection setup. Distinguish request-write,
  response-header and response-body errors.
- Validate final names and CR/LF-free values, including generated cookies.
  Preserve ordered, repeated final Set-Cookie fields; ignore interim cookies.
- Default Accept-Encoding to identity and preserve content-coded bytes.
  Lengths and Range offsets describe those bytes; no implicit decompression.
- Preserve delivered prefixes. A failed Writer call has unknown partial extent,
  so completed writes are only a lower bound. Keep the primary error if flush
  or cleanup also fails.
- Limit lines to 64 KiB, headers to 1 MiB, fields per block and trailers to
  1024, and interim responses to 128. Header rejection precedes output opening;
  trailer rejection retains body prefixes.

Empty reply, bodyless response and close-delimited body are distinct states.
Both command profiles accept EOF after a complete 200 status line while
collecting headers, subject to parsed framing. StrictProfile rejects incomplete
headers and premature fixed/chunked EOF.

## Command profiles

| Concern | Curl | Wget |
| --- | --- | --- |
| Initial URL controls | Reject raw space/TAB/CR/LF/DEL before connection, status 3 | Percent-escape them, preserving existing escapes |
| Redirect spaces | %20 in path, + in query; TAB becomes %09 | %20 in path/query; TAB becomes %09 |
| Basic credentials | Initial-origin scope; custom Authorization routes separately | Explicit credentials span origins; each origin first challenges unless --auth-no-challenge |
| Explicit cookies | Initial-origin scope; jar and explicit fields stay separate | Replace outgoing jar cookies and follow origins; response storage remains active |
| Body failure | Empty reply 52, partial body 18, receive 56, write 23 | Fixed truncation/malformed framing fail; exhausted network retries return 4 |
| Chunk EOF | Incomplete framing/payload fails | Payload/trailer EOF accepted; next-size-line or post-payload-CRLF EOF fails |
| Consumed stdin | --retry-all-errors may retry an empty body; replay-required redirect fails with 65 | StdinBody is not retried |

Cookie domain/path/Secure/expiry, update order and malformed/overflow Max-Age
policies remain profile-specific. Exact wire tests own the detailed cases;
this does not establish browser policy, PSL/IDNA or full jar serialization.

Wget retains the lowest nonzero transfer exit code across URL operands, matching
the [GNU exit-status rule](https://www.gnu.org/software/wget/manual/wget.html#Exit-Status).
Usage and generic setup failures return before the transfer loop. A later
success does not clear an earlier failure. The previous implementation retained
the last failure, so network error 4 followed by HTTP error 8 incorrectly exited
8. `wget-exit-network-before-http` and `wget-exit-http-before-network` in the
[CLI cases](../../tests/cases/wget.json) assert both orders and a later successful
body, with the pinned Linux oracle route registered in the case index. This is
an unpublished workspace correction; the frozen 0.2.5 coordinate is unchanged.

## Output ownership

Curl opens ordinary files on first payload or successful empty completion.
Initial empty failure preserves unopened destinations. Retry resets an opened
regular file before another request; remove-on-error applies only after final
failure. Stdout prefixes cannot be reset. A network error remains primary if
flushing the 4096-byte file buffer also fails.

Curl -O -J exclusively creates eligible 2xx/3xx server-selected names and keeps
the first name across retries. Existing names fail unchanged. Selected 404/500
responses use ordinary URL-derived output; -f rejects before opening.

Wget resumes from the actual selected file. A 206 must match Content-Range
before writing and finish with the declared span. A 200 skips retained prefix
bytes; a shorter complete known-length response preserves them. A 416 does not
open transfer output; explicit -O initialization is an earlier separate effect.
With -c --content-disposition and no -O, HEAD selects the file before GET derives
its offset. Preserve that order and filename across retries.

Owned sinks close on success, failure and observable cancellation. Path-based
retry reset does not prove inode/descriptor continuity under replacement.
Signal, buffered-tail and remove-on-error parity require separate evidence.

## Verification and reconsideration

Raw loopback fixtures and command scenarios assert framing, request order,
retries, filenames, Range and partial files against the immutable oracle.
Broader ordered headers, authentication and cookie combinations are project
work ([issue #34](https://github.com/moonbit-community/cmd/issues/34)).
Descriptor/path guarantees require public handle operations and adversarial
tests under [ADR-0004](0004-filesystem.md). Published-coordinate acceptance
remains separate from local parser and wire tests.

Implementation: [wire](../../core/netops/http_wire.mbt),
[serialization](../../core/netops/http_wire_request.mbt),
[transfer](../../core/netops/transfer.mbt),
[sink lifetime](../../core/netops/transfer_sink.mbt),
[network scenarios](../../tests/scenarios/network/).
