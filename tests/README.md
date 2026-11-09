# Command validation

Use `MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/run.mbtx -- COMMAND`.
Keep the current PATH toolchain. CI installs MoonBit and its matching core through
the official Unix/PowerShell installers in `.github/actions/setup-moonbit`, with
bounded retries for installer and archive downloads. Setup does not require Nu or
GitHub release assets. The entry discovers the workspace and resolves
its arguments from that root. Moon commands sharing a build directory run
serially. Product acceptance targets Wasm; Native is only for test tools.

Command policies and their private tests live together. The jq and jqlog adapters
consume all 28 records in `fixtures/jq/adapter.json`, including the original
3,000-member stable-order inputs and independent expected arrays. This fixture
was extracted from the previous tests without evaluating either implementation.
Readers require the exact count, unique nonempty IDs and valid records; missing
files fail. Error propagation remains covered beside each adapter.

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
Choose a fresh absolute `CMD_TEST_REPORT_ROOT` for each execution. Linux correctness
exports prepared Wasm and Native tools to the upstream job, bound to the commit,
toolchain and complete artifact inventory. Diagnostic subsets
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
events. These implementations and tests live in the commands' private download
packages. Wget's 73 authentication records run through its private option parser
and execution path with an injected environment and in-process loopback peer.
Original status, response bytes and ordered credential/replay observations are
preserved. Four separate CLI events retain host-scoped sessions, binary replay,
refusal and option-error diagnostics. The full 73-case CLI route and its frozen
published alias remain available. Retry, output failure and cleanup retain both
private state regressions and real command events.

Timezone package tests cover TZif v1-v4, literal zero-offset names, fractional
offsets, post-2038 and far-future seasons, rejected DST gaps/folds, truncated
files and retained legacy inputs. Date's TZDIR file case exercises the Wasm
adapter with explicit nanoseconds; existing date/diff contracts retain output
and timestamp formatting. These are compatibility checks, not timing evidence.

| Location | Responsibility |
| --- | --- |
| `run.mbtx`, `tools/` | Public entry and internal MoonBit orchestration |
| `harness/`, `harness/driver/` | Execution, observation, selection and reporting |
| `harness/catalog/`, `cases/` | Current command declarations, identities and cases |
| `scenarios/` | Concrete events and resource lifetimes |
| `fixtures/` | Original corpora and immutable oracle inputs |
| `release/` | Candidate generation and independent published expectations |
| `benchmark/`, `resources/` | Manual timing and resource programs |

Assertions execute directly. Registration checks inspect the case expectations
and scenario dispatch without generating an intermediate descriptor. The
per-assertion review/descriptor/proof chain,
generated quality/coverage catalogs and assertion-source sealing are retired.
Their historical content is preserved in Git at `aa65c57`. This does not retire
original cases, corpus records, immutable oracle identity or performance baselines.

`index check` validates current bindings and assertion routes before platform
filtering, then checks the candidate. `index update` changes only the candidate
after validation. Neither rewrites `release/latest.json` or `latest-cases.json`.
Case aliases do not cause duplicate execution.
The same rule covers network, filesystem metadata/umask, tee, mktemp and printf
state events: current registrations select one scenario, and differential mode
uses its candidate observations for assertions and comparison. Published aliases
retain their frozen dispatch routes. Metadata relations compare their documented
selector subset upstream; other relation assertions remain independent contracts.
Shared filesystem events register both find and test as consumers. Read-only
scenario mounts remain read-only in each worker signature, including isolated
metadata directories; incompatible mount layouts still use owned containers.

Upstream selection covers executable source, dependencies, test inputs and CI
execution configuration. Plain documentation and document assets are excluded.
MoonBit `.mbt.md` files remain source because their code blocks are executable.

Every selected case must produce
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
output. Scenarios with shared or unreviewed state remain serial. The `isolated`
case flag records reviewed private directories, servers and process state; those
events use at most four tasks (two in differential runs). Their internal steps
remain serial. Partial child observations remain failures, not fabricated completion.

Fixed timestamp declarations use each contract's private directory and can share
the bounded execution queue. Network, delayed and explicit timestamp-observation
contracts remain serial. The Windows mv link event and sort spill event also use
private directories, streams and child environments, so they join the existing
isolated scenario queue. Fixture-owner UID/GID is prepared once per runner process.

## Oracle and delivery boundaries

