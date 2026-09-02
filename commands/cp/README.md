# cp

Copy regular files with bounded streaming buffers and copy directory trees with
`-R`/`-r`. Supports force/no-clobber selection (`-f`/`-n`), explicit target
paths (`-T`), and verbose output. Symbolic-link and special-file sources are
rejected because the portable runtime API does not expose a policy-checked
read-link operation.

`-a`/`--archive` and `-p`/`--preserve` (including an attribute list) are
recognized but fail before creating output because the portable API cannot
read and restore complete links, modes, ownership, and timestamps. See the
[Phase 4 filesystem spike](../../docs/spikes/2026-09-03-filesystem-primitives.md).
