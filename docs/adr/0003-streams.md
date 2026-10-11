# ADR-0003: Preserve Streams and Caller Locale

Status: Accepted
Date: 2026-09-05
Updated: 2026-10-11
Revision: Repair strings and column against pinned oracles; remove seq's arbitrary output-count limit and document its numeric bounds.

## Target and decision

Preserve byte streams, final newlines and partial output. Set LC_ALL=C explicitly in differential fixtures; inherit caller locale in real commands. C-byte collation tests do not certify non-C behavior. Keep bounded sort and descriptor-follow tail as declared subsets.

## Alternatives and compatibility cost

Reject universal newline normalization, whole-output trimming and forced locale. Command substitution removes trailing LF only, preserving spaces and embedded newlines. Grep separators require requested context; base64 -w0 emits no newline. Full locale-aware comparisons remain unverified.

## Versions and evidence

Baseline: async 0.22.4, x 0.5.5, moonjq 0.1.2; MoonBit 2026-09-20.
Exact CLI contracts in tests/cases cover grep, base64 and shell substitution on both backends. The original audit records the previous mismatches; the original fidelity probe is retained in the 2026-09-21 evidence archive.
Historical results remain in [the audit](../reports/2026-09-19-command-fidelity-audit.md).
Candidate runtime results are recorded separately from published versions.

## Revisit when

Add locale profiles only when implementation and oracle evidence cover them; never rewrite the caller environment to hide a gap.

## Migrated text and binary profiles

The target remains each command's upstream behavior. These are bounded release
choices, not permission to reinterpret accepted upstream flags. Evidence below
uses MoonBit 2026-09-20, async 0.22.4 and x 0.5.5; the first eleven commands are
released at 0.1.1 and subsequent additions at 0.1.0. Per-command byte contracts
are in `tests/cases/<command>.json`; package tests and the three-platform release
reports are separate from full upstream differential certification.

| Commands | Choice and reason | Rejected alternative and compatibility cost | Evidence and condition for expansion |
| --- | --- | --- | --- |
| rev, tac | Reverse byte lines / fixed-separator records with exact LF handling; first release accepts stdin or one file to bound the initial implementation. | Do not decode invalid UTF-8 or normalize unterminated lines. Multiple files and tac `-r` are missing project features, not missing async IO. Whole-input reversal consumes input-sized memory. | `rev.json`, `tac.json`, 0.1.1 release report. Add ordered multi-file failures, regex empty/overlapping separator fixtures and bounded-memory tests before expansion; evaluate the shared byte regex without waiting for async. |
| expand, unexpand, fold | C-byte columns, explicit tab stops and control-byte rules; fold preserves input bytes and uses space breaks only when requested. Deterministic byte contracts require no terminal discovery. | Reject UTF-8 replacement decoding and assuming one code point occupies one display column. Non-C widths remain unimplemented; fold handles tabs/backspace/CR in column mode. | Their JSON contracts and fold package tests; expand locale claims only after wide/combining/malformed input and tab/control interactions pass the selected upstream oracle. |
| od, hexdump | Concatenate operands, zero-pad partial words, preserve duplicate-block and final-offset output. Default integer endian is explicitly little endian on tested targets. | No host delegation or pretending little endian is universal host-native format. od float/string/legacy-offset forms and hexdump `-e/-f` are project work. hexdump stdin seek rejects without a reliable seekability contract. | `od.json`, `hexdump.json` and formatter tests. Add endian-target evidence, format grammar and float edge cases; reopen stdin seek only when seekability is established. |
| fmt | Width/goal-based paragraph formatting with C-byte indentation, sentence spacing and no file rewrite; independent of terminal state. | Do not substitute fold or discard long words. Crown/tagged margins and prefix selection are deferred algorithm work; full GNU paragraph choices and locale widths are not certified. | `fmt.json`, `format_wbtest.mbt`; expand with exact paragraph/oracle fixtures covering margins, tabs, long words and goal ties. |
| strings | Whole-file C-byte scanning; GNU d/o/x offsets, last -o/-t selection, seven-column padding, TAB, explicit filename prefixes, s/S raw byte encodings. | Reject b/l/B/L before input until wide decoding is implemented. Reject the former binary-radix / single-byte -e b reinterpretations. No BFD/FFI or host fallback. Input is still buffered; locale/object sections remain project work. | Binutils 2.44, corrected JSON and package contracts; [repair evidence](../reports/2026-10-11-fidelity-repair/README.md). Open wide modes only after endian/minimum-length/offset/invalid-input differentials, and streaming only with equivalent partial-output behavior. |
| column | Default vertical column layout; -x row layout, explicit -c/COLUMNS/80 width; -t combines all files, preserves empty fields and emits LF with two-space defaults. | Buffer records to determine global widths. Reject copying input as default columnation and per-file independent tables. GNU/Linux C-locale non-ASCII bytes are escaped; non-ASCII delimiters reject. Terminal width discovery and full Unicode widths remain separate capabilities. | Util-linux 2.40, Native/Wasm byte contracts and Linux oracle; [repair evidence](../reports/2026-10-11-fidelity-repair/README.md). Add terminal discovery only with public terminal APIs; expand locale widths against versioned Unicode/locale data. |

Raw observations and exact invocations are in
[the follow-up audit](../reports/2026-10-11-command-followups/README.md).

`seq` streams without an arbitrary ten-million-record cutoff. Counting records
is unnecessary for separator placement; a boolean avoids both that semantic
limit and eventual counter overflow. Keep the explicit 4096-character numeric
operand bound and exponent/scale range -4096..4096 to bound BigInt allocation;
README/help and rejection contracts describe them. Arbitrary-precision input
growth remains project work, not async work. Remove these bounds only with
measured resource behavior and pre-output error tests; do not weaken normal
sequence output to enforce a test runner's budget.
The over-cap stress probe exposed the cost of two unbuffered writes per record.
Use the released public `io.BufferedWriter` with a 64 KiB buffer and an explicit
final flush. This bounds extra storage and preserves output bytes; partial
buffer visibility follows normal buffered CLI output. Per-record syscalls and
buffering the complete sequence were rejected. Retain the large-record-count
stress gate and ordinary separator/fraction/error contracts when changing this.
The second column review also compares controls and ANSI color sequences against
util-linux 2.40: table widths ignore complete control + `[` ... `m` sequences,
while the default grid retains its printable-character width rule. Output bytes
are preserved; this is not terminal detection or automatic color generation.
The [prioritized register](../command-followups.md) tracks fixes without
turning known defects into positive compatibility claims.
