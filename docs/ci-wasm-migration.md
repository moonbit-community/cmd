# Wasm CI migration

Updated: 2026-10-26

## Accepted scope

The delivered command backend is Wasm through MoonX. Development checks execute
current release Wasm artifacts on Linux, macOS and Windows. Native remains a
test-driver implementation detail. Resource observations and exact-version
MoonX acceptance are separate manual workflows. The change-coverage, source
sealing, per-test evidence and backend-pair systems are retired.

The implementation does not publish packages or alter command versions,
dependencies, supported command behavior or historical acceptance records.

## Assertion migration ledger

| Existing assertion family | Destination |
| --- | --- |
| Native/Wasm command contracts | One Wasm contract execution per applicable case |
| Native/Wasm persistent and filesystem scenarios | Shared Wasm/MoonX scenario executor |
| Metadata pairing | Standalone metadata contracts against the selected version |
| Native catalog/environment/chunk/process cohorts | Shared command launcher, including child commands |
| Native tail follow and cancellation | Wasm/MoonX lifecycle execution |
| Native HTTP/HTTPS/proxy cohorts | Wasm/MoonX execution with existing fixtures |
| Native stream stress correctness | Wasm/MoonX bounded correctness regression |
| Native host GNU comparisons | Pinned Linux oracle cases; no host PATH parity claim |
| Native/Wasm package pairing | Batched Wasm product tests |
| Native harness package tests | Batched maintained harness tests |
| Permission allow/deny and rejection cases | Both delivery modes, applicable platform only |
| Resource sampling and large repeated matrices | Manual Linux resource workflow |
| Local-only timeout | Workspace boundary checks; excluded from published acceptance |
| Coverage/scope/sealing-specific assertions | Removed with the retired mechanisms |

The old `gnu-host` byte/status checks are covered by the fixed-oracle command
corpora for base64, cat, cut, head, sha256sum, sort, tail and tr. Its follow and
truncation checks are merged into `compat-tail-follow`, which asserts complete
append bytes, truncation recovery, empty stderr, multi-file headers and default
polling. The host PATH comparison itself is removed. The Windows Native-only
empty-environment and `mv-windows-native-links` cases leave product scope;
Wasm environment composition and `mv-windows-wasm-links-boundary` remain.
Native helper lifecycle tests continue to use explicit observer processes,
including injected read, launch, snapshot, cleanup and report failures.

Metadata keeps exact stdout/stderr/status expectations and adds an inherited
stdin sentinel observer. The published adapter inserts its own `--` separator,
so a command's literal `--` and following dash-prefixed operands survive MoonX.
One stateful scenario now produces one result rather than duplicate legacy and
typed audit records; lower report counts do not represent removed assertions.

Only current `latest.json` changes its case pointer, to independent
`latest-cases.json`. Its 78 coordinates and the historical published snapshots
remain unchanged. The workflow selects these coordinates even when workspace
package versions differ. Child commands use the same selected coordinate map.

## Validation record

Local Wasm package tests passed: 491/491. Native harness tests, including the
new failure paths, an injected successful process returning the wrong package
version, stream-command selection and compatibility-fixture cleanup failures,
passed: 117/117. A complete workspace functional run with
the entire Native product artifact directory temporarily moved away recorded
2,027 passing results (including explicit boundaries), 18 platform skips and
zero failures. Scenario records are no longer duplicated. Its six suite stages
took about 56 seconds on this local macOS machine; this is not hosted CI timing.
The artifact directory was restored after the run.

After strict cleanup was extended to the retained compatibility fixtures, a
fresh full workspace run again recorded 2,027 passes, 18 platform skips and zero
failures. All ten compatibility/stream cohorts also passed through exact-version
MoonX after serial startup of the 78 selected coordinates. Diagnostic selectors
now associate the stream cohort with its actual `seq`/`wc` invocations and include
the `printenv` child in environment composition. These changes preserve the
full-suite assertions and make cleanup errors fail the containing cohort.

Local exact-coordinate MoonX functional acceptance of all 78 current commands
recorded 2,094 passes (including startup and boundaries), 18 platform skips and
zero failures. The identical inherited-stdin metadata checks, shared scenarios,
policy allow/deny paths and stream assertions ran through MoonX. Seven focused
fixed-oracle cat/unlink checks also passed locally with the pinned image. These
local results do not replace the planned complete hosted Linux comparison or
three-platform release workflow.

The complete hosted MoonX workflow
[40270955851](https://github.com/moonbit-community/cmd/actions/runs/40270955851)
passed on Linux, macOS and Windows with all 78 exact published coordinates;
Linux also passed the complete pinned upstream comparison. It built only Native
acceptance tools, so product execution did not depend on workspace command
artifacts. No package was uploaded and no published manifest was rewritten.

The controlled cold run at `0e80efd` passed all three development jobs within
20 minutes. Detailed phase timings, counts and cached measurements are recorded
in [CI performance](ci-performance.md). The previous successful main run
40193652755 is a historical cost baseline, not evidence for this implementation.
Final PR checks, the branch-protection transition, actual-main verification and
the manual resource entrypoint are tracked in
[PR #57](https://github.com/moonbit-community/cmd/pull/57). A fresh Native-debug
build passed all 117 harness tests locally; its complete functional run retained
2,027 passes and 18 platform skips. Product Wasm builds remain release builds.
