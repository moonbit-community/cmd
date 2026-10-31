# Direct-Wasm resource observations

The `resource-observations` workflow is manual only. It builds the selected ref's
Wasm commands and defaults to the complete existing matrix. Choose an existing
profile (`records`, `long`, `mixed-synthetic`, `kernel-rss-linux`, `performance`, `literal-planner`) and optional comma-separated
commands for diagnosis. Ordinary development and release checks do not start it.

The current timing gate also requires the Native benchmark tool's canonical
panels: the 190-row representative matrix (65 modes across 36 commands), the
183 three-seed variants, 21 original and 60 extended complete-file tasks,
14 slow-output controls, 20 fragmented stdin-pipe controls for
cat/wc/grep/rg, and the original 89 rg tasks when rg is selected. Each applicable
panel uses two windows of nine pairs, 5% MAD and 10% between-window drift limits.
An optional frozen Wasm baseline additionally limits each row's slowdown to 5%
in both windows. The separate formal benchmark mode retains 105 pairs. These
are per-row evidence gates, not broad performance or upstream-parity acceptance.
See [the benchmark guide](../benchmark/README.md) and
[shared-change protection](../benchmark/PROTECTION.md).

Earlier resource reports used a byte-zero diff edit and a first-record csplit
boundary; retain those reports with that limited meaning. The current resource
recipes select three distinct-file diff regimes and repeated interior csplit
boundaries, described below, alongside separately named legacy single-record
stress controls when long-record input is requested. Other profiles keep their existing coverage:
varying unique keys still do not exercise substantial adjacent duplicate runs
for uniq, and resource gzip observes compression rather than the canonical
decoder block/backreference matrix. The sampled and kernel resource observers
require their own applicable executions. Recipe repairs and canonical timing
do not retroactively qualify old results or constitute full RSS qualification.

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
1–8, uniq compares adjacent records, and wc counts newlines. Ordinary records
are 80 bytes. Varying decimal keys make reverse ordering observable and sorting
require reordering. Diff selects equal bytes in distinct files, a sparse
interior insertion plus deletion of two complete rows at separate positions,
and distributed interior replacements/insertions/deletions about every 4096
rows. Its ordinary inputs retain 80-byte rows; mixed inputs are short-byte
dominant. Each regime retains actual named input hashes before and after work
and compares unified output with explicit labels. These are selected edit
regimes rather than worst-case edit-distance coverage.

Sort uses a 4 MiB requested run budget to exercise external runs. Split creates
8 MiB fragments. Csplit uses repeated `/^SECTION /` interior boundaries every
4096 rows, a six-digit output suffix, and retains boundary offsets/count and
tail metadata. Each fragment is independently checked against its complete
source range as well as compared with the reference. Gzip output is decoded by
the fixed native observer after timing. All output comparisons read bounded
chunks and include split/csplit fragments.

Use `--commands csplit,tac`, `--sizes 8388608` or `--timeout-ms 900000` to
select a diagnostic subset. A separate `--sizes 67108864 --long-record true`
run supplies a 64 MiB single record. Each invocation needs a fresh report
directory. Diff and csplit keep their many-record content recipes and add an
explicit `legacy-long-record` result alongside them. Each legacy input is one
unbroken ASCII payload with a final LF. Legacy diff changes byte zero in a
distinct right file; legacy csplit retains `/^/`, requiring an empty `part-00`
and a `part-01` equal to the complete source. Their names and metadata identify
them as single-record stress controls, not ordinary edit/split coverage. Other
long records also use an unbroken ASCII token, keeping the longest-cell case
separate from tables with millions of fields. The script does not build,
publish, install or modify dependencies.
Use a separate `--sizes 8388608 --distribution mixed-synthetic` run for mixed
7/89/4097/65537/128-byte records on the existing general profiles. Diff/csplit
use their separate short-byte-dominant mixed recipes. Byte profiles include NUL
and invalid UTF-8; rev/diff keep ASCII input, and grep explicitly selects text
handling with `-a`.

`heldout` remains a legacy input/profile alias for `mixed-synthetic`. New
metadata records both the requested name and canonical distribution, with
`blind_holdout: false` and `general_performance_acceptance: false`. The mixed
generator is public, deterministic synthetic stress; it is not a reserved
natural corpus. Historical reports keep their original names and scope.

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
sort, diff, cut, uniq and wc at 8, 64 and 512 MiB. Each selected diff regime
retains its own byte/status/effect/cleanup comparison. The current default
selection declares 113 resource comparisons, including the two separately named
legacy-long controls in the long profile; the literal-planner profile adds
sixteen, giving 129. These are selected-case counts, not execution or acceptance
claims, and exclude the separate timing panels. Command subsets change them.
The exported reference uses the host's dynamic loader and system libraries;
these resource observations do not replace sealed-container upstream parity.
Reports remain under
`test-reports/resources-linux/{records,long,mixed-synthetic,kernel-rss-linux,performance,literal-planner}`.
Sampled candidate/reference invocations have a 15-minute deadline; kernel-mode
invocations rely on the CI resource step's 120-minute overall deadline.
Failed profiles do not suppress later profiles, and `profiles.json` is updated
after each completed profile. A step
deadline can leave partial reports. The normal artifact upload retains them;
the exported oracle prefix is removed on observed completion or failure.
The artifact excludes that copied prefix if the whole step is killed.

