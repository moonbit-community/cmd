# Ordering and Structured Data

## Sort: prepare once, preserve exact comparisons

The call path is [invocation](../../commands/sort/internal/driver/invocation.mbt) to
[input batching](../../commands/sort/internal/driver/input.mbt),
[key preparation](../../commands/sort/internal/order/keys.mbt),
[comparison](../../commands/sort/internal/order/compare.mbt),
[external runs](../../commands/sort/internal/driver/external.mbt) and
[output](../../commands/sort/internal/driver/output.mbt).

Input batches admit complete records synchronously. Field boundaries are indexed
once per record and selected ranges are borrowed during preparation. Plain
untransformed byte ordering is chosen once per invocation. Stable ties, reverse
ordering and the first unique representative remain part of comparison/output
state, not shortcuts inferred from a benchmark.

`-n` uses [exact decimal keys](../../commands/sort/internal/decimal/decimal.mbt): sign,
canonical integer digits and fractional digits. Comparison uses sign, integer
length and lexical digits; insignificant zeros do not alter equality. A bounded
integer fast path is exact only within its admitted digit range. General numeric
mode remains separate; arbitrary decimal prefixes must not be narrowed through
Float64.

Prepared explicit numeric fields store canonical digits and private framing in
run records. Memory grows with precision and is included in entry accounting.
Whole-record keys avoid eager prepared-field allocation. Cached run entries
decode synchronously when complete; refill and malformed/truncated frames keep
their error paths. The default accounted budget is 64 MiB with at most sixteen
merge inputs, excluding oversized active records and runtime overhead.

Sorting needs comparison work as well as input/output work; key preparation
reduces repeated parsing without removing comparison complexity. Spill creates
extra sequential I/O passes. Ordinary output consumes inputs before truncating
an existing destination; merge output retains the existing-target refusal.

Earlier broad numeric caches either penalized integer/spill modes or failed
stability. A later explicit-field implementation is adopted with exact decimal
storage; the old Float64 cache proposal is not the current algorithm. Any new
cache must preserve arbitrary precision, stable/unique/check behavior, marker
collisions and all six integer/fractional/spill controls. See the
[historical sort trials](https://github.com/moonbit-community/cmd/blob/c4ea7795b0eb6e6fd6d0dffa0e7709809569bbb1/docs/adr/0003-streams.md#sort-inputcomparison-and-diff-bytescript-pilots-2026-11-01).

## Diff and patch: bytes, keys and edit scripts

[Diff comparison](../../commands/diff/internal/compare/compare.mbt) separates original records
from comparison keys. Byte equality and delimiter scans avoid text round trips.
Identical outer records can leave the active search domain while retaining
context and absolute hunk positions. Sparse repeated-anchor
[discard rules](../../commands/diff/internal/compare/discard.mbt) precede the Myers search.

Bidirectional frontiers and an explicit subdivision stack bound auxiliary
reconstruction storage to O(N+M) records. Inputs, keys and result objects remain
additional allocations, and difficult edit structure still affects work.
Minimum edit count alone does not establish GNU-compatible repeated-record hunk
choice. Blank-only suppression also cannot delete blank records before matching.
[Output](../../commands/diff/internal/compare/output.mbt) appends original bytes while preserving
labels, context and missing-newline markers.

[Patch byte records](../../commands/patch/internal/hunks/bytes.mbt) keep full-source editing in
the byte domain; [hunk application](../../commands/patch/internal/hunks/apply.mbt) retains
offset/fuzz ordering, failed-hunk source regions and later successful hunks.
This avoids repeated conversions, not whole-input retention. Existing-file
mode-preserving replacement remains a filesystem boundary.

## Merge and structured-value paths

| Owner | Current mechanism | Contract that prevents a shortcut |
| --- | --- | --- |
| [comm](../../commands/comm/internal/driver/merge.mbt) | Synchronous merge of available borrowed records | Keep ordering diagnostics and own pending records across refill |
| [join](../../commands/join/internal/driver/main.mbt) | Group equal keys and batch complete output records | Duplicate groups require their output product; unpaired/header rules remain distinct |
| [jq input](../../commands/jq/internal/driver/cursor.mbt) | Scan each available byte chunk synchronously while framing complete JSON values | Quoting, nesting, concatenated values and late parse errors determine safe emission |
| [jq grouping](../../commands/jq/internal/filter/grouping.mbt) / [sorting](../../commands/jq/internal/filter/sorting.mbt) | Evaluate each key stream once, retain original values and preserve stable ties | Lexical bindings, empty/multiple keys and object key semantics cannot use debug-string equality |
| [seq](../../commands/seq/internal/driver/integer.mbt) | Checked Int64 admission and synchronous digit/output batches | Overflow, nonintegral values and formatted output use the exact numeric path |
| [cmp](../../commands/cmp/internal/driver/main.mbt) | Quiet byte-span comparison stops at the first mismatch | Reported differences, offsets and input-error ordering use their command-specific paths |

Jq's dependency comparator still limits exact numeric ordering at and above
2^53. The AST adapters and fixed Extended80 numeric profile are decisions in
[ADR-0008](../adr/0008-data.md); throughput tuning cannot silently change them.

## Verification routes

Use `sort-spill`, `sort-fractional-fields`, `diff-byte-pipeline`,
`patch-byte-records`, `join-record-output`, `comm-borrowed-merge`,
`jq-frame-chunks`, `seq-integer-batches` and `cmp-quiet-chunks` in
[protection.json](../../tests/benchmark/protection.json). Independent regressions
must cover exact large decimals, tiny spill budgets, duplicate ties, repeated
diff anchors, complete edit reconstruction and later I/O errors.

The real inventory includes genuine release-pair diffs and distinct copies for
equal-file comparisons. A same-path identity fast path cannot establish content
throughput. Report source size, record/key shape and spill mode separately;
startup-heavy small files do not reveal the same costs as large comparisons.
