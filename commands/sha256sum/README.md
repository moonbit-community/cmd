# sha256sum

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Compute SHA-256 digests for binary input and verify standard checksum files
with `-c`. Supports stdin, multiple files, binary/text compatibility flags,
and NUL-delimited output with `-z`. Verification supports quiet/status-only
output, malformed-record warnings, strict parsing, and ignored missing files.
`-b` emits the binary `*` marker and `-t` the text-space marker; the last one
wins. With `--ignore-missing`, at least one listed file must still be verified.

With no file operand, the command silently reads stdin until EOF, matching the
upstream terminal, pipe, redirection, and explicit `-` behavior.
