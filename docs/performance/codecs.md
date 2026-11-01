# Codecs and Checksums

## Base32 and base64 encoding

Base32 follows `main -> convert -> encode_stream -> Base32Encoder::encode/finish`
in [main.mbt](../../commands/base32/main.mbt) and
[encode.mbt](../../commands/base32/encode.mbt). Encoding reads at most 64 KiB,
encodes complete groups with the byte kernel, then applies wrapping while
carrying the current output column. Base64 uses the analogous byte-group loop
in [encode.mbt](../../commands/base64/encode.mbt).

| Encoder | Complete group | State between reads |
| --- | --- | --- |
| Base32 | Five input bytes to eight symbols | At most four unfinished bytes and wrap column |
| Base64 | Three input bytes to four symbols | At most two unfinished bytes and wrap column |

Work is linear in input plus output size; chunk allocations depend on the read
bound and wrap width, not total input. Complete groups can be emitted before
EOF. Only successful EOF adds final padding and the wrapped trailing newline.
Read failure may leave completed output; write failure is not replayed. The
final newline rules for zero wrapping remain command-specific.

Base32 decoding still reads the complete input before decoding and retains its
existing partial-decoded-prefix rules. An encoding memory improvement says
nothing about that path. Tests preserve RFC vectors, all byte values, arbitrary
wrap columns, cross-read carry, open input and later read/write failures.

The `c4ea779` local macOS comparison qualifies all five base32 rows. Complete
source encoding takes about 7% less time unwrapped and 10% less time wrapped
against the original audit baseline. Separate 32 MiB resource probes reduce
peak RSS from 219–272 MiB to about 20 MiB. Small inputs and fragmented transports
have separate rows; these numbers are not command-wide guarantees.

## DEFLATE encoding

[deflate_encoder](../../core/gzipops/deflate_encoder.mbt) coordinates
[LZ matching](../../core/gzipops/deflate_lz.mbt),
[Huffman construction](../../core/gzipops/deflate_huffman.mbt) and
[block selection](../../core/gzipops/deflate_blocks.mbt). A 32 KiB history
supports 3–258-byte matches; levels vary search effort. Stored, fixed and dynamic
blocks are compared by complete coding cost over the selected chunks.

Preserve levels, input history, ties and valid output, rather than demanding
byte-identical GNU compression. Benchmarks decode the result independently and
compare the original bytes. Named replacement and metadata restoration remain
[filesystem boundaries](../adr/0004-filesystem.md).

## Buffered DEFLATE decoding

[inflate.mbt](../../core/gzipops/inflate.mbt) owns headers, block state, Huffman
trees, output history, CRC and trailers. Its
[ready-span loop](../../core/gzipops/inflate_ready.mbt) decodes synchronously
only while six input bytes are buffered, the upper bound for one complete
length/distance token. It consumes only the bytes needed by the actual codes.

`NeedInput`, `NeedOutput`, `MatchTail` and `EndBlock` return control to the I/O
owner. A decoded match crossing the output boundary saves its remaining length
and distance, flushes, then continues through the same overlapping history.
Exactly full output must flush before the next symbol. Short input uses the
ordinary decoder; complete short Huffman codes need not refill to table width.

Input/output windows are 64 KiB and history is 32 KiB. Reader decoding preserves
prefixes on CRC, truncation, trailer and read failures; failed writes cannot be
retried during cleanup. Bytes callers still retain their supplied input. These
are codec buffer bounds, not whole-process RSS limits.

The current code uses structured main/secondary Huffman entries and scalar CRC
updates fused with output expansion. The adopted ready-span loop is distinct
from earlier experimental packed-table/CRC bundles.

## Approaches already tested

| Approach | Why it is not in the current implementation | Condition for another trial |
| --- | --- | --- |
| Packed Huffman entries plus earlier buffered decoder | Incremental gains did not qualify the complete cumulative stored-block controls | Isolate representation from the current loop and qualify all codec artifacts and modes |
| Separate or deferred block CRC during expansion | Dynamic decoding regressed about 7–14% in the recorded trials | Avoid an additional pass while preserving overlap, test-only output and failure prefixes |
| Wider CRC16 slicing | Stored decoding regressed over 50% in a stable first window | Identify a different execution/layout mechanism; table width alone is not evidence |
| Flat CRC8 tables / direct DEFLATE symbol maps | Promising individual rows still failed complete stability gates | Preserve all stored/fixed/dynamic/member controls and establish a changed hypothesis |
| Unrolled LZ comparison | Qualified rows still cost about 2–3% with no compensating requirement | Demonstrate a concrete benefit on the same registered encoder workload |
| SHA-1 schedule/block trials | Source-file gains did not qualify every affected checksum artifact | Check all changed artifacts, block boundaries and chunk/padding cases |

The complete [historical trials](https://github.com/moonbit-community/cmd/blob/c4ea7795b0eb6e6fd6d0dffa0e7709809569bbb1/docs/adr/0003-streams.md#byte-ownership-and-crc-follow-up-2026-10-31)
retain failed windows and superseded intermediate acceptances. None of these
rejections means the current ready-span decoder is unadopted.

## Verification routes

`base32-byte-encoding`, `base64-byte-encoding` and `inflate-ready-spans` in
[protection.json](../../tests/benchmark/protection.json) bind current sources,
private regressions and real rows. Codec controls include stored/fixed/dynamic
blocks, concatenated members, overlapping copies, maximum distance, short input,
exact-full output, trailer ownership and failed writes. Checksum vectors and
incremental chunk tests live in [core/checksum](../../core/checksum/).
Keep codec algorithms separate from their command adapters and digest records.
