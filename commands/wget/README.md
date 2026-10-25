# wget

Pure-MoonBit GNU Wget 1.25 HTTP/HTTPS profile, version **0.2.3**. See the
[support record](../../docs/compatibility.md) for platform verification and
exact-version publication evidence.

The command supports:

- URL operands and repeated `-i/--input-file` lists with blank/comment-line
  handling and aggregate failure status;
- quiet mode, stdout/default/file output, `-o` log replacement, and `-a` log
  append behavior;
- `-c` range resume, and
  `-N` conditional requests that preserve output after 304;
- repeated `--header`, all documented `--method` values, and explicit-method
  `--body-data` or binary `--body-file` input;
- bounded/unlimited tries, connection-refused and HTTP-status retry controls,
  retry delay, redirect limits, `Content-Disposition`, and numbered filename
  collisions;
- combined/connect/read/inactivity timeouts, certificate verification control,
  environment HTTP CONNECT proxies, and explicit proxy bypass.
- `--user/--password` and their `--http-*` aliases for Basic authentication,
  available to redirected hosts after their own Basic challenge;
  `--auth-no-challenge` sends these explicit credentials on every request,
  including cross-host redirects, as GNU Wget does;
- response cookies shared across redirects and URL operands, Netscape
  `--load-cookies/--save-cookies` jars, `--keep-session-cookies`, and `--no-cookies`.

Default redirect rules remain Wget-specific: POST is rewritten on 301/302/303,
other methods are retained, and 307/308 preserve method and body.

The command percent-encodes raw ASCII space, TAB, CR, LF and DEL
in initial URL paths and queries using uppercase escapes. Already encoded
bytes remain unchanged. Redirect Location spaces become `%20` and TAB becomes
`%09` in both path and query. The calibrated complete-response cases succeed;
this does not establish general browser URL normalization.

Network authorization belongs to the caller or host. The command does not
embed an allowlist.

The command retains partial response bytes. Fixed-length truncation,
missing chunk-size lines and incomplete chunk payload CRLF report status 4
when network retries are exhausted. The calibrated GNU profile accepts EOF
inside an announced chunk's payload or while reading trailers, retaining all
delivered bytes. Retries reuse the actual selected file
name and request the next byte after the already delivered prefix. A 206
response must report that exact Content-Range before more output is written.
When the server ignores Range with 200, the existing prefix is retained and
the repeated response prefix is discarded before the remaining bytes are
appended. This preserves both streamed stdout and earlier URL output in a
shared `-O` file. It does not verify that a server has kept the earlier prefix
unchanged. Consumed stdin request bodies are not replayed on a retry. These
behaviors require exact-version published acceptance checks.
A complete known-length 200 response shorter than the retained prefix leaves that prefix
unchanged and succeeds. At the transfer layer, HTTP 416 succeeds without opening
or changing output, including without a resume request and with missing or
malformed Content-Range, matching the fixed GNU observations. Explicit `-O`
files are initialized before transfers, so their earlier creation or truncation
is separate from this response handling. Incorrect resumed 206 ranges fail with
status 4 before appending bytes. Ordinary 304 responses return 8; timestamping
treats 304 as successful preservation of the existing file.

For GET with `-c --content-disposition` and no explicit `-O`, a HEAD request
first discovers the selected filename. Only then is that file's size used for
the GET resume offset; an unrelated URL-derived file does not supply the prefix.
Discovery does not add an automatic resume Range, while an explicitly supplied
Range header remains a caller choice. GET retries retain the selected name.
These request-order and file-effect contracts require the current fixed-oracle
acceptance; they do not establish every method or redirect combination.

Requests default to `Accept-Encoding: identity` and preserve an explicitly
supplied header. Response content-coding bytes are written unchanged; retry
offsets refer to those encoded bytes. Automatic decompression is not enabled.
Resumed bodies must match the Content-Range byte span even for chunked or
close-delimited responses without Content-Length. Bodyless responses do not
consume the retained prefix.

The pure MoonBit HTTP/1 adapter retains received chunk payload even when its
following CRLF is missing or invalid. EOF after a complete 200 status line
accepts completed headers and ignores the unfinished field; malformed complete
headers still fail before the transfer opens output. Explicit `-O` initialization
still occurs earlier. The [shared transfer profile](../../core/netops/README.md) records
protocol metadata limits and framing support; these are project support choices.

This remains a bounded HTTP transfer profile, not full Wget compatibility.
Recursive mirroring, FTP, non-Basic authentication/HSTS, post-download timestamp
restoration, exact GNU progress and diagnostic bytes, and options outside the
documented package help are not claimed.

Version 0.2.1 lets an explicit `--header='Cookie: ...'` replace
the outgoing jar cookie field, including across origins, as in GNU Wget 1.25.0.
The jar still receives
response cookies. This correction is included in 0.2.1; historical 0.2.0 is unchanged.
Cookie matching includes host/domain boundaries, path order, Secure, Max-Age,
Expires, replacement and deletion. Public-suffix database and IDNA behavior
remain project implementation gaps. A challenge cannot replay an already
consumed stdin request body and fails explicitly; file and in-memory bodies
can be replayed. As in GNU Wget, cookie-jar write failures do not change the
transfer exit status; non-quiet runs print a diagnostic.

The command ignores a response Set-Cookie field without `=`
without failing an otherwise complete body. A replacement with nonnumeric
Max-Age is ignored, preserving the matching stored cookie. Positive decimal
overflow with fewer than 32 digits instead expires that cookie, including its
previous value; overlong attributes discard the replacement. Outgoing cookies
sort by descending domain and path byte length, then name and value byte order.
Repeated fields are processed in response order. Final response header observations retain
Set-Cookie field names, values and order separately from parsed storage, with
HTTP optional whitespace normalized; interim response cookies are not retained.
These behaviors require fresh Native/Wasm and fixed-oracle acceptance; they
do not establish byte-for-byte cookie-jar serialization parity.

## Standalone metadata

Standalone `--version` prints exactly `wget 0.2.3` followed by one
newline. Standalone `--help` starts with `Usage: wget`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
