# strings

Version **0.1.3**. See the [support record](../../docs/compatibility.md) for release evidence.

Print printable byte sequences from files or standard input:

```sh
printf 'hello\000world\n' | moonx cli/strings
moonx cli/strings -n 6 -t d data.bin
```

The default minimum is four bytes. `-n`/`--bytes` changes it. TAB and
printable ASCII belong to a sequence; other control bytes end it.
`-e s`/`--encoding=s` selects 7-bit bytes (the default); `-e S` includes
8-bit bytes and preserves their raw output. Wide encodings `b/l/B/L` are
rejected before input is read.

`-t`/`--radix` accepts `d`, `o` or `x` for decimal, octal or hexadecimal
offsets, padded to at least seven columns. `-o` is octal; the last `-o` or
`-t` wins. `-f`/`--print-file-name` adds the filename; multiple input files
do not add it automatically. `-a`/`--all` and bare `-` select whole-file
scanning. With no files, stdin is read once.

`-s/--output-separator=STR` replaces the newline after each accepted string,
including the final one. An empty separator joins the runs without adding
bytes; repeated options use the last value. Prefixes and byte offsets are
unchanged, and a separator is not emitted for a run below the minimum.

Input is scanned in 64 KiB chunks. Once a run reaches the selected minimum,
its bytes are emitted incrementally; storage is bounded by the chunk buffer
and a candidate prefix shorter than the minimum. Offsets use 64-bit counters.

`--help` and `--version` are available. Object-section selection, locale
decoding and GNU Unicode rendering modes are not implemented.

## Standalone metadata

Standalone `--version` prints exactly `strings 0.1.3` followed by one
newline. Standalone `--help` starts with `Usage: strings`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
