# ls

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

List files without invoking a host command. Supports hidden entries (`-a`,
`-A`), directory operands (`-d`), type indicators (`-F`), one-entry-per-line
output (`-1`, the deterministic default), and recursion (`-R`). Long listing
is intentionally excluded because the portable runtime does not expose ownership
and permission metadata on every supported target.
