# curl

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Pure-MoonBit curl 8.22 migration. The verified HTTP/HTTPS paths stream to
stdout by default and cover `-s`/`-S`, `-f` status 22, `-o`, `-L`, `-I`,
repeated `-H`, `-d`, GET, HEAD, redirect, POST, and output-file behavior. The
remaining help-visible transfer controls are listed as unverified in the
support record.

The observed `--idle-timeout 0` parse failure returns status 2. A successful
inactivity timeout expiry, timer-range behavior, retry windows, and other
timeout spellings are not claimed.

curl does not follow redirects unless `-L` is present. `-s` suppresses the
meter and errors; `-sS` restores errors only in the observed paths. The meter
and `--remove-on-error` cleanup require their own terminal/partial-transfer
probes before they can be treated as compatibility guarantees.

The command remains `partial`, not fully curl-compatible. A Wasm `-X` probe
using a nonstandard method reached the transfer path, so method validation and
endpoint behavior beyond the verified requests are not a compatibility claim.
Byte-exact raw response-header/version display, compressed/HTTP2 negotiation
controls, config/auth/cookie features, retry-after/backoff parity, and curl's
non-HTTP protocol families remain outside the observed profile. See the
[support record](../../docs/compatibility.md).
