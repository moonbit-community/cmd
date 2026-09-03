# wc for moonx

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Count lines, words, and bytes without installing anything:

```sh
printf 'one two\nthree\n' | moonx cli/wc
moonx cli/wc -l notes.txt
```

Options: `-l` lines, `-w` words, `-c` bytes, `-m` UTF-8 characters. With no
flags it prints lines, words, and bytes. Counts are separated by single
spaces (not column-aligned like GNU wc). Multiple files get a `total` row.

With no file operand, the command silently reads stdin until EOF; terminal,
pipe, and redirection paths do not receive a repository-specific prompt.
