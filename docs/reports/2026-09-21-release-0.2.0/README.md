# 0.2.0 publication and acceptance

The source release gate [35576541301](https://github.com/moonbit-community/cmd/actions/runs/35576541301)
passed Linux, macOS and Windows at commit
`442015078b8dc01f64f499e5df0847d7c7458c3d`. Publication followed that successful
gate: local `MOON_HOME="$HOME/.moon-accounts/cli" moon publish` first published
`cli/core@0.2.0`, then each of the 47 command modules sequentially. All 48
invocations exited 0 and received `Server status: 200 OK`; receipts are in
`publication/` and coordinates are in `publication.json`. `timeout` remains
local-only and was not published.

## Actual source execution

| Host | Contract passes per backend | Boundary passes | Platform skips | Stateful scenarios per backend |
| --- | ---: | ---: | ---: | --- |
| Linux | 293 | 8 | 3 | 5 passed |
| macOS | 293 | 8 | 3 | 5 passed |
| Windows | 270 | 9 | 25 | 4 passed, POSIX metadata scenario skipped |

Native and Wasm each ran these suites. Linux's fixed oracle separately passed
230 differential cases and 2 boundary cases per backend, including the complete
curl/Wget authentication and cookie scenario. Oracle versions and image digest
are saved alongside the raw JSONL reports. Source CI job and step timing is in
`source-ci.json`; this is not an estimate of performance improvement.

## Exact published MoonX acceptance on macOS

The consumer driver invoked all 47 exact `cli/<command>@0.2.0` coordinates,
inheriting the requested `MOON_HOME`. The complete 382-case selection passed:

| Verification | Passed | Skipped |
| --- | ---: | ---: |
| Contract | 292 | 1 |
| Availability | 81 | 0 |
| Boundary | 6 | 2 |

There were zero failures or infrastructure failures. `moonx-results.jsonl`
records every case and `moonx-summary.json` records counts. The three skips are
Windows-specific cases; availability and boundary rows do not certify semantic
compatibility. The published manifest is
[`published-0.2.0.json`](../../../tests/release_runner/published-0.2.0.json).

The first invocation encountered registry download timeouts. Once networking
recovered, a full retry isolated four launcher argument mismatches: MoonX
consumes the first `--`, so the driver must insert its own separator before
the case argv. Direct `moonx cli/echo@0.2.0 -- -- -e` and
`moonx cli/dirname@0.2.0 -- -- -operand` verified the cause. Correcting the
driver preserved the original assertions and the full subsequent run passed.
No command package needed republishing. Earlier reports remain under local
`test-reports/moonx-0.2.0-final` and `moonx-0.2.0-retry1`; the passing report is
`test-reports/moonx-0.2.0-argv-fixed`.

Scheduled/manual CI now selects the 0.2.0 published manifest for three-platform
MoonX smoke and Linux fixed-oracle published differential. Workspace CI and
the local published result above are distinct evidence; remote published
acceptance is reported by its own workflow run. Historical 0.1.x manifests,
frozen fixtures and previous audit reports remain unchanged.
