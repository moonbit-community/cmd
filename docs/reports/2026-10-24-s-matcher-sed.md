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

Grep/csplit use span searches; expr/sed retain captures. `grep_syntax` preserves
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

After the approved profile change below, core tests passed 15/15 on each backend
and the focused consumer report `test-reports/s-profile-boundaries-20261024`
passed 57/57 with no skips: 12 rejection rows, 30 supported contract rows and
15 backend pairs, including metadata. The final all-target strict check, four
consumer Native/Wasm release builds, registry/candidate validation and formatting
passed. Six current rejection bindings preserve compile-before-input/output
behavior; ordinary references, non-cloned star paths and the former expr/hold
rejection IDs have positive controls. The registry has 1,912 entries and 44
current boundaries. These remain local development observations.

The existing intent/audit now records the retired expr/hold restrictions through
actual positive replacement evidence. Current rejections and old backend,
platform and observation obligations remain required, alongside each target's
current requirements.

## Approved matcher boundary

The initial source failed the two bounded nullable-capture reference cases above
and adjacent private controls. On 2026-10-24 the user explicitly narrowed this
round's compatibility profile: reject a reference when its group body can match
empty structurally and repetition emits multiple closing-capture copies for that group.
This includes adjacent counted bounds, plus and cloning by an outer repetition;
it preserves nonnullable clones, single-copy bounds and non-cloned star paths.
Compilation raises `backreference to a cloned nullable capture is unsupported`.
The two stable sed IDs become rejection contracts, with corresponding consumer
error/effect cases. This is a project algorithm restriction, not an API gap.

The implementation adds structural nullability and emitted-program analysis at
compilation, without matcher-state changes or a second GNU cache/replay engine.
The rejected private filter remains outside the repository. Lifting the boundary
requires a coherent capture-selection algorithm and independent GNU controls
across adjacent bounds, empty/nonempty inputs, nested groups, multiple references
and unanchored searches. No full GNU/POSIX claim follows from the narrowed scope.

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
