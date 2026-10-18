# pwd

Version **0.2.2** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Print the current working directory with `-L` and `-P`; the result follows the
host cwd contract. `-L` uses `PWD` only when it is an
absolute, dot-free path resolving to the current directory; otherwise it falls
back to the physical cwd. The default is `-P`, or `-L` when
`POSIXLY_CORRECT` is present; the last explicit `-L`/`-P` wins.

## Standalone metadata

Standalone `--version` prints exactly `pwd 0.2.2` followed by one
newline. Standalone `--help` starts with `Usage: pwd`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
