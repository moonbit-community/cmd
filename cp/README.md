# cp

Copy regular files with bounded streaming buffers and copy directory trees with
`-R`/`-r`. Supports force/no-clobber selection (`-f`/`-n`), explicit target
paths (`-T`), and verbose output. Symbolic-link and special-file sources are
rejected because Moonrun does not expose a portable, policy-checked read-link
operation.
