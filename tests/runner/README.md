# Workspace command test runner

The Native test driver executes prebuilt workspace commands. It shares case,
fixture, process, HTTP and report helpers with the [release runner](../release_runner/README.md)
through `testkit`. It never builds commands or substitutes a host command for a
candidate implementation.

| Suite | Scope | Command backend |
| --- | --- | --- |
| `contract` | Selected catalog cases with output/status/effect contracts or explicit rejection boundaries | Native or Wasm |
| `backend-pair` | Direct status/stream/file comparison of both executions after each contract passes | Native and Wasm |
| `scenarios` | Registered persistent-input, network and lifecycle scenarios | Native or Wasm |
| `compat` | Retained compatibility cohorts | Native |
| `policy` | Host authorization allow/deny cases | Wasm |
| `gnu` | Host GNU differential checks, without the compat suite | Native/Linux |
| `oracle` | Selected cases and network rounds compared with the pinned upstream container | Native or Wasm/Linux |
| `stress` | Stress cases, without the compat suite | Native |
| `all` | compat, contract, backend-pair, policy, oracle and scenarios | Selected backend, both for pairing, Wasm for policy |

`--gnu-diff` and `--stress` remain aliases for adding their independent suites.
Repeated suite selections run once; neither extension implicitly reruns compat.
The default suite is `compat`, and the default backend is Native.

## Build and select

Build serially with the local publishing account, retaining the PATH toolchain:

```sh
MOON_HOME="$HOME/.moon-accounts/cli" moon build --target native --release --deny-warn
MOON_HOME="$HOME/.moon-accounts/cli" moon build --target wasm --release --deny-warn
```

Default artifact roots are `_build/native/release/build` and
`_build/wasm/release/build`. Override with `--native-root` or `--wasm-root`.
The default manifest is `tests/fixtures/runner/cases.json`. It indexes per-command
case files; schema 1 remains readable for historical replay. Validate or list
cases before creating fixtures or launching commands:

```sh
./_build/native/release/build/mooxCLI/cmd-tests/runner/runner.exe --validate-only
./_build/native/release/build/mooxCLI/cmd-tests/runner/runner.exe --suite contract --command jq --list
./_build/native/release/build/mooxCLI/cmd-tests/runner/runner.exe --suite contract --command jq --backend wasm --report-dir test-reports/jq-wasm
./_build/native/release/build/mooxCLI/cmd-tests/runner/runner.exe --suite backend-pair --command jq --report-dir test-reports/jq-pair
./_build/native/release/build/mooxCLI/cmd-tests/runner/runner.exe --suite scenarios --backend native --report-dir test-reports/scenarios-native
./_build/native/release/build/mooxCLI/cmd-tests/runner/runner.exe --suite policy --report-dir test-reports/policy-wasm
```

`--command NAME` and `--case ID` may repeat. Selections within one kind form a
union; command and case filters intersect. An unknown command/case or empty
selection returns 2. A failed assertion or unavailable required infrastructure
returns 1. Platform exclusions produce an explicit skip with a reason.

`--list` respects the selected suites. Retained multi-command cohorts have stable
IDs such as `compat-tail-follow`; command filtering selects cohorts containing
that command, and the complete selected cohort runs. They are supplemental
grouped assertions, not individual option certification. Old duplicate case IDs
remain aliases and select their canonical case once.

Ordinary independent contract and differential cases use at most four concurrent tasks by
default; set `--jobs N` to change this. Stateful scenarios remain serial.
Local cases default to a 15-second deadline, Docker/MoonX cases to 120 seconds;
`timeout_ms` overrides the case deadline. A runner deadline is distinguished
from the candidate deliberately returning status 124. Direct children are
cancelled and waited in an uncancellable cleanup region; this does not promise
control over arbitrary grandchildren.

## Cases and evidence

Cases declare stdin, fixture files, environment, arguments, status, output and
required observations. Prefer `stdin_text`/`content_text` and text expectations
for ordinary text; use hex for binary or invalid UTF-8. Text and hex for the same
field are mutually exclusive. Preserve stable case IDs when moving cases.
`delay_ms` remains available for fixture timestamp ordering; multi-step behavior
uses a MoonBit scenario instead of encoding a new script language in JSON.
`oracle: true` also selects a contract for the pinned differential suite without
copying its definition. Newly migrated boundary contracts run in the contract suite on both
backends; they are not implicitly upstream differential cases, since their
expected status describes candidate refusal. Frozen differential boundary
fixtures keep their separate upstream status and unchanged-state checks. The
ls link/time cases exclude GNU-incompatible `-P`
extensions; jq explicit-color cases run against jq 1.8.2. Reasoned diagnostic
fragments are checked on both sides; other stream comparisons use full bytes.

