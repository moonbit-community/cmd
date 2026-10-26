# CI performance

Updated: 2026-10-26

The active design is [Wasm CI migration](ci-wasm-migration.md): three parallel
Wasm development jobs, separate manual resource and MoonX acceptance workflows,
no audit or daily schedule. The target is 10 minutes ideally, under 15 minutes
normally, at most 20 minutes without abnormal queueing, and under 45 total runner
minutes. These targets require measured cold and warm runs; they are not claimed
as achieved by removing old steps.

Wasm products and package tests use release builds. Daily Native test tools use
debug builds: a fresh local driver build took 3.96 seconds, while hosted release
tool compilation remained a major cost even after a confirmed cache hit reduced
90 build tasks to nine. Harness assertions and product launch modes are unchanged.
Manual published acceptance keeps its existing release-tool configuration. The
fresh local debug harness build and all 117 tests took 6.83 seconds; the complete
workspace functional suite still passed. These are local observations, not
hosted timing predictions.

Final required PR and actual-main results are tracked in
[PR #57](https://github.com/moonbit-community/cmd/pull/57). The preliminary hosted
measurements below use release tools. A controlled cold/two-warm series for the
final debug-tool configuration is not claimed.

The compilation cache includes `_build/.moon_db` together with Wasm release and
Native debug compiler outputs, and keys distinguish these configurations.
In the pinned Moon revision, this file is the shared incremental-build
database ([executor source](https://github.com/moonbitlang/moon/blob/748b63c/crates/moonbuild/src/execution/n2.rs#L122));
restoring output directories alone loses the executor's build history. Cache
restoration and saving are separate: a cold run restores no dependency,
compilation or Docker layers, then saves successful compiler state for later
normal runs. Tests still execute on every run, including an exact cache hit.
The dependency key is computed once immediately after checkout and excludes
downloaded and generated package files. Restore and save use that same value;
re-evaluating a recursive manifest hash after the build changes the key and
prevents restoration, as observed in the preliminary cached run at `0e80efd`.

The pinned oracle recipe builds its 16 upstream components in independent
stages and assembles their prefixes in the original installation order. BuildKit
admits at most two stages concurrently and each Make build uses two jobs.
Versions, source checksums, configure options and the base image stay unchanged.
The recipe checksum changes with this build-layout change. The cold build and
complete upstream comparison passed on the resulting image.

## Preliminary release-tool measurements

The preliminary runs use candidate `635f355817c191023d913428384ae3e4c75970d0`
with the unchanged pinned toolchain. Durations below come from GitHub job and
step timestamps; functional/oracle splits come from the uploaded `stages.json`.
They include setup, tests, reports and cache saving. Runner totals are the sum
of actual job elapsed times, not billing-rounded minutes. Dispatch-to-result
time and job queue time are reported separately.

| Run | Linux | macOS | Windows | Runner total | Dispatch to last result |
| --- | ---: | ---: | ---: | ---: | ---: |
| [Cold, caches disabled](https://github.com/moonbit-community/cmd/actions/runs/40273387917) | 13:35 | 5:48 | 12:44 | 32:07 | 14:26 |

The cold run disabled dependency/compiler and Docker-layer restoration. It saved
successful compilation state for the following normal runs. Job queue time was
3 seconds on Linux and 4 seconds each on macOS and Windows; 48 additional seconds
elapsed before GitHub created the jobs. This satisfies the cold-run ceiling;
it does not establish normal cached duration by itself.

Cold phase durations (seconds; functional subphases are rounded):

| Phase | Linux | macOS | Windows |
| --- | ---: | ---: | ---: |
| Runner setup, checkout, cache key and toolchain | 13 | 17 | 39 |
| Dependencies | 1 | 1 | 8 |
| Product and test-tool checks | 3 | 7 | 8 |
| Wasm command build | 7 | 12 | 13 |
| Native test-driver build | 87 | 66 | 145 |
| Wasm batch tests | 22 | 36 | 55 |
| Native harness batch tests | 122 | 98 | 294 |
| Docker builder, image and profile preparation | 302 | 0 | 0 |
| Functional assertions | 67 | 96 | 188 |
| Fixed upstream comparison | 177 | 0 | 0 |
| Interfaces and formatting | 2 | 0 | 0 |
| Test-report upload | 1 | 2 | 2 |

Subphase sums exclude small driver/step-transition overheads. Each platform ran
491 Wasm package tests and 115 harness tests at this measured candidate. Linux
recorded 2,220 passing functional/comparison results, 15 explicit platform skips
and no failures. Subsequent selector and cleanup-error regressions increase the
harness total to 117, and formatting checks cover the entire workspace. These
changes preserve full functional assertions; their final PR and actual-main
checks are separate from this fixed-candidate measurement series.

The preliminary cold run at `0e80efd`
([40270933353](https://github.com/moonbit-community/cmd/actions/runs/40270933353))
also passed: Linux 18:49, macOS 4:56, Windows 12:42, runner total 36:27 and wall
time 18:53. Its attempted normal-cache follow-up missed compilation caches
because restore/save keys differed, and was superseded by the corrected series.
Hosted machine variation affects these observations; the cold-time difference
between the two candidates is not attributed to the cache-key correction.

The earlier cold attempt at `40efae2`
([run](https://github.com/moonbit-community/cmd/actions/runs/40268916908)) exceeded
the Linux 20-minute limit and was cancelled by the job deadline. It is a failed
attempt, not performance acceptance. The final candidate parallelizes the pinned
oracle build and retains cancellation diagnostics without racing live fixtures.

The previous successful main run
[40193652755](https://github.com/moonbit-community/cmd/actions/runs/40193652755)
remains the historical baseline: 70:50 overall, 108:25 accumulated runner time,
including the former audit job. No old workflow was rerun for this comparison.

## Manual published acceptance

[Run 40270955851](https://github.com/moonbit-community/cmd/actions/runs/40270955851)
passed on all three platforms at `0e80efd`, using the 78 exact coordinates in
`latest.json`, with no workspace Wasm command build and no package publication.
Linux also completed the full pinned upstream comparison. Counts include
explicit boundaries and startup-resolution checks; skips remain distinct.

| Platform | Pass | Platform skip | Failure | Job duration |
| --- | ---: | ---: | ---: | ---: |
| Linux | 2,287 | 15 | 0 | 19:34 |
| macOS | 2,094 | 18 | 0 | 10:28 |
| Windows | 1,961 | 151 | 0 | 9:06 |

These manual durations are outside daily CI targets. Successful test artifacts
were approximately 68-87 KB compressed per platform. Native remains limited to
test tools, and every published product invocation uses its selected MoonX
coordinate, including scenario children.

## Historical optimization record

The following entries describe the former CI and retain their original results.
They do not define current gates or certify this migration.

# CI execution reuse

Updated: 2026-10-24

C1 actual main `f2769846` and run `39955744640` are the accepted baseline.
C2 is removed. Full three-platform verification, coverage-audit and the daily
schedule remain required. This record covers test infrastructure; command/core
behavior and package versions are unchanged.

## C3 local validation

The current public `moon test --target all --outline` lists 598 Native,
287 Wasm, two JS and two Wasm-GC tests. Every Native/Wasm package, source and
test name maps uniquely to the refreshed registry, with no missing or duplicate
bindings or doctest/inline residuals. JS and Wasm-GC retain their ordinary Moon
test executions. Existing platform exclusions still apply to package selection.

The combined `paired` suite executes each supported Native/Wasm contract or
scenario once, checks its contract, and compares the actual two observations.
It emits the same five report roles. Boundaries and backend-specific Windows
scenarios retain separate executions; oracle scenarios retain their own suite.
The standalone suite entrypoints remain available for diagnosis.

| Report role | Rows | Pass | Platform skip |
| --- | ---: | ---: | ---: |
| contract-native | 839 | 833 | 6 |
| contract-wasm | 839 | 833 | 6 |
| scenarios-native | 14 | 12 | 2 |
| scenarios-wasm | 14 | 12 | 2 |
| backend-pair | 813 | 809 | 4 |

All 2,519 `(role, case, result, verification)` records match the C1 macOS log.
Raw comparison still checks streams, statuses and portable filesystem effects.
Successful standalone contract rows keep their existing no-evidence convention;
failed captures and scenario traces remain available.

Package preparation builds once per package/backend and reads/freezes each
blackbox/whitebox artifact once. Each named test still uses public Moon `--index`
and requires exactly one passing test. The local full runs passed 855/855 package
pair rows and 311/311 Native-only rows, including all five new regressions.
Preparation calls decreased from 570 to 114 for the applicable pair selection
and from 311 to nine for Native-only. Per-test executions are retained.
The reused local build took 93.9 and 68.2 seconds respectively; these are local
development observations, not hosted cold/warm speedup claims.

Local evidence is under `/private/tmp/cmd-c3-paired-live-20261024`,
`/private/tmp/cmd-c3-package-pair-live-20261024`,
`/private/tmp/cmd-c3-package-native-live-20261024`, and
`/private/tmp/cmd-c3-current-outline-registry-join-20261024.json`.
These precommit runs establish the implementation comparison. Exact committed
three-platform and actual-main acceptance remain separate CI gates.
PR #45 run `40015090550` passed all four required checks at `935fe17` and
merged as `222d9b1`. Actual-main run `40020157020` passed all four required
checks: macOS 12:09, Linux 26:28, Windows 23:36 and coverage-audit 7:13.
Full/shadow retained 1,733 behaviors with no findings; the independent frozen
proof passed 1,028 rows across 78 coordinates. These hosted observations are
not a controlled cold/warm performance comparison.

## C4 measurement

[PR #44](https://github.com/moonbit-community/cmd/pull/44) computes scope once
per CI entrypoint and directly reuses a release coverage CLI. Its 52 coverage
regressions, release build, direct entrypoint probes and workflow validation
passed locally. Hosted run `39995981396` passed all four required checks and
PR #44 merged as `f32438b5`. Actual-main run `40004057220` then passed all four
required checks: macOS 17:17, Linux 27:14, Windows 42:53 and coverage-audit 7:10;
the actual-main audit body took 180 seconds.

The PR coverage-audit job took 420 seconds, compared with 813 seconds on the C1
actual-main run; its audit body decreased from 596 to 167 seconds. The three
platform stamp steps together decreased from 265 to 115 seconds. Full/shadow
execution retained all 1,728 behaviors and the frozen publication proof retained
1,028 cases across 78 coordinates, with no audit findings.

Platform jobs took 18:05 on macOS, 44:01 on Windows and 32:28 on Linux, compared
with 14:20, 40:22 and 37:31 at C1. These single-run observations include hosted
runner variation and do not establish an overall CI speedup. Early CLI
compilation and the later Native build together retained the same macOS release
task count. Cache, artifact-transfer and concurrency changes require an observed
benefit before adding complexity.
