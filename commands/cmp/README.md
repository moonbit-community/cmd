# cmp

Version **0.2.2** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Compare two inputs byte by byte. Supports silent mode (`-s`), listing every
difference (`-l`), a byte limit (`-n`), and independent initial skips (`-i`).
`-b/--print-bytes` adds the differing octal values and visible byte notation
(`^@`, `^?`, and `M-` for controls and high bytes) to the first difference or
the `-l` listing. Listing offsets use the applicable input/limit width.
When FILE2 is omitted it defaults to stdin; `-l` and `-s` are rejected when
combined.
Exit statuses are 0 for equal, 1 for different, and 2 for an error.
Comparison and status selection remain byte-oriented under `LC_ALL=C`, and an
error takes precedence over a difference that could not be fully examined.
The frozen Linux C profile labels an ordinary first difference `char`; `-b`
labels it `byte` and includes the byte values.

## Standalone metadata

Standalone `--version` prints exactly `cmp 0.2.2` followed by one
newline. Standalone `--help` starts with `Usage: cmp`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
