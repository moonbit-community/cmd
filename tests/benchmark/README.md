# Direct-Wasm benchmark workloads

## Current declared scope (2026-10-31)

`real.json` is the single active timing inventory. Its 125 data-driven rows
cover 40 commands. `real-coverage.json` records the full 43-command scope,
including explicit correctness-only dispositions for ln, make and sh. Those
three commands have independent local contract witnesses; they have no
real-source timing claim. These are inventory counts, not execution results.

The inventory reuses 31 complete source files totaling 22,152,148 unique
payload bytes. Each measured source is at most 16 MiB, and the complete source
budget is 64 MiB. `tests/fixtures/benchmark/real-sources.json` pins the byte
counts, SHA-256 identities, provenance, immutable source locations and license
records. Sources include standards and Unicode data, ordinary source code,
CSV/JSON data, a genuine PNG, an empty Python module, an unterminated HTML
file and a genuine minified long record. There is no repetition, padding,
truncation or generated size-budget input.

Every verdict applies to the exact command mode, sources, input transport and
output sink that ran. Reports retain `general_performance_acceptance: false`,
`upstream_parity: false` and `blind_holdout: false`. The source selection is
known evaluation data, not demonstrated blind data or a workload-frequency
distribution. Missing required rows, failed correctness, incomplete windows
and unstable timing cannot pass. Gains in other rows do not compensate for a
loss.

New timing accepts schema 3 only, with explicit frozen direct-Wasm artifacts.
The former pilot, generated matrices, schema-2 replay, command-specific rg
launcher and independent synthetic timing system have been removed. Their
definitions, tests, dated outcomes and disclosure workflow remain recoverable
from Git checkpoint `8c4efe2` and the external B0 evidence. There is one active
source catalog and one timing engine; resource observers have a separate
measurement purpose.

## Prepare complete checked sources

Use a fresh absolute output directory. Existing complete sources and checked
upstream archives can be reused through one or more `--from` roots; explicit
download mode fetches registered upstream sources. These examples are
alternatives:

```text
MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/benchmark/prepare_real_corpora.mbtx -- \
  /absolute/new-corpus --from /absolute/existing-corpus
MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/benchmark/prepare_real_corpora.mbtx -- \
  /absolute/another-new-corpus --download
```

The preparer verifies actual byte counts and SHA-256 before admitting each
complete source. Missing or changed files fail; it never substitutes a
generated approximation. Download/extraction uses the host curl, tar and unzip
setup tools outside timing. Upstream archive containers have a separate bounded
setup allowance; they are not measured payload files.

Input collections map genuine files to declared fixture paths. Distinct copies
preserve full bytes. Pair comparisons use complete genuine files. The only
declared semantic preparations are sorting/key projection for join and comm,
codec encoding and distinct-file copies. Decoder rows retain their genuine
decoded source alongside registered stored, fixed-literal, dynamic or
concatenated-member encodings. Synthetic distance/overlap stress remains a
correctness regression rather than real-source timing evidence.

## Run the generic suite

Build the product Wasm before starting. `run.mbtx` rebuilds both the Native
benchmark observer and correctness driver in release mode with warnings denied,
then supplies that just-built driver. External driver overrides are rejected. Native is a test tool and calibration reference; product
correctness is exercised through frozen release Wasm.

```text
MOON_HOME="$HOME/.moon-accounts/cli" moon build --target wasm --release
MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/benchmark/run.mbtx -- panels \
  --wasm-root /absolute/current-artifacts \
  --baseline-wasm-root /absolute/frozen-baseline-artifacts \
  --moonrun /absolute/moonrun \
  --oracle-bin /absolute/native-oracle/bin \
  --corpus-root /absolute/prepared-corpus \
  --report-dir /absolute/new-panel-report
```

Artifact roots contain `cli/COMMAND/COMMAND.wasm`, or directly
`COMMAND/COMMAND.wasm`. `--commands cat,wc` selects applicable command rows;
empty, unknown and duplicate selections fail. Omit `--baseline-wasm-root` for
a native-reference observation. The selected manifest, coverage registry,
source catalog, local case definitions, inputs, tools, runtime and command
artifacts are frozen and checked again after execution. Use a fresh report
directory and a quiet host; builds, tests and other timing jobs must not overlap.
The wrappers build the current driver and reject an external override. Direct
binary calls freeze the explicitly supplied driver but cannot certify its
source freshness by themselves.

Before timing, the independent local-contract stage executes the declared
finite boundary witnesses against the same frozen candidate Wasm. Per-case
ownership, expected results and applicable platform rules matter; a count or
a scenario pass tag cannot replace the assertions. These witnesses cover
functional boundaries such as EOF, errors, stateful behavior and filesystem
effects. They do not establish a throughput or resource claim.

The actual real-source invocation also receives a native correctness
calibration outside old/new timing. Candidate and old Wasm must agree with the
declared native relation, rather than making two identically wrong artifacts
a pass. Native `wc` runs with `POSIXLY_CORRECT=1` under `LC_ALL=C` to match
the documented C-byte whitespace profile. A verified immutable oracle profile
is still required for upstream parity; executable hashes alone do not establish
source provenance.

