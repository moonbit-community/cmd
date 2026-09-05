# printenv

Support note (2026-09-05): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it separates native compatibility evidence from Wasm policy and smoke evidence. Options mentioned here but not promoted in that record are not compatibility guarantees.

Print selected environment values, or the complete environment when no names
are supplied. `-0` emits NUL-delimited records. Existing names are emitted in
operand order; any missing name makes the final status 1 without suppressing
values found earlier or later.
