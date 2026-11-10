# wget

Download HTTP and HTTPS resources for MoonX.

```sh
moonx cli/wget@0.2.6 [OPTION]... [URL]...
```

## Supported scope

Download URLs or URL lists with resume, conditional requests, headers/bodies, retries, redirects, Basic authentication and cookies.

Version 0.2.6: multiple URL failures retain the lowest
nonzero transfer exit code, regardless of operand order. A later success keeps
that failure status and still writes its response body. HTTP 401 returns 6,
including absent credentials and missing or unsupported challenges; other HTTP
errors return 8. URL parsing and unsupported input schemes return 1. Network
failure 4 takes precedence over authentication failure 6, which takes precedence
over HTTP failure 8. The published 0.2.5
coordinate is unchanged; see [ADR-0005](../../docs/adr/0005-transfer.md).

The command recognizes Basic challenges in repeated WWW-Authenticate fields
and comma-separated challenge lists, preserving quoted commas and escapes.
Final response fields retain their order, casing and repetition after
optional-whitespace normalization. Same-name request headers still use the last
value; explicit Cookie headers continue across origins.

URL username/password fields take precedence individually. An omitted URL
password can use the configured password; an explicit empty password cannot.
HTTP-specific options precede general options regardless of argv order. A
missing password prevents Basic authentication; an empty password is valid.
Empty URL usernames reject before network access.

By default URL credentials wait for a challenge independently at each redirect
hop. Global option credentials cache challenged hostnames across ports, operands
and retries, including failed authentication. URL credentials neither seed nor
consume that cache. Explicit Authorization fields remain intact on retry.
`--auth-no-challenge` enables preemptive Basic; attached on/off, yes/no and 1/0
values are case-insensitive, with the last occurrence winning. Binary named-file
request bodies replay unchanged. This finite profile does not add Digest/NTLM,
netrc, configuration loading, password prompts or arbitrary stdin replay.

Cookie prefix names retain Wget's ordinary-name behavior. Secure cookies are
sent only over HTTPS; curl's loopback exception and prefix/admission/overlay
rules do not apply to Wget. Cookie dates follow the finite C-locale profile
below; remaining malformed jar grammar stays open under issue #34.
The command applies the complete pinned [ICANN/PRIVATE Public Suffix List](../../tests/fixtures/psl/README.md)
to ASCII response cookie domains and hosts, including wildcard and exception rules. Exact public-suffix
domains keep Wget's domain scope; imported files retain Wget's separate policy.
Earlier coordinates retain their recorded profile.

The `--local-encoding=UTF-8` option enables the pinned
[Unicode 15 IDNA profile](../../tests/fixtures/idna/README.md) for URL hosts,
including whole-host transitional retry. Like the fixed oracle build, default
raw non-ASCII input retains its spelling; percent-encoded UTF-8 hosts are
decoded and converted. Failed IDNA conversion retains the decoded host.
ASCII/US-ASCII/ANSI_X3.4-1968 explicitly select the default input profile.
Other legacy encodings, invalid UTF-8 bytes, the complete IRI retry dialect and
Cookie Domain normalization remain unsupported. Canonical hosts are retained
as structured fields across connection setup, redirects and cookie selection.
Outgoing Host fields bracket mapped colons and omit the scheme's default port.

## Options

| Option | Description |
| --- | --- |
| `-q, --quiet` | quiet (no output) |
| `--local-encoding=ENC` | Select UTF-8 or ASCII URL-host input. |
| `-O, --output-document=FILE` | write documents to FILE |
| `-o, --output-file=FILE` | log messages to FILE |
| `-a, --append-output=FILE` | append messages to FILE |
| `-i, --input-file=FILE` | download URLs found in FILE |
| `-c, --continue` | resume after the already written prefix |
| `-N, --timestamping` | do not re-retrieve unchanged files |
| `-t, --tries=NUMBER` | set number of retries (0 means unlimited) |
| `--retry-connrefused` | retry even if the connection is refused |
| `--retry-on-http-error=CODES` | retry comma-separated HTTP status codes |
| `--waitretry=SECONDS` | wait between retries |
| `--max-redirect=NUMBER` | maximum redirects (default 20) |
| `--content-disposition` | honor Content-Disposition filenames |
| `--header=STRING` | set a request header; last same-name value wins |
| `--user=USER` | HTTP Basic user name |
| `--password=PASSWORD` | HTTP Basic password |
| `--http-user`, `--http-password` | HTTP-specific credentials, before general option fallback |
| `--auth-no-challenge[=on\|off]` | control preemptive Basic, including redirects |
| `--load-cookies=FILE` | load a Netscape cookie jar |
| `--header='Cookie: ...'` | override jar cookies, including on redirects |
| `--save-cookies=FILE` | save persistent cookies |
| `--keep-session-cookies` | also save session cookies |
| `--no-cookies` | disable cookie storage |
| `--method=HTTPMethod` | use a supported HTTP method |
| `--body-data=STRING` | send STRING with an explicit --method |
| `--body-file=FILE` | send FILE with an explicit --method |
| `--no-check-certificate` | disable TLS certificate verification |
| `--no-proxy` | do not use proxy environment variables |
| `-T, --timeout=SECONDS` | set connect and read timeouts |
| `--connect-timeout=SECONDS` | set connection timeout |
| `--read-timeout=SECONDS` | set response inactivity timeout |
| `--idle-timeout=SECONDS` | extension: response inactivity timeout |
| `--help` / `--version` | Show help / package version. |

