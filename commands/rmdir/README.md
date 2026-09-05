# rmdir

Support note (2026-09-05): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it separates native compatibility evidence from Wasm policy and smoke evidence. Options mentioned here but not promoted in that record are not compatibility guarantees.

Remove empty directories. Supports parent removal (`-p`), verbose output
(`-v`), and ignoring failures caused only by non-empty directories
(`-I`/`--ignore-fail-on-non-empty`). Failed operands do not stop later
directories from being attempted.
