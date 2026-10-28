# Delivery benchmark workloads

For local old/new protection of shared runtime changes, use the
[shared-foundation registry and runner](PROTECTION.md). It checks all command
artifacts and runs the registered two-window profiles. The delivery/upstream
workflows below retain their separate purpose and historical criteria.

The user's 2026-10-24 decision changes performance acceptance to direct release
Wasm. Use the schema-2 driver with `--wasm-root` and an explicit `--moonrun`:

```text
MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/benchmark/run.mbtx -- run \
  --wasm-root /absolute/path/to/release/artifacts \
  --moonrun /absolute/path/to/moonrun \
  --oracle-bin /private/tmp/cmd-native-oracle-2026-10-23/prefix/bin \
  --manifest /absolute/path/to/current-workloads.json \
  --profile tests/benchmark/profile-full.json \
  --report-dir test-reports/performance/wasm-unique
```

The artifact directory follows testkit's `cli/<command>/<command>.wasm` layout.
Each candidate starts moonrun directly; command arguments follow its `--`.
Use a workload manifest pointing at current cases to assess new workspace
features. Rows record `direct-wasm`, no publication coordinate, actual argv and
the artifact root. Timing includes moonrun startup, I/O and exit, without MoonX
or subtraction of empty-runtime time. Correctness, 5 warmups, 105 pairs, noise
rules remain. The user's 2026-10-26 target is a 1-3x runtime ratio relative to
GNU/Rust counterparts: all three upper limits below are now 3.0x. Faster results
are permitted; 1x is not a lower acceptance bound. Historical reports retain
their original 1.5x verdicts. The older `--moonx` mode and
retained reports describe the previous published baseline; MoonX timing is no
longer a cmd performance gate. Exact published-consumer semantics remain part
of release acceptance.

The schema-2 `functional.json` adds a first real functional/startup path for all
79 command names. It loads frozen published Cases by ID; generated fixtures
cover mktemp/realpath/tree/yes and controlled child work. Env/sh/make/xargs use
the same pure-MoonBit helper on both sides; curl/wget perform real POST requests
against the existing pure-MoonBit loopback fixture. Sleep requests10ms. Timeout
remains local-only and is diagnosed through workspace Wasm. In MoonX mode its
row is pending, not passed. All other published candidates use the exact
coordinate from the current published manifest, never a workspace candidate.

After an explicit release build, check one pair per functional workload:

```text
MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/benchmark/run.mbtx -- baseline \
  --moonx /absolute/path/to/moonx \
  --oracle-bin /private/tmp/cmd-native-oracle-2026-10-23/prefix/bin \
  --manifest tests/benchmark/functional.json \
  --profile tests/benchmark/profile-full.json \
  --report-dir test-reports/performance/functional-unique
```

`baseline` checks functional results and records raw process observations; it
does not emit a performance verdict. With the same schema-2 manifest, `run`
first checks correctness and then uses the existing5warmups/105pairs/statistics.
Choose a new report directory for every run. These commands launch real work
and must be coordinated with a quiet measurement window. The original schema-1
pilot manifests and their reports retain their existing behavior.

Every side starts from a freshly prepared fixture on every call. Small original
Case assertions and expected effects reuse testkit. Filesystem comparison uses
the content-free snapshot mode plus bounded file comparison; it does not load
all regular files into memory. Captures stay in files. The initial literal
Case assertion adapter is limited to64KiB captures; the scaled variants below
use separate bounded output relations. Remaining corpus families, resources
and host qualification stay open.
Only fixture-declared root relations may normalize paths. Mktemp validates one
created empty private file instead of comparing random names. Gzip outputs are
decoded and compared with the input outside the timer; differing compressed
bytes are valid, and their sizes remain recorded.
The current accepted base exposes `decode(Bytes)` here, so this gzip relation
buffers only the small functional input. It is not a Reader-based512MiB decoder
path. Scaled rows below use an explicit fixed native observer instead; formal
512MiB gzip experiments remain unexecuted.

Yes uses a4096-byte consumer that closes its pipe and waits for the producer.
Prefix validation happens outside the measured interval. Actual close statuses
and stderr are retained and compared; a difference is a failed functional row,
not a success normalization. Failed rows stop immediately and keep captures and
the mutated fixture. Missing diagnostics or explicitly pending recipes remain
pending. Trial checks are per-side assertions; `comparison.json` records the
separate candidate/upstream stream/status/effect comparison.

`profile-full.json` composes the existing native build records once. It does
not imply complete semantic or performance qualification: the macOS curl build
lacks HTTP2/HTTP3, while grep/Wget PCRE2 is present; Linux requires its own actual
provider records. The first79 functional entries do not cover the required
0/1/4KiB,8/64/512MiB, long-record, shape, option, side-effect and resource sweeps.
Neither their presence nor the earlier18 pilot rows completes B2.

