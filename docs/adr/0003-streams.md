# ADR-0003: Preserve Streams and Caller Locale

Status: Accepted
Date: 2026-09-05
Updated: 2026-10-25
Revision: Extend selected split, reverse, numeric-dump and pipe-output profiles while retaining explicit stream and signal limits.

## Target and decision

Preserve byte streams, final newlines and partial output. Set LC_ALL=C explicitly in differential fixtures; inherit caller locale in real commands. C-byte collation tests do not certify non-C behavior. Keep bounded sort and descriptor-follow tail as declared subsets.

## Alternatives and compatibility cost

The unpublished core 0.8.0 line scanner owns one 64 KiB read buffer, tracks the
unconsumed range and uses the public single-byte search operation. It does not
rescan an accumulated prefix or copy the remaining chunk for each line. Only
cross-chunk records accumulate; returned lines own their bytes before refill.
Storage follows the largest record encountered plus a block, rather than the
number of records. The existing constructor/next calls and delimiter behavior
remain; the generated structural interface records the new state.

Plain cat copies reuse a 64 KiB buffer across operands. Wc computes only selected
counters. Its current candidate follows the frozen C byte profile: both -c and
-m count every byte, including malformed UTF-8, with no decoder or pending
sequence state. The earlier UTF-8 counter observations remain historical.
Strings retains a candidate prefix only until the requested minimum, then
streams its printable continuation with 64-bit input offsets.
Head batches record/byte/header output and flushes completed output on input
errors. Shared new-file copying uses a reusable 64 KiB buffer; this changes
neither replacement preflight nor filesystem capability decisions.
Sort prepares comparison keys once, carries stable sequence IDs through disk
runs and merges at most sixteen inputs. Its default 64 MiB budget counts
record/key payloads, bookkeeping and reserved buffers; active/oversized records
and runtime allocation overhead remain explicit additional costs. Preserve
first-representative unique behavior and error cleanup before raising the budget
or widening options; require measured RSS before claiming a memory cap.
These are implementation candidates with package and command regressions;
published coordinates and final performance acceptance remain separate.

Rev selects the fixed Linux C-locale util-linux 2.40 profile. It reverses
ASCII/NUL records without decoding and rejects a record containing a non-ASCII
byte before writing it. Completed records remain on stdout, their count appears
in the diagnostic, and later named inputs continue. PR #54's pinned Linux
Native/Wasm observation for `o6-rev-invalid-c-byte` establishes that behavior;
the older macOS provider's high-byte acceptance is not Linux parity.

Reject universal newline normalization, whole-output trimming and forced locale. Command substitution removes trailing LF only, preserving spaces and embedded newlines. Grep separators require requested context; base64 -w0 emits no newline. Full locale-aware comparisons remain unverified.

## O1 selected text options

The unpublished 0.2.2 candidates add cut complements/output delimiters, uniq
member/group output, comm column delimiters/totals, join ASCII-folded keys/
headers/automatic output fields, and wc total policies. Cut keeps distinct
adjacent explicit spans when an output delimiter makes their boundary visible.
Uniq retains only its current key and pending record; member output does not
buffer an entire duplicate group. Comm/join retain their streaming merge and
current equal-key runs. Default disorder diagnostics preserve the GNU output
prefix and continuation; explicit order checking stops early. Join's automatic
field counts freeze on the first record, and explicit output lists accumulate.

Wc total-only output has no per-input rows, names or padding. Opened inputs keep
their observed counters after a read error, and later inputs still run. Numeric
alignment for named files uses public kind/size metadata; standard input uses
the seven-column stream layout for multiple counters. Exact GNU alignment for
a regular file redirected to stdin is not claimed: released async 0.22.5 exposes
Input.fd but no public descriptor kind/size query or fd-to-File borrowing API.
Lift that layout limit only when such a public API and Native/Wasm regular-file/
pipe/partially-consumed/repeated-stdin regressions exist. This does not prevent
total-only output or named-file counting. Do not import internal event-loop
metadata functions or add host-process workarounds.

## O2-O4 sort, paragraphs and tab stops

Sort preserves sequence IDs for stable ties and first representatives. Random
ordering caches MD5(seed16 || transformed key), then the effective key for hash
ties, within the existing run format and accounting. Explicit sources consume
exactly sixteen bytes; an ineffective random-source option does not open its
source. A public random seed supplies ordinary `-R`. Merge assumes its inputs
are already ordered, as GNU does; it does not validate or repair them. This
corrects the optimization plan's earlier wording about merge validation.
Fatal errors use GNU status 2, including failed temporary-file creation. The
host policy regression retains the blocked-write diagnostic and empty stdout;
its earlier status-1 expectation belonged to the pre-O2 generic error handler.
Input read diagnostics are scoped to reads, so spool failures retain their
actual operation instead of being labeled input failures.

Ordinary named output consumes all inputs before truncating an existing file,
including an input alias. New output creation and late-read failures retain
their observed ordering. Existing streaming merge output retains the narrower
identity/error-effects limit in ADR-0004. No arbitrary PRNG shuffle, path-name
identity check or content hash substitutes for GNU behavior.

Fmt reuses its paragraph optimizer with first/continuation indentation and
prefix metadata. Split mode takes precedence over crown mode, then tagged
mode. Tagged paragraphs retain continuation indentation across paragraphs;
prefix spaces affect matching, and unmatched EOF records preserve their bytes.
Paragraph buffering and locale widths remain separate resource/profile work.

Expand and unexpand share one tab-stop parser and cursor. Repeated lists
accumulate; `/N` extends the absolute grid and `+N` extends from the last fixed
stop. Trailing zero suffixes follow GNU's no-extension behavior. Signed 64-bit
stops, backspace and ordinary CR columns remain byte operations. Unexpand's
first-only policy overrides explicit/all-by-tabs policy regardless of order.

