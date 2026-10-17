# Change coverage audit

The audit connects an explicit committed Git range to registry bindings and
actual runner evidence. A declaration alone, a passing package test command,
or an increased case count does not establish coverage.

Run the pure MoonBit launcher from the repository root:

```text
MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/coverage/audit.mbtx \
  --base <base-ref> --head <head-ref> \
  --declaration <change.json> \
  --run-metadata <native-report>/run-metadata.json \
  --run-metadata <wasm-report>/run-metadata.json \
  --run-metadata <pair-report>/run-metadata.json \
  --manifest tests/fixtures/runner/cases.json \
  --case-corpus tests/fixtures/runner/cases.json \
  --report <coverage-audit.md>
```

`--run-metadata`, `--manifest`, `--case-corpus`, and `--oracle-profile` may be
repeated to combine separate evidence runs. Each metadata file is paired with
the `summary.jsonl` in its directory. `--report` writes Markdown plus a JSON
sidecar at `<report>.json`. Exit codes are 0 for acceptance, 1 for coverage
findings, and 2 for invalid input or infrastructure failure. The `.mbtx`
launcher fails if its native audit child returns any nonzero status.

Use `tests/coverage/push.mbtx` for the gated local push workflow. Supply the
same audit arguments plus `--remote <configured-remote>` and `--branch
<destination-branch>`. This entry requires `--report`, runs the audit before
any push, and sends the resolved audited SHA to that branch without force.
Unknown remotes, invalid branch names, missing evidence, and a rejected audit
stop before `git push`. A direct Git invocation does not install or invoke
this gate; repository policy requires using the reviewed audit workflow.

Both refs are resolved to commit SHAs before comparing paths. Runs must identify
that exact head and report a clean source revision. A run against uncommitted
sources cannot prove the committed range. Untracked report outputs should be
stored outside the source tree or in an ignored report directory. Changes under
`commands/<command>/` require that command in `affected_commands`; core changes
also require `core_impact` to be `explicit` or `all`. `all` must name every
registered command. Impact declarations still require human review: Git paths
and a registry cannot infer every semantic effect of a source change.
Omit `core_impact` when core is unchanged. Optional fields use omission for
absence; an explicit JSON `null` is not accepted by the derived decoder.
The audit itself must also run from a clean checkout at the resolved head.
Changed registered test sources must have at least one owned affected behavior
in the declaration, and a changed published manifest requires an explicit true
published-manifest impact decision.

The local push audit also accepts an empty `affected_commands` array for a
harness-only range. Every affected behavior must be a registered package test
under `tests/` without a command owner, and the range must not change `core/`
or `commands/`. Nonempty affected behaviors and actual passing evidence remain
required. This exception also checks the committed `ci-change.json` path
bindings below and requires its reviewed impact and evidence requirements to
match the local declaration. A dummy command is neither needed nor accepted as
a substitute for harness evidence. Existing command-scoped local declarations
keep their original interface.
This exception requires both declarations to contain no boundaries, deferred
behaviors, uncovered items or `core_impact`; it accepts passing harness evidence
only.

Use `change.example.json` as a shape example, replacing every case, tag, and
report reference with the actual change. Report paths are repository-relative
and must identify supplied evidence bundles. `report` preserves the earlier
single-path declaration form; `reports` supports several runs. Stable behavior
IDs, legacy aliases, and case IDs resolve to one canonical registry identity.
Scenario, cohort, policy, metadata, and package-test evidence uses typed stable
IDs; a bare display name cannot substitute for a different executor's row.
Options and operand tags, updated case IDs, and the published-manifest impact
decision must be recorded explicitly, even when they are empty or false.

For every affected behavior the audit checks the required evidence on each
required backend with all required observations present in the same execution
row. Contract passes on Native and Wasm do not prove `backend-pair` evidence.
Availability, host tools, platform skips on applicable hosts, incomplete
observations, and mismatched run identities do not establish semantic coverage.
Registry, manifest, and recursively referenced case corpus fingerprints must
match the supplied current inputs. JSON cases must be selected by the run's
matching manifest and match their canonical registered bodies, so reusing a
registered ID with a substituted invocation or assertion cannot prove coverage.
Release selection follows the runner: empty `case_ids` selects every base and
extra case; otherwise extras remain unconditional and explicit IDs select base
cases in request order. Metadata is decoded and validated through the shared
run schema, including policy provenance and Docker provenance for oracle runs.
A supplied `complete` label does not exempt missing or malformed fields.

Upstream differential evidence requires a sealed profile with the matching
immutable image digest, base image digest, version inventory hash, and source
checksums. The default profile is `tests/runner/image/profile.json`; pass
`--oracle-profile` for other immutable profiles. Published differential rows
must use the `published-wasm` backend and an exact `cli/<command>@<version>`
coordinate recorded in that run. These two evidence classes are distinct.

