# Direct-Wasm resource observations

The manual resource workflow observes selected Linux RSS, temporary disk and
large-input behavior. Ordinary development and release checks do not start it.
The Native package separates process observation (`observer.mbt`), generated
stress input (`inputs.mbt`), exact effect relations (`relations.mbt`), command
arguments (`workloads.mbt`) and execution/reporting (`main.mbt`).

Build the release Wasm artifacts first. The public entry builds the observer:

```sh
MOON_HOME="$HOME/.moon-accounts/cli" moon build --target wasm --release --deny-warn
MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/run.mbtx -- resources \
  --wasm-root /absolute/current-artifacts \
  --moonrun /absolute/moonrun \
  --oracle-bin /absolute/pinned-oracle/bin \
  --report-dir /absolute/fresh-report
```

Artifacts use `ARTIFACT_ROOT/cli/COMMAND/COMMAND.wasm`. Select a subset with
`--commands`, `--sizes` or `--timeout-ms`; defaults are the concrete profiles
in `main.mbt`, not a second workload registry. A report directory must be fresh.

## Inputs and effect assertions

Ordinary records are 80 bytes with varying decimal keys. Diff compares distinct
equal files, sparse interior insertion/deletion and distributed interior edits.
Csplit uses repeated interior `SECTION` boundaries and six-digit fragment
suffixes. Every fragment must match its complete declared source interval,
including the final tail; output equality alone is insufficient.

`--long-record true` uses an unbroken ASCII payload with a final LF. Diff and
csplit additionally retain their many-record recipes, with the separate
`single-record-control` regime for the long input. That control changes byte
zero for diff and checks csplit's empty first fragment and complete second
fragment. It does not claim ordinary edit/split coverage.

`--distribution mixed-synthetic` selects deterministic mixed-width records.
Byte profiles include NUL and invalid UTF-8; text profiles keep their explicit
input constraints. Input generation is outside candidate observation. These
public generated stress inputs have `blind_holdout: false` and are excluded
from the genuine-source timing inventory.

All comparisons include actual status, stdout bytes and filesystem effects.
Gzip is decoded by the fixed native observer after execution. Inputs and diff
edit recipes retain their identities. Successful large captures are removed;
failed captures, stderr and report diagnostics remain.

## Observation boundaries

Sampled mode observes direct-child RSS and invocation-owned temporary logical
and allocated disk use, with a 100 ms pause between samples. Observer execution
adds to that interval. Sampled maxima are lower bounds; short allocations can
be missed. First output is the first pipe read or named-file polling result,
including process startup. Each sampled child has a deadline and is cancelled
and reaped on timeout; arbitrary grandchildren are outside that guarantee.

`--kernel-rss linux` uses GNU `/usr/bin/time -f %M`, retaining raw KiB data and
converted bytes. It redirects output to files and has no per-row deadline or
first-output observation. The manual CI step's overall deadline can leave
partial evidence. The observer does not provide a Windows RSS adapter.

Children inherit the account environment and use owned `TMPDIR`/`TMP`/`TEMP`.
Residual files are checked after exit. Abrupt process or machine termination
does not establish product cleanup guarantees; those require focused
package/contract assertions.

## Manual profiles and timing

`tests/run.mbtx -- resource-profiles --image sha256:ID` exports the pinned image's
oracle prefix and runs the selected profiles serially: `records`, `long`,
`mixed-synthetic`, `kernel-rss-linux`, `performance`, and `literal-planner`.
`CMD_RESOURCE_PROFILE` and `CMD_RESOURCE_COMMANDS` narrow the selection.
The wrapper records every completed profile and preserves failures. The
exported reference uses host libraries, so resource observations do not replace
sealed-container upstream comparison.

`literal-planner` measures sampled and kernel RSS separately for shared/diverse
suffix collisions, sparse misses and an over-budget trie. Each selected side
must have exact count output, status, empty stderr, equal effects and no
residual candidate entries. Whole-process RSS does not prove a table bound.

`performance` invokes the single schema-3 `benchmark/real.json` engine, using
the complete pinned sources in `fixtures/benchmark/real-sources.json`.
Authoritative workload/source counts and the two-window statistical gates are
in [the benchmark guide](../benchmark/README.md) and
[protection policy](../benchmark/PROTECTION.md). There are no generated-input
timing panels or separate command timing pipelines. The wrapper prepares
sources through the internal corpus tool; local timing requires
`CMD_BENCH_CORPUS_ROOT`.

Historical observer experiments, including their failed stability gates,
remain in Git checkpoint `8c4efe2`. Their source and dated outcomes are not an
active execution path or current acceptance evidence. Resource observations,
finite correctness, timing and publication retain independent scopes.
