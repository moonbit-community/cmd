# cp

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Copy regular files and directory trees with `-R`/`-r`. Supports
force/no-clobber/interactive selection (`-f`/`-n`/`-i`), `-u`/`--update` modes
(`all`, `none`, `none-fail`, `older`), `-b`/`--backup` controls, `-S`, `-T`,
`-v`, and `-H/-L/-P` traversal. Non-recursive command-line symlinks are
followed; recursive traversal rejects links unless explicitly enabled. The
source tree, unsupported entries, cycles, and nested destinations are
preflighted before mutation.

`-a`/`--archive` and `-p`/`--preserve` (including an attribute list) are
recognized but fail before creating output because the portable API cannot
read and restore complete links, modes, ownership, and timestamps. See the
[support record](../../docs/compatibility.md).
