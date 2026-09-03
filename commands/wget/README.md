# wget

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Pure-MoonBit GNU Wget 1.25 migration. The verified HTTP/HTTPS paths cover
quiet stdout/file output, `-O -`, a POST request body, status 8 for a 404
response, and invalid idle-timeout status 2. Other controls in `--help`,
including input files, resume/timestamping, header/method edge cases, retry,
proxy, TLS, and default remote-name behavior, remain help-visible only until
separately probed.

The tested `--idle-timeout=0` input fails before transfer with status 2.
Successful timeout expiry, timer range, and other timeout-spelling parity are
not yet compatibility claims.

The tested HTTP status failure returns Wget status 8. `-q -O -` streams the
body to stdout without diagnostics in the measured paths. Default filename,
file-truncation ordering, terminal progress, and redirected-stderr formatting
need dedicated side-effect/TTY probes before they are compatibility claims.

The command remains `partial`, not fully Wget-compatible. Recursive/mirroring
features, authentication/cookies/HSTS, exact Wget diagnostic and progress
bytes, complete retry/backoff rules, post-download timestamp restoration, and
FTP remain outside the observed profile. A nonstandard `--method` probe ended
with endpoint status 8, so method validation beyond the POST path is not a
compatibility claim. See the [support record](../../docs/compatibility.md).
