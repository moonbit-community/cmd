# find

Observed Wasm profile (2026-09-04): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Walk directory trees without following symbolic links. Supports `-name` and
`-path` shell patterns, `-type`, `-xtype`, `-empty`, `-size`, `-amin/-atime`,
`-cmin/-ctime`, `-mmin/-mtime`, `-newer`, `-anewer`, `-cnewer`, `-newerXY`,
`-used`, `-readable/-writable/-executable`, depth limits, `-depth`, `-prune`,
negation, AND/OR composition, and newline or NUL output. `-exec COMMAND ... ;` runs one direct child per match, while
`-exec COMMAND ... +` batches paths in deterministic traversal order under a
64 KiB argument budget. `-delete` removes matching files and empty directories
in postorder.

This is a Restricted-tier command: Wasm hosts must allow file reads, and
process launches are required for `-exec`. Deletion additionally requires the
host's filesystem-mutation policy. Actions are parsed before traversal and
unsupported expressions fail without side effects. The profile does not follow
symlinks or claim ownership/link-target predicates or the full findutils
expression language. Time references are read once before traversal and all
entries share one fixed current-time sample.