A contract checks stdout and stderr, including explicitly empty streams. Partial
diagnostic assertions require `diagnostic_reason`; forbidden internal-error
strings alone do not establish correct behavior. `expected_rejection` describes
a boundary and must not be counted as upstream parity. Supported operations may
have partial output and earlier successful filesystem effects before failing.

The result vocabulary is `pass`, `fail`, `skip`, `infra`; the independent
verification vocabulary is `availability`, `contract`, `differential`,
`backend-pair`, `boundary`. Reports include source version, backend, platform, case duration,
failure stage and observed/missing dimensions. Use `--report-dir DIR` for
`summary.jsonl`, `summary.md` and retained failure artifacts. Successful fixture
workspaces are removed. Keep a fresh directory per run so evidence is not
silently overwritten.

`backend-pair` compares fresh Native and Wasm executions of every selected
contract, retaining both raw results on failure. Separate backend contract
passes cannot replace this direct comparison. Registry platform exclusions
remain explicit skips. Every report directory includes `run-metadata.json`;
each case references its run, registry and artifact identities.

JSON contracts declare partial filesystem expectations in `expected_files`:
each entry names a relative `path` and may assert `exists`, `kind`,
`content_text`/`content_hex`, octal-valued integer `mode`, symlink `target`, or
`same_identity_as`. Each requested `observe` dimension must have an actual
expectation. `cwd` is a safe fixture-relative directory. `${WORK}` expands in
arguments, text input, fixture text and text expectations; hex stays literal.
`stdout_order: "lines"` is reserved for declared unordered output and preserves
line multiplicity and termination. `expected_*_contains_all` requires every
fragment and a `diagnostic_reason`. Time relationships remain stateful tests.
Output-only contracts cannot claim filesystem dimensions.
Generic filesystem snapshots inspect path, kind and file bytes. Explicit
observations add mode, symlink target, hard-link equivalence or timestamps.
Metadata is sampled before reading file content to avoid observation-induced
atime changes. Inode numbers are converted to equivalence classes within each
fixture. Time checks compare fixed values or before/after relationships; they
must not compare separate fixture creation times as equal. POSIX-only observer
cases state their platform requirement; missing required measurements cannot
produce a semantic pass.

## Upstream and CI

Pinned comparison needs Docker, the image built from `image/`, and a reviewed
sealed profile. The default `image/profile.json` starts unsealed, so it
cannot certify upstream differential evidence. After building the image, obtain
its immutable ID and explicitly seal a staged copy of the reviewed inputs:

```sh
docker build --tag mooncmd-oracle:phase0 tests/runner/image
docker image inspect --format='{{.Id}}' mooncmd-oracle:phase0
mkdir -p test-reports/oracle-profile
cp tests/runner/image/profile.json tests/runner/image/Dockerfile tests/runner/image/versions.sh test-reports/oracle-profile/
./_build/native/release/build/mooxCLI/cmd-tests/runner/runner.exe --seal-oracle sha256:<reviewed-image-id> --oracle-profile test-reports/oracle-profile/profile.json
./_build/native/release/build/mooxCLI/cmd-tests/runner/runner.exe --suite oracle --oracle-image mooncmd-oracle:phase0 --oracle-profile test-reports/oracle-profile/profile.json --report-dir test-reports/oracle-native
```

Sealing verifies build-recipe checksums and captures source checksums and the
version inventory from the selected immutable image. `--oracle-profile FILE`
selects both the profile and its adjacent `Dockerfile`/`versions.sh`; omission
retains the tracked default path. A copied profile must match the tracked
profile ID, version, image name, base digest and recipe checksums, as well as
selected registry profile requirements. A sealed tracked identity cannot be
replaced by an override. Reports use the verified profile's actual ID.

CI seals only the copy under ignored `test-reports/oracle-profile/` and uploads
it with the reports. Tracked inputs and generated-file checks remain unchanged.
Supply that saved profile to the coverage audit with `--oracle-profile FILE`.
Review the resulting profile as part of the run evidence. Every oracle run
rechecks the resolved image ID
and inventory; a mismatch or unavailable observer yields `infra`. Subsequent
container launches use that verified ID, so mutable tags cannot change a run.
The image recipe pins GNU coreutils 9.11, jq 1.8.2 and the other command upstreams.
HTTP and HTTPS fixtures are local; command contracts do not depend on a public
service. Installed host curl/wget results are separate evidence from this pinned
oracle.

The CI workflow configures package checks on Linux/macOS/Windows, reuses one
Native/Wasm release build per host, and executes contracts/scenarios on both
backends. Linux oracle, GNU checks and candidate manifest validation reuse those
builds. Scheduled and manual runs add stress and published consumer checks.
Oracle steps use the sealing and verification above; recording a Docker tag or versions file alone
does not satisfy that gate. The checked-in unsealed profile supplies no
successful immutable-oracle execution evidence. Reports retain actual
selection/execution evidence; command inventory labels and README claims do not
certify option coverage by themselves.
