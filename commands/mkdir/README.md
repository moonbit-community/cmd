# mkdir

Support note (2026-09-05): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it separates native compatibility evidence from Wasm policy and smoke evidence. Options mentioned here but not promoted in that record are not compatibility guarantees.

Create one or more directories. Supports recursive parent creation (`-p`),
numeric octal modes (`-m`), and verbose output (`-v`). Failed operands do not
stop later directories from being attempted.
