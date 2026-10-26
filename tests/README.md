# Command validation

The delivery target is Wasm through MoonX. Development checks execute current
Wasm artifacts on Linux, macOS and Windows. Native packages implement the test
tools; Native command builds and backend pairing are not product gates.

## Workflows

| Workflow | Trigger | Responsibility |
| --- | --- | --- |
| check | PR, main push, manual | Full applicable Wasm tests on three platforms; pinned upstream comparisons on Linux |
| resource observations | Manual | Selected Linux RSS, temporary disk and large-input observations |
| release acceptance | Manual | Exact-version MoonX functional checks on three platforms; pinned upstream comparisons on Linux |

There is no daily full run, post-platform coverage audit, change declaration or
audited-push wrapper. Main still requires a PR and successful platform checks.
Independent cases use at most four tasks. Stateful, network and timestamp
fixtures run serially. Moon commands sharing a build directory are serialized.

## Local development

Keep the current PATH toolchain and prefix every Moon invocation with
`MOON_HOME="$HOME/.moon-accounts/cli"`. Build commands once, then reuse artifacts:

```text
MOON_HOME="$HOME/.moon-accounts/cli" moon check --target wasm --deny-warn
MOON_HOME="$HOME/.moon-accounts/cli" moon build --target wasm --release --deny-warn
MOON_HOME="$HOME/.moon-accounts/cli" moon build --target native --release --deny-warn tests/runner
MOON_HOME="$HOME/.moon-accounts/cli" moon test --target wasm --release --deny-warn --no-parallelize
MOON_HOME="$HOME/.moon-accounts/cli" moon test --target native --release --deny-warn --no-parallelize tests/testkit tests/registry tests/network_scenarios tests/mv_scenarios tests/runner tests/release_runner tests/benchmark
MOON_HOME="$HOME/.moon-accounts/cli" ./_build/native/release/build/mooxCLI/cmd-tests/runner/runner.exe --suite functional --report-dir test-reports/local-functional
```

Use a fresh report directory. `functional` includes metadata, contracts,
stateful scenarios, retained compatibility cohorts, permission checks and
bounded stream correctness regressions. `--suite all` additionally requires
the pinned Linux oracle. See [runner usage](runner/README.md).

The [runtime index](registry/README.md) supplies stable case selections and
release policy. Ordinary package tests execute in batches through Moon;
individual test names are not separately registered or sealed.

## Results and boundaries

Results are `pass`, `fail`, `skip` or `infra`. Verification kinds distinguish
availability, contracts, upstream comparisons and explicit rejection boundaries.
An expected rejection is not support for the rejected operation. Platform skips
do not prove behavior on that platform. Missing required infrastructure, empty
selections, timeouts and uncertain cleanup are failures.

Reports contain `run.json`, `summary.jsonl`, `summary.md` and failure captures.
They record the platform, revision label, selected coordinates and durations.
There are no source-corpus hashes, artifact seals or cross-report proof chains.
The upstream image and inventory remain fixed independently of these reports.

Successful fixtures are removed. Failed captures and cleanup diagnostics are
retained; direct-child cancellation does not promise arbitrary grandchild
cleanup. Tests and fixtures remain pure MoonBit. Host programs are restricted
to CI setup, observation and fixed upstream references.

## Publication and performance

[Published acceptance](release_runner/README.md) uses the current exact version
inventory and its independent expected cases. Workspace changes do not rewrite
old published expectations. The local-only `timeout` command is excluded.

[Resource observations](resources/README.md) run only when explicitly requested.
They are distinct from the statistical [benchmark contract](benchmark/README.md).
Existing historical reports are immutable and are not current acceptance claims.

The migration and measured results are recorded in
[the CI migration ledger](../docs/ci-wasm-migration.md).
