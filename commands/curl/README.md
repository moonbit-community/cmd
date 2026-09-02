# curl

Pure-MoonBit curl 8.22 migration. The Phase 2 HTTP/HTTPS slice streams to
stdout by default and supports multiple URLs, `-s`/`-S`, `-f` status 22,
`-o`, `-O`/`-OJ`, `-L`, `--max-redirs`, `-I`, repeated `-H`, the supported
`-X` methods, repeated `-d`/`--data-raw`/`--data-binary`/
`--data-urlencode`, `-T`, retries, `--connect-timeout`, `-m`/`--max-time`,
proxy/`--noproxy`, `-k`, and `--remove-on-error`.

Retry delay and retry-window values use upstream integer-second grammar and
are bounded by the millisecond timer range (`2147483` seconds). Connection and
total timeouts accept decimals; zero selects curl's disabled/default behavior.

curl does not follow redirects unless `-L` is present. `-s` suppresses the
meter and errors; `-sS` restores errors only. The meter never shares a terminal
with a body written to terminal stdout, and redirected stderr receives bounded
newline output rather than carriage-return spam. Failed fixed-length transfers
are detected; `--remove-on-error` removes a partial output file.

The command remains `partial`, not fully curl-compatible. Arbitrary extension
methods, byte-exact raw response-header/version display, compressed/HTTP2
negotiation controls, config/auth/cookie features, retry-after/backoff parity,
and curl's non-HTTP protocol families are not yet implemented. `-X` is limited
to GET, HEAD, POST, PUT, DELETE, CONNECT, OPTIONS, TRACE, and PATCH by the
closed public HTTP method enum and rejects other values before network side
effects. See `docs/spikes/2026-09-02-http-protocol-feasibility.md`.
