# G2 streaming decoder development evidence

The unpublished `cli/core@0.8.0` adds `gzipops.decode_reader`; existing
`decode(Bytes, ...)` adapts to it while its caller retains the input. The
`cli/{gzip,gunzip,zcat}@0.1.2` candidates read stdin/files directly through this
path. No package was published and final CI/release acceptance remains open.

One cursor spans optional gzip headers, DEFLATE, trailers and concatenated
members. It retains complete prefetched trailer bytes when aligning. Input and
output buffers are 64 KiB each, history is 32 KiB, and Huffman decoding uses
bounded main/secondary tables with a canonical EOF path. Output updates are
synchronous within a chunk; writes occur at chunk boundaries. Cleanup flushes
decoded prefixes on input/format failure without replaying a failed write.

## Correctness

All 30 codec tests pass on Native and Wasm. The six new tests cover real
one/two/seven-byte feeds, optional and long headers, every short-member
truncation, stored-block boundaries, secondary lookup/invalid trees, absent
history and read/write failure effects. Existing levels, dynamic overlap,
full-window encoding, CRC/ISIZE and member tests remain.

Both backends decode all 108 retained G1 streams: four corpora, nine levels,
and Native/Wasm/GNU encoders. All 216 outputs match every input byte. The final
implementation's record is `verify-tables.json` in the private evidence root.
The three frontend selections cover 25 Native/Wasm pairs, including named
files, CRC-prefix operand continuation and metadata (22 original passes plus
the three refreshed help pairs). Fifteen registered GNU differential cases
pass on each backend, including unchanged named files. These semantic oracle
runs use the existing immutable GNU 1.14 image, not the timing provider.

## Development timing and memory

These macOS arm64 observations compare saved G1 decoder artifacts with G2 and
native GNU gzip 1.14 using the same toolchain and fixed GNU level-six inputs.
Each arm has one warmup and three measured calls with rotating order. All 60
calls pass full-byte comparison outside the clock. Timing includes startup,
decoding, output and exit. VMs/builds were stopped; ordinary desktop apps stayed
open. This small sample is not the formal 105-pair published MoonX gate.

| 8 MiB decoded corpus | G1 Native ms | G2 Native ms | G1 direct Wasm ms | G2 direct Wasm ms | GNU ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| Repeated record | 174.98 | 36.69 | 584.49 | 74.77 | 8.26 |
| Repeated 32,000-byte block | 179.16 | 40.89 | 625.78 | 91.11 | 6.12 |
| Entropy | 285.75 | 31.89 | 852.17 | 57.41 | 11.72 |

For incompressible inputs growing from 8 MiB to 128 MiB, `/usr/bin/time -l`
reports these peak resident bytes. Every one of the eight measured outputs is
piped to native GNU `cmp` against its complete original, with pipeline exit 0.

| Decoder | 8 MiB input | 128 MiB input |
| --- | ---: | ---: |
| G1 Native | 11,288,576 | 137,150,464 |
| G2 Native | 2,572,288 | 2,654,208 |
| G1 direct Wasm | 39,927,808 | 293,339,136 |
| G2 direct Wasm | 23,035,904 | 25,378,816 |

Wasm includes moonrun. The new observations support bounded decoder storage;
they do not remove Bytes callers' input ownership. GNU remains faster in the
selected rows, so delivery performance and publication stay unfinished.

The temporary pure MoonBit observer, raw timing (`timing/`), memory records and
stream checks are retained in `/private/tmp/cmd-g2-development-20261024/`.
The separate `timing-crc/` experiment was removed from product source after
mixed results; it is not substituted for the final implementation's data.
