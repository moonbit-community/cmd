# Direct-Wasm resource observations

The `resource-observations` workflow is manual only. It builds the selected ref's
Wasm commands and defaults to the complete existing matrix. Choose an existing
profile (`records`, `long`, `heldout`, `kernel-rss-linux`, `performance`) and optional comma-separated
commands for diagnosis. Ordinary development and release checks do not start it.

Build and stage the current release Wasm artifacts first, using the existing
testkit layout `ARTIFACT_ROOT/cli/COMMAND/COMMAND.wasm`. Then run from the
repository root:

```text
MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/resources/run.mbtx -- \
  --wasm-root /absolute/current-artifacts \
  --moonrun /absolute/moonrun \
  --oracle-bin /private/tmp/cmd-native-oracle-2026-10-23/prefix/bin \
  --report-dir /absolute/new-report-directory
```

The observer runs rev, strings, split, csplit, tac, column, sort, grep, gzip,
diff, cut, uniq and wc serially on 8, 64 and 512 MiB inputs. Cut selects bytes
1–8, uniq compares adjacent records, and wc counts newlines. Records are 80 bytes except for
diff's 4096-byte records, which avoid millions of duplicate record descriptors.
Each record begins with a deterministic varying decimal key, so reverse ordering
is observable and sorting must reorder the records.
Diff changes one byte and compares unified output with explicit labels; it is
not a worst-case edit-distance workload. Sort uses a 4 MiB requested run budget
to exercise external runs. Split creates 8 MiB fragments; csplit uses one regex
boundary. Gzip output is decoded by the fixed native observer after timing.
All output comparisons read bounded chunks and include split/csplit fragments.

Use `--commands csplit,tac`, `--sizes 8388608` or `--timeout-ms 900000` to
select a diagnostic subset. A separate `--sizes 67108864 --long-record true`
run supplies a 64 MiB single record. Each invocation needs a fresh report
directory. That record uses an unbroken ASCII token, keeping the longest-cell
case separate from tables with millions of fields. The script does not build,
publish, install or modify dependencies.
Use a separate `--sizes 8388608 --distribution heldout` run for mixed
7/89/4097/65537/128-byte records. Its byte profiles include NUL and invalid UTF-8;
rev/diff keep ASCII input, and grep explicitly selects text handling with `-a`.

The default sampled mode records actual status, bytes/effects equivalence, stdout byte count,
elapsed time and first observed output. Stdout timing begins at process launch
and ends at the first pipe read; named-file output uses polling. The sampler
queries the direct child's RSS and invocation-owned temporary logical/allocated
disk use, with a 100 ms pause between samples. Observer execution adds to that
interval. These sampled high-water values are lower bounds, not kernel peak
RSS or guaranteed peak disk measurements; short-lived allocations may be missed.
The observer and the later native-oracle invocation are outside candidate RSS.
These are resource/correctness observations, not the statistical performance
acceptance implemented by `tests/benchmark`.

Use `--kernel-rss linux` for a separate Linux kernel-peak run. It wraps each
candidate/reference in GNU `/usr/bin/time -f %M`, saves raw `rusage.txt`, and
converts its KiB `ru_maxrss` to `kernel_peak_rss_bytes`. The default sampled mode
leaves that field null. Kernel mode redirects stdout/stderr to files and keeps
the same status, byte/effect and residual-temporary checks; it reports no
first-output time and leaves sampled fields at zero. It is limited to known
completed profiles and has no per-row deadline, avoiding a timer wrapper whose
grandchild could survive cancellation. The CI step's overall deadline stops
the run and can leave partial reports or temporary files.

The child inherits the CLI account and gets an owned `TMPDIR`/`TMP`/`TEMP`.
Residual temporary files are checked after exit. Sampled-mode timeouts hard-cancel and reap
the direct child; they fail the row and do not establish guest cleanup after
abrupt termination. Runtime-observed cancellation, output closure and permission
failure behavior need separate focused package/contract evidence. SIGKILL,
machine failure and unavailable recoverable-signal APIs carry no cleanup promise.
No Windows RSS or `du` adapter is provided by this Unix observer.

JSON results and stderr remain in the report directory. After successful exact
comparison, large stdout/fragment/decode captures are removed to bound retained
disk space. Failed captures remain. Inputs are generated deterministically in
64 KiB blocks and reused within the current size; their generation is outside
candidate timing. These observations do not establish upstream parity or formal
statistical performance acceptance.

