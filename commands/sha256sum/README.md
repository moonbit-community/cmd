# sha256sum

Version **0.2.2** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Compute SHA-256 digests for binary input and verify standard checksum files
with `-c`. Supports stdin, multiple files, binary/text compatibility flags,
and NUL-delimited output with `-z`. Verification supports quiet/status-only
output, malformed-record warnings, strict parsing, and ignored missing files.
`-b` emits the binary `*` marker and `-t` the text-space marker; the last one
wins. With `--ignore-missing`, at least one listed file must still be verified.

The command uses the shared incremental checksum
engine. `--tag` writes BSD tagged records; verification accepts BSD/OpenSSL
tagged records, GNU standard records and consistently BSD-reversed records.
Ordinary output escapes backslash, LF and CR in filenames. `-z` disables
escaping. Verification reads manifests one line at a time and quotes result
filenames like GNU. `--quiet`, `--status` and `--warn` reset one another; the
last one wins. Status mode still reports actual read errors. Explicit `--tag`,
`-b/-t`, and `-z` cannot be combined with checking; `--tag` cannot use `-t`.
Malformed or empty manifests, strict checking, missing files and mismatches
follow the same rules as md5sum, sha1sum and sha512sum. Binary/text flags keep
input bytes unchanged on Windows. Candidate work does not alter frozen releases.

With no file operand, the command silently reads stdin until EOF, matching the
upstream terminal, pipe, redirection, and explicit `-` behavior.

## Standalone metadata

Standalone `--version` prints exactly `sha256sum 0.2.2` followed by one
newline. Standalone `--help` starts with `Usage: sha256sum`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
