# ls

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

List files without invoking a host command. Supports hidden entries (`-a`,
`-A`), directory operands (`-d`), type indicators (`-F`, including executable
`*`), one-entry-per-line output (`-1`), recursion (`-R`), reverse order (`-r`),
time/access/status sorting (`-t/-u/-c` and `--time`), regular-file size sorting
(`-S`), and `-H/-L/-P` link-following rules. Ties use C-locale byte order.
Long listing, ownership, permissions, inode/link counts, blocks, and full color
rules remain outside the portable profile. `-S` rejects a set containing a
non-regular entry before output.
