# mkdir

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Create one or more directories. Supports recursive parent creation (`-p`),
numeric octal modes (`-m`), and verbose output (`-v`). Failed operands do not
stop later directories from being attempted.