`scaled.json` reuses the functional workload IDs and expands 292 rows for30
stdin command families. These are generated data variants; the reference ID
retains behavior ownership and does not claim execution of the frozen literal
Case or coverage-audit evidence. The shared axes are0/1/4096 B startup,8/64/512 MiB
with80-byte records, and independent1 KiB/64 KiB/1 MiB/8 MiB/64 MiB records.
Separate8 MiB shape rows cover deterministic entropy/repetition/NUL/invalid
UTF-8/no-final-LF and sorted/reverse/random/skew/long-prefix inputs. The pure
generator writes at most64 KiB per chunk; a completed immutable input is reused
within that run. Fresh side fixtures and output files remain separate. The
expanded rows are saved before execution in `expanded-workloads.json`.
Entropy rows are raw binary bytes rather than fixed-length text records.
Direct `corpus` entries use decimal strings for `bytes` and `record_bytes`,
following the public MoonBit JSON representation of64-bit integers.

Use `baseline --manifest tests/benchmark/scaled.json` for correctness only;
do not run the whole retained-output matrix without sufficient disk space.
Original small literal assertions do not apply to changed data: scaled rows
keep status/stderr/effect checks and compare real output files in bounded
chunks. Gzip uses the explicit fixed native gzip observer outside measurement
to encode decode-input fixtures and validate compressed output; its argv,
status and captures are retained. No G2 source has been imported. This initial
matrix does not cover file/argv/tree/network/process sweeps, regex option
families, diff edits, real/held-out corpora or resource observations. Existing
tree/yes differences remain failures in the functional manifest.

## Observed correctness baselines

The first79-row macOS baseline recorded76 checked and3 failed rows. A focused
xargs rerun passed after adding its standard `--` operand delimiter; the
original report is unchanged. Tree still differs under `LC_ALL=C` (branch
glyphs and the separator before its count). Yes produced the required4096-byte
prefix on both sides, then exited0 for the publication versus GNU SIGPIPE
status-13. Neither difference is normalized into success.

The new scaled smoke checked9 of10 rows, including512 MiB cat input and a
64 MiB single record. Gunzip exposed a stale small-literal contract rule;
after the adapter correction, focused gunzip/zcat1 MiB entropy rows both
checked using bounded source relations. These separately retained runs are
correctness observations, with no statistical verdict. The292-row expansion
has not been executed. Raw reports remain under
`/private/tmp/cmd-b2-functional-baseline-20261024/` and
`/private/tmp/cmd-b2-scaled-smoke-20261024/`; they are not coverage-audit proof
for a future committed revision. The original pilot reports also remain
unchanged. Full B2 scale/shape/options/effect/resource/host/formal requirements
remain open.

The original schema-1 pilot covers eight early command families. Each
workload links a `reference_behavior_id` as context for the same command and
reads its exact published coordinate from
`tests/release_runner/current/published.json`. That reference does not execute
the cited case or satisfy coverage audit; each workload's own arguments and
output checks define its measured behavior. Each candidate
call is a real `moonx <coordinate> -- <args...>` process. Source Native and
direct Wasm timings cannot substitute for this delivery role.

| Manifest | Workloads | Input classification |
| --- | --- | --- |
| `manifest.json` | Original true/false startup and cat-8m (3 rows) | Empty stdin or 8 MiB stdin |
| `small-inputs.json` | basename/wc/sha256sum/grep/gzip (15 rows) | 0/1/4096-byte operands for basename, stdin for the other four |

The original manifest and its 660-call report remain separate from the added
rows. Their results must not be combined into a newly measured eight-command
report. The four other commands use 0.2.1; gzip retains its actual 0.1.1 release.

Those original manifests are a pilot of the benchmark path, not full B2
acceptance. The existing CI owns immutable semantic-oracle qualification. This
driver records explicit executable paths, versions, host observations and the
existing native GNU build record; it does not create another identity system.
Its default profile refers to the previously prepared native macOS coreutils
9.11 build. Other hosts need their own actual build record and reviewed profile.
The chosen oracle directory must be that build record's `prefix/bin`.

## Build and run

Run from the repository root. Prepare the exact published consumers and their
warm caches separately, before the experiment. The launcher does not download,
install, build the benchmark executable, or prepare the cache automatically.
Use a quiet host on stable power, with other benchmarks and the Linux VM stopped
during macOS measurements. Preserve noisy attempts rather than choosing the
fastest attempt; the plan permits at most two complete retests.

