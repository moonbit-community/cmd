# curl

Pure-MoonBit curl 8.22 HTTP/HTTPS profile. The authoritative capability record
is [`docs/compatibility.md`](../../docs/compatibility.md); this README describes
the package-level P1 contract verified by the unified test runner.

The command streams HTTP/HTTPS responses to stdout or files and supports:

- `-s/-S`, `-f`, `-o`, `-O/-J`, `-L`, `-I`, repeated `-H`, and all documented
  HTTP methods through `-X` (`GET`, `HEAD`, `POST`, `PUT`, `DELETE`, `CONNECT`,
  `OPTIONS`, `TRACE`, and `PATCH`);
- ordered `-d`, `--data-raw`, `--data-binary`, and `--data-urlencode` values,
  including their documented `@file`, empty-value, and binary behavior;
- `-T` file/stdin uploads, multiple sequential URLs, retry controls, redirect
  limits, connect/total/inactivity timeouts, HTTP CONNECT proxies, proxy bypass,
  insecure TLS, and partial-output cleanup.

Redirect behavior distinguishes ordinary data from upload streams. An explicit
`-X` method remains explicit after a redirect; 301/302/303 can still discard a
`--data-*` body as curl does, while 307/308 and upload streams preserve their
body. Cross-origin redirects remove authorization headers.

`--max-redirs -1` is unlimited; zero disables followed hops. Zero for
`--connect-timeout`, `--max-time`, and `--retry-max-time` selects the documented
disabled/default behavior, while `--idle-timeout` must be positive. Timer input
is bounded by the runtime millisecond range.

Network authorization is supplied by the Wasm harness. The command does not
embed an allowlist: the policy suite proves both a denied connection and a
connection allowed only to a local fixture endpoint.

This remains a bounded HTTP transfer profile, not full curl compatibility.
Non-HTTP protocols, HTTP/2 negotiation, cookie/config/auth state, exact native
progress and diagnostic bytes, and the rest of curl's option surface are not
claimed.
