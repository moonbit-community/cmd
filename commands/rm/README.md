# rm

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Remove files, empty directories with `-d`, or directory trees with `-r`/`-R`.
Supports force and verbose modes. Recursive deletion never follows symbolic
links and refuses filesystem roots and normalized dot or dot-dot paths;
disabling root protection is intentionally unsupported. Operand failures do
not prevent later safe operands from being processed; the final status records
any failure.