The `performance` profile now invokes the single schema-3
`tests/benchmark/real.json` inventory through the generic Native benchmark
engine. It declares 125 real-source rows for 40 timing commands; ln, make and
sh have explicit correctness-only dispositions in the 43-command registry.
Its 31 complete sources total 22,152,148 unique payload bytes, bounded by
16 MiB per source and 64 MiB for the suite. These are declared selections,
not executed-result or workload-frequency claims.

The manual Linux wrapper prepares checked sources with
`prepare_real_corpora.mbtx --download`. Local use requires a previously
checked `CMD_BENCH_CORPUS_ROOT`. The performance launcher rebuilds the Native
benchmark observer and local correctness driver before measurement. Declared
independent local-contract witnesses run against the same frozen Wasm first;
actual source invocations also receive native correctness calibration outside
old/new timing. The retired generated regression panels and separate rg
pipeline are not performance stages. See
[the benchmark guide](../benchmark/README.md) for source provenance, finite
coverage gaps and invocation details.

Two separate windows each use a correctness pair, one warmup and nine
alternating complete-process pairs. Each side requires MAD/median at most 5%
per window and at most 10% drift between window medians. Old/new Wasm
comparisons additionally require each candidate/baseline median ratio at most
1.05 in both windows; native ratios without an old baseline remain observations.
Noisy or incomplete windows fail and remain available. There is no automatic
retry, discarded sample, startup subtraction or MoonX launch/cache timing.
This two-window policy is distinct from the separate formal 105-pair mode.

The engine freezes selected Wasm, native references, gzip, runtime, definitions,
inputs and tools, then verifies identities after execution. Actual source
SHA-256, record/byte histograms and features are observed outside timing.
Regular-file input, fragmented stdin pipes and slow-output sinks are distinct
declared regimes. Output/status/stderr and filesystem effects require their
complete declared byte or structured relation. Inherited pause, preload and
diagnostic observer settings are rejected for this ordinary timing path.
Unknown or empty required selections fail.

The resource sampler's generated stress cases, sampled RSS, kernel peak RSS
and pipe observations retain their own resource/correctness meaning. Earlier
large-input regression and stability diagnostics retain their dated reports
and failure scope; they do not become evidence for the bounded real-source
suite. This profile does not establish broad performance, upstream parity,
full resource qualification or publication acceptance.

The Linux `literal-planner` profile runs `literal.mbtx` separately from timing.
It uses sampled and kernel RSS observers for sixteen fixed patterns with a
shared two-byte suffix: shared-first and diverse-first collision misses,
diverse-first sparse misses (each 8/64 MiB, one-MiB records), and a 4096-byte
pattern set whose trie exceeds 1024 states (64 KiB / 1 MiB). `run.mbtx` exposes
these as `--distribution literal-shared|literal-diverse|literal-sparse|literal-budget`
and requires `--commands grep`. Each side must exit 1 with `0\n`, empty stderr,
equal effects and no residual candidate entries. Table bounds and whole-process
RSS are distinct; these runs include runtime and I/O memory. The `all` selection
skips this profile only when grep is explicitly excluded. Previous stability
failures and the maintainer's PR #60 integration exception do not grant a pass
to this new candidate.

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

The Linux-only `cpu` phase compares the unwrapped Native observer with
`perf stat --null`, retaining high-resolution elapsed, user and system time
for every invocation. Null mode does not request hardware counters or change
kernel permissions. CI installs the distribution's Linux tools, and the report
records the actual executable and version. A preflight and every sample require
all three accounting fields. The outer process time includes the wrapper and
remains separate from perf's child accounting; neither replaces acceptance time.

The first Linux x64 diagnostic (run 40395472012, commit 87dc76b) retained all
23 workloads in both windows. The existing Wasm observer and Native observer
each had 17 stable workloads; the 100 ms pause and one-CPU variants each had
14. No variant passed the complete stability gate. One-CPU CPU-pressure
observations increased substantially. These negative results do not justify
adopting a pause, replacing the observer, or restricting acceptance to one CPU.

The cache/control run 40398697579 at 8fcdad5 retained all 25 workloads in both
windows, including the two empty-input controls. Unwrapped Native and preloaded
variants each had 16/25 stable workloads; GNU-time observation had 15/25. The
unwrapped Wasm `true` control drifted from 9.54 to 8.46 ms (11.9%), demonstrating
that some variability exists without text processing. This does not identify
runtime compilation, allocation, host scheduling or storage as the unique
cause. GNU time's coarse CPU values cannot resolve the remaining distinction.
The host CPU differed from the first diagnostic, so cross-run absolute times
cannot establish an improvement. No tested intervention is a stability fix.
