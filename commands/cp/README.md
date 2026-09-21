# cp

This documents version 0.2.0. The [support record](../../docs/compatibility.md)
tracks platform verification and exact-version publication evidence separately.

Copy regular files and directory trees to new destinations with
`--no-preserve=mode` (and `-R`/`-r` for trees). Source modes cannot be read with
the public async 0.22.1 API, so default copying is explicitly unavailable.
New files use `0666 & ~umask`, and new directories use `0777 & ~umask`.
Supports `-T`, `-v`, and `-H/-L/-P` traversal. No-clobber (`-n`) and
`-u`/`--update` modes (`all`, `none`, `none-fail`, `older`) can select a no-op
without requiring copying capabilities. Non-recursive command-line symlinks are
followed; recursive traversal rejects links unless explicitly enabled. The
source tree, unsupported entries, cycles, and nested destinations are
preflighted before mutation for each source operand. Existing regular-file
overwrites are rejected because public file identity and truncation on the
same open handle are unavailable. This includes same-file and hard-link
aliases; no temporary-file rename is substituted for inode-preserving overwrite.
The parser accepts `-f`/`-i`, backup controls (`-b`/`--backup`) and `-S`, but
they do not enable replacement: overwrite requests fail during preflight,
before an interactive prompt or backup mutation. A successful new-file copy
with these flags does not establish their overwrite semantics.

`-a`/`--archive` and `-p`/`--preserve` (including an attribute list) are
recognized but fail before creating output because the portable API cannot
read and restore complete links, modes, ownership, and timestamps. See the
[support record](../../docs/compatibility.md).
