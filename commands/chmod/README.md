# chmod

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Change numeric Unix-style permission bits through the policy-visible MoonBit
filesystem API. Supports octal modes, `-R`/`--recursive`, and `-v`/`--verbose`.
Symbolic modes, `--reference`, and symlink traversal are intentionally outside
this first portable implementation. On platforms where the runtime does not
provide chmod, the command fails instead of claiming success.
`--reference` is recognized and fails before mutation because current
permission bits cannot be read through the portable API. See the
[support record](../../docs/compatibility.md).
