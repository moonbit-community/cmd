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

Base32 decoding still reads the complete input before decoding. An encoding memory improvement says
nothing about that path. Tests preserve RFC vectors, all byte values, arbitrary
wrap columns, cross-read carry, open input and later read/write failures.

The `c4ea779` local macOS comparison qualifies all five base32 rows. Complete
source encoding takes about 7% less time unwrapped and 10% less time wrapped
against the original audit baseline. Separate 32 MiB resource probes reduce
peak RSS from 219–272 MiB to about 20 MiB. Small inputs and fragmented transports
have separate rows; these numbers are not command-wide guarantees.

## Base32 and base64 decoding

Base32 follows `convert -> read_input -> decode_to_writer -> decode_block`;
Base64 follows `main -> decode_stream -> stream.read_chunk -> decode_quad`.
Both byte decoders commit a byte after validating its contributing symbols,
before examining later symbols or canonical tail bits. Thus an invalid tail can
leave useful earlier bytes; validating an entire quantum before appending any
output would lose required failure prefixes.

At EOF, absent padding is completed only if the remaining quantum contains no
explicit `=`. A complete padded group does not prohibit a following group.
Incomplete explicit Base32 quanta fail before emitting any of their bytes;
Base64 retains determined bytes from that incomplete quantum. Canonical tail
masks and GNU 9.11 source contracts are recorded in
[ADR-0008](../adr/0008-data.md#search-and-codecs).

Base32 retains whole encoded input, then writes each decoded quantum; Base64
retains a quantum across reads and at most one read's decoded output. Decode
errors flush only the determined prefix. Normal writes and error-path writes
are outside any catch that could replay them. The package tests inject partial
writer failure and check its cause and exact write count; Base64 also crosses
the public 65536-byte read limit with a shifted quantum. CLI vectors in
[base32.json](../../tests/cases/base32.json) and
[base64.json](../../tests/cases/base64.json) have independent expected bytes.
These correctness changes make no new timing or memory-acceptance claim.

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

## International URL-host conversion

Added 2026-11-09; correctness work, without performance qualification.
`transfer -> ParsedUrl::for_transfer -> transfer_host -> idna_host` in
[url_wire.mbt](../../core/netops/url_wire.mbt) and
[idna.mbt](../../core/netops/idna.mbt) decodes host escapes, applies the selected
input profile, and then converts Unicode hosts. ASCII input takes the command's
bypass path. Unicode properties use binary searches over immutable sorted
Unicode 15 ranges, followed by the released NFC and Punycode primitives.

The mapping pass bounds emitted codepoints below 255 before NFC; encoded labels
are at most 63 bytes and the complete name is at most 253 bytes, or 254 with a
trailing root dot. Input scanning remains linear even when ignored characters
produce no mapped output. Intermediate normalized labels and validation arrays
are bounded by the admitted mapped host. The immutable generated tables add
artifact/startup cost; that cost has not been measured or accepted here.

Nontransitional failure retries the entire original host transitionally. It
does not concatenate labels converted under different modes. Fixed-profile
admission retains the pinned category override, ContextJ and bidi behavior and
ACE round-trip checks in [idna_validation.mbt](../../core/netops/idna_validation.mbt).
The canonical host remains a structured field: mapped slash, at-sign, colon
or brackets cannot become new URL syntax, credentials or a loopback exception.

Using the released generic IDNA converter directly was rejected because its
Unicode version and domain-wide bidi/fallback rules differ from the fixed
oracle. Reconsider that choice only when the public converter can select this
profile or an explicit compatibility decision advances the oracle. The full
independent data and regeneration command are in the
[fixture guide](../../tests/fixtures/idna/README.md); NFC corpus tests, private
converter controls and the [raw command scenario](../../tests/scenarios/network/idna.mbt)
establish different layers of correctness. [ADR-0005](../adr/0005-transfer.md#international-url-hosts)
owns input, proxy and cookie boundaries.

## Wget cookie selection and persistence

`HttpWire::read_response -> wget_wire_cookie -> CookieJar::receive` separates
field extraction from domain/path admission. The extractor scans quoted and
unquoted parameters once, preserving Wget's ASCII whitespace, quote and RFC
2231 adjustments. Response parsing retains the existing header limits; trusted
jar input does not gain a new size limit in this repair.

`CookieJar::replace` keeps the first domain-chain spelling and places each new
or replaced Wget cookie at the head. `header_for` selects domain, port, path,
expiry and Secure matches, orders domain chains, retains the last identical
name/value pair, then orders by domain/path quality and name/value. Pair
identity must precede serialization: `a=b` plus `c` differs from `a` plus `b=c`.
Sorting by quality before removing duplicates was rejected because it selects
the wrong path representative. Saving preserves chain order; reloading reverses
that order and can change the representative, which real two-process controls
observe explicitly.

The current array insertion and duplicate scans use quadratic comparisons in
the number of selected records, plus UTF-8 domain/path comparison costs. Extra
selection storage is linear. No timing or resource acceptance is claimed.
Any indexing optimization must retain the chain representative, replacement
order, port identity, jar failures and raw sequence in
[`network-wget-cookies`](../../tests/scenarios/network/wget_cookies.mbt), with
the frozen corpus in [network fixtures](../../tests/fixtures/network/README.md).
Numeric/date and Domain-normalization limits remain in ADR-0005.

## Verification routes

`base32-byte-encoding`, `base64-byte-encoding` and `inflate-ready-spans` in
[protection.json](../../tests/benchmark/protection.json) bind current sources,
private regressions and real rows. Codec controls include stored/fixed/dynamic
blocks, concatenated members, overlapping copies, maximum distance, short input,
exact-full output, trailer ownership and failed writes. Checksum vectors and
incremental chunk tests live in [core/checksum](../../core/checksum/).
Keep codec algorithms separate from their command adapters and digest records.
