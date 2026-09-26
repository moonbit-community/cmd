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
redirects. Premature fixed-length EOF is an error.

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

The legacy `fetch` and `fetch_with_options` entry points remain source
compatible and retain the original 30-second default. New command adapters use
`transfer_options` directly.

`CookieJar` uses async 0.22.4's public `Response.cookies` array, preserving
multiple Set-Cookie fields. Stores survive redirects and separate transfers;
request selection enforces host/domain and path boundaries, expiration and
Secure, with longer paths first. Netscape files preserve HttpOnly and session
state. A public-suffix database, IDNA and browser cookie-prefix rules remain
project work, not async API blockers. Response events expose reconstructed
Set-Cookie headers without promising original capitalization or attribute order.

Basic credentials are scoped to the initial origin. Callers choose preemptive
authentication or a single challenge retry; cross-origin redirects do not
forward those credentials. A challenge retry reopens file bodies, but refuses
to replay an already consumed stdin body.

The current workspace uses the public client's persistent headers and per-request
headers as separate layers. `CustomCookieMode::SeparateFields` sends stored
cookies before the explicit Cookie field (curl); `ReplaceStored` sends only the
explicit field while continuing to receive cookies (wget). Wget also enables
`custom_cookie_cross_origin`; curl leaves it disabled, independently of Basic
credential scope. This corrects the
0.2.0 rejection without new FFI or a replacement HTTP transport. It does not
provide arbitrary ordered repeated headers: each layer is still a map.
The response cookies array preserves each Set-Cookie field.

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
