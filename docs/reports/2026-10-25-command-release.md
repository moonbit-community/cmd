# Command documentation and latest-version release

Updated: 2026-10-25

This release starts from the completed O-stage mainline. It reviews every
command README against the implementation and metadata output, preserves the
existing documentation style, and accepts all 78 published commands through
their exact latest MoonX coordinates. `timeout` remains local-only.

## Scope and preparation

- Dependency declarations and dependency versions are unchanged.
- The existing unpublished package versions are retained. Registry inspection
  found 77 unused coordinates: `cli/core@0.8.0` and 76 command versions.
  `cli/curl@0.2.3` and `cli/wget@0.2.3` are already current and are reused.
- All 79 command READMEs were reviewed, including local-only `timeout`.
  Corrections cover actual option forms, input/output behavior, timer limits,
  filesystem boundaries, and stale candidate wording.
- Help corrections cover cmp's optional second input, grep recursion, ln's
  invocation forms, separate make flags, nl's delimiter, printf's `%F`, sleep's
  millisecond cap, and gzip/gunzip/zcat stream modes. The touch boundary
  diagnostic names its existing async dependency correctly.
- Shared documentation distinguishes cp's buffered copying from mv's
  rename-only implementation. Windows Wasm link-move restrictions remain.
- Existing current help/version contracts are refreshed from matching Native
  and Wasm captures. Historical published expectations remain unchanged.

## Validation and release status

All-target strict checking and release builds passed locally. The metadata
comparison passed all 237 Native, Wasm and backend-pair rows for 79 commands.
The full candidate validates 78 packages and 2127 selected cases.

The user requested a local documentation release without a PR or a new CI
cycle. PR #55 was closed and its workflow was cancelled. Help and diagnostic
strings are documentation corrections; command logic and dependencies are
unchanged. The existing O-stage source validation and the local checks above
are retained. Serial registry publication completed for `cli/core@0.8.0` and
76 new command versions, with status 0, `Server status: 200 OK`, and exact
registry confirmation for every upload. Curl and wget retain `0.2.3`.
Transient transport failures were retried only after confirming the coordinate
was still absent. A final registry query confirmed that all 79 coordinates
(core plus 78 commands) are the registry's latest versions.

`tests/release_runner/current/latest.json` records all 78 actual latest command
coordinates for local acceptance. `current/published.json` remains the previous
frozen cross-platform baseline; this local release does not create a new CI or
historical archive workflow.

## Local MoonX acceptance

All executions inherited `MOON_HOME="$HOME/.moon-accounts/cli"` and used exact
`cli/<command>@<version>` coordinates on macOS. The existing release runner
completed the full 2127-case selection:

| Result | Cases |
| --- | ---: |
| Semantic pass | 1868 |
| Availability observation | 186 |
| Documented boundary verified | 51 |
| Platform skip | 22 |
| Failure | 0 |

The result audit found successful nonmetadata observations for 75 commands.
Find, test and yes had only metadata or availability assertions in that
selection, so ten additional exact-version functional checks were executed:

- `cli/find@0.2.2`: name/type filtering and maximum traversal depth.
- `cli/test@0.2.2`: integer true/false, regular-file and directory predicates,
  missing paths, and invalid-integer status 2.
- `cli/yes@0.1.3`: default `y` output and joined operands, piped into
  `cli/head@0.2.2`, including successful producer exit when the pipe closes.

All ten checks passed. All 78 commands therefore have actual nonmetadata
runtime observations, including documented rejection profiles. No functional
failure or additional README/help discrepancy was observed in this local
selection. Platform skips and the documented filesystem, process and terminal
boundaries remain; this is not a new cross-platform, upstream-parity or formal
performance acceptance claim.

The review updated 41 command READMEs after checking all 79, including
local-only timeout. Help/diagnostic edits changed no command logic. No
`moon.mod` or `moon.pkg` declaration changed.

Reproduce the full local run from the repository root:

```sh
MOON_HOME="$HOME/.moon-accounts/cli" \
  ./_build/native/release/build/mooxCLI/cmd-tests/release_runner/release_runner.exe \
  --manifest tests/release_runner/current/latest.json --suite smoke --jobs 1 \
  --timeout-ms 120000 --report-dir test-reports/moonx-latest-rerun
```

Retained local results are under
`test-reports/moonx-latest-all-20261025/`: `summary.md`, `summary.jsonl`,
`run-metadata.json`, `acceptance-summary.md`, and `functional-extra.json`.
Upload receipts are in `test-reports/direct-release*-20261025/`; they record
77 acknowledged new uploads across the resumed serial runs.

## Local workspace

The primary checkout was synchronized from main before this work. Pre-existing
generated-interface edits remain preserved in the stash named
`codex-preserve-local-before-main-release-2026-10-25`; they were based on the
older source and were not reapplied over the updated interfaces. The user's
untracked `docs/algorithm-performance-plan.md` was restored. Release and
documentation commits remain local under the requested direct-release flow.
