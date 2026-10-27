# wc for moonx

Version **0.2.3** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

This version counts newlines and C-byte words with SIMD masks and carries word
state across blocks. Display-width requests retain scalar counting; -m and -c
still count bytes. Input buffers are 1 MiB.

Count lines, words, and bytes without installing anything:

```sh
printf 'one two\nthree\n' | moonx cli/wc
moonx cli/wc -l notes.txt
```

Options: `-l` lines, `-w` words, `-c` bytes, `-m` characters, and
`-L` maximum display width under the fixed C-locale profile. In this profile,
every input byte counts as a character, so `-m` and `-c` produce equal counts,
including for UTF-8 and malformed byte sequences. Other locale profiles are
not claimed. With no flags it
prints lines, words, and bytes. Named inputs use GNU's file-size-based alignment;
stdin uses the seven-column stream layout when multiple counters are selected.
A single selected counter for one input has no leading padding.
`--files0-from=FILE` reads NUL-delimited file names (`-` means stdin) and
cannot be combined with positional file operands.

`--total=WHEN` controls the aggregate row: `auto` (the default) prints it for
multiple inputs, `always` also prints it for one input or an empty file list,
`never` omits it, and `only` prints just the aggregate counters without names,
the `total` label or leading alignment spaces. Failed inputs still produce
diagnostics and a nonzero status; successful counts remain in the aggregate.
Repeated `--total` uses the last value; unambiguous value prefixes are accepted.
Read failures retain the counters already observed for an opened input and
continue later files. A failed open has no individual output row.

Only selected counters run. Byte and character modes accumulate chunk sizes;
line mode scans newline bytes. All modes reuse a 64 KiB read buffer.

With no file operand, the command silently reads stdin until EOF; terminal,
pipe, and redirection paths do not receive a repository-specific prompt.

## Standalone metadata

Standalone `--version` prints exactly `wc 0.2.3` followed by one
newline. Standalone `--help` starts with `Usage: wc`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
