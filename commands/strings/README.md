# strings

Version **0.1.1**. See the [support record](../../docs/compatibility.md) for release evidence.

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

`--help` and `--version` are available. Object-section selection, locale
decoding and GNU Unicode rendering modes are not implemented.