`panels` now means two windows of this one generic inventory. Each window
has a correctness pair, a warmup pair and nine alternating measured pairs;
the second window reverses its initial order. Each side needs positive finite
durations and MAD/median at most 5% per window. The two medians for each side
may differ by at most 10% of their mean. With an old Wasm baseline, every row
also requires a candidate/baseline median ratio at most 1.05 in each window.
Native ratios without an old baseline remain observations. No automatic retry,
sample removal or aggregate score hides a failed row.

## Inputs, effects and transport evidence

Actual source observations include full-file SHA-256, bytes, LF and record
counts, unterminated tails, record-length extrema, row/byte-weighted histograms,
NUL/non-ASCII bytes and duplicate records. Declared data and transport facets
require actual observations; a catalog label alone is insufficient. The 105
reviewed command/mode contracts in `real-coverage.json` pin 107 distinct
argument/preparation/status combinations independently of workload row IDs.
Operation facets must match those exact contracts as well as native calibration
and independent local correctness. They describe requested operations rather
than proving input features or an internal execution route. Join/comm sorting
is preparation outside timing; sort's spill facet means a requested 4M run
budget, with no temporary-I/O proof.
Named and collection inputs are checked before and after execution.

One generic workload representation supplies arguments, named inputs, stdin
files, fragmented stdin pipes and slow stdout consumers for every command.
Producer chunks of 257 or 65,537 bytes describe writes; the operating system
may split or combine reads. Regular-file stdin is distinct from pipe scanning.
Slow-output delay and chunk size are part of the declared measured regime.
Complete process time includes startup, I/O, exit and direct-child teardown;
there is no startup subtraction or MoonX launch/cache measurement.

Outputs stay file-backed and complete bytes are compared in bounded chunks,
alongside status, stderr and declared filesystem effects. Explicit tree
relations compare full record multisets with multiplicity or complete parsed
JSON with array order and values preserved. Gzip output is independently
decoded and compared with the original source; different valid compressed
streams are accepted. Split/csplit relations reconstruct the actual source.
The local HTTP fixture enforces the declared method and the complete genuine
upload body before returning a response. Hashing, preparation, comparison,
reporting and cleanup occur outside timing.

## Protection and separate formal sampling

Exact native comparison also reports support/profile boundaries. Regular-file
stdin gives GNU wc a physical-size-dependent field width unavailable to the
product; complete counts can agree while padding differs. These configured
exact wc comparisons remain failures and block full-suite qualification. They
are not normalized, deleted or converted into performance regressions. The
genuine CPython module pair also exposed a default diff alignment discrepancy;
the 2026-10-31 product correction applies repeated-anchor filtering before
Myers search. Its configured exact comparison remains in the inventory.
See ADR-0003 for the correction and its finite validation scope.

Seven legacy synthetic regimes remain untimed: two repeated diff edit shapes,
two-sided duplicate join fan-out, and four codec distance/overlap regimes. Their
exact local contracts or private mechanism regressions are bound in
`real-coverage.json`. They constrain those finite behaviors without pretending
to be genuine-source throughput witnesses. This inventory does not prove
complete command functionality or an application-frequency distribution.

`protect.mbtx` compares all 80 command artifacts, requires real timing
coverage for every changed command, and invokes this same inventory. Unchanged
artifacts outside its 43-command declared scope gain no timing claim.
Correctness-only dispositions cannot qualify a changed artifact's performance.
See [PROTECTION.md](PROTECTION.md) for the two-argument launcher and recovery
requirements.

`baseline` checks correctness without a timing verdict. `probe` uses an odd
diagnostic pair count (`--probe-pairs`, default nine); one probe window does not
satisfy the two-window gate. The separate `run` mode retains five warmups and
105 measured pairs in five blocks of 21, with continuous alternating order.
It reports median, nearest-rank p95, MAD, block drift and 10,000 paired
bootstrap resamples. Its R50, R95 and R50 interval upper endpoint limits are
3.0, with MAD at most 5% and block drift at most 10%. A two-window pass is not
a formal 105-pair result, and a formal result does not replace protection's
old/new windows.

```text
MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/benchmark/run.mbtx -- inventory \
  --manifest tests/benchmark/real.json
MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/benchmark/run.mbtx -- run \
  --wasm-root /absolute/current-artifacts --moonrun /absolute/moonrun \
  --oracle-bin /absolute/native-oracle/bin \
  --corpus-root /absolute/prepared-corpus \
  --report-dir /absolute/new-formal-report
MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/benchmark/run.mbtx -- report \
  --report-dir /absolute/retained-report
```

Reports retain the frozen definitions, actual inputs and arguments, per-row
evidence, trial order, statuses, timings and output sizes. Failed or incomplete
runs retain diagnostics and cannot pass. Synthetic corpus, codec, statistics,
observer, cancellation and cleanup tests remain test-tool correctness
regressions. They are excluded from the active timing inventory and do not
imply real-source coverage. Resource diagnostics, three-platform Wasm
correctness, exact-version MoonX acceptance and publication remain separate.
Publication uses `moon publish` only.

## Retired evidence

Historical pilot correctness failures, noisy timing windows and disclosure
records retain their original scope in Git checkpoint `8c4efe2` and saved
external reports. Removing their execution paths does not turn those results
into passes or qualify the current suite. The published acceptance snapshots
and the original rg regression records remain independent of benchmark cleanup.
