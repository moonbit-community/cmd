# Codecs and Checksums

## Jq stream events

`run -> StreamInput::read -> emit` in
[stream_input.mbt](../../commands/jq/internal/driver/stream_input.mbt) scans a 64 KiB input
chunk with an explicit container stack and current path. A pending scalar is
committed only when its delimiter admits it; a completed root string has its
own earlier commit point. Empty containers are leaves, while nonempty endings
emit paths. Adjacent input files feed one reader without inserting bytes.
Reader failures preserve completed output; output failure stops evaluation
without replay. `--stream-errors` discards the remaining fixed jq CLI input
buffer after an error, then clears the parse stack and resumes. File EOF ends
that recovery buffer even when a successful token continues into the next file.

Parsing is linear in input plus emitted path bytes. The live parser retains
one chunk, one scalar and nesting/path state; a single huge string or deep path
can grow. Events copy their paths and the evaluator owns each result.
`--slurp` explicitly retains the complete event sequence. Decimal spelling in
[stream_number.mbt](../../commands/jq/internal/driver/stream_number.mbt) preserves coefficient
digits and bounded exponents without routing them through Double; arithmetic
still follows the existing evaluator. Whole-document parsing was rejected for
this mode because it loses early events and read/error ordering. The independent
[jq fixture](../../tests/fixtures/jq/stream.json), fragmented-reader and injected
failure tests govern this path; no timing or RSS acceptance is claimed.

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
[url_wire.mbt](../../commands/curl/internal/download/url_wire.mbt) and
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

Physical response callbacks in `core/netops` carry bytes through the command's
`http_headers.mbt` admission state before `http_wire_cookie` extraction. The
private one-byte projection used for Cookie grammar retains all octets; readable
header strings are never used to reconstruct wire bytes. Curl folds admitted
continuations and observes informational cookies; Wget keeps its distinct
control-byte and final-block rules. Both preserve admitted prefixes at EOF.
Configuration parsing stays at the CLI boundary, including Curl's typed
header-file provenance and Wget's distinct setting normalization.

Wget's domain table reproduces the fixed GNU hash-table slot iteration, growth
and deletion behavior. Jar saving groups records once, then walks domain slots
and each chain, using linear extra storage. Replacement, selected-cookie sorting
and duplicate scans retain their existing costs below. The fresh
[HTTP corpus](../../tests/scenarios/network/http_cookie.mbt) checks exact jar
bytes, second-process reloads, raw request fields and response effects. Neither
the table layout nor byte preservation establishes timing acceptance.

`HttpWire::response -> wget_wire_cookie -> CookieJar::receive` separates
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
Date profiles and Domain-normalization limits remain in ADR-0005.

Domain admission keeps an independent view of the stored key. The private
[`wget_cookie_domain_allows`](../../commands/wget/internal/download/wget_cookie_domain.mbt) uses
ASCII case-folded, leading-dot-stripped PSL lookup for ASCII inputs and the
fixed non-NLS Wget fallback for non-ASCII inputs. The latter counts labels
and UTF-8 bytes without IDNA or Unicode normalization. Actual URL conversion
occurs earlier and can select a different admission path. Both scans are
linear in their input lengths; splitting labels allocates linear storage.

Curl's stored creation order stays in the existing array. Saving selects Curl
entries through a backwards cursor, using linear time and constant extra cursor storage. A private live
marker distinguishes response cookies from file imports; reloading a file
cannot overwrite a response key. Loading before each URL/retry preserves real
file changes and deletion/refill behavior, with file I/O and parsing costs on
each transfer. Caching the first file contents would change observable behavior.
Expired response records retain their live marker until a cleanup boundary.
Saving after every Curl operand, but not between retries, provides one such
boundary; it also makes input/output aliasing and `-c -` observable. Expiry
cleanup scans the existing array linearly. Successful HTTP retry decisions stay
in the command layer after body completion, so no synthetic early HTTP error
can discard body bytes or replace the terminal status of a declined retry.
The [Domain scenario](../../tests/scenarios/network/cookie_domains.mbt) checks
two processes, raw Host/targets, unchanged inputs and original saved row order.

Numeric expiry uses the private [prefix parser](../../commands/wget/internal/download/wget_cookie_number.mbt).
It scans the C-locale prefix, delegates a valid decimal substring to the released
binary64 parser, and converts hexadecimal digits directly. The hexadecimal path
retains at most 53 significant bits plus guard/sticky state, rounds ties to even
once, and handles subnormal exponents before constructing a power of two. Its
digit scans take linear time and constant auxiliary space. Decimal conversion
retains the public parser's storage costs. No new maximum is imposed on imported
numeric fields; response Max-Age retains Wget's existing 31-byte maximum.

Ordered expiry operations preserve the original Double and explicit deletion
state until one jar timestamp is available. Converting immediately to Int64 was
rejected because a nonzero fraction, floating zero, rejected -1 and overflow
produce different mutation and persistence effects. Saving rounds Int64 through
binary64 but formats the integral magnitude directly, avoiding exponent notation
and preserving the oracle's rounded digits near 2^63. Fixed-clock tests own time
boundaries; [frozen CLI inputs](../../tests/fixtures/network/wget-cookie-expiry.json)
own real storage/reload expectations. This adds no performance acceptance claim.

Wget [date parsing](../../commands/wget/internal/download/wget_cookie_date.mbt) keeps four explicit
layouts in upstream order. A shared cursor scans English names, bounded decimal
fields and exact punctuation; format spaces consume zero or more ASCII spaces.
The numeric scanner preserves the range-dependent stopping rule, since adjacent
year/time fields can select an earlier format. Original text remains available
for the case-sensitive trailing GMT check. Starting at the month's first valid
day and adding day/time offsets implements UTC normalization without asking the
public calendar constructor to accept an invalid date. A valid result of -1 is
then rejected explicitly. Reusing Curl's permissive token scan was rejected
because it changes accepted grammar, year mapping and calendar normalization.
The field owner bounds input below 128 UTF-8 bytes; the fixed number of scans
is linear in that bounded input with one lowercase copy. The date corpus and
private regressions preserve these rules without establishing timing acceptance.

## Verification routes

`base32-byte-encoding`, `base64-byte-encoding` and `inflate-ready-spans` in
[protection.json](../../tests/benchmark/protection.json) bind current sources,
private regressions and real rows. Codec controls include stored/fixed/dynamic
blocks, concatenated members, overlapping copies, maximum distance, short input,
exact-full output, trailer ownership and failed writes. Checksum vectors and
incremental chunk tests live in [core/checksum](../../core/checksum/).
Keep codec algorithms separate from their command adapters and digest records.
