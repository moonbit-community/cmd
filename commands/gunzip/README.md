# gunzip

Version **0.1.0** is a local candidate. The
[support record](../../docs/compatibility.md) distinguishes workspace checks from
published MoonX behavior; the examples become available after publication.

Decode gzip data from stdin, or write named compressed files to stdout with `-c`:

```sh
moonx cli/gunzip -c notes.txt.gz
moonx cli/gunzip -t notes.txt.gz
cat notes.txt.gz | moonx cli/gunzip
```

`-c`/`--stdout` keeps input files, `-t`/`--test` verifies without output, and
`-d`/`--decompress` explicitly selects the default decoding operation.
`-n`/`--no-name` is accepted; stdout decoding never restores saved metadata.
Multiple files and `-` operands are processed in order.

Concatenated gzip members and optional name, extra and comment fields are
accepted. Header CRC, data CRC and uncompressed size are checked. A late format
error returns 1 without retracting bytes already written. Trailing garbage
returns 2 with a warning; `-q`/`--quiet` suppresses that warning. Compressed input
is buffered, while decoded output is written in chunks.

Named-file replacement without `-c` is rejected. Other compression formats,
force/pass-through behavior, metadata restoration, recursive operation and
listing are not implemented. Use `--help` or `--version` for command information.
