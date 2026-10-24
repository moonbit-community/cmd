# S matcher and sed workspace evidence

Date: 2026-10-24
Status: unpublished workspace candidate; current-revision validation pending, issue #28 open.

This records local implementation evidence, not stage or release acceptance.
Candidates are core 0.8.0, grep 0.3.0 and sed/expr/csplit 0.2.0. Existing
published coordinates and frozen expectations remain unchanged. The canonical
[support scope](../compatibility.md#workspace-matcher-and-sed-candidates) applies.

## Implementation

The pure MoonBit matcher parses C-byte BRE/ERE once into a private byte program.
Ordinary expressions use ordered Thompson threads, with literal/mandatory-prefix
paths. `find` retains byte capture spans and materializes only the chosen result;
`find_span` omits capture state when no backreference can observe it. Capturing
and backreference searches retain distinct states rather than merging histories
with different future behavior. An explicit stack imposes no hidden step cap;
ambiguous capture/reference inputs can require exponential time and memory.

Grep uses span searches; expr and sed substitutions retain captures. Csplit and
sed regex addresses use a capture-free predicate, matching GNU's calls without
output registers. Candidate pruning still runs; only output-register restoration
is omitted, which matters for ambiguous nullable backreferences. `grep_syntax` preserves
the exercised GNU grep interval/right-parenthesis rules. `ignore_case` defaults
to false and expands ASCII literals/classes before negation, preserves grammar
escapes, and compares references without changing original captured bytes.
Grep no longer lowercases regex source. Tac and nl are unchanged follow-ups.

Sed compiles labels/groups before opening input, then executes a PC with separate
pattern/hold spaces, substitution-success state and an append queue. Hold,
branch/group and `n/N/P/D/a/i/c` operations preserve the exercised address/range,
empty-regex reuse, multi-file, EOF, queued-output and missing-input behavior.
A streaming cursor uses a 64 KiB chunk and current record; lazy `$` evaluation
does not inspect unreachable later operands. Script-controlled spaces can grow
and branches need not terminate. In-place editing remains the ADR-0004 boundary.

## Local checks and observations

The workspace all-target strict check passed with `--no-mbti`. Focused package
runs totalled 35 tests per backend across core/grep, expr/csplit and sed; these
were separate Native/Wasm runs, not the entire repository suite. Sed passed
11/11 on each backend. All four affected consumer release builds completed.

The private sed observations matched status/stdout in 90 cases on each backend:
80 matched full streams; six static-error and four missing-input cases retained
explicit project diagnostic differences. The handoff and raw comparisons are
under `/private/tmp/cmd-sed-execution-spec-20261024/implementation.md`.
All 90 were adopted into the existing Case schema/registry: 80 marked `oracle=true`
and 10 project contracts with `oracle=false`. The old hold-space rejection case now
exercises supported `p;h`; static errors are checked before input effects.

The four-consumer runner selection recorded 530 rows: 521 pass, nine fail and
zero skip in `test-reports/s-current-contracts-20261024`. Six failures are the
two matcher cases below across Native/Wasm/backend-pair; three were stale sed
help expectations. After synchronizing help, the separate
`test-reports/s-help-fix-20261024` run passed all three metadata roles.
The original full report is retained; no single all-passing 530-row run exists.
All 90 newly adopted sed contracts passed in that full selection. The earlier
`test-reports/s1-new-regressions-20261024` retains 21 passes and six semantic
failures across the nine selected cases and three roles.

An intermediate profile checkpoint passed 15/15 core tests per backend and
57/57 focused consumer rows. Its retained report is
`test-reports/s-profile-boundaries-20261024`; those checks precede the final
GNU selection implementation below and do not validate its current source.
Current-source consumer, metadata, registry and platform checks remain required.

The existing intent/audit now records the retired expr/hold restrictions through
actual positive replacement evidence. Current rejections and old backend,
platform and observation obligations remain required, alongside each target's
current requirements.

## GNU repeated-capture selection

The user's subsequent 2026-10-24 direction restores the two remaining GNU
compatibility cases to this round. The matcher now selects candidate spans,
prunes incompatible paths and then restores capture registers. This handles
nullable captures copied by counted repetition, nested groups and multiple
references while preserving the ordinary matching path. The earlier compile-time
restriction is removed; the two stable sed IDs and consumer regressions exercise
supported behavior.

The private GNU comparison retained in
`/private/tmp/cmd-s1-nullable-20261024/run-15/summary.json` contains 1,098
observations: all 1,095 applicable cases match, with zero mismatches and three
GNU oracle faults recorded separately. Cases include adjacent bounds,
empty/nonempty inputs, nested captures, multiple references and unanchored
searches. These are local correctness diagnostics, not formal CI, resource,
published-consumer or performance acceptance.

## Development performance boundary

`/private/tmp/cmd-s1-development-20261024/{results,prefix-results}.md` retains
direct Native/Wasm observations at a source checkpoint with the same compiler, three samples
per cell. The prefix-only retest preserved earlier records and validated all
72 observations; at length 2048, no-match medians changed from 8.17 to 0.764 us
on Native and 330.5 to 69.3 us on Wasm. Unsupported old backreference rows have
no ratio. These are development diagnostics, not final-source, 105-pair,
MoonX delivery, resource acceptance or cross-command ranking evidence.

Current-revision coverage/platform CI, published consumers, formal performance
and overall stage acceptance remain pending. Issue #28 stays open until the
selected profile completes its remaining release and performance acceptance.
