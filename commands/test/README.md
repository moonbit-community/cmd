# test

Version **0.2.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Evaluate string, integer, file-kind, access, size, and nanosecond timestamp
predicates. In addition to `-e/-f/-d/-r/-w/-x`, the portable profile supports
`-L/-h`, `-p/-S/-b/-c`, `-s`, `-N`, and `-nt/-ot`. Logical negation, AND
(`-a`), OR (`-o`), and parentheses are supported. Exit status is 0 for true,
1 for false, and 2 for an invalid expression or runtime error. Missing files
are false; newer/older comparisons use GNU missing-side semantics.

Timestamp comparisons and positive special-file predicates are implemented,
but their complete backend/host combinations still need independent probes.
`-t` terminal detection, permission-bit/owner predicates, and same-file `-ef`
are not implemented. Public async file kind/time/access reads do not imply
public file identity or mode reads. File-access authorization belongs to the
caller or host.
