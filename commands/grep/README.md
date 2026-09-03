# grep

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Search text using MoonBit regular expressions or fixed strings. The observed
surface includes `-E`, `-F`, `-i`, `-v`, `-n`, `-c`, `-l`, `-L`, `-q`, `-H`,
`-h`, `-x`, `-w`, `-e`, `-f`, and recursive `-r`. Exit statuses are 0 for a
selected line/file, 1 for no selection, and 2 for an error in the verified
paths.
