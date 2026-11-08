# Command validation

Use one entry: `MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/run.mbtx -- COMMAND`.
Keep the current PATH toolchain. The entry discovers the workspace from any
working directory inside it; arguments passed through this entry are relative
to the repository root unless absolute. From `tests/`, use `moon run run.mbtx`.
Moon commands sharing the workspace build directory run serially.

## Commands

| Command | Responsibility |
| --- | --- |
| `check` | Wasm products, Native test packages, and every `.mbtx` script |
| `test tools` / `test packages` / `test all` | Native infrastructure regressions, Wasm package tests, or both |
| `format --check` | Package formatting and explicit formatting of every standalone script |
| `index check` / `index update` | Verify or regenerate current derived definitions; never execution evidence |
| `list --command sort` / `validate` | Inspect or validate functional selection without executing products |
| `functional` | Build Wasm, execute applicable correctness checks, and verify fresh coverage evidence |
| `architecture /absolute/fresh.json` | Validate package and strategy boundaries |
| `published` | Build acceptance tools and validate the exact published coordinates |
| `oracle --image sha256:ID` | Verify the immutable Linux reference used by functional/published checks |
| `corpus`, `benchmark`, `protect` | Pinned sources and the single [timing engine](benchmark/README.md) |
| `resources`, `resource-profiles` | Separate manual [resource observations](resources/README.md) |

Daily tools default to debug builds; product Wasm and package tests use release.
`CMD_TEST_PROFILE=release` selects optimized tools. Published acceptance always
uses release tools. Choose a fresh absolute report root for every execution:

```sh
MOON_HOME="$HOME/.moon-accounts/cli" CMD_TEST_REPORT_ROOT=/absolute/fresh-report moon run tests/run.mbtx -- functional
```

On Linux, prepare `oracle` into the same report root first: the complete Linux
run adds pinned differential comparisons. Diagnostic driver selections are
documented in [harness/driver](harness/driver/README.md); subsets do not qualify
full development or publication acceptance.

## Ownership

| Path | Source of truth |
| --- | --- |
| `run.mbtx` | Public command routing, workspace paths, script discovery |
| `tools/` | Internal orchestration scripts; CI uses the public entry |
| `harness/` | Generic fixtures, launchers, deadlines, assertions and reports |
| `harness/driver/` | Selection, scheduling and execution orchestration |
| `harness/catalog/` | Command capability declarations, case index and release policy for Native validation tools |
| `cases/*.json` | Current CLI cases; `manifest.json` lists files, `index.json` binds stable identities |
| `cases/generated/` | Derived assertion-quality inventory |
| `scenarios/` | Stateful, multi-command and permission assertions with private regressions |
| `fixtures/` | Static corpora and pinned external oracle setup inputs |
| `coverage/review/` | Manually reviewed finite facets, expected observations and remaining work |
| `coverage/generated/` | Derived definitions and gap indexes; no saved execution passes |
| `coverage/*.mbt` | Join actual execution receipts to reviewed definitions |
| `release/` | Release policy, generated candidate, independent published coordinates and expectations |
| `benchmark/` | Single timing inventory, engine and protection policy |
| `resources/` | Resource observer, input recipes and effect relations |

Keep private-state and injected-runtime tests beside product packages. Large
static rg corpora belong to [fixtures/rg](fixtures/rg/README.md); CLI-equivalent
cases belong to `cases/`. Do not widen product APIs to relocate tests. New
automation is pure MoonBit. Host programs are limited to oracle setup,
observation and diagnostics.

## Maintaining definitions and evidence

Change a case and its `cases/index.json` entry together. Change manually reviewed
coverage only when a concrete discriminating assertion justifies it; follow
[the coverage guide](coverage/README.md). Run `index update`, review the diff,
then run `index check` and applicable tests. CI rejects stale generated files.
The generator completes every stage before replacing derived outputs.

Current cases use schema 2 and the identity index uses schema 3. There are no
old path forwarders, overlay chains or alternative product backends. Aliases
remain stable case identities without duplicate execution. Frozen published
expectations are independent inputs, never an overlay on current cases.

Results are `pass`, `fail`, `skip` or `infra`; verification distinguishes
availability, local contracts, differential comparisons and explicit boundaries.
Missing fixtures, empty required selections, deadlines, uncertain cleanup and
report failures cannot pass. Stateful fixtures run serially; independent cases
use at most four tasks. Successful fixtures are removed and failure captures
are retained. Reports and driver/source receipts stay under the fresh report
root, outside versioned definitions.

Development CI runs all applicable Wasm checks on Linux, macOS and Windows,
using the official `latest` toolchain and core, with pinned upstream comparisons
on Linux. Every run records its resolved toolchain; compilation caches include
that identity. Mainline changes require a PR,
the three checks and actual-main validation. Resource observations and exact
[published acceptance](release/README.md) are separate manual workflows.
Correctness, finite coverage, upstream agreement and performance retain their
own scopes. Historical reports remain recoverable from Git, without an active
compatibility path or backfilled acceptance claims.
