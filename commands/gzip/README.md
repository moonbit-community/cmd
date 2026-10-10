# gzip

Version **0.1.0** is a local candidate. The
[support record](../../docs/compatibility.md) distinguishes workspace checks from
published MoonX behavior; the examples become available after publication.

Compress stdin to a gzip stream, or use `-c -n` to compress named files while
keeping the originals:

```sh
printf 'hello\n' | moonx cli/gzip > hello.gz
moonx cli/gzip -cn notes.txt > notes.txt.gz
moonx cli/gzip -dc notes.txt.gz
moonx cli/gzip -t notes.txt.gz
```

`-d`/`--decompress` decodes, `-t`/`--test` checks compressed data without writing
decoded bytes, and `-c`/`--stdout` selects stdout. `-n`/`--no-name` omits saved
names and timestamps. Multiple operands are processed in order; `-` reads stdin.
The encoder emits valid gzip data using stored DEFLATE blocks, so output can
be larger than its input. Compression levels are not implemented.

Decompression accepts concatenated members, optional names, comments and extra
header fields, and verifies header CRC, payload CRC and size. Decoded bytes
already written remain visible if a later member or trailer fails. Zero padding
is accepted; trailing garbage produces a warning and status 2 (`-q` suppresses
the warning). Input and format failures return 1. Compression streams input;
decompression buffers compressed input and emits decoded chunks.

Named-file compression requires `-cn`; named-file decompression requires `-c`
unless only testing. In-place replacement, saved metadata, recursive traversal,
listing, force/pass-through modes and compression levels are rejected.
`--help` and `--version` describe this command.