## Limitations

The command checks ASCII response cookie domains using the complete pinned PSL.
Admission folds ASCII case and strips leading dots without rewriting the
stored key. The fixed Linux Wget build disables NLS: a non-ASCII host or Domain
uses its older label heuristic instead of Unicode normalization. Exact matches
remain eligible; a parent needs a label boundary and at least two labels.
Two-label domains outside `.com`, `.edu`, `.net`, `.org`, `.gov`, `.mil`, `.int`
need more than three UTF-8 bytes in the second-level label. Consequently raw
`a.公司.cn` can accept `公司.cn`, while UTF-8 URL conversion changes the actual
host and admission result. This is the selected upstream dialect, not browser policy.
Wget then discards a matching stored name/domain/port/path even for an unexpired
update, after validating that an explicit Path prefixes the request path.
It strips one leading Domain dot and retains distinct repeated-dot keys.
Request cookie paths use raw prefixes; a missing Path uses the URL directory
including its trailing slash. Host-only response cookies from ports other than
80 and 443 retain that port in identity, request selection and jar persistence;
explicit Domain cookies and response cookies from those two default ports have
no port restriction. An explicit jar port remains restricted, including 80/443.
Imported jars use exact uppercase TRUE flags, ignore all comment lines including
`#HttpOnly_`, retain TABs in the last value column, and keep the first domain-chain
spelling. Matching name/value pairs are sent once even across different paths.
Single-label parent chains are excluded while exact single-label hosts remain
eligible; hosts with more than 32 labels do not receive jar cookies.
Quoted parameters and ASCII whitespace follow Wget's extractor; Secure ignores
an assigned value and HttpOnly is ignored. Empty Expires and Max-Age=-1 reject
the field; deletion remains sticky across later expiry attributes. Numeric expiry
accepts C-locale decimal/hexadecimal floating prefixes, including incomplete
exponents and numeric suffixes. Exactly -1 rejects a Max-Age update; only floating
zero requests deletion. A nonzero negative age retains an expired entry and its
domain-chain spelling. Expiry equal to the current second remains live; a
permanent zero timestamp remains live and can be saved without the session flag.
Imported zero timestamps become session cookies. Saved expiry integers use
binary64 rounding, matching the fixed Wget profile. Non-finite/out-of-range
conversion follows the observed Linux/amd64 oracle explicitly; it is not a
portable C guarantee.

Expires uses Wget's four ordered C-locale date formats (RFC 1123, RFC 850,
asctime and Netscape) with English weekday/month names. Two-digit years use
the 69 pivot; four-digit year fields accept one to four literal digits.
Days 1..31 and seconds 0..61 normalize through UTC calendar arithmetic, even
for a nonexistent day within that range. Weekday/date agreement is not checked.
A missing timezone, uppercase `GMT` prefix or signed digit prefix is accepted;
timezone offsets are ignored. Other suffixes reject the date, leaving previous
expiry operations intact. The timestamp -1 is rejected; zero parses as a valid
past date and requests deletion. This follows the fixed Linux/glibc oracle, including
ASCII spacing and field-width behavior; it does not claim every libc dialect.
Cookie Domain normalization remains separate work.

- Recursive mirroring, FTP, non-Basic authentication, HSTS and timestamp restoration are unsupported.
- Content-encoded bodies remain encoded. Consumed stdin request bodies cannot be replayed.
- Resume retains prior bytes without proving the server's earlier prefix is unchanged. Cookie Domain normalization and complete legacy input encodings remain unsupported.

## Examples

```sh
moonx cli/wget@0.2.6 -O page.html https://example.com/
moonx cli/wget@0.2.6 -q -O - https://example.com/
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0005-transfer.md)
