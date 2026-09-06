# seq

Support note (2026-09-05): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it separates native compatibility evidence from Wasm policy and smoke evidence. Options mentioned here but not promoted in that record are not compatibility guarantees.

Print a numeric sequence using `LAST`, `FIRST LAST`, or
`FIRST INCREMENT LAST`. Two-operand sequences choose the unit step direction,
so `seq 3 1` prints `3`, `2`, `1`. Supports custom separators (`-s`) and
equal-width zero padding (`-w`). Decimal and exponent inputs use exact
fixed-point arithmetic, avoiding cumulative floating-point drift.
`--version` reports the published command version.
