# cmd tests

This workspace module validates command behavior and is not published with the
commands. All test drivers and automation are MoonBit. The Native drivers
share `testkit`: fixture descriptions, byte assertions, process execution,
HTTP fixtures, filesystem observations and reports. They execute Native or Wasm
commands, or exact published MoonX versions.

| Layer | Purpose | Entry point |
| --- | --- | --- |
| Package tests | Parsers, algorithms, shared APIs and focused in-process behavior | `MOON_HOME="$HOME/.moon-accounts/cli" moon test --target all` |
| Registered package evidence | Exact named package tests with auditable per-test reports | [Package report adapter](packages/README.md), `tests/packages/run.mbtx` |
| Command contracts | Input, exact output/status and declared filesystem effects | [Workspace runner](runner/README.md), `--suite contract --backend native\|wasm` |
| Backend pairing | Direct comparison of Native and Wasm status, streams and declared file effects | Workspace runner, `--suite backend-pair` |
| Stateful scenarios | Persistent shell input, HTTP exchanges and process lifecycle | Workspace runner, `--suite scenarios --backend native\|wasm` |
| Compatibility cohorts | Retained cross-command regressions | Workspace runner, `--suite compat` |
| Host authorization | Allowed/denied Wasm capabilities, independently of semantics | Workspace runner, `--suite policy` |
| Upstream differential | Byte/status/effect comparison with pinned GNU/Linux tools | Workspace runner, `--suite oracle`; host GNU checks use `--suite gnu` |
| Published consumers | Exact `moonx cli/<cmd>@<version>` invocations | [Release runner](release_runner/README.md) |

The [unified registry](registry/README.md) owns every test identity and typed
source binding. Active command cases live in `cases/<command>.json`; generated
manifests select those stable IDs. Stateful cases register MoonBit functions rather than a second
scripting language. Package tests, CLI contracts, backend checks and stateful
scenarios protect different boundaries; similar inputs alone are not a reason
to delete one. Historical reports and the frozen 0.1.x release manifest remain
replayable and are not active duplicate test definitions.

The metadata regression covers the common command surface independently of
behavioral cases:

```sh
MOON_HOME="$HOME/.moon-accounts/cli" moon run --target native tests/metadata/verify.mbtx native --report-dir _build/reports/metadata-native
MOON_HOME="$HOME/.moon-accounts/cli" moon run --target native tests/metadata/verify.mbtx wasm --report-dir _build/reports/metadata-wasm
```

It checks the exact standalone `--help` and `--version` output contract for
every workspace command on both Native and Wasm, including the local-only
`timeout` module.

The stage-0 dependency invariant checks all 81 current `moon.mod` files and
their workspace membership: core, 79 commands and tests declare async 0.22.5;
core-dependent modules request the current core coordinate, while the six
independent commands remain independent. This is a manifest consistency test,
not independent registry resolution. Before publication, a temporary minimal
workspace containing only the selected module and local core can check that
other command workspace members are not masking dependencies. Retain its
`moon tree` output, source identities and Native/Wasm checks as local-core
evidence.

Core 0.7.0 is intentionally unpublished until the centralized release. Exact
standalone registry resolution for its dependent modules and exact-version
MoonX consumers remain release acceptance, after core and the changed commands
are published in the documented order. Run standalone module checks from the
module directory with `MOON_WORK=off`; pin `MOON_WORK` to the temporary
`moon.work` path for minimal-workspace checks. These modes must be recorded
separately. A local-core pass cannot establish registry availability or published
consumer parity, and no early core publication is required to run stage 0.

