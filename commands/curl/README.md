# curl

Pure-MoonBit curl 8.22 HTTP/HTTPS profile, version **0.2.0**. See the
[support record](../../docs/compatibility.md) for platform verification and
exact-version publication evidence.

Repeated literal `-b` values join with `; `, matching the pinned curl 8.22
request bytes. This differs from the earlier macOS curl 8.7 comparison.

The command streams HTTP/HTTPS responses to stdout or files and supports:

- `-s/-S`, `-f`, `-o`, `-O/-J`, `-L`, `-I`, repeated `-H`, and all documented
  HTTP methods through `-X` (`GET`, `HEAD`, `POST`, `PUT`, `DELETE`, `CONNECT`,
  `OPTIONS`, `TRACE`, and `PATCH`);
- ordered `-d`, `--data-raw`, `--data-binary`, and `--data-urlencode` values,
  including their documented `@file`, empty-value, and binary behavior;
- `-T` file/stdin uploads, multiple sequential URLs, retry controls, redirect
  limits, connect/total/inactivity timeouts, HTTP CONNECT proxies, proxy bypass,
  insecure TLS, and partial-output cleanup.
- `-u/--user user:password` Basic authentication; `-b/--cookie` literal cookie
  values or Netscape input jars, and `-c/--cookie-jar` output jars. A shared jar
  processes every response, including redirects, and matches domain, path,
  expiry and Secure attributes before sending cookies.

Redirect behavior distinguishes ordinary data from upload streams. An explicit
`-X` method remains explicit after a redirect; 301/302/303 can still discard a
`--data-*` body as curl does, while 307/308 and upload streams preserve their
body. Cross-origin redirects remove authorization headers.

`--max-redirs -1` is unlimited; zero disables followed hops. Zero for
`--connect-timeout`, `--max-time`, and `--retry-max-time` selects the documented
disabled/default behavior, while `--idle-timeout` must be positive. Timer input
is bounded by the runtime millisecond range.

Network authorization belongs to the caller or host. The command does not
embed an allowlist.

This remains a bounded HTTP transfer profile, not full curl compatibility.
Non-HTTP protocols, HTTP/2 negotiation, config files, non-Basic authentication,
interactive password prompts, exact native progress and diagnostic bytes,
and the rest of curl's option surface are not claimed. Cookie files use the
Netscape format; importing raw Set-Cookie header files, a public-suffix database,
IDNA, and curl's HTTP-localhost Secure-cookie exception are not implemented.
These are command implementation gaps, not limitations of async's public
cookie parser. Like curl, cookie-jar write failures do not change the transfer
exit status (verbose-mode warnings are not implemented).

The current workspace supports a custom `-H 'Cookie: ...'` together with
matching stored cookies as two separate request fields, with stored cookies
first. This correction is not included in published 0.2.0. Literal `-b` cookies
can be combined with stored cookies and preserve curl's ordering. Explicit
custom Cookie headers and literal `-b` data are scoped to the initial origin,
matching curl 8.22. Jar cookies are selected again for the
destination.
