# ADR-0005: Pure MoonBit HTTP Transfer Profiles

Status: Accepted
Date: 2026-09-05
Updated: 2026-11-09

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
  Preserve ordered, repeated final response fields, including interleaved
  Set-Cookie fields, after optional-whitespace normalization. Ignore interim
  fields. Keep the separate semantic framing map and its existing validation.
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
| Custom request fields | Retain repeats and argument order, including User-Agent | Last same-name value replaces the earlier value |
| Explicit cookies | Initial-origin scope; jar and explicit fields stay separate | Replace outgoing jar cookies and follow origins; response storage remains active |
| Body failure | Empty reply 52, partial body 18, receive 56, write 23 | Fixed truncation/malformed framing fail; exhausted network retries return 4 |
| Chunk EOF | Incomplete framing/payload fails | Payload/trailer EOF accepted; next-size-line or post-payload-CRLF EOF fails |
| Consumed stdin | --retry-all-errors may retry an empty body; replay-required redirect fails with 65 | StdinBody is not retried |

Cookie domain/path/Secure/expiry, update order and malformed/overflow Max-Age
policies remain profile-specific. Exact wire tests own the detailed cases;
this does not establish browser policy, URL IDNA or full jar serialization.

The unpublished Curl profile checks case-sensitive `__Secure-` and `__Host-`
prefixes before mutating storage, including Netscape imports. Header cookie
names, values and attributes trim ASCII SP/HTAB before identity, prefix and
overlay decisions. Empty Domain, Max-Age and Expires attributes retain earlier
values; assigned Secure attributes remain distinct from the Curl flag.
`__Host-` uses
the normalized root path and final host-only scope, not mere Domain-attribute
absence; an exact IP Domain remains host-only. Path normalization removes
quotes and one trailing slash, maps invalid provided paths to `/`, and uses
the request directory when absent. Secure admission and transmission permit
HTTPS or exact case-insensitive localhost, 127.0.0.1 and ::1. Other HTTP origins
cannot replace/delete overlapping live Secure cookies. The pinned curl overlay
rule compares the old path's first component as a prefix, including
`/loginhelper` for `/login`; expired records do not block updates. Curl identity
includes host-only/domain scope, while Wget retains its separate identity and
HTTPS-only transmission without these prefix/admission/overlay policies.
Cookie files are trusted for Secure attributes; response-origin admission and
overlay checks do not apply to local jar imports.

Private fixed-clock tests cover domain overlap, expiration, path and identity.
The shared CLI security matrix observes real redirect requests, unchanged
input jars and all logical saved rows, with separate candidate/oracle records.
Headers and row ordering in jar files are not byte-parity claims.

The workspace embeds the complete ICANN and PRIVATE PSL snapshot at
`94ec5df7273926560d91e77c002000ba1a53fec4`, with original input, license and
checksums in `tests/fixtures/psl`. The pure MoonBit generator retains Unicode
rules and adds Punycode aliases. This does not normalize incoming URL or
Domain spellings with IDNA/NFKC; that distinct Unicode input behavior remains
unfinished under #34. Complete data coverage is not complete Unicode admission.
Private sorted tables implement libpsl 0.21.2's cookie policy, including
wildcard bases, exceptions and the longest suffix of the request host. Curl
converts accepted exact suffix responses to host-only before prefix validation;
imports reject public suffixes with the localhost exception. Wget retains
domain scope for exact suffixes and does not apply response admission to jars.
Its response domain rejection marks the matching cookie for removal, including
unexpired updates and foreign domains; explicit Path must prefix the request
path before that removal can occur. Missing Path uses the request directory
including its trailing slash. One leading Domain dot is removed from response
and imported keys, so additional dots cannot accidentally target another key.
Real Linux observations exposed the earlier incorrect ignore-only behavior;
permanent cases cover expired/unexpired updates, private suffixes, foreign
domains and the path gate. Wget's port component remains in the open scope below.
Request selection also uses Wget's raw path prefix, independently of Curl's
segment-boundary rule. CLI jar loading explicitly selects the Wget profile;
defaulting to Strict would collapse additional leading dots before deletion.
Storage spelling and admission views remain distinct for leading/trailing dots
and ASCII case. Curl keeps received/imported domain spelling while domain
selection, replacement and insecure overlay protection compare ASCII case
insensitively. Linux raw jar observations exposed the earlier lowercase rewrite;
case-preservation and mixed-case replacement/overlay regressions retain it.
Strict IP spelling is checked before using the released public address parser.

