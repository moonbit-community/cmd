# test

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Evaluate string, integer, file-kind, access, size, and nanosecond timestamp
predicates. In addition to `-e/-f/-d/-r/-w/-x`, the portable profile supports
`-L/-h`, `-p/-S/-b/-c`, `-s`, `-N`, and `-nt/-ot`. Logical negation, AND
(`-a`), OR (`-o`), and parentheses are supported. Exit status is 0 for true,
1 for false, and 2 for an invalid expression or runtime error. Missing files
are false; newer/older comparisons use GNU missing-side semantics.
