# dirname

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Remove the final path component. Multiple operands and NUL-delimited output
with `-z` are supported. Empty operands produce `.`, root remains `/`, and
repeated separators are handled without filesystem access.