`functional` always runs complete applicable correctness. Linux upstream execution
is a separate required job. `ci select BASE HEAD` uses both names of a rename,
command source/test/dependency changes, command case files and the `inputs` paths
on existing case registrations. Shared or unclassified execution inputs and a
missing comparison baseline select all registered differential cases. Pure prose
changes select none explicitly. An affected command without a differential case
requires an explicit `oracle_boundary` in the existing release policy; an empty
required selection fails. These boundaries do not establish parity.

`ubuntu-24.04` aggregates Linux correctness and the required comparison. Missing,
failed, cancelled or unexpectedly skipped dependencies cannot pass. Main pushes
repeat selection and execution on the actual merged commit. macOS and Windows
remain independent required checks. `ci import` rejects incomplete inventories,
changed bytes and mismatched source/toolchain; it never rebuilds candidate tools.

Within a differential run, at most two reusable containers own compatible mount
and network configurations. Each invocation has a separate working directory,
environment and temporary directory. The runner observes remaining processes
before reuse; timeout, cancellation and uncertain cleanup destroy the owned
container. Specialized incompatible container layouts retain the existing owned
single-invocation path, counted separately in run metadata. Frozen published
execution remains supported. No dynamic candidate observation is cached.

Run metadata records driver-observed process starts and container starts;
`ci metrics` records report file count and bytes. Compare these with Actions job
and stage durations, including upstream and gate jobs, when measuring CI latency.
The counters cover the runner's direct launch paths, not arbitrary descendants
inside command oracles or the compiler. Three warm and one cold comparable runs
are required before accepting the CI latency target.

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

## CI timing observations (2026-11-09)

The comparable runs below use Moon 0.1.20261104, moonc v0.10.20+65efd5b93,
the refreshed dependencies and identical execution code. The main synchronization
between `08155c7` and `c061759` changes ancestry only. Every run includes 2,129
Wasm package tests, 230 Native tool regressions and all 2,723 registered Linux
upstream comparisons. Functional results are 3,874 passes/37 platform skips
on Linux, 3,871/40 on macOS and 3,253/658 on Windows, with zero failures.

Warm samples verify restored compilation caches on all three platforms and
cached Docker layers. The cold sample explicitly sets `use_cache=false`, skipping
compilation and Docker caches. Times include job setup and reporting; all-gate
time spans the first job start through the last required completion. Runner
minutes sum job elapsed time without billing multipliers. Process counts cover
the harness's direct launches; report sizes exclude the shared build artifact.

| Run | Linux | macOS | Windows | Upstream | All gates | Runner minutes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| [Warm 1](https://github.com/moonbit-community/cmd/actions/runs/42605039964) | 6:55 | 9:00 | 8:19 | 11:16 | 18:35 | 35.8 |
| [Warm 2](https://github.com/moonbit-community/cmd/actions/runs/42605199782) | 5:55 | 10:06 | 11:14 | 9:24 | 15:41 | 36.9 |
| [Warm 3](https://github.com/moonbit-community/cmd/actions/runs/42607771426) | 8:23 | 8:31 | 11:18 | 11:29 | 20:12 | 39.9 |
| [Cold](https://github.com/moonbit-community/cmd/actions/runs/42605197381) | 8:15 | 9:12 | 11:27 | 18:30 | 27:09 | 47.7 |

| Run | Direct process starts | Containers | Reports MiB | Uploaded MiB |
| --- | ---: | ---: | ---: | ---: |
| Warm 1 | 39,656 | 58 | 61.1 | 3.5 |
| Warm 2 | 39,684 | 62 | 61.2 | 3.6 |
| Warm 3 | 39,684 | 62 | 61.2 | 3.6 |
| Cold | 39,670 | 60 | 61.2 | 3.5 |

The three-platform correctness critical paths are 9:00, 11:14 and 11:18
(mean 10:31), approaching the daily ten-minute target with visible variation.
Full required gates for shared changes remain 15:41–20:12 warm and 27:09 cold;
a uniform ten-minute gate is not established. Affected-command selection reduces
comparison scope, but these measurements deliberately retain the full workload.
The remaining measured costs include Windows functional execution (3:38–5:27),
Windows package tests (2:02–2:43), full comparison (8:27–10:24 warm), and cold
oracle image construction (6:53). Preserve event steps, complete corpora and
cleanup observations when revisiting these costs. The fixture-owner query now
starts `id` twice per differential run, down from 3,968 in the
[preceding warm run](https://github.com/moonbit-community/cmd/actions/runs/42601971893).
