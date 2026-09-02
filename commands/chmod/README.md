# chmod

Change numeric Unix-style permission bits through the policy-visible MoonBit
filesystem API. Supports octal modes, `-R`/`--recursive`, and `-v`/`--verbose`.
Symbolic modes, `--reference`, and symlink traversal are intentionally outside
this first portable implementation. On platforms where the runtime does not
provide chmod, the command fails instead of claiming success.
`--reference` is recognized and fails before mutation because current
permission bits cannot be read through the portable API. See the
[Phase 4 filesystem spike](../../docs/spikes/2026-09-03-filesystem-primitives.md).
