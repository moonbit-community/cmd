# seq

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Print a numeric sequence using `LAST`, `FIRST LAST`, or
`FIRST INCREMENT LAST`. Supports custom separators (`-s`) and equal-width
zero padding (`-w`). Decimal and exponent inputs use exact fixed-point
arithmetic, avoiding cumulative floating-point drift.
