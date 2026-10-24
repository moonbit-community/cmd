# wc for moonx

Version **0.2.2** behavior is documented here. The
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

Only selected counters run. Byte-only mode accumulates chunk sizes, line mode
scans newline bytes, and character mode carries incomplete UTF-8 sequences
across the reused 64 KiB read buffer.

With no file operand, the command silently reads stdin until EOF; terminal,
pipe, and redirection paths do not receive a repository-specific prompt.

## Standalone metadata

Standalone `--version` prints exactly `wc 0.2.2` followed by one
newline. Standalone `--help` starts with `Usage: wc`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
