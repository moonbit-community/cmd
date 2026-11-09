# Command validation

Use `MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/run.mbtx -- COMMAND`.
Keep the current PATH toolchain. The entry discovers the workspace and resolves
its arguments from that root. Moon commands sharing a build directory run
serially. Product acceptance targets Wasm; Native is only for test tools.

## Commands

| Command | Responsibility |
| --- | --- |
| `check` | Wasm products, Native tools and every standalone `.mbtx` script |
| `prepare` | Build product Wasm and Native execution tools once |
| `test packages` / `test tools` / `test all` | Wasm package tests and Native infrastructure regressions |
| `format --check` | Packages and all standalone scripts |
| `index check` / `index update` | Validate cases and bindings; check or update the derived candidate |
| `list --command sort` / `validate` | Inspect or validate selection without product execution |
| `functional` | Run applicable workspace assertions and verify complete results |
| `architecture /absolute/fresh.json` | Validate package and strategy dependencies |
| `oracle --image sha256:ID` | Prepare and verify the immutable Linux oracle |
| `published` | Validate independent exact published coordinates and expectations |
| `corpus`, `benchmark`, `protect` | Separate [performance protection](benchmark/PROTECTION.md) |
| `resources`, `resource-profiles` | Separate manual [resource observations](resources/README.md) |

Tools default to debug, products and package tests to release. Published tools
use release. Standalone commands build their required tools. CI runs `prepare`
first and sets `CMD_TEST_PREPARED=1` for later commands; missing artifacts fail.
Choose a fresh absolute `CMD_TEST_REPORT_ROOT` for each execution. Linux currently
prepares `oracle` in that root before the full functional run. Diagnostic subsets
do not qualify complete development or published acceptance.

## Ownership and assertions

Package tests own parser tables, numeric boundaries and private state. Keep
large original corpora in `fixtures/`, preserve their independent expected
values, and fail on missing files. Command scenarios own argument mapping,
diagnostics and real file, network, stream and child-process effects. Do not
expose product internals to relocate tests.

The complete Cookie tables run beside `CookieJar`: 58 Wget dialect records,
194 expiry records, 87 date records and 255 Curl/Wget Domain records. These
tests retain original IDs and expectations, use a fixed clock, and assert the
request/save/reload state including row order. Missing or duplicate records
fail. Their full CLI differential remains selectable on Linux under the same
scenario ID; ordinary correctness uses the package tables and real session
events. Authentication, retry and output events remain in command scenarios
until their policy state has an independently testable owning boundary.

| Location | Responsibility |
| --- | --- |
| `run.mbtx`, `tools/` | Public entry and internal MoonBit orchestration |
| `harness/`, `harness/driver/` | Execution, observation, selection and reporting |
| `harness/catalog/`, `cases/` | Current command declarations, identities and cases |
| `scenarios/` | Concrete events and resource lifetimes |
| `fixtures/` | Original corpora and immutable oracle inputs |
| `release/` | Candidate generation and independent published expectations |
| `benchmark/`, `resources/` | Manual timing and resource programs |

Assertions execute directly. The per-assertion review/descriptor/proof chain,
generated quality/coverage catalogs and assertion-source sealing are retired.
Their historical content is preserved in Git at `aa65c57`. This does not retire
original cases, corpus records, immutable oracle identity or performance baselines.

`index check` validates current bindings and assertion routes before platform
filtering, then checks the candidate. `index update` changes only the candidate
after validation. Neither rewrites `release/latest.json` or `latest-cases.json`.
Case aliases do not cause duplicate execution. Every selected case must produce
exactly one terminal result, with explicit platform exclusions; missing,
duplicate, unknown or substituted results cannot pass.

## Reports and lifecycle

Each run retains the selection, structured result stream, stage durations and a
short summary of counts and nonpassing results. Successful temporary fixtures
are removed. Network success observations are compacted into one JSONL stream
per scenario, preserving relative paths, file kinds and exact hexadecimal bytes.
Failures retain raw directories and diagnostics. Compaction reads, writes and
cleanup must complete before the scenario passes.

Results are `pass`, `fail`, `skip` or `infra`. Availability, local contract,
differential comparison and explicit boundary are separate verification kinds.
Missing fixtures, empty required selections, deadlines, uncertain cleanup and
report failures cannot pass. Original expected values never come from candidate
output. Stateful scenarios remain serial; independent cases use at most four
tasks. Partial child observations remain failures, not fabricated completion.

## Oracle and delivery boundaries

The oracle family remains `pinned-oracle-v1`, with reviewed profile version 2.
It verifies image identity, tool inventory and source/distribution checksums.
PSL rules and A-label aliases are checked against the pinned libpsl. Complete
Unicode 15 inputs and IDNA generation remain checked by `check`; the independent
normalization corpus retains all 19,074 records. Network corpora retain their
original request, jar, file and authentication expectations.

Required development checks cover Linux, macOS and Windows. Mainline changes
use a PR and actual-main validation. Resource observations and exact published
acceptance remain separate manual workflows. Historical run claims remain
dated in CHANGELOG and Git; this restructuring does not establish full upstream
parity or formal product performance acceptance.
