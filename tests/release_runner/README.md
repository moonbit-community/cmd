# Published-version Runner

`release_runner` executes exact `moonx cli/<command>@<version>` coordinates.
It shares cases, fixtures, process capture, byte assertions, observations and
report writing with the workspace runner through `testkit`.

Validate the retained preparation manifest against local package versions:

```sh
MOON_HOME="$HOME/.moon-accounts/cli" moon run --target native tests/release_runner -- \
  --manifest tests/release_runner/candidate-0.2.0.json --suite validate
```

Run published 0.2.0 against the pinned oracle:

```sh
MOON_HOME="$HOME/.moon-accounts/cli" moon run --target native tests/release_runner -- \
  --manifest tests/release_runner/published-0.2.0.json --suite differential \
  --oracle-image mooncmd-oracle:phase0 --report-dir _build/release-report
```

`all` aliases `differential`. It requires the oracle and cannot fall back to
smoke. `smoke` needs no Docker oracle: successful ordinary cases report
`result=pass, verification=availability`. They do not count as semantic passes.
Explicit contracts and documented rejection boundaries retain their own
verification level. Availability checks do not replace the release differential
gate. `latest`, ranges and implicit versions are rejected. `timeout` remains
local-only and is absent from the release manifest.

Published 0.2.0 selects 382 shared per-command cases across 47 command modules.
Frozen schema 1 manifests (`manifest.json` and their bases) remain readable after
local source versions change. Only `validate` compares pinned versions to local
package versions. The retained preparation manifest accepts `validate` and
`--list`; its candidate flags deliberately continue to block execution. Use
`published-0.2.0.json` for the released packages.

The process argv is `moonx cli/<command>@<version> -- <command arguments>`.
The inserted separator preserves a command's own leading `--`; such an operand
must not be consumed as MoonX's separator. Local launchers inherit
`MOON_HOME="$HOME/.moon-accounts/cli"`. Publication and exact-version execution
are separate facts; current results are in the
[release evidence](../../docs/reports/2026-09-21-release-0.2.0/README.md).

Contracts require explicit stdout and stderr assertions plus status. Stable
outputs use complete bytes; partial diagnostics require a reason. A prohibition
on internal diagnostics alone cannot establish public behavior. Frozen weak
contracts report invalid contracts instead of being silently promoted to semantic
evidence. Unsupported operations are checked as `boundary`, including nonzero
status, a diagnostic and preserved fixture observations; they do not count as
upstream agreement.

Differential cases compare status, stdout, stderr, file contents and types.
Cases explicitly request additional mode, symlink-target and within-fixture
identity observations. A missing required observation is infrastructure failure.
Timestamp relations belong to stateful scenarios; independent wall-clock
timestamps must not be compared. The pure MoonBit HTTP fixture is started only
when applicable selected cases need it.

Repeat `--command NAME` or `--case ID` to select unions within each filter;
command and case filters intersect. `--list` prints command/ID pairs before
launching MoonX, Docker or HTTP fixtures. Unknown selectors and empty selections
exit 2. `--jobs` defaults to 4 independent cases. There are no automatic retries.
The default deadline is 120 seconds, overridable by positive `--timeout-ms` or
case `timeout_ms`. A command's own exit 124 differs from a runner deadline.
Platform-excluded cases report `skip` with a reason. Schema 1 `posix` remains
accepted alongside `linux`, `macos` and `windows`.

`--report-dir` writes the shared JSONL/Markdown results plus `coverage.jsonl`
with selected, platform-applicable, executed and semantically verified options.
Each result includes its source coordinate, real OS, backend, duration and failure
stage. Availability, skipped and boundary cases do not certify options. Registry,
missing asset, oracle, timeout, candidate and fixture failures stay distinct.
Failed cases retain working directories and raw stdout/stderr; successful cases
are cleaned. Use a fresh report directory for independent runs. Local child
launchers inherit `MOON_HOME`; CI uses its own environment without developer
account credentials.

When publishing, update package versions, README, help, catalog, compatibility
records and case coverage together. Validate first, publish only with explicit
authorization, then rerun exact published coordinates after their assets exist.
