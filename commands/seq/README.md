# seq

This documents version 0.2.3. The [support record](../../docs/compatibility.md)
tracks platform verification and exact-version publication evidence separately.

Print a numeric sequence using `LAST`, `FIRST LAST`, or
`FIRST INCREMENT LAST`. The default increment is always `1`, so `seq 3 1`
produces no output; use `seq 3 -1 1` to count down. Supports custom separators (`-s`) and
equal-width zero padding (`-w`). Decimal and exponent inputs use exact
fixed-point arithmetic, avoiding cumulative floating-point drift.
Without `-f`, numeric operands are limited to 4096 characters; their decimal
exponent and scale must each lie within -4096..4096. Larger values fail before
output.

`-f/--format` accepts one `e/E/f/F/g/G/a/A` floating conversion with literal
prefixes and suffixes, `%%`, numeric width and precision, and the flags
`-+ 0#`. An existing `L` modifier is accepted; dynamic `*`, integer conversions,
missing conversions and multiple conversions fail before output. Repeated
formats use the last value, and `-f` cannot be combined with `-w`.

The formatted path uses the frozen GNU Linux amd64 extended-precision profile
(64 significand bits and the x87 exponent range) with exact ties-to-even
conversion and rendering on every supported host and backend. It evaluates `FIRST + i * INCREMENT`
with binary rounding and applies GNU's format-dependent final-value recovery.
This preserves negative zero and exposes binary rounding at high precision;
it does not select the running host's long-double ABI or claim non-C locale.
The default exact-decimal path is unchanged.
Output is streamed through a bounded 64 KiB buffer without a fixed record-count
cap. `--version` reports the package version. The earlier published release
`cli/seq@0.2.2` uses the GNU-compatible default `+1`.
`--help` prints usage and `--version` prints the command and package version.

## Standalone metadata

Standalone `--version` prints exactly `seq 0.2.3` followed by one
newline. Standalone `--help` starts with `Usage: seq`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
