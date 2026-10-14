# Test-system migration: local implementation evidence

Date: 2026-10-14. Source checkout: `f54baac45730f5ded956ceb41f353b77fdd5c34e` plus uncommitted test-system changes. This report records local implementation checks, not a clean-commit coverage acceptance, CI result, registry upload, or new release.

The unified registry contains 1,278 behavior entries: 848 JSON cases, 333 named package tests, 79 metadata probes, 11 compatibility cohorts, 6 stateful scenarios, and 1 policy test. The migration baseline verifier checked 242 immutable historical manifest and report files. The current candidate validates as 78 releasable packages selecting 841 cases; `timeout` remains local-only. Historical published manifests moved to `tests/release_runner/historical/` without content changes.

The workspace and release runners select registered identities, emit run-level metadata, distinguish semantic contracts from availability and boundaries, and require direct Native/Wasm pair evidence where applicable. The coverage audit binds a committed base/head range and clean-head execution reports to declared behavior changes. Its integration test exercises a real two-commit Git fixture and rejects dirty or mismatched run provenance. The freeze path requires exact registry receipts and MoonX evidence before archiving a published snapshot. Lifecycle registrations identify 26 proven paths and one deferred grandchild-process boundary; injected failure tests do not claim a real registry or operating-system outage.

## Local execution results

All commands used `MOON_HOME="$HOME/.moon-accounts/cli"` with the existing PATH toolchain, except direct prebuilt executables. The package check, test, build, interface generation, and format steps were serialized.

| Check | Observed result | Local evidence |
| --- | --- | --- |
| Registry refresh and baseline verification | 1,278 registered behaviors; 242 immutable files verified | `tests/registry/registry.json`, `tests/registry/baseline.json` |
| All-target MoonBit check and package tests | Check passed; Native 333/333, Wasm 217/217, Wasm-GC 2/2, JS 2/2 | Local Moon command output |
| All-target release build | Passed | `_build/native/release/build/`, `_build/wasm/release/build/` |
| Native and Wasm contracts | 617 contract and 36 boundary passes per backend; 4 platform skips per backend | `_build/verification/contract-native-final/`, `_build/verification/contract-wasm-final/` |
| Direct backend pair | 617 paired semantic passes and 2 explicit macOS skips | `_build/verification/backend-pair-verified/` |
| Stateful scenarios | 10 semantic passes per backend | `_build/verification/scenarios-native-final/`, `_build/verification/scenarios-wasm-final/` |
| Metadata probes | 79/79 on Native and 79/79 on Wasm | `_build/verification/metadata-native-final/`, `_build/verification/metadata-wasm-final/` |
| Exact published MoonX versions | 841 rows across 78 commands: 616 contracts, 185 availability, 36 boundaries, 4 skips, 0 failures | `_build/verification/published-full-smoke-final/` |
| Candidate manifest validation | 78 packages and 841 selected cases | `tests/release_runner/current/candidate.json` |
| Unsealed oracle preflight | Nonzero exit, 6 infrastructure rows, 0 differential passes | `_build/verification/oracle-profile-final/` |

Each retained report directory has `run-metadata.json`, `summary.jsonl`, and `summary.md`. The published MoonX check executed the already published exact coordinates; it did not publish any package. Its metadata records `git_dirty=true`, so it cannot be used to freeze a new published snapshot. The local machine did not have Docker available, and no immutable upstream-oracle differential was executed. CI now stages and seals a copy of the reviewed oracle profile in its report directory, but that workflow has not run for this change. Publication freeze still requires reviewed release evidence and cannot treat a CI-only staged profile as a published acceptance result. The clean-head push audit has not been run for this uncommitted worktree.

Product files under `core/` and `commands/` were not changed. No commit, push, or publication was performed for this migration report.
