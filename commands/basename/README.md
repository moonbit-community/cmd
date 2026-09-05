# basename

Support note (2026-09-05): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it separates native compatibility evidence from Wasm policy and smoke evidence. Options mentioned here but not promoted in that record are not compatibility guarantees.

Remove directory components from path operands. Supports `-a`/`--multiple`,
`-s`/`--suffix`, and NUL-delimited output with `-z`.

An empty operand produces an empty record; repeated separators and root paths
follow the coreutils byte-oriented path rules.