`network-cookie-suffix` independently observes real proxy requests, unchanged
input files and all logical Curl saved rows. It has its own bounded execution
window; existing authentication and transfer deadlines are unchanged. The
official 78-record corpus remains an independent input. Full rule/alias
observations use fixed libpsl over the raw official data, not generated product
tables. Oracle profile revision 2 advances the PSL snapshot prospectively while
retaining the family ID required by frozen case bindings. The recipe checks
that client and PSL/IDNA library binaries remain unchanged when adding fixed
diagnostic tools. Fresh receipts bind data bytes, counts, metadata and immutable
image identity; real Curl/Wget file-read traces verify actual use. Old revision
1 profiles and receipts retain their original scope and cannot satisfy revision
2 binding. Dataset updates require regeneration, complete rule/alias comparison
and actual CLI regressions, never a partial handcrafted suffix list.

Wget port-scoped cookies,
its full path dialect, HttpOnly jar handling, and complete malformed jar/field
grammar (including early rejection of conflicting Domain attributes) remain
issue #34 work. No host implementation or private API is needed.

Wget retains the lowest nonzero transfer exit code across URL operands, matching
the [GNU exit-status rule](https://www.gnu.org/software/wget/manual/wget.html#Exit-Status).
Usage and generic setup failures return before the transfer loop. A later
success does not clear an earlier failure. The previous implementation retained
the last failure, so network error 4 followed by HTTP error 8 incorrectly exited
8. `wget-exit-network-before-http` and `wget-exit-http-before-network` in the
[CLI cases](../../tests/cases/wget.json) assert both orders and a later successful
body, with the pinned Linux oracle route registered in the case index. This is
an unpublished workspace correction; the frozen 0.2.5 coordinate is unchanged.

The transfer error retains authentication failure only when a 401 Basic
challenge rejects an outgoing Basic Authorization field. Wget maps that state
to 6; other HTTP errors remain 8. This distinguishes actual transmitted
credentials from configured credentials that were never sent. Curl preserves
its ordinary HTTP response behavior and maps both HTTP failure kinds to 22
under `--fail`. Authentication rejection does not become a default retryable
network failure; explicit HTTP retry selection still applies.
`wget-auth-rejected` and the four authentication/HTTP/network operand-order
cases cover statuses and later successful output. Wget's private wire test
checks both challenge-based and preemptive credentials, exact Authorization
bytes, request counts, challenge-free 401 controls and unopened file contents.
The existing successful Basic case and Curl rejection cases remain controls.
The unpublished header repair recognizes Basic among repeated WWW-Authenticate
fields and comma-separated challenges, respecting quoted commas and escaped
quotes. A Basic-named auth parameter or a longer scheme token does not qualify.
It does not implement non-Basic authentication.

Private ordered request fields replace the lossy map in Curl's profile; Wget
and StrictProfile retain same-name replacement. Generated jar Cookie fields
still precede explicit fields. Multiple request Content-Length fields reject
before request bytes, retaining the existing single-length upload invariant.
Raw request/response tests assert order and repetition, actual authentication
attempts, interim exclusion and preserved framing failures. The CLI header
fixture reads raw fields rather than letting a server Map erase duplicates.
The shared authentication scenario also compares reflected request fields,
default User-Agent placement, final HEAD fields and a multi-field Basic
challenge through its pinned Linux oracle route. Product and oracle request
counts are checked separately; challenge attempts assert exact Authorization
presence and bytes. This preserves custom-field relative order, without claiming
full absolute ordering of every generated header and jar field.
Wget's explicit Cookie cross-origin coverage now uses an actual --header
redirect, independently of its unchanged --no-cookies case.

Header removal/semicolon syntax and header files, URL IDNA, complete cookie-jar
serialization, configuration loading and stdin authentication replay remain
project work under issue #34. Extend the owning parser and protocol fixtures
before lifting these limits; no upstream list API is required. This batch does
not establish full curl/Wget parity or performance qualification.

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
