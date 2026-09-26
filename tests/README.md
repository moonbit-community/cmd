# cmd tests

This workspace module validates command behavior and is not published with the
commands. All test drivers and automation are MoonBit. The two Native drivers
share `testkit`: fixture descriptions, byte assertions, process execution,
HTTP fixtures, filesystem observations and reports. They execute Native or Wasm
commands, or exact published MoonX versions.

| Layer | Purpose | Entry point |
| --- | --- | --- |
| Package tests | Parsers, algorithms, shared APIs and focused in-process behavior | `MOON_HOME="$HOME/.moon-accounts/cli" moon test --target all` |
| Command contracts | Input, exact output/status and declared filesystem effects | [Workspace runner](runner/README.md), `--suite contract --backend native\|wasm` |
| Stateful scenarios | Persistent shell input, HTTP exchanges and process lifecycle | Workspace runner, `--suite scenarios --backend native\|wasm` |
| Compatibility cohorts | Retained cross-command regressions | Workspace runner, `--suite compat` |
| Host authorization | Allowed/denied Wasm capabilities, independently of semantics | Workspace runner, `--suite policy` |
| Upstream differential | Byte/status/effect comparison with pinned GNU/Linux tools | Workspace runner, `--suite oracle`; host GNU checks use `--suite gnu` |
| Published consumers | Exact `moonx cli/<cmd>@<version>` invocations | [Release runner](release_runner/README.md) |

Active command cases live in `cases/<command>.json`; manifests select those
stable IDs. Stateful cases register MoonBit functions rather than a second
scripting language. Package tests, CLI contracts, backend checks and stateful
scenarios protect different boundaries; similar inputs alone are not a reason
to delete one. Historical reports and the frozen 0.1.x release manifest remain
replayable and are not active duplicate test definitions.

## Running locally

Keep the current PATH toolchain and use the publishing account for every local
Moon command. Serialize workspace commands because they share the build tree:

```sh
MOON_HOME="$HOME/.moon-accounts/cli" moon check --target all --deny-warn
MOON_HOME="$HOME/.moon-accounts/cli" moon test --target all
MOON_HOME="$HOME/.moon-accounts/cli" moon build --target native --release --deny-warn
MOON_HOME="$HOME/.moon-accounts/cli" moon build --target wasm --release --deny-warn
```

Run the existing Native driver against the selected command backend:

```sh
./_build/native/release/build/mooxCLI/cmd-tests/runner/runner.exe --suite contract --backend native --command jq --report-dir test-reports/jq-native
./_build/native/release/build/mooxCLI/cmd-tests/runner/runner.exe --suite scenarios --backend wasm --report-dir test-reports/scenarios-wasm
MOON_HOME="$HOME/.moon-accounts/cli" ./_build/native/release/build/mooxCLI/cmd-tests/release_runner/release_runner.exe --manifest tests/release_runner/published-0.1.0.json --suite smoke --command base32 --report-dir test-reports/published-base32
```

Use a fresh report directory for a new run; failures retain their working files
and raw stdout/stderr. The driver never rebuilds commands. Ensure artifacts
match the source being tested. `release_runner/published-0.1.0.json` selects
the current 58 published command rows. The preparation manifest
`release_runner/candidate-0.1.0.json` remains validation-only; its candidate
flags are not the release's current publication status. The driver
inserts `--` after the MoonX coordinate so a command's own leading `--` reaches
the command unchanged.

## Reading results

Every case separates **result** (`pass`, `fail`, `skip`, `infra`) from
**verification** (`availability`, `contract`, `differential`, `boundary`). A
successful package download and invocation is availability evidence. A correctly
rejected unsupported operation is boundary evidence. Neither counts as semantic
compatibility. Only passing contract/differential observations with all required
measurements count toward semantic coverage.

Reports include platform, backend, source version, elapsed time, failure stage,
observed dimensions and missing required observations. Selected case coverage,
platform applicability, actual execution and passing semantic observations are
different facts. An empty `supported_options` list certifies no options.

File bytes and kind are ordinary observations. Cases explicitly request mode,
symlink target, hard-link relationships or timestamps. POSIX metadata observers
may use the host's `stat`/`readlink` in tests; product commands still use only
public MoonBit APIs. Identity comparisons describe relationships within a
fixture, not raw inode equality across two directories. Timestamp checks require
fixed values or before/after relationships, not independently sampled wall
clocks. A missing required observer is not a successful comparison.

## CI and maintenance

Pull requests retain Linux, macOS and Windows checks and package tests. Each
host builds Native and Wasm release artifacts once; all following suites and
candidate validation reuse them. Portable command contracts and stateful
scenarios run on both backends. Linux additionally runs the host GNU suite and
pinned Docker oracle without repeating compatibility. Scheduled/manual runs
reuse the same builds for published smoke, Linux published differential and
Linux stress. CI uses its installed toolchain, never a developer account.

GitHub records step/job durations; case reports record execution durations.
Only reports and failed fixtures are uploaded, not the whole build tree.
Failures are not automatically retried. A CI definition is not proof that its
platforms passed: implementation reports record the platforms actually run.
The [0.2.0 source gate](https://github.com/moonbit-community/cmd/actions/runs/35576541301)
passed on all three hosts, including Linux Native/Wasm pinned oracle cases.
Published-consumer results are recorded in the separate
[release evidence](../docs/reports/2026-09-21-release-0.2.0/README.md).

When changing a behavior, update its package README, help, support records and
regression together. Remove an assertion only after mapping it to retained
coverage of the same behavior, backend and observed effects. Finish with serial
`MOON_HOME="$HOME/.moon-accounts/cli" moon info` and
`MOON_HOME="$HOME/.moon-accounts/cli" moon fmt`, then inspect interface changes.
