# split

Version **0.1.0** is a local candidate. The
[support record](../../docs/compatibility.md) distinguishes workspace checks from
published MoonX behavior; the examples become available after publication.

Split a file or stdin into consecutive byte-preserving pieces:

```sh
moonx cli/split -l 100 input.txt part-
moonx cli/split -b 64K -d --additional-suffix=.bin input.bin chunk-
```

The default is 1000 lines per piece and filenames `xaa`, `xab`, … . `-l`/
`--lines` changes the line count; `-b`/`--bytes` selects a byte count, accepting
`b`, `K`, `M`, `G`, `KiB`, `MiB`, `GiB`, `kB`, `MB` and `GB` multipliers.
A missing file or `-` reads stdin; the second operand changes the filename
prefix. Empty input creates no files, and an unterminated final line is retained.

`-d`/`--numeric-suffixes` selects numbers. Default suffixes grow as needed;
`-a`/`--suffix-length` fixes their width and reports exhaustion after retaining
the files already written. `--additional-suffix` appends a filename suffix.
Input is buffered before splitting. Counts are limited to a positive signed
32-bit value, and suffix widths to 1024 characters.

Existing output paths are refused and left unchanged. Chunk distribution,
line-byte mode, filters, numeric starting offsets and hexadecimal suffixes are
not implemented. `--help` and `--version` provide command information.
