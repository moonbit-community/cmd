# C1 Windows evidence fixture correction

Status: fixture correction in local validation; C1 acceptance remains pending.
Earlier C1 reports and exact-source evidence remain unchanged.

The user separately authorized the exact `a9d36a1` push to the existing
[PR 43](https://github.com/moonbit-community/cmd/pull/43).
[Run 39929992296](https://github.com/moonbit-community/cmd/actions/runs/39929992296)
attempt one checked synthetic merge `ffb0a11d2c6a498c63c6264cff6c6bd61c1ec3b5`,
whose parents are main `4180e527` and that authorized head. Its tree
`b4afd3906f96f4b2fb55b982bbe34c6f80358f77` matches the frozen candidate.

Actual Windows scope preflight and warning-denying checks passed. The global
Native test run passed 585 of 593 tests, with eight coverage-fixture failures;
Wasm 287, JS two and Wasm GC two all passed. The failed positive checks concern
old/current scope mappings, aliases, full/shadow separation and identical
frozen publication references. This does not establish a command defect or
complete Windows command acceptance.

The diagnostic artifact is `package-test-logs-windows-2025`, ID `12490558895`,
3,675 bytes, SHA-256
`6d93fc95436e5fa570e9b3e6303b552377823cc4d9be7aafd9e0927a561e5ab2`.
Downloaded bytes match the service digest and ZIP CRC checks. The extracted
log SHA-256 is
`28b4640d4eb4c984ec2d61b93f399964c694a4e3e4324f4c1c1c4a043b5ca4a1`.
Evidence is retained under
`/private/tmp/cmd-c1-remote-evidence-2026-10-23/pr43-run39929992296/`.

## Cause and correction

`report_references` normalizes references with the current OS path rules, then
the evidence validator matches them exactly to supplied bundle paths. Two new
fixture builders retained literal forward-slash paths. On Windows the
normalized references contain backslashes, so they cannot select those raw
fixture bundles. Existing production bundle builders and older passing
fixtures already normalize the bundle path.

Only the two fixture builders now apply the existing normalization invariant.
Affected positive assertions compare the findings array to `[]`, exposing
diagnostics on future failures. An existing alias regression also verifies
canonical reference equality and rejects a noncanonical dot-segment bundle.
Production matching, source/oracle/artifact validation and acceptance rules
are unchanged. No named test, import, public API, registry count, dependency
graph, command/core source, version or frozen publication input changed.

A private probe using the exact unchanged matcher sources and the released
Win32 path implementation reproduced missing-report and missing-contract
findings. Supplying the normalized bundle path yielded no findings. A separate
dot-segment control reproduced the same mechanism on all hosts. This is a
path-protocol diagnostic on macOS, not actual Windows execution. Probe output
is retained at `/private/tmp/cmd-c1-path-normalization-diagnostic.json`.

The warning-denying coverage check, all 52 coverage Native tests and formatting
of the three affected test files passed. Logs are retained as
`/private/tmp/cmd-c1-report-path-{check,coverage,fmt}.log`.
The new exact commit still requires fresh applicable local evidence, an honest
partial audit and its own bounded bootstrap authorization under plan section
15.1. Actual Windows and all required PR/actual-main gates remain pending.