```text
MOON_HOME="$HOME/.moon-accounts/cli" moon build tests/benchmark --target native --release
MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/benchmark/run.mbtx -- run \
  --moonx /absolute/path/to/moonx \
  --oracle-bin /private/tmp/cmd-native-oracle-2026-10-23/prefix/bin \
  --report-dir test-reports/performance/pilot-unique
```

To run only the added rows, add `--manifest tests/benchmark/small-inputs.json`
and choose a fresh report directory; this does not rerun the original three.
`--profile FILE` selects another actual native build record. `LC_ALL=C`,
`LANG=C` and `TZ=UTC` are set for each measured
child; `MOON_HOME` is inherited from the prefixed launcher. The remaining normal
environment and PATH are inherited. No global environment is changed.

`run` performs the row gate and exits nonzero if any row fails or is
inconclusive. To display a retained report without running any workload:

```text
MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/benchmark/run.mbtx -- report \
  --report-dir test-reports/performance/pilot-unique
```

## Existing Linux guest

Reuse `cmd-performance` (Colima VZ, Linux virtualized arm64, 4 vCPU, 8 GiB RAM,
nominal 80 GiB disk); keep it stopped during macOS measurements. Inside that
guest, use a VM-local checkout, its existing Oct21 toolchain and anonymous
`/home/winter.guest/.moon-accounts/cli` account. Build and prepare the exact
published consumers there without copying host credentials. The driver measures
direct guest processes; an outer SSH/Colima connection may launch the driver,
but its latency is outside these intervals. Source and corpus stay on the guest
filesystem. From that repository root, after the explicit Native build above:

```text
MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/benchmark/run.mbtx -- run \
  --moonx /home/winter.guest/.moon/bin/moonx \
  --oracle-bin /home/winter.guest/cmd-native-oracle-2026-10-23/prefixes/6/bin \
  --profile tests/benchmark/profile-linux.json \
  --manifest tests/benchmark/small-inputs.json \
  --report-dir test-reports/performance/linux-small-unique
```

The existing worker writes the guest build record to
`/home/winter.guest/cmd-native-oracle-2026-10-23/runs/6/manifest.json`; its host
setup copy remains under `/private/tmp/cmd-linux-native-oracle-prep-20261023/evidence-6/`.
The Native timing API uses `CLOCK_MONOTONIC` for elapsed durations. Earlier VM
epoch-clock synchronization observations do not by themselves invalidate these
elapsed samples; leave timesync unchanged and retain this run's actual noise
and host observations. This remains the same limited pilot, not complete B2.

## Sampling and correctness

Each workload gets five warmup pairs, then five blocks of 21 measured pairs:
105 fresh processes per side. AB/BA order alternates globally, including block
boundaries, giving 53 candidate-first and 52 upstream-first pairs. The saved
sampling plan records the complete order and fixed bootstrap seed.

The measured interval covers process launch through IO, flush and exit using
the public monotonic clock. Redirect setup, input preparation, output checks,
reporting and cleanup are outside it. Input generation writes deterministic
64 KiB chunks plus the final partial chunk. The two startup workloads require
empty stdout/stderr and statuses 0/1; cat compares stdout with its 8 MiB input.
Basename receives the generated text as an operand, while its stdin is empty.
Wc checks the exact byte count; sha256sum checks a once-prepared digest and GNU
stdin label; grep checks its actual matched lines and the empty-input status 1.
All workloads require empty stderr. Every invocation is checked before the
next call. A timeout, process error, unexpected status, wrong output or invalid
duration stops that row and preserves the failed captures. Gzip uses `-n -c`;
the released public `gzipops.decode` checks its output and decoded bytes against
the input outside timing. Both compressed outputs may differ. Each trial records
the actual stdout size. These initial gzip observations buffer only the small
0/1/4 KiB cases; large-data decoding and full size acceptance remain pending.

For each side the report includes median, nearest-rank p95, MAD and five block
medians. The even-count median averages the two middle values. For 105 samples,
p95 is sorted element 100. Bootstrap uses the released core ChaCha8 PRNG and
10,000 paired-index resamples, recomputing the ratio of medians; the two-sided
95% endpoints are sorted elements 250 and 9750, without interpolation.

A row passes only when R50, R95 and the R50 interval upper endpoint are all
at most 3.0. MAD/median above 5% or block-median range above 10% of the overall
median marks either side noisy. Noisy rows cannot pass. Missing samples are
inconclusive; correctness failures stay failed. This pilot has no automatic
retry, slow-sample deletion or aggregate compensation.

## Retained files

### Exploratory implementation comparisons

`explore.mbtx` is a separate diagnostic probe, not a delivery verdict. It uses
one warmup followed by a requested number of alternating process pairs, validates
status/stderr/bytes after every pair, and fails on empty/unknown selection,
timeouts or unequal output. It measures release Wasm through `moonrun` on PATH,
including runtime startup, file I/O and exit. It never invokes MoonX or subtracts
runtime startup. Input is a redirected regular file, not a pipe. Small-input
ratios and GNU metadata shortcuts must be interpreted accordingly.

