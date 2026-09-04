# wc for moonx

Observed native/Wasm profile (2026-09-04): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable unified-runner results and exclusions.

Count lines, words, and bytes without installing anything:

```sh
printf 'one two\nthree\n' | moonx cli/wc
moonx cli/wc -l notes.txt
```

Options: `-l` lines, `-w` words, `-c` bytes, `-m` valid UTF-8 characters, and
`-L` maximum display width under the fixed C-locale profile. With no flags it
prints lines, words, and bytes. Multiple inputs are aligned to the total width
and receive a `total` row, while a single input has no leading padding.
`--files0-from=FILE` reads NUL-delimited file names (`-` means stdin) and
cannot be combined with positional file operands.

With no file operand, the command silently reads stdin until EOF; terminal,
pipe, and redirection paths do not receive a repository-specific prompt.
