# touch

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Create missing files and update the modification timestamp of existing regular
files without changing their bytes. `-c`/`--no-create` suppresses creation.
Symbolic links are rejected deliberately because this command does not follow
links for mutation.

`-a`, `-m`, `-d`, `-r`, `-t`, and `--time` are recognized but fail before mutation:
the portable API cannot select or assign arbitrary access/modification times.
See the [support record](../../docs/compatibility.md).