`tests/cases/` describes the workspace. The historical release base
`release_runner/historical/active-cases.json` overlays 21 frozen metadata
contracts from `release_runner/historical/published-metadata-2026-10-11.json`,
preserving older help/version bytes.
New release candidates must use the workspace cases, rather than inheriting
that historical metadata overlay. Overrides must refer to an existing case
with the same command, and duplicate overrides are rejected.

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
MOON_HOME="$HOME/.moon-accounts/cli" ./_build/native/release/build/mooxCLI/cmd-tests/release_runner/release_runner.exe --manifest tests/release_runner/current/published.json --suite smoke --command base32 --report-dir test-reports/published-base32
```

Use a fresh report directory for a new run; failures retain their working files
and raw stdout/stderr. The driver never rebuilds commands. Ensure artifacts
match the source being tested. `release_runner/current/published.json` selects
the current 78 published command rows. The generated preparation manifest
`release_runner/current/candidate.json` remains a candidate until exact registry
receipts and required published evidence pass the freeze gate. The driver
inserts `--` after the MoonX coordinate so a command's own leading `--` reaches
the command unchanged.

## Reading results

Every case separates **result** (`pass`, `fail`, `skip`, `infra`) from
**verification** (`availability`, `contract`, `differential`, `backend-pair`,
`boundary`). A successful package download and invocation is availability
evidence. A correctly rejected unsupported operation is boundary evidence.
Neither counts as semantic
compatibility. Only passing contract, differential or backend-pair observations
with all required measurements count toward their respective semantic coverage.

Reports include platform, backend, source version, elapsed time, failure stage,
observed dimensions and missing required observations. Selected case coverage,
platform applicability, actual execution and passing semantic observations are
different facts. An empty `supported_options` list certifies no options.

Every run also writes `run-metadata.json`; case rows reference its `run_id`,
registry revision, artifact identity and, when required, verified oracle profile. Missing
provenance keeps reproducibility partial. Native and Wasm contract passes do not
substitute for the direct `backend-pair` result. The oracle profile remains
unsealed until its image digest, version inventory, and source checksums are
collected; oracle-dependent runs must fail as infrastructure errors meanwhile.

Environment provenance records both a host fingerprint and the actual child
profiles observed at spawn boundaries. Profiles apply each invocation's
overrides and inheritance setting, keep unset and empty values distinct, and
contain only approved locale, timezone and terminal settings. The execution
fingerprint covers these profiles; metadata probes do not enter that set.
Program basenames are recorded without user directory paths. Additional
profiles discovered during execution do not falsely indicate source drift;
changes to the host fingerprint or input artifacts still invalidate the run.

Use the [change coverage audit](coverage/README.md) to connect an explicit Git
range to registry behaviors and actual evidence before pushing a behavior
change. Package-test success or more case rows alone cannot establish coverage.
The [package report adapter](packages/README.md) supplies standard reports for
exact registered package tests; use those per-test reports when an audit needs
package evidence. It serializes child Moon invocations and must not overlap
workspace build, check, test, info or format commands. For applicable changes,
a missing or failing audit blocks the push, including documented boundaries
without the required passing rejection evidence.

File bytes and kind are ordinary observations. Cases explicitly request mode,
symlink target, hard-link relationships or timestamps. POSIX metadata observers
may use the host's `stat`/`readlink` in tests; product commands still use only
public MoonBit APIs. Identity comparisons describe relationships within a
fixture, not raw inode equality across two directories. Timestamp checks require
fixed values or before/after relationships, not independently sampled wall
clocks. A missing required observer is not a successful comparison.

## CI and maintenance

The CI workflow configures Linux, macOS and Windows checks and package tests.
Each host builds Native and Wasm release artifacts once; following suites and
candidate validation reuse them. Portable command contracts and stateful
scenarios run on both backends. Linux additionally runs the host GNU suite and
pinned Docker oracle without repeating compatibility. Scheduled/manual runs
reuse the same builds for published smoke, Linux published differential and
Linux stress. CI uses its installed toolchain, never a developer account.

GitHub records step/job durations; case reports record execution durations.
Only reports and failed fixtures are uploaded, not the whole build tree.
Failures are not automatically retried. A CI definition is not proof that its
platforms passed: implementation reports record the platforms actually run.
The archived [0.2.0 source gate](https://github.com/moonbit-community/cmd/actions/runs/35576541301)
and [0.2.0 release evidence](../docs/reports/2026-09-21-release-0.2.0/README.md)
describe that historical revision. The
[2026-10-11 repair report](../docs/reports/2026-10-11-fidelity-repair/README.md)
records the earlier repair. The current core 0.6.0 and 78-command baseline is
recorded in the [metadata release report](../docs/reports/2026-10-15-metadata-release/README.md).
Historical acceptance never validates a later harness revision or seals a newly
built oracle image.

PR and main-push verification additionally require the `coverage-audit` job.
Its reviewed impact input is `coverage/ci-change.json`; CI binds evidence from
that exact execution and checks every applicable platform, not merely any one
passing host. Native-only package evidence complements the existing package
pairs. The required main-branch checks and PR protection are operational settings
that must be verified against GitHub; workflow text alone does not enable them.

Verification serves the current workspace and current published coordinates.
CI retains its reports, required identity checks and failed fixtures using the
normal Actions artifact retention policy. Source, artifact and oracle hashes
bind the current results to what actually ran; no GitHub Release archive,
historical evidence backfill or old-image recovery is required. Existing old
reports retain their historical meaning and do not establish current acceptance.

When changing a behavior, update its package README, help, support records and
regression together. Remove an assertion only after mapping it to retained
coverage of the same behavior, backend and observed effects. Finish with serial
`MOON_HOME="$HOME/.moon-accounts/cli" moon info` and
`MOON_HOME="$HOME/.moon-accounts/cli" moon fmt`, then inspect interface changes.
