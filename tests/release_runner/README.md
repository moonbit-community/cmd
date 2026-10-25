# Published-version Runner

`release_runner` executes exact `moonx cli/<command>@<version>` coordinates.
It shares cases, fixtures, process capture, byte assertions, observations and
report writing with the workspace runner through `testkit`.

The 2026-10-25 release uses `current/latest.json` as an ordinary published
manifest containing exact registry versions and the current local acceptance
cases. Core 0.8.0 and 76 command packages have been uploaded; curl and wget
retain 0.2.3. Local MoonX acceptance covered all 78 latest commands: the
2,127-case run recorded 1,868 semantic passes, 186 availability passes,
51 explicit boundary results, 22 platform skips and zero failures. Ten
supplemental functional checks for find, test and yes also passed, so all 78
commands have functional checks beyond metadata/availability. Their results
are in `test-reports/moonx-latest-all-20261025/functional-extra.json`.
Dependency declarations remain unchanged. Run the local consumer suite with:

```sh
MOON_HOME="$HOME/.moon-accounts/cli" moon run --target native tests/release_runner -- \
  --manifest tests/release_runner/current/latest.json --suite smoke \
  --report-dir test-reports/release-latest-smoke
```

`current/published.json` remains the previous frozen baseline. This local
release does not replace it through the archive/freezing workflow described
below. Publication and the observed acceptance scope are recorded in the
[release report](../../docs/reports/2026-10-25-command-release.md); no new
cross-platform or formal performance acceptance is claimed.

Validate the retained preparation manifest against local package versions:

```sh
MOON_HOME="$HOME/.moon-accounts/cli" moon run --target native tests/release_runner -- \
  --manifest tests/release_runner/current/candidate.json --suite validate
```

Regenerate the current candidate after changing command package versions:

```sh
MOON_HOME="$HOME/.moon-accounts/cli" moon run --target native tests/release_runner -- \
  --generate-candidate
```

The generator reads versions only from `commands/*/moon.mod`. Release
metadata (`compare_profile`, supported options, policy sensitivity and the
releasable set) is authoritative in `tests/registry/registry.json` under
`release_commands`; it is not inferred from case coverage. Registry refresh
exports `release-profiles.json` only as a compatibility artifact. A supplied
`--metadata` file must exactly match the registry section. The same command regenerates
`current/active-cases.json` from JSON-case entries in `tests/registry/registry.json`;
the generated current index has no historical metadata overrides. Use
`--registry FILE` or `--active-output FILE` only when reviewing an alternate
registry input. Missing metadata, invalid registry entries, a module-name
mismatch, or a command version that cannot be parsed is a hard generation error.
The candidate also records the exact `cli/core` version read from `core/moon.mod`.
Validation checks both that core coordinate and every command's module name
against the selected candidate.

The generator validates the complete candidate against its generated case
index before writing it. It sorts command names, case files, and selected case
IDs using a stable lexical order and never expands `supported_options` from
case labels. `current/published.json` preserves the previous frozen release;
`current/published.json.cases.json` retains its historical metadata expectations
separately from the generated candidate corpus.

An optional candidate `release_scope` selects a nonempty, unique list of command
names in lexical order. The candidate still contains and validates all release
commands against their source modules. Only selected commands need upload
receipts and new MoonX acceptance; the shared core receipt remains mandatory.
For historical stage 0 the scope was `["curl", "mv", "wget"]`, with core 0.7.0.
Its other 75 command coordinates and frozen cases remained unchanged.
Omitting the field retains a full release. A published manifest must
not contain `release_scope`.

The legacy `publish_candidate.mbtx` uploader rejects scoped candidates before
account, registry or upload operations. Its full-inventory loop must not be used
for a partial release. Publish only the reviewed core and selected command
coordinates, serially, after their required checks pass.

The shared network authentication and interrupted-transfer scenarios launch the
same fixture through exact MoonX coordinates during release acceptance. Each
retained call identifies its package version and argv; metadata binds both curl
and wget even though curl owns the scenario. Smoke runs check the scenario
contract. Oracle scenario runs additionally require the sealed immutable image
before reporting differential agreement.

