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
