# printenv

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Print selected environment values, or the complete environment when no names
are supplied. `-0` emits NUL-delimited records. Existing names are emitted in
operand order; any missing name makes the final status 1 without suppressing
values found earlier or later.