The manual Linux workflow runs `tests/resources/ci.mbtx --image SEALED_IMAGE_ID`.
It exports the pinned image's `/oracle` prefix
and runs the three profiles above serially with the host MoonBit toolchain,
followed by a separate kernel-peak profile for rev, split, csplit, tac, column,
sort, diff, cut, uniq and wc at 8, 64 and 512 MiB. The complete resource selection
contains 95 byte/status/effect/cleanup comparisons.
The exported reference uses the host's dynamic loader and system libraries;
these resource observations do not replace sealed-container upstream parity.
Reports remain under
`test-reports/resources-linux/{records,long,heldout,kernel-rss-linux,performance}`.
Sampled candidate/reference invocations have a 15-minute deadline; kernel-mode
invocations rely on the CI resource step's 120-minute overall deadline.
Failed profiles do not suppress later profiles, and `profiles.json` is updated
after each completed profile. A step
deadline can leave partial reports. The normal artifact upload retains them;
the exported oracle prefix is removed on observed completion or failure.
The artifact excludes that copied prefix if the whole step is killed.

The `performance` profile runs 23 selected cut/uniq/wc/grep workloads through
`tests/benchmark/explore.mbtx`, using the exported oracle executables. Two
separate windows each use one warmup and nine alternating direct-Wasm/GNU pairs,
with exact status, stdout and stderr checks after every pair. This exercises
short/long/repeated records, word counting, multi-literal sets, regex spans and
overlapping suffixes. It never measures MoonX or subtracts runtime startup.
Long-record cut and required-literal regex misses use 64 MiB inputs: the first
local 8 MiB pilot had stable Wasm windows but noisy millisecond-scale GNU
references. Increasing input size retains the same algorithmic case and
stability thresholds; that original failed diagnostic remains recorded.
`stability.json` reports both windows and requires MAD/median at most 5% for
each side in each window, and a difference between window medians at most 10%
of their mean. Noisy windows fail and remain available; no automatic retry or
sample removal is performed. GNU ratios are reported without imposing a ratio
gate: this is a repeatability check, not the formal 105-pair acceptance suite.
The complete matrix and focused command selections both retain raw samples.
An `all` selection for unrelated commands explicitly skips this profile; an
explicit `performance` selection with no applicable commands fails.

`stability-diagnostic` is an explicit investigation profile and is excluded
from `all`. It preserves two windows of the same selected workloads for the
existing Wasm observer, a release Native observer, a Native observer with a
100 ms pause before each arm, and (on Linux) a Native observer confined to one
allowed CPU. Both candidate and reference inherit the same affinity. The
second window reverses variant order. Product commands remain the same release
Wasm files; pauses are outside the complete child-process interval. CPU
topology, affinity, aggregate scheduler counters and pressure snapshots accompany
the raw observations. These interventions test hypotheses about measurement
interference; they do not change acceptance settings or establish stability.
Completion requires every diagnostic window, and no failed sample is retried
or discarded. `plan.json` and `runs.json` retain the diagnostic selection and
report paths. The ordinary `performance` profile keeps its existing thresholds.

The `cache` diagnostic phase adds direct-Wasm `true` and empty-input grep as
controls. It compares the Native observer with an explicit complete input read
before each arm, outside timing. A separate Linux counter arm uses GNU time
under GNU timeout's process-group deadline to retain CPU seconds, voluntary and
involuntary switches, faults and kernel peak RSS for each invocation. Those
wrapped elapsed times include observation overhead and are not acceptance
measurements. GNU time's CPU-time fields have centisecond resolution; they
cannot resolve a single millisecond-scale CPU difference. No MoonX invocation
or startup subtraction is used. `diagnostic_phase` selects the hypothesis set
only for the explicit diagnostic profile.

The first Linux x64 diagnostic (run 40395472012, commit 87dc76b) retained all
23 workloads in both windows. The existing Wasm observer and Native observer
each had 17 stable workloads; the 100 ms pause and one-CPU variants each had
14. No variant passed the complete stability gate. One-CPU CPU-pressure
observations increased substantially. These negative results do not justify
adopting a pause, replacing the observer, or restricting acceptance to one CPU.
