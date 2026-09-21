# wc for moonx

Version **0.2.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

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
