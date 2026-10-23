# Delivery benchmark pilot

This Native host driver covers the eight early pilot command families. Each
workload references an existing registry behavior and reads its exact published
coordinate from `tests/release_runner/current/published.json`. Each candidate
call is a real `moonx <coordinate> -- <args...>` process. Source Native and
direct Wasm timings cannot substitute for this delivery role.

| Manifest | Workloads | Input classification |
| --- | --- | --- |
| `manifest.json` | Original true/false startup and cat-8m (3 rows) | Empty stdin or 8 MiB stdin |
| `small-inputs.json` | basename/wc/sha256sum/grep/gzip (15 rows) | 0/1/4096-byte operands for basename, stdin for the other four |

The original manifest and its 660-call report remain separate from the added
rows. Their results must not be combined into a newly measured eight-command
report. The four other commands use 0.2.1; gzip retains its actual 0.1.1 release.

This is a pilot of the benchmark path, not complete 79-command coverage or B2
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
at most 1.5. MAD/median above 5% or block-median range above 10% of the overall
median marks either side noisy. Noisy rows cannot pass. Missing samples are
inconclusive; correctness failures stay failed. This pilot has no automatic
retry, slow-sample deletion or aggregate compensation.

## Retained files

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
