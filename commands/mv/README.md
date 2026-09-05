# mv

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Move files and directories with the policy-checked atomic rename operation.
Supports force/no-clobber/interactive selection (`-f`/`-n`/`-i`), update modes
(`-u`/`--update`), backup controls (`-b`/`--backup`, `-S`), explicit target
paths (`-T`), directory destinations, and verbose output. Cross-filesystem
copy-and-delete fallback is intentionally excluded because the portable runtime
does not expose an `EXDEV` discriminator. The source remains intact when rename
or backup commit fails.
The source remains intact when rename fails. See the
[support record](../../docs/compatibility.md).
