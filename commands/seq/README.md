# seq

This documents version 0.2.0. The [support record](../../docs/compatibility.md)
tracks platform verification and exact-version publication evidence separately.

Print a numeric sequence using `LAST`, `FIRST LAST`, or
`FIRST INCREMENT LAST`. The default increment is always `1`, so `seq 3 1`
produces no output; use `seq 3 -1 1` to count down. Supports custom separators (`-s`) and
equal-width zero padding (`-w`). Decimal and exponent inputs use exact
fixed-point arithmetic, avoiding cumulative floating-point drift.
`--version` reports the built package version. The published `cli/seq@0.1.5`
still uses the earlier automatic descending-step behavior; the default `+1`
change requires the candidate build.
