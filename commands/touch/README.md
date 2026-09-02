# touch

Create missing files and update the modification timestamp of existing regular
files without changing their bytes. `-c`/`--no-create` suppresses creation.
Symbolic links are rejected deliberately because this command does not follow
links for mutation.

`-a`, `-m`, `-d`, `-r`, `-t`, and `--time` are recognized but fail before mutation:
the portable API cannot select or assign arbitrary access/modification times.
See the [Phase 4 filesystem spike](../../docs/spikes/2026-09-03-filesystem-primitives.md).
