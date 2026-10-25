# gunzip

This documents version **0.1.2**. The
[support record](../../docs/compatibility.md) tracks platform verification and
exact-version publication evidence separately.

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
`-1` through `-9`, `--fast` and `--best` are accepted and ignored by
decompression and testing; they do not change this command into a compressor.

Concatenated gzip members and optional name, extra and comment fields are
accepted. Header CRC, data CRC and uncompressed size are checked. A late format
error returns 1 without retracting bytes already written. Trailing garbage
returns 2 with a warning; `-q`/`--quiet` suppresses that warning. The command
streams compressed input through 64 KiB input/output buffers, a 32 KiB history
window and bounded main/secondary Huffman tables. It does not retain whole
compressed input or decoded output. The shared
[gzip encoder](../gzip/README.md) now uses 32 KiB LZ history, 3–258 byte matches,
64 KiB input chunks and stored/fixed/dynamic block selection. The G1 frontend
GNU cases pass on Native and Wasm; performance acceptance remains pending. See the
[G1 development report](../../docs/reports/2026-10-24-g1-codec.md).
The [G2 report](../../docs/reports/2026-10-24-g2-streaming.md) records the
streaming decoder's byte/error checks and resource observations.

Named-file replacement without `-c` is rejected. Other compression formats,
force/pass-through behavior, metadata restoration, recursive operation and
listing are not implemented. Use `--help` or `--version` for command information.

## Standalone metadata

Standalone `--version` prints exactly `gunzip 0.1.2` followed by one
newline. Standalone `--help` starts with `Usage: gunzip`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
