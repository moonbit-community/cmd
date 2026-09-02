# wget

Pure-MoonBit GNU Wget 1.25 migration. The Phase 2 HTTP/HTTPS slice follows
redirects by default, streams bodies, accepts multiple URLs and `-i`, derives
remote filenames, numbers collisions, and supports `-O`, `-q`, `-o`/`-a`,
`-c`, `-N`, `-t`, `--retry-connrefused`, `--retry-on-http-error`,
`--waitretry`, `--max-redirect`, `--content-disposition`, `--header`,
`--method`, `--body-data`, `--body-file`, proxy environment variables,
`--no-proxy`, `--no-check-certificate`, and upstream timeout spellings.

Timeout values are bounded by the runtime millisecond timer range
(`2147483.647` seconds) and fail before network side effects when exceeded.

HTTP status failures return Wget status 8. `-q` suppresses all diagnostics;
`-O FILE` is truncated before the request, while the default remote-name path
is opened only after a successful response. Terminal progress uses one dynamic
stderr line; redirected stderr receives ordinary newline summaries. `-O -`
streams the response body to stdout.

The command remains `partial`, not fully Wget-compatible. Recursive/mirroring
features, authentication/cookies/HSTS, exact Wget diagnostic and progress
bytes, complete retry/backoff rules, post-download timestamp restoration, and
FTP are not yet implemented. `--method` is limited to GET, HEAD, POST, PUT,
DELETE, CONNECT, OPTIONS, TRACE, and PATCH because the current public HTTP
request type is closed. The command rejects other methods before network side
effects. See `docs/spikes/2026-09-02-http-protocol-feasibility.md`.