For the retained archive/freezing workflow, after publication,
`--verify-candidate --freeze-evidence FILE` permits exact
MoonX checks of the candidate only after the registry receipts have passed.
It never uploads packages. Run separate smoke and differential suites into
fresh report directories, then freeze with:

```sh
MOON_HOME="$HOME/.moon-accounts/cli" moon run --target native tests/release_runner -- \
  --manifest tests/release_runner/current/candidate.json --freeze-published \
  --freeze-evidence test-reports/release/evidence.json --release-id 2026-10-13
```

Start from `freeze-evidence.example.json`; its empty hashes deliberately fail
validation until replaced with observed values. The evidence JSON uses schema 1,
`candidate_hash` from the canonical manifest
fingerprint, `git_revision`, `registry`, `smoke_report_dirs` and
`semantic_report_dirs`. Every registry receipt supplies `package_name`, exact
`version`, HTTP `status` 200, `response_file` and the response byte
`response_sha256`; receipts are required for every command and `cli/core`.
For a scoped candidate, command receipts cover only its explicit scope.
Response bodies must contain the exact non-yanked Mooncakes package entry with
its distribution checksum. The gate independently queries the fixed official
HTTPS registry endpoint and verifies downloaded archive bytes; a local receipt
and self-authored checksum cannot establish registry state. Paths are relative to the evidence JSON directory;
absolute paths and parent traversal are rejected.
Report directories supply `run-metadata.json` and `summary.jsonl`; complete
metadata must match the candidate, Git revision, registry and case corpus.
Reports from dirty source trees are rejected. Every command needs exact MoonX
smoke from a selected fixture with its smoke verification level and required
observations; every selected case needs its contract, immutable-oracle differential
or documented boundary result with all required observation dimensions. Empty
or missing observations and duplicate case rows cannot satisfy these gates.
Skips do not satisfy these requirements.

`--host-contracts` selects explicitly platform-bound contracts and boundaries
within the release scope. The Windows acceptance job executes this selection
independently of smoke, preserving its exact MoonX status, streams and file
observations. Oracle-dependent cases cannot enter this contract-only selection;
an empty selection fails instead of claiming platform coverage.
The selected mv boundary scenario reuses the workspace observer and all Wasm
link operations through `moonx cli/mv@<version>`. It retains the runtime version,
invocations, source and target entries, link targets, referent bytes, and
open-stdin observations; the two no-clobber contracts do not replace it.

All gates run before writes. The previous current manifest is preserved byte
for byte as `historical/published-<release-id>.json` and its resolved cases
are frozen beside it in a `.cases.json` sidecar. The original base-manifest
bytes are retained separately as `.base-source.json`; replay uses the resolved
sidecar so future case-file edits cannot change the archived behavior. The
`.sources/` directory retains every recursively referenced source and override
as exact bytes, with a path-to-SHA-256 inventory. Reference cycles are rejected.
The release ID names the outgoing published snapshot. New snapshots embed
selected case definitions to preserve replay as the workspace evolves.
Existing historical files cannot be replaced;
a directory lock rejects concurrent freezes, and the current file is replaced
through a temporary file only after its archive hash has been checked.

A partial publication reconstructs the preceding committed published snapshot,
then replaces only scoped command rows and cases. Its distinct provenance
records both the candidate and predecessor source identities. Replay checks the
complete deterministic merge, so a new result cannot rewrite an unselected
command's old expectations or falsely mark an unpublished candidate as released.

