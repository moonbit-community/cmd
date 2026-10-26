# CI performance

Updated: 2026-10-26

The active design is [Wasm CI migration](ci-wasm-migration.md): three parallel
Wasm development jobs, separate manual resource and MoonX acceptance workflows,
no audit or daily schedule. The target is 10 minutes ideally, under 15 minutes
normally, at most 20 minutes without abnormal queueing, and under 45 total runner
minutes. These targets require measured cold and warm runs; they are not claimed
as achieved by removing old steps.

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
