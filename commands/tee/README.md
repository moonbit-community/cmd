# tee

Version **0.2.2** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Copy standard input to standard output and each file operand. The observed
`-a`/`--append` path appends instead of truncating files.
If one output cannot be opened or written, `tee` continues writing stdout and
the remaining outputs, then exits nonzero.

`tee` always reads stdin silently until EOF. Terminal, pipe, and redirection
paths do not receive a repository-specific prompt.

## Standalone metadata

Standalone `--version` prints exactly `tee 0.2.2` followed by one
newline. Standalone `--help` starts with `Usage: tee`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
