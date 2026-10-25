# md5sum

Version **0.1.2** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Compute MD5 digests for binary input and verify standard GNU checksum files
with `-c`. With no file operand, or with `-`, read stdin until EOF. Multiple
files are processed in order; an unreadable file does not prevent later files
from being processed.

```sh
moonx cli/md5sum file.txt
moonx cli/md5sum -c checksums.txt
```

`-b/--binary` emits the `*` marker and `-t/--text` the space marker; the last
flag wins. Both hash the original bytes. `-z/--zero` terminates output records
with NUL and disables filename escaping. Ordinary output escapes backslash,
newline and carriage return in filenames.

Verification supports `--quiet`, `--status`, `--strict`, `-w/--warn`, and
`--ignore-missing`; these options require `-c`. Ignoring missing files still
requires at least one file to be verified. Verification accepts uppercase or
lowercase digests, escaped filenames, comments and CRLF checksum files.
The command supports `--tag` output and verification of
BSD/OpenSSL tagged records. It reads manifests one line at a time, accepts
GNU standard or consistently BSD-reversed records, and quotes verification
filenames like GNU. `--quiet`, `--status` and `--warn` reset one another; the
last one wins. Status mode still reports actual file read errors.
`-z`, explicit `--tag`, and `-b/-t` cannot be combined with verification.
`--help` and `--version` are available. Exit status is 0 on
success and 1 for an invalid option, unreadable input or failed verification.

On Windows, text mode does not translate CRLF or treat Ctrl-Z as EOF. Use
binary mode for portable checksums of the same bytes.

## Standalone metadata

Standalone `--version` prints exactly `md5sum 0.1.2` followed by one
newline. Standalone `--help` starts with `Usage: md5sum`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
