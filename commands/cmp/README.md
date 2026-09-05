# cmp

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Compare two inputs byte by byte. Supports silent mode (`-s`), listing every
difference (`-l`), a byte limit (`-n`), and independent initial skips (`-i`).
When FILE2 is omitted it defaults to stdin; `-l` and `-s` are rejected when
combined.
Exit statuses are 0 for equal, 1 for different, and 2 for an error.
Comparison and status selection remain byte-oriented under `LC_ALL=C`, and an
error takes precedence over a difference that could not be fully examined.
