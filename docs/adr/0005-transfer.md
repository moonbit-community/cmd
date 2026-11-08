# ADR-0005: Pure MoonBit HTTP Transfer Profiles

Status: Accepted
Date: 2026-09-05
Updated: 2026-11-09

## Decision

Use released public TCP/TLS readers and writers with a private connection owner
for direct and proxy setup. Preserve the parsed canonical host without passing
it through a second URL parser. HttpWire owns pure MoonBit HTTP/1 serialization,
framing, request payloads, timeouts and write errors. The public default is
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
this does not establish browser policy or full jar serialization.

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
rules and adds Punycode aliases. Cookie Domain normalization remains separate
unfinished #34 work; URL conversion is described below. Complete suffix data
coverage is not complete Unicode admission.
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

Wget host-only response cookies retain nondefault ports in identity, matching
and persistence. Response ports 80/443 and explicit Domain cookies use ANY;
explicit imported ports remain exact even for 80/443. The first case-insensitive
domain-chain key spelling survives replacement and additional names until the
chain is deleted. Single-label parent chains are not searched, exact single-label
hosts remain eligible, and lookup skips hosts above 32 labels. Stale imports do
not remove live keys. Imported TRUE flags are
case-sensitive, all comment lines including HttpOnly are ignored, the final
value retains TABs, and nonempty raw paths remain stored. Selected identical
name/value pairs are emitted once. New and replaced cookies enter the head of
their domain chain; saving retains that chain order. The fixed profile keeps
the last equal pair from specific-to-general domain-chain traversal before
quality sorting, so a reload can change which duplicate path participates.
The regression pins raw row order and both processes' Cookie order for that
case, in addition to logical rows. The field extractor handles ASCII whitespace,
quoted semicolons and Wget's RFC 2231 name adjustment; Secure ignores its value,
HttpOnly is ignored, and an earlier deletion is sticky. Finite frozen oracle
expectations in `tests/fixtures/network/wget-cookies.json` drive real candidate
and fixed-oracle wire, logical jar rows and second-process reload controls.
They are independent of generated coverage definitions.

Wget numeric expiry keeps the original binary64 value until the owning jar
applies it at one timestamp. Decimal and hexadecimal C-locale prefixes include
numeric suffixes and incomplete exponents; Max-Age keeps its existing fewer-than-
32-byte bound, while imported numeric fields have no such bound. Exactly -1
rejects the entire Max-Age field. Floating zero requests deletion; a nonzero
value that truncates to zero instead remains valid during the current second.
Expiry operations retain field order and sticky explicit deletion. A stale
negative replacement stays in the domain chain; a stale imported value is
ignored before replacement. Expiry zero and the permanent/session flag remain
distinct. Saving uses binary64-rounded integer digits, including values above
2^53; a saved permanent zero becomes a session cookie on reload.

The selected immutable Linux/amd64 Wget binary converts non-finite and
out-of-range values to INT64_MIN and wraps the subsequent time addition.
Pure MoonBit spells out this observed profile rather than depending on a host C
cast. This does not assign portable semantics to undefined C conversions or
claim identical behavior from every Wget build. The private wire response and
cookie types retain ordered expiry information without changing the public
CookieJar API or Curl/Strict expiry rules.

The 194 fixed expectations in `tests/fixtures/network/wget-cookie-expiry.json`
come directly from frozen independent oracle records and check both processes'
requests, saved rows and row order. Current-second and relative-future cases
are excluded from those static expectations: fixed-clock package tests and
separate measured-clock real-process probes cover them. A crossed-second
observation remains inconclusive; large integer timestamps are compared exactly,
never normalized through a lossy Double difference. Full date parsing, remaining
malformed jar/field behavior and Cookie Domain normalization remain issue #34
work. Broader numeric spellings require independent fixed-oracle controls before
extending the finite acceptance claim. No host implementation is needed.

