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
new failure paths, passed: 114/114. A complete workspace functional run with
the entire Native product artifact directory temporarily moved away recorded
2,027 passing results (including explicit boundaries), 18 platform skips and
zero failures. Scenario records are no longer duplicated. Its six suite stages
took about 56 seconds on this local macOS machine; this is not hosted CI timing.
The artifact directory was restored after the run.

Local exact-coordinate MoonX functional acceptance of all 78 current commands
recorded 2,094 passes (including startup and boundaries), 18 platform skips and
zero failures. The identical inherited-stdin metadata checks, shared scenarios,
policy allow/deny paths and stream assertions ran through MoonX. Seven focused
fixed-oracle cat/unlink checks also passed locally with the pinned image. These
local results do not replace the planned complete hosted Linux comparison or
three-platform release workflow.

Implementation and hosted validation are in progress. Hosted duration, three-platform
MoonX acceptance and actual-main acceptance must be recorded from real runs.
The previous successful main run 40193652755 is a historical cost baseline,
not evidence for this implementation.