Selected GNU cases and named package regressions supply Native/Wasm evidence;
private development observations remain distinct from committed PR/main,
formal performance and publication acceptance.

## O5-O8 and O13 stream candidates

Split uses bounded reads and owned spools for total-dependent layouts. Byte,
line-aligned and round-robin selection preserve empty partitions, elision,
suffix state and completed files on later failure. `--filter` supplies each
piece through a public pipe to the existing pure MoonBit Session, with `$FILE`
in its environment. Actual signal termination remains separate from an
ordinary exit 141; this adds no host-shell fallback or new shell language.
GNU 9.11's undefined alphabet indexing for hexadecimal FROM=a-f is outside the
parity domain; the workspace deliberately uses mathematical base-16 names.

Csplit's suffix descriptor compiles one selected integer conversion, flags,
width, precision and literal percent. Suppress-matched applies to the adjusted
split boundary, including repeated and negative-offset patterns. Rev and tac
process operands in order without invented separators. Tac compiles GNU Emacs
C-byte regexes and selects rightmost start/longest end, with explicit progress
for nullable separators. Resource acceptance for remaining whole-input/index
paths is still a separate R task.

Od decodes the frozen Linux amd64 float profile, including binary16, bfloat16,
binary32/64, x87 Extended80 and binary128, through the shared numeric package.
Its strings and traditional offset/label paths retain their own termination,
radix and option-conflict rules. Hexdump compiles custom formats into a small
format representation; raw `%c`/`%s` bytes, partial elements, multiple formats,
address/final-address units, iteration and explicit `_L` colors are observed
against util-linux 2.40. Automatic color behavior on an interactive terminal is
unclaimed without a public terminal query. Undefined/nonterminating upstream
format combinations are not golden contracts.

Forward hexdump stdin skip now reads/discards and preserves the equivalent
named-file display. This is a selected extension: the fixed util-linux 2.40
pipe path reports Illegal seek. The former boundary ID is a positive
oracle=false case, not a GNU-pipe parity claim. Xxd likewise reads/discards
forward stdin positions and uses public size/read-at for wide named-file seeks.
Backward/end-relative stdin requires a public seekable input; new output files
support reverse backpatching, while existing outputs retain ADR-0004's limit.
Cmp byte notation and strings output separators preserve C byte names and
unterminated accepted strings without a complete output buffer.

Tail `-z` selects NUL record boundaries while preserving final terminators,
positive origins, byte mode and ordinary multi-file headers. Tee's explicit
warn/warn-nopipe/exit/exit-nopipe and `-p` policies classify real public pipe
errors and preserve observed later-sink and prefix effects. The test scenarios
actually close stdout's pipe reader; their observations are status, stderr and
file type/content, not captured stdout. Default tee cannot restore GNU SIGPIPE
termination because the released runtime ignores it and exposes no public
restore/raise operation. It reports the registered exact status-2 rejection
with the created sink empty, rather than inventing signal status -13. Lift
this boundary only after a released signal API and actual Native/Wasm
closed-pipe termination/prefix/cleanup comparisons pass.

The new selected cases, named package tests, generated mktemp relationships and
closed-pipe scenarios remain source contracts pending the required platform,
coverage, actual-main and publication gates. They do not certify RSS bounds or
the formal direct-Wasm performance targets.

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
| rev, tac | Ordered operands; rev reverses ASCII/NUL lines under the frozen Linux C profile and tac supports GNU Emacs byte separators with nullable progress. | Rev rejects non-ASCII records before output; neither command performs multibyte-locale decoding or newline normalization. Whole-input/index resource acceptance remains separate R work. | `rev.json`, `tac.json`, production-reader package regressions and pinned Linux Native/Wasm observations; older release evidence remains frozen. |
| expand, unexpand, fold | C-byte columns, explicit tab stops and control-byte rules; fold preserves input bytes and uses space breaks only when requested. Deterministic byte contracts require no terminal discovery. | Reject UTF-8 replacement decoding and assuming one code point occupies one display column. Non-C widths remain unimplemented; fold handles tabs/backspace/CR in column mode. | Their JSON contracts and fold package tests; expand locale claims only after wide/combining/malformed input and tab/control interactions pass the selected upstream oracle. |
| od, hexdump | Concatenate operands and preserve partial words, duplicate blocks and final offsets; the O7 candidate adds the frozen Linux float ABI, strings/legacy offsets and custom hexdump format/color units. | No host delegation or inferred native ABI. Forward stdin skip is a documented read/discard extension; backward positioning needs a seekable input. | `od.json`, `hexdump.json`, numeric/format package tests and fixed-provider Native/Wasm development observations; PR/main and publication remain separate. |
| fmt | Width/goal paragraph optimization, crown/tagged margins and prefix selection with C-byte indentation and sentence spacing; no file rewrite. | Do not substitute fold or discard long words. Paragraph storage and non-C display widths remain separate work. | Current `fmt.json`, named regressions and O3 GNU margin/prefix/tab/EOF observations; PR/main and formal resources remain separate gates. |
| strings | Streaming C-byte scanning, GNU d/o/x offsets, last -o/-t selection, seven-column padding, TAB, filename prefixes, s/S encodings and selected output separators. | Reject b/l/B/L before input until wide decoding is implemented. No BFD/FFI or host fallback; locale/object sections remain project work. | Binutils 2.44 JSON and package contracts plus selected separator/cross-block development observations. Wide modes require endian/minimum-length/offset/invalid-input differentials. |
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
