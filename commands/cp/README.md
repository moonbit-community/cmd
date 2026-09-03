# cp

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Copy regular files and directory trees with `-R`/`-r`. Supports
force/no-clobber selection (`-f`/`-n`), explicit target
paths (`-T`), and verbose output. Symbolic-link and special-file sources are
rejected because the portable runtime API does not expose a policy-checked
read-link operation.

`-a`/`--archive` and `-p`/`--preserve` (including an attribute list) are
recognized but fail before creating output because the portable API cannot
read and restore complete links, modes, ownership, and timestamps. See the
[support record](../../docs/compatibility.md).