After sealing the immutable oracle profile as described in the
[workspace runner guide](../runner/README.md#upstream-and-ci), a historical
published 0.2.0 comparison can be requested with:

```sh
MOON_HOME="$HOME/.moon-accounts/cli" moon run --target native tests/release_runner -- \
  --manifest tests/release_runner/historical/published-0.2.0.json --historical-replay --suite differential \
  --oracle-image mooncmd-oracle:phase0 \
  --oracle-profile test-reports/oracle-profile/profile.json --report-dir _build/release-report
```

`--oracle-profile FILE` uses a staged profile and its adjacent reviewed recipe
files without modifying the tracked default `tests/runner/image/profile.json`.
The same identity/recipe and registry checks as the workspace runner apply; a
different profile cannot be reported as `pinned-oracle-v1`. The release runner
also accepts `--seal-oracle sha256:IMAGE-ID --oracle-profile FILE` as a separate
operation. Freeze accepts the same staged profile, validates its recipe binding
to the reviewed tracked profile, and re-verifies the actual Docker identity.

`all` aliases `differential`. Oracle-dependent selections require a verified
oracle and cannot fall back to smoke. A selection containing only contracts
without `oracle: true` does not require Docker. `smoke` needs no Docker oracle:
successful ordinary cases report `result=pass, verification=availability`. They
do not count as semantic passes.
Explicit contracts and documented rejection boundaries retain their own
verification level. Availability checks do not replace the release differential
gate. `latest`, ranges and implicit versions are rejected. `timeout` remains
local-only and is absent from the release manifest.

Historical published manifests live under `historical/` and preserve their
release coordinates. Published 0.1.1 selects the first migrated command cases
alongside the frozen 0.2.0 rows for the original 47 command modules. The historical published manifest
`historical/published-2026-10-11.json` additionally selects the second 0.1.0 batch and the
P2 `column`, `date`, `strings` and `which` packages, with `cli/core@0.4.0`.
Frozen schema 1 manifests (`manifest.json` and their bases) remain readable after
local source versions change; the resolver also locates their moved base files
under `historical/`. `validate` checks candidate coordinates against local
package versions; historical manifests validate their frozen shape without
requiring current source versions. The current preparation manifest accepts
`validate` and `--list`; exact execution additionally requires verified registry
receipts through `--verify-candidate`. Use
`historical/published-0.1.1.json` for the historical 58 released packages; the
`historical/published-2026-10-11.json` snapshot covers 78 released command
coordinates. The previous `historical/published-0.1.0.json` and frozen
`historical/published-0.2.0.json` remain available for historical replay.
Historical replay requires `--historical-replay` and a verified frozen corpus
sidecar. Migrated sidecars recover source definitions from each manifest's Git
revision; they do not manufacture evidence of historical execution. Current and
historical replay no longer read mutable workspace case files. See
[frozen snapshot provenance](FROZEN-SNAPSHOTS.md) for the migration boundary.

The shared historical base preserves pre-2026-10-12 metadata output in
`historical/published-metadata-2026-10-11.json`. Its `case_overrides` replace only the
listed existing cases; active workspace contracts use the new help text and
`<command> <version>` line. Use workspace cases for future candidates so this
historical overlay cannot certify a new package against old metadata bytes.

The process argv is `moonx cli/<command>@<version> -- <command arguments>`.
The inserted separator preserves a command's own leading `--`; such an operand
must not be consumed as MoonX's separator. Local launchers inherit
`MOON_HOME="$HOME/.moon-accounts/cli"`. Publication and exact-version execution
are separate facts. Historical publication results are in the
[0.2.0 release report](../../docs/reports/2026-09-21-release-0.2.0/README.md) and
the [2026-10-11 repair report](../../docs/reports/2026-10-11-fidelity-repair/README.md).
Those archived runs do not establish a new publication or an immutable-oracle
differential pass for this test-system revision.

Contracts require explicit stdout and stderr assertions plus status. Stable
outputs use complete bytes; partial diagnostics require a reason. A prohibition
on internal diagnostics alone cannot establish public behavior. Frozen weak
contracts report invalid contracts instead of being silently promoted to semantic
evidence. Unsupported operations are checked as `boundary`, including nonzero
status, a diagnostic and preserved fixture observations; they do not count as
upstream agreement.

Differential cases compare status, stdout, stderr, file contents and types.
In `differential`/`all`, a contract marked `oracle: true` also runs the pinned
oracle and reports `differential`; both executions must satisfy the contract.
It stays a contract in `smoke`. Contract cases without the marker remain
contract-only, and rejection boundaries never become upstream parity claims.
Justified diagnostic fragments are checked in both results; all other stream
comparisons use complete normalized bytes.
Cases explicitly request additional mode, symlink-target and within-fixture
identity observations. A missing required observation is infrastructure failure.
Timestamp relations belong to stateful scenarios; independent wall-clock
timestamps must not be compared. The pure MoonBit HTTP fixture is started only
when applicable selected cases need it.

Repeat `--command NAME` or `--case ID` to select unions within each filter;
command and case filters intersect. `--list` prints command/ID pairs before
launching MoonX, Docker or HTTP fixtures. Unknown selectors and empty selections
exit 2. `--jobs` defaults to 4 independent cases. Published `smoke` execution
is serialized after macOS time contracts showed unexpected atime changes during
concurrent runs; the source of those changes is not yet established. In
differential runs, fixed-time, time-observation and delayed fixtures execute
serially after all ordinary cases finish. No assertion is weakened and there
are no automatic retries. Workspace runners retain their normal parallelism.
The default deadline is 120 seconds, overridable by positive `--timeout-ms` or
case `timeout_ms`. A command's own exit 124 differs from a runner deadline.
Command-oracle and shared network-scenario Docker calls use the testkit's
[invocation-owned container adapter](../runner/README.md#upstream-and-ci).
Their lifecycle evidence sits outside the compared fixture tree. Uncertain
ownership, control execution or cleanup remains infrastructure failure;
successful direct-child reaping alone does not establish container cleanup.
Platform-excluded cases report `skip` with a reason. Schema 1 `posix` remains
accepted alongside `linux`, `macos` and `windows`.

Every execution writes run metadata and shared JSONL/Markdown results plus
`coverage.jsonl`. Without `--report-dir`, the runner creates a unique
`test-reports/release-<timestamp>` directory. Reports include hashes of the exact
cached MoonX Wasm assets; unavailable artifact bytes make provenance partial.
Validation-only runs and source/registry preflight failures also retain metadata.
They cannot claim execution completeness or semantic case coverage.
Missing assets are resolved serially with exact-coordinate `--help` invocations
before recording the initial fingerprints. These resolution warmups retain
their original exit status and output under `asset-preflight/` and never
satisfy selected case coverage. A historical package may reject `--help`;
resolution succeeds once the invocation ends without timeout or cleanup error
and the exact cached Wasm bytes are available. Missing bytes or uncertain
cleanup stop the run with infrastructure evidence. The subsequently selected
smoke and contract cases keep their own strict status and output assertions.
The run compares its source, registry, corpus, environment and artifact inputs
before and after execution; changes prevent complete evidence. Coverage records
with selected, platform-applicable, executed and semantically verified options.
Each result includes its source coordinate, real OS, backend, duration and failure
stage. Availability, skipped and boundary cases do not certify options. Registry,
missing asset, oracle, timeout, candidate and fixture failures stay distinct.
Failed cases retain working directories and raw stdout/stderr; successful cases
are cleaned. Use a fresh report directory for independent runs. Local child
launchers inherit `MOON_HOME`; CI uses its own environment without developer
account credentials.

Release lifecycle regressions inject a pure MoonBit process response only after
the complete MoonX coordinate, argv, stdin, cwd and environment are constructed.
Missing assets and registry transport faults therefore pass through the actual
fixture, capture, classification, evidence retention and report-writing paths.
The smoke concurrency regression runs three asynchronous candidates with four
requested jobs, measures one active candidate, and uses a parallel contract-only
control to prove the injected boundary can overlap. These deterministic harness
checks do not claim live registry availability or a real published-package run.

When publishing, update package versions, README, help, catalog, compatibility
records and case coverage together. Validate first, publish only with explicit
authorization, then rerun exact published coordinates after their assets exist.
The 2026-10-11 P2 publication was validated by
`historical/published-2026-10-11.json`; its final local smoke report is
`test-reports/published-smoke-20261011-p2-final` and the release evidence is
the [P2 release report](../../docs/reports/2026-10-11-p2-release-0.1.0/README.md).

The frozen repair manifest `historical/published-2026-10-11-repair.json` records
78 exact command coordinates. Its historical repair report records 841 selected
cases at that source revision; use `--list` to inspect a current replay selection.
The two HTTPS cases use the fixed certificate fixture on POSIX hosts and are
skipped on Windows, where the native TLS fixture is unavailable. The earlier
P2 manifest remains historical. Source
gate 38119870855 is historical three-platform evidence; the repair report tracks
fresh-download and remote published acceptance separately. CI resolves the
MoonX launcher to an absolute path before fixture PATH overrides.
