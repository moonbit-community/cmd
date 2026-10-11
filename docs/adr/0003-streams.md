# ADR-0003: Preserve Streams and Caller Locale

Status: Accepted
Date: 2026-09-05
Updated: 2026-10-11
Revision: Record migrated text/binary profiles and buffering/locale costs; distinguish column/strings fidelity defects from intentional boundaries.

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
| strings | Initial whole-file C-byte scanning avoids an object-format dependency. Wide decoding and object-section selection are separately implementable. | No BFD/FFI or system strings fallback. Shipped `-t b` / `-e b` meanings, rejection of `-t d` / `-e s`, and TAB termination are **known fidelity defects**, not accepted GNU replacements. Automatic multiple-file prefixes also need correction/verification. | 2026-10-11 Native/Wasm/exact MoonX probes and GNU strings manual. Correct radix/encoding, TAB/minimum-length, offset padding and file prefixes against pinned binutils before closing; self-authored contracts alone are insufficient. |
| column | Initial `-t` field alignment buffers input for widths. Terminal-width discovery and Unicode display widths are not claimed. | Copy-through without `-t`, single-space padding conventions, per-file tables and dropped final LF are shipped behavior, **not faithful default columnation**. Layout/newlines are project work; do not label them async blockers. | 2026-10-11 probes record copy-through and missing LF on Native/Wasm/MoonX. Correct using fixed util-linux default/table, empty-field, multi-file, invalid-byte and newline comparisons; automatic terminal width remains a separate API gate. |

Raw observations and exact invocations are in
[the follow-up audit](../reports/2026-10-11-command-followups/README.md).
The [prioritized register](../command-followups.md) tracks fixes without
turning known defects into positive compatibility claims.
