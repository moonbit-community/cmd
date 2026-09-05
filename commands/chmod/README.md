# chmod

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Change Unix-style permission bits through the policy-visible MoonBit filesystem
API. Supports octal modes, `-R`/`--recursive`, `-v`/`--verbose`, and closed
symbolic assignments such as `a=rwx` or `u=rw,g=r,o=`. For symbolic
assignments, `+/-`, omitted classes, `X/s/t`, permission copies, directories,
symlinks, and `--reference` remain rejected. Numeric directory and recursive
operation remains supported. Assignments are computed without reading the old
mode and all operands are validated before mutation.
`--reference` is recognized and fails before mutation because current
permission bits cannot be read through the portable API. See the
[support record](../../docs/compatibility.md).
