# seq

This documents version 0.2.3. The [support record](../../docs/compatibility.md)
tracks platform verification and exact-version publication evidence separately.

Print a numeric sequence using `LAST`, `FIRST LAST`, or
`FIRST INCREMENT LAST`. The default increment is always `1`, so `seq 3 1`
produces no output; use `seq 3 -1 1` to count down. Supports custom separators (`-s`) and
equal-width zero padding (`-w`). Decimal and exponent inputs use exact
fixed-point arithmetic, avoiding cumulative floating-point drift.
Numeric operands are limited to 4096 characters; their decimal exponent and
scale must each lie within -4096..4096. Larger values fail before output.
Output is streamed through a bounded 64 KiB buffer without a fixed record-count
cap. `--version` reports the published package version. The current release is
`cli/seq@0.2.1` and uses the GNU-compatible default `+1`.
`--help` prints usage and `--version` prints the command and package version.

## Standalone metadata

Standalone `--version` prints exactly `seq 0.2.3` followed by one
newline. Standalone `--help` starts with `Usage: seq`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