```text
MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/benchmark/explore.mbtx -- \
  /absolute/lab /absolute/build/cli/ prepare cut-8m 9
MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/benchmark/explore.mbtx -- \
  /absolute/lab /absolute/build/cli/ prototype cut-8m,uniq-8m,wc-l-64m,wc-w-64m,grep-regex-1m 9
MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/benchmark/explore.mbtx -- \
  /absolute/lab /absolute/build/cli/ ab cut-8m,uniq-8m,wc-l-64m,grep-regex-1m 9 /absolute/baseline/cli/
```

The lab and `results/` directories must exist. `prepare` generates deterministic
corpora without fetching/building references. The expected reference layout is
`oracles/coreutils-9.11/src/`, `oracles/grep-3.12/src/`, and, for optional other
rows, `oracles/gzip-1.14/gzip` and pinned `oracles/bin/{rg,jq}`. Bind executable,
source and input hashes separately before interpreting results. The `ci` mode
accepts an exported oracle `bin` directory as its final argument for the
cut/uniq/wc/grep resource profile; the enclosing workflow records its image ID.
It uses the same correctness checks and sampling as `prototype`. Each run retains
raw samples and final output/error files under `results/`. Exploratory medians
cannot replace the full 105-pair, noise-qualified, immutable-provider workflow.

The `grep-adaptive-*` rows exercise the production literal planner. Six rows
combine shared/diverse first bytes with all-`a` collision inputs at 64 KiB,
256 KiB and 1 MiB. Four use all-`Z` sparse input at 1/64 MiB. Dense records,
a collision prefix followed by 64 MiB of sparse records, and a 4096-byte pattern
set exceeding the trie-state budget complete thirteen cases. `prepare` builds
every corpus deterministically; measured `grep -F -c` includes compilation,
record handling and output. The existing workload rows are retained. The
separate resource profile measures RSS and temporary effects without wrapping
the ordinary timed processes.

Each fresh report directory contains expanded `profile.json`, the actual
`manifest.json`, `sampling-plan.json`, and `report.json`. Each workload keeps
`trials.jsonl`, `row.json`, its input, and one reusable stdout/stderr file per
side. Trial records preserve phase/order, raw timing, actual status and output
comparison result. Successful large captures are reused after checking;
failed captures remain because that row stops immediately. Trial paths name
reusable files, so an earlier successful trial's full bytes are represented by
its completed comparison rather than a permanently retained separate capture.
The row JSON also retains every complete measured pair; warmups never enter
the statistics. Gzip also reuses one decoded file per side. Existing report
directories are not overwritten.

The initial 2026-10-24 macOS and Linux reports used the released filesystem
writer's default truncate mode together with append. Their `trials.jsonl` files
retain only the final observation; complete trial records and timing samples
remain in `row.json` and `report.json`. Those historical files are unchanged.
New runs explicitly open the JSONL file without truncation.
Historical manifests retain the earlier `behavior_id` field name; those links
also provide context rather than proof of the referenced case.

## Initial published baseline

The 2026-10-24 macOS pilot completed all 660 invocation checks. Median
MoonX/GNU times were 96.0/2.57 ms for true, 97.2/2.56 ms for false, and
262.9/4.10 ms for cat-8m: ratios 37.4, 38.0 and 64.1. All rows failed the
performance gate. The two startup rows also marked the upstream samples noisy;
cat-8m was stable. These are current published-package observations, not final
optimized acceptance. Raw samples and the host profile remain at
`/private/tmp/cmd-b1-pilot-20261024/report.json` and its sibling files.

The separate small-input run completed all 3,300 invocation checks for the
five additional commands, with 105 measured pairs per row. MoonX medians were
97-106 ms; upstream medians were 1.5-3.2 ms. All 15 rows exceeded the performance
limits and marked upstream samples noisy; these observations do not establish
final accepted ratios. No row was automatically retried. Raw samples, output
sizes and gzip roundtrip observations remain in
`/private/tmp/cmd-b1-small-inputs-pilot-20261024/report.json` and its sibling files.

Separate development controls found a large MoonX startup increment and an
async copy-buffer effect: 64 KiB buffers reduced the observed cat process time
from 98.81 to 4.77 ms Native and 180.12 to 13.44 ms Wasm (six samples per setting).
These are causal diagnostics, not a shipped optimization or delivery acceptance.
See `/private/tmp/cmd-b1-startup-diagnostic-20261024/source-attribution.md` and
`/private/tmp/cmd-cat-buffer-{native,wasm}-20261024-run1/report.json`.
