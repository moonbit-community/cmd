# zcat

This documents the **unpublished workspace 0.1.2** candidate. The current
published release is **cli/zcat@0.1.1**. The
[support record](../../docs/compatibility.md) separates these profiles;
the examples select the published release.

Write the decoded contents of gzip files to stdout, keeping the input files:

```sh
moonx cli/zcat@0.1.1 first.gz second.gz
cat first.gz | moonx cli/zcat@0.1.1
```

With no file or with `-`, read stdin. Operands are processed in order. `-c` and
`-d` explicitly select the default stdout/decompression behavior; `-t` validates
without output. `-n` is accepted because stdout output never restores metadata.
Workspace `-1` through `-9`, `--fast` and `--best` are accepted and ignored by
decompression and testing.

Concatenated members, optional header fields and CRC/size checks follow the
same gzip behavior as `gunzip`. The workspace streams input and output through
64 KiB buffers, a 32 KiB history window and bounded main/secondary Huffman tables.
Invalid or truncated data returns 1, preserving any
decoded prefix; trailing garbage returns 2. `-q` suppresses trailing-garbage
warnings, and `--help`/`--version` provide command information.
The shared [workspace encoder](../gzip/README.md) uses pure MoonBit 32 KiB LZ
history, 3–258 byte matches, 64 KiB chunks and stored/fixed/dynamic cost selection.
The G1 frontend GNU cases pass on Native and Wasm; performance acceptance
remains pending. See the
[G1 development report](../../docs/reports/2026-10-24-g1-codec.md).
The [G2 report](../../docs/reports/2026-10-24-g2-streaming.md) records streaming
byte/error checks, direct timings and memory observations.

Only gzip input is accepted. Other compression formats, filename suffix
searching, force/pass-through behavior and metadata restoration are not supported.

## Standalone metadata

Standalone `--version` prints exactly `zcat 0.1.2` followed by one
newline. Standalone `--help` starts with `Usage: zcat`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
