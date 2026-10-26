# Direct-Wasm resource observations

The `resource-observations` workflow is manual only. It builds the selected ref's
Wasm commands and defaults to the complete existing matrix. Choose an existing
profile (`records`, `long`, `heldout`, `kernel-rss-linux`) and optional comma-separated
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

The observer runs rev, strings, split, csplit, tac, column, sort, grep, gzip
and diff serially on 8, 64 and 512 MiB inputs. Records are 80 bytes except for
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
sort and diff at 8, 64 and 512 MiB.
The exported reference uses the host's dynamic loader and system libraries;
these resource observations do not replace sealed-container upstream parity.
Reports remain under
`test-reports/resources-linux/{records,long,heldout,kernel-rss-linux}`.
Sampled candidate/reference invocations have a 15-minute deadline; kernel-mode
invocations rely on the CI resource step's 120-minute overall deadline.
Failed profiles do not suppress later profiles, and `profiles.json` is updated
after each completed profile. A step
deadline can leave partial reports. The normal artifact upload retains them;
the exported oracle prefix is removed on observed completion or failure.
The artifact excludes that copied prefix if the whole step is killed. Both
scripts retain bare import headers for the pinned MoonBit 0.10.15 CI parser.