Wget retains the lowest nonzero transfer exit code across URL operands, matching
the [GNU exit-status rule](https://www.gnu.org/software/wget/manual/wget.html#Exit-Status).
Usage and generic setup failures return before the transfer loop. A later
success does not clear an earlier failure. The previous implementation retained
the last failure, so network error 4 followed by HTTP error 8 incorrectly exited
8. `wget-exit-network-before-http` and `wget-exit-http-before-network` in the
[CLI cases](../../tests/cases/wget.json) assert both orders and a later successful
body, with the pinned Linux oracle route registered in the case index. This is
an unpublished workspace correction; the frozen 0.2.5 coordinate is unchanged.

Wget classifies every HTTP 401 as authentication failure and maps it to 6,
including absent credentials and missing or unsupported challenges. Other HTTP
errors remain 8; URL parse failures and unsupported input schemes return 1.
The earlier sent-Basic-only classification missed these 401 cases. Independent
fixed Wget controls retain their actual status and absence of extra requests.
Curl preserves its ordinary HTTP response behavior and maps both HTTP failure kinds to 22
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

Keep optional username and password separate until each hop resolves URL and
command options. URL fields override configured fields individually; empty
values prevent fallback while an absent password can use the configured one.
HTTP-specific options precede general options regardless of argv order. Wget
rejects empty URL usernames before connection setup. The command owns a
case-insensitive hostname challenge map across operands, discovery and retries;
this is Wget domain state. Registration happens when Basic is selected even
if authorization later fails. URL credentials neither register nor consume
this cache and use a separate per-hop challenge flag. Preserve explicit
Authorization fields on retry and Curl's existing initial-origin policy.

The 73 frozen controls in `tests/fixtures/network/wget-authentication.json`
cover real request order, statuses, streams, binary file-body replay and
unchanged inputs. Negative controls include absent passwords, invalid booleans,
other hosts and non-401 errors. New independent observations reopen this finite
profile. Digest/NTLM, netrc, configuration, password prompts, arbitrary stdin
replay and full URL grammar remain #34 work. Absent schemes, empty/zero ports,
signed ports, malformed IP literals and space-containing hosts need separate
grammar controls; this batch does not establish full URL parsing parity.

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

Header removal/semicolon syntax and header files, complete cookie-jar
serialization, configuration loading and stdin authentication replay remain
project work under issue #34. Extend the owning parser and protocol fixtures
before lifting these limits; no upstream list API is required. This batch does
not establish full curl/Wget parity or performance qualification.

## International URL hosts

The unpublished converter pins Unicode 15.0.0 mapping, derived IDNA categories,
canonical combining classes, general categories, bidi and joining properties
to the complete original inputs in `tests/fixtures/idna`. The pure MoonBit
generator verifies every input hash and full mapping coverage. The published
normalization and Punycode primitives remain implementation dependencies;
the complete original 19,074-record Unicode NFC corpus supplies independent
expectations. The adapter preserves libidn2 2.3.7's U+19DA override, per-label
bidi rules, known-CONTEXTO-rule policy, ContextJ checks, ACE round-trip and
length limits, and retries the entire original host transitionally after a
nontransitional failure. It must not mix output from the two attempts.

Curl selects UTF-8 input by the environment value's suffix, through LC_ALL,
LC_CTYPE and LANG precedence; C/POSIX rejects non-ASCII hosts. This does not
query installed host locales or reproduce `setlocale` failure. The pinned
oracle's differential acceptance covers its installed C and C.UTF-8 profiles;
unavailable names such as en_US.UTF-8 are a separate known boundary. Lifting it
requires a released public host-locale capability and real child-process
controls for installed and unavailable profiles on each platform.
Wget's fixed build defaults to ASCII input and enables
UTF-8 through `--local-encoding`. Its failed conversion retains the decoded
host. Percent decoding precedes conversion; already-ASCII hosts keep the
command's bypass behavior. Invalid UTF-8 and other legacy encodings have an
explicit rejection boundary. Full Wget IRI retry behavior remains open.

Canonical host fields are never reparsed as URL syntax. Mapping may introduce
slash, at-sign, colon or space characters, so relative redirects retain the
structured host, userinfo and port. Loop identity uses separate origin,
userinfo and request-target fields. DNS, SNI, Host, credential scope, cookie
selection and NO_PROXY comparisons share this canonical host; NO_PROXY tokens
themselves are not normalized. Original bracket syntax is tracked separately.
Only an original IP literal loses brackets for Curl cookie identity; fullwidth
brackets mapped by IDNA retain their host spelling and cannot obtain the HTTP
loopback exception for Secure cookies. Independent real proxy observations
exposed and constrain this distinction. The current proxy implementation always
uses CONNECT; fixed Curl's mapped-bracket ordinary forward-proxy path can fail
before sending a request, so its successful cookie comparison explicitly uses
the equivalent tunnel route. That difference does not establish full proxy parity.
Wget formats mapped colons in the outgoing Host field with brackets and omits
the scheme's default port, while retaining the canonical host/port internally.
Its fixed forward-proxy URL escapes host `@` as `%40`; raw assertions verify
that absolute target separately from Host and the workspace's origin-form target.

The private connection owner uses released TCP/TLS APIs. CONNECT headers are
read one byte at a time to retain any tunnel prefetch in the underlying public
reader, and nested TLS owns both layers for cancellation and failure cleanup.
Independent conversion probes and real command wire/transport observations
are separate requirements. The `network-idna` scenario records actual Host,
request target, Authorization and Cookie fields, preserving raw CONNECT and
HTTP requests. Source-derived definitions alone are not execution evidence.
Changing data, input profiles or transport ownership requires fresh immutable
oracle and cleanup controls. This scope does not resolve Cookie Domain
normalization, configuration loading, all proxy dialects or published acceptance.

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
