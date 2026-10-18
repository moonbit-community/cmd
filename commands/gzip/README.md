# gzip

Version **0.1.2** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

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
The published 0.1.2 baseline uses stored DEFLATE blocks. The unpublished workspace
with async 0.22.5 uses its public Encoder, which performs bounded LZ matching and
fixed-Huffman DEFLATE encoding with a 1 KiB history and matches up to 64 bytes.
Output can still be larger than its input. A 32 KiB compressor, dynamic-Huffman
block selection and compression levels remain planned work; the dependency
upgrade does not complete those features or establish ratio/performance claims.

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

## Standalone metadata

Standalone `--version` prints exactly `gzip 0.1.2` followed by one
newline. Standalone `--help` starts with `Usage: gzip`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
