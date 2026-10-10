# sha1sum

Version **0.1.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; this version is an unpublished candidate.

Compute SHA-1 digests for binary input and verify standard GNU checksum files
with `-c`. With no file operand, or with `-`, read stdin until EOF. Multiple
files are processed in order; an unreadable file does not prevent later files
from being processed. Hashing uses bounded memory for streams of any length.

```sh
moonx cli/sha1sum file.txt
moonx cli/sha1sum -c --quiet checksums.txt
```

`-b/--binary` emits the `*` marker and `-t/--text` the space marker; the last
flag wins. Both hash the original bytes. `-z/--zero` terminates output records
with NUL and disables filename escaping. Ordinary output escapes backslash,
newline and carriage return in filenames.

Verification supports `--quiet`, `--status`, `--strict`, `-w/--warn`, and
`--ignore-missing`; these options require `-c`. Ignoring missing files still
requires at least one file to be verified. Verification accepts uppercase or
lowercase digests, escaped filenames, comments and CRLF checksum files.
`-z` cannot be combined with verification. BSD tagged records and `--tag` are
not included. `--help` and `--version` are available. Exit status is 0 on
success and 1 for an invalid option, unreadable input or failed verification.

On Windows, text mode does not translate CRLF or treat Ctrl-Z as EOF. Use
binary mode for portable checksums of the same bytes.
