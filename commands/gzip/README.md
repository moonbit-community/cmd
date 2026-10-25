# gzip

This documents version **0.1.2**. The
[support record](../../docs/compatibility.md) tracks platform verification and
exact-version publication evidence separately, including the frozen 0.1.1
stored-block encoder.

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
The encoder uses pure MoonBit LZ matching with a 32 KiB history and
3–258 byte matches. It compares complete stored/fixed/dynamic DEFLATE bit costs,
including headers and alignment, and can extend an open Huffman block. Input is
processed in 64 KiB chunks with bounded history, tokens and coding tables.
`-1` through `-9` select search effort, defaulting to `-6`; `--fast` aliases `-1`
and `--best` aliases `-9`. The last level option wins, including grouped short
options. Levels are accepted and ignored when decompressing or testing.
Compressed bytes need not match GNU's encoding. All nine levels pass the
direct Native/Wasm GNU roundtrips and selected size limits in the
[G1 development report](../../docs/reports/2026-10-24-g1-codec.md).
Published MoonX and performance acceptance remain open.

Decompression accepts concatenated members, optional names, comments and extra
header fields, and verifies header CRC, payload CRC and size. Decoded bytes
already written remain visible if a later member or trailer fails. Zero padding
is accepted; trailing garbage produces a warning and status 2 (`-q` suppresses
the warning). Input and format failures return 1. Both directions stream input
and output in bounded chunks. Decoding uses 64 KiB input/output buffers, a
32 KiB history window and bounded Huffman lookup tables; it does not retain the
whole compressed input or decoded output.
The [G2 development report](../../docs/reports/2026-10-24-g2-streaming.md)
records byte/error checks, direct timings and memory observations.

Named-file compression requires `-cn`; named-file decompression requires `-c`
unless only testing. In-place replacement, saved metadata, recursive traversal,
listing and force/pass-through modes are rejected. The public Bytes decoder
remains an adapter; its caller still holds the supplied bytes.
`--help` and `--version` describe this command.

## Standalone metadata

Standalone `--version` prints exactly `gzip 0.1.2` followed by one
newline. Standalone `--help` starts with `Usage: gzip`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
