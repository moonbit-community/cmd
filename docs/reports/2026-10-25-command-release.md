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
was still absent. Exact-version MoonX functional acceptance is pending.

`tests/release_runner/current/latest.json` records all 78 actual latest command
coordinates for local acceptance. `current/published.json` remains the previous
frozen cross-platform baseline; this local release does not create a new CI or
historical archive workflow.
