# zcat

Version **0.1.0** is a local candidate. The
[support record](../../docs/compatibility.md) distinguishes workspace checks from
published MoonX behavior; the examples become available after publication.

Write the decoded contents of gzip files to stdout, keeping the input files:

```sh
moonx cli/zcat first.gz second.gz
cat first.gz | moonx cli/zcat
```

With no file or with `-`, read stdin. Operands are processed in order. `-c` and
`-d` explicitly select the default stdout/decompression behavior; `-t` validates
without output. `-n` is accepted because stdout output never restores metadata.

Concatenated members, optional header fields and CRC/size checks follow the
same gzip behavior as `gunzip`. Compressed input is buffered and decoded bytes
are written in chunks. Invalid or truncated data returns 1, preserving any
decoded prefix; trailing garbage returns 2. `-q` suppresses trailing-garbage
warnings, and `--help`/`--version` provide command information.

Only gzip input is accepted. Other compression formats, filename suffix
searching, force/pass-through behavior and metadata restoration are not supported.
