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
MOON_HOME="$HOME/.moon-accounts/cli" moon build --target native --deny-warn tests/runner
MOON_HOME="$HOME/.moon-accounts/cli" moon test --target wasm --release --deny-warn --no-parallelize
MOON_HOME="$HOME/.moon-accounts/cli" moon test --target native --deny-warn --no-parallelize tests/testkit tests/registry tests/network_scenarios tests/mv_scenarios tests/runner tests/release_runner tests/benchmark tests/proofs
MOON_HOME="$HOME/.moon-accounts/cli" CMD_TEST_PROFILE=debug CMD_TEST_REPORT_ROOT=/absolute/fresh-report moon run tests/ci.mbtx -- functional
```

Use a fresh report directory. `functional` includes metadata, contracts,
stateful scenarios, retained compatibility cohorts, permission checks and
bounded stream correctness regressions. `--suite all` additionally requires
the pinned Linux oracle. See [runner usage](runner/README.md).

Daily Native tools use debug builds to reduce C compilation cost; Wasm products
and their package tests remain release builds. CI sets `CMD_TEST_PROFILE=debug`
for `tests/ci.mbtx` and `tests/oracle.mbtx`. Those scripts default to release
tools for the separate published-acceptance workflow.

The [runtime index](registry/README.md) supplies stable case selections and
release policy. Ordinary package tests execute in batches through Moon;
individual test names are not separately registered or sealed.

Large rg corpus data is owned by [`fixtures/rg`](fixtures/rg/README.md).
Engine tests remain Wasm package tests because rg's internal interfaces are
module-private. CLI-equivalent printer cases use the ordinary JSON contract
runner and registry; injected clocks, paths and engine state remain package
regressions. Pipelines requiring rg's private command matcher live in driver
white-box tests; isolated printer and searcher mechanisms retain their own
tests. Neither lower-level package imports driver for testing. Both layers
run in the existing development workflow.

## Results and boundaries

Results are `pass`, `fail`, `skip` or `infra`. Verification kinds distinguish
availability, contracts, upstream comparisons and explicit rejection boundaries.
An expected rejection is not support for the rejected operation. Platform skips
do not prove behavior on that platform. Missing required infrastructure, empty
selections, timeouts and uncertain cleanup are failures.

Reports contain `run.json`, `summary.jsonl`, `summary.md` and failure captures.
They record the platform, revision label, selected coordinates and durations.
The controller also binds selected cases, exact result hashes and typed scenario
observations to current assertion sources and a freshly built driver receipt.
The finite [proof verifier](proofs/README.md) joins those actual reports and
rejects missing, stale or mismatched evidence. This verifies only reviewed
facets; the separate gap index retains unresolved labels. It is neither an
audit-before-push wrapper nor a performance or publication seal. The upstream
image and inventory remain fixed independently of these reports.

Exact expectations can render a known fixture path with `${WORK_NATIVE}` and
`${PATH_SEPARATOR}`. The former formats only the supplied fixture root for the
host; `${WORK}` keeps its existing bytes. These templates never rewrite observed
output or literal payload backslashes. Directory-output differential cases
declare the existing working-directory mapping for the host fixture versus its
`/work` container mount; the exact relative suffix and complete output remain
asserted.

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