A deferred limitation is accepted only as a registered boundary with a passing
rejection row, a nonempty existing support document and ADR, a current limit,
and an unlock condition. A bare `deferred` label is not evidence. Reports list
uncovered, unsupported, boundary, and deferred behavior IDs separately.

`integration_wbtest.mbt` exercises the complete audit in a temporary Git
repository with two real commits, registered case inputs, and a report written
through the shared report serializer. It accepts the clean exact head, rejects
a same-ID substituted corpus with matching supplied hashes, a dirty checkout,
a different audited head, mismatched run revision and dirty run metadata, then
accepts the restored inputs. The fixture relaunches the
current compiled Native test in the temporary directory, avoiding a nested
Moon build or a process-wide directory change during concurrent tests. It
disables inherited Git configuration and hooks and removes the fixture after
execution. Its controlled report proves the audit protocol, not acceptance of
any command or published package.

## Required CI audit

The `check` workflow runs the stable `coverage-audit` job after all three
platform jobs. Branch protection must require `coverage-audit`, `ubuntu-24.04`,
`macos-15`, and `windows-2025`. A skipped or failed platform cannot establish
coverage. Pull requests audit the target-base SHA to GitHub's exact synthetic
merge SHA and verify both merge parents; pushes audit the event's exact
`before` SHA to its new SHA. A manual dispatch may supply `audit_base` as an
exact SHA. Scheduled runs and manual dispatches without a base validate the
regression evidence and explicitly report change coverage as not applicable.

For an impactful range, update the reviewed `tests/coverage/ci-change.json` in
that range. Its schema is the impact portion of the local declaration:
`schema`, `affected_commands`, `affected_behaviors`, `affected_options`,
`affected_operands`, `case_ids`, optional `core_impact`,
`published_manifest_affected`, `required_backends`, `required_evidence`,
`required_observations`, `boundaries`, `deferred`, and `uncovered`. Add
`harness_bindings`, an array of objects containing a changed `path` and its
affected registered package-test `behavior_ids`. Do not supply `coverage`,
report paths, pass labels, or other execution outcomes: the CI input rejects
them. Requirements come from this reviewed impact and the registry; successful
rows never generate the declared scope.

Harness-only changes use their registered tests with an empty
`affected_commands` array. Nonregistered harness/configuration paths need
explicit bindings to affected harness tests. Changed registered test sources
must still declare their owned behaviors. Frozen published JSON snapshots
require `published_manifest_affected`, without one binding per source blob;
executable files in those directories remain gated. Only narrative `.md`
files newly added below `docs/reports/`, plus the live `docs/reports/README.md`
index, qualify for the documentation-only path. Before either that shortcut
or a mixed-change audit, CI rejects edits, deletions, type changes and renames
of narrative reports already present at the audited base. This check uses
only the current base-to-head Git diff and fails if the comparison is
unavailable; it does not run a historical baseline or maintain an archive.
Executable documentation, manifests, recorded data, current support records,
ADRs, agent instructions, and command documentation require impact. The documentation-only decision is
derived from the actual Git diff and remains separate from semantic acceptance.

| Evidence | Linux | macOS | Windows |
| --- | --- | --- | --- |
| Metadata pair, Native compatibility, Native/Wasm contracts and scenarios | Required | Required | Required |
| Command/backend pair, package pair, Native-only registered package tests | Required | Required | Required |
| Wasm policy and Native stress scenarios | Required | Required | Required |
| Pinned immutable upstream differential, Native and Wasm | Required | Not applicable | Not applicable |
| Exact published-version differential | When declared; also manual/scheduled runs | Not applicable | Not applicable |

The CI audit requires each declared backend/evidence combination on every
applicable platform; oracle comparisons use Linux. The local audit's existing
interface remains unchanged. Requirements without an applicable CI evidence
producer fail rather than being inferred from an availability result.

The `ci.mbtx requirements` probe enables published verification from the
reviewed intent and registry requirements before any results exist. Its Linux
bundle retains the exact published manifest, resolved corpus, frozen registry,
provenance and sealed oracle profile. Both the platform stamp and aggregation
reuse the release runner's complete Git-backed frozen-snapshot validation.
Only that validated manifest/corpus/registry combination may use its frozen
registry fingerprint in the CI audit; the local interface retains its current
registry check. Published rows must name exact manifest coordinates and use
the sealed Linux oracle. A frozen fixture whose canonical body differs from
the current registered case cannot prove the changed behavior.

`ci.mbtx stamp test-reports` binds each fixed report bundle, its source corpus,
and the Linux oracle profile to the workflow run, exact source/range, platform,
and file checksums. The aggregation step downloads the three named platform
artifacts and calls `ci.mbtx audit test-reports/ci <report.md>`. It rejects
missing, stale, substituted, dirty, incomplete, or foreign-run bundles, checks
their current registry/manifest/corpus fingerprints, then uses the normal audit
validators. Failed-job reruns may retain successful bundles from earlier
attempts of the same run and exact source. The `coverage-audit` artifact retains
the result, context, or infrastructure-failure diagnostic.
