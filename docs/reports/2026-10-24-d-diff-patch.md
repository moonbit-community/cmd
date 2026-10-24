# Diff and patch D implementation

Date: 2026-10-24. Unpublished diff/patch 0.2.0 candidates, selecting core 0.8.0.
This records development evidence before the PR and actual-main gates. It does
not change current registry coordinates or certify a new publication.

## Implementation and scope

Diff separates C-byte comparison keys from displayed records for case,
whitespace, blank-change and CR rules. It adds recursive and missing-side
directory workflows, byte-lexical traversal, GNU path quoting and per-side
diagnostics. Explicit labels stay literal. Bidirectional Myers frontiers,
explicit subdivision and GNU change alignment replace the growing edit trace.
Reconstruction uses O(N+M) auxiliary space; inputs, keys and results remain
additional allocations. No linear-time or constant-RSS claim follows.

Patch adds signed offsets, fuzz tiers, cumulative displacement, used regions,
batch reverse selection and mixed hunk results. Rejected hunks retain their
regions while later hunks continue. New unified/context reject files are
exclusive; several files can share this invocation's reject handle. Stdout
output supports multiple file patches; dry-run creates no target/reject file.
Pure insertions retain their logical positions beyond EOF while copying only
actual input. Existing parser coordinate bounds remain.

Existing-file and named-output mode preservation remain filesystem boundaries.
Existing reject replacement also refuses without damaging either file. Distinct
directory character/block devices need public device-number metadata; the
POSIX scenario checks actual rejection and unchanged links on both backends.
Its two temporary device symlinks are removed before artifact collection.
FIFO/socket reports and top-level readable streams are supported. Non-C locale,
interactive patch prompting and extended binary/rename/mode formats remain
outside this selected profile. See ADR-0004, ADR-0008 and the support record.

## Local validation

- All-target strict checking passes. Native and Wasm each pass 10 diff tests
  and 13 patch tests; the unchanged catalog regressions also pass on each.
- The final paired command selection records 251 passing contract, boundary,
  scenario and backend-pair rows, with no failed, infrastructure or skipped rows.
  It includes directory order/quoting, both missing operands, CR interactions,
  offsets/fuzz, mixed/shared rejects, EOF insertion and exact metadata.
- A separate development matrix of 356 repeated/blank input pairs and three
  output styles matches fixed GNU diffutils 3.12 in all 1,068 observations on
  each backend. Earlier failed checkpoints remain separate diagnostics.
- The benchmark package passes all 20 Native harness tests, including direct
  Wasm argument selection. An actual schema-2 correctness run starts the built
  cat Wasm through moonrun and records `direct-wasm`, without a coordinate or
  MoonX invocation. It has no performance verdict.
- The exact published-device executor has one passing launch/report-mapping
  harness regression. This does not execute an unpublished coordinate.
- Current candidate generation succeeds; frozen publication inputs stay intact.

Raw command records are under `/private/tmp/cmd-d-paired-20261024-final/`;
package/build logs are under `/private/tmp/cmd-d-final-validation-20261024/`.
Repeated-record observations are under
`/private/tmp/cmd-diff-repeat-native-20261024-3/` and
`/private/tmp/cmd-diff-repeat-wasm-20261024-1/`. Native GNU preparation and probe
cases remain under `/private/tmp/cmd-d-gnu-observations-20261024/`.

These precommit observations are local correctness evidence. Existing C1
prepare/verify/audit, required three-platform PR checks and actual-main
validation supply committed integration acceptance. Performance follows the
user's revised direct-Wasm contract; MoonX launcher timing is outside it.

## Direct Wasm development observations

The unchanged macOS arm64 Oct21 toolchain compares saved pre-D and current
release Wasm artifacts through the same moonrun, plus native GNU diffutils 3.12.
Each arm has one warmup and three measured fresh-process calls in rotating
order. Setup and complete output/status/stderr comparisons occur outside the
clock; the interval includes moonrun, command I/O and exit. No builds or other
benchmark children from this task run concurrently. Ordinary desktop apps stay
open. All 36 timing calls match complete GNU output and status.

| Workload | Before Wasm ms | D Wasm ms | GNU ms |
| --- | ---: | ---: | ---: |
| 8 MiB common prefix plus one changed final record | 329.290 | 346.324 | 7.333 |
| 1,024 disjoint records per side | 353.861 | 18.509 | 3.445 |
| 4,096 disjoint records per side | 6324.288 | 32.711 | 4.112 |

The disjoint-body path removes the growing trace cost. The common-prefix row
is about 5% slower in this small sample; input/record representation remains
resource-stage work. None of these rows establishes the formal 1.5x gate.

Separate `/usr/bin/time -l` observations include moonrun in peak RSS. All six
calls match complete GNU output and status:

| Workload | Before RSS MiB | D RSS MiB |
| --- | ---: | ---: |
| 8 MiB common prefix | 150.20 | 154.00 |
| 1,024 disjoint records | 244.08 | 25.84 |
| 4,096 disjoint records | 3566.02 | 28.39 |

These are observed process peaks, not a product memory cap or a full size/host
matrix. Raw trials, observer stderr, input/output files and the temporary pure
MoonBit observer are under `/private/tmp/cmd-diff-wasm-development-20261024/`
and `/private/tmp/cmd-diff-wasm-observe-20261024.mbtx`.
