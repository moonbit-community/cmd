# rm

Support note (2026-09-05): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it separates native compatibility evidence from Wasm policy and smoke evidence. Options mentioned here but not promoted in that record are not compatibility guarantees.

Remove files, empty directories with `-d`, or directory trees with `-r`/`-R`.
Supports force and verbose modes. Recursive deletion never follows symbolic
links and refuses filesystem roots and normalized dot or dot-dot paths;
disabling root protection is intentionally unsupported. Operand failures do
not prevent later safe operands from being processed; the final status records
any failure.
