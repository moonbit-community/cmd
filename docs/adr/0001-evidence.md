# ADR-0001: Evidence First

Status: Accepted
Date: 2026-09-05
Updated: 2026-09-21
Revision: Share test mechanisms and active cases; separate invocation health, semantic compatibility and explicit capability boundaries; record the three-platform 0.2.0 source gate and subsequent publication.

## Target and decision

Command support requires observable GNU/POSIX or upstream agreement in stdout,
stderr, status and required filesystem effects. Exact published MoonX versions
are separate from local artifacts. Pinned GNU/Linux is the strict oracle;
label installed macOS-tool evidence. Use released public APIs and pure MoonBit
code and automation. Host tools may observe test fixtures or act as an oracle,
but cannot implement a product command.

Keep three test layers: package behavior, real CLI contracts and stateful
scenarios. The workspace and published-consumer drivers share one Native
`testkit` for case schemas, bytes, fixtures, processes, HTTP, observations and
reporting. Active cases live by command and retain their stable IDs. Stateful
cases are MoonBit functions. Frozen release manifests remain readable through
the schema 1 adapter; they are historical evidence, not a second active source.

Each report separates result (`pass`, `fail`, `skip`, `infra`) from verification
(`availability`, `contract`, `differential`, `boundary`). Successful smoke is
availability evidence. Expected rejection verifies a documented boundary.
Neither, nor a platform skip, contributes to semantic compatibility. Only a
passing contract or differential with every required observation contributes.
Contracts assert both output streams and status; diagnostic fragments require a
reason. Absence of internal errors alone is not a behavioral contract.

Validate option coverage against the actual selected cases, then report platform
applicability, execution and passing observations separately. An empty option
list does not certify the parser's entire option surface. Selection happens
before command artifacts or fixtures are required. Preserve raw failure output,
fixture state, backend, platform, source version and elapsed time.

Retain Linux/macOS/Windows PR checks. Build each release backend once per host
and reuse it for contracts, scenarios, policy and manifest validation. Linux
runs pinned oracle and independent GNU checks; scheduled/manual checks add
stress and exact published consumers using the same builds. Duplicate compat
runs are removed. This changes execution cost, not the required platform gates.

## Alternatives and compatibility cost

Reject status-only smoke as semantic success, and reject treating a healthy
uncompared invocation as a test failure. Reject a third runner, a general-purpose
fixture scripting language, parallel copies of fixture infrastructure and
automatic retries that hide unstable assertions. Package tests and CLI tests
are distinct boundaries; similar inputs do not prove they are redundant.

Delete an assertion only when its behavior, backend and observation dimensions
map to retained coverage. This preserves some intentional test overlap. Legacy
cohorts retain explicit stable group IDs for genuine process composition, live
tail sessions, streaming round trips and network fixtures. Independent command
calls have moved to per-command JSON with an assertion-to-case map; groups must not claim
case-specific option verification. Historical frozen fixtures cost storage but
preserve reproducibility. Successful workspaces are cleaned; reports and failed
fixtures are uploaded instead of the whole build tree.

JSON effects use explicit file expectations rather than an embedded execution
language. Cwd and text fixture placeholders support independent invocation
contracts. Exact duplicate contracts keep old IDs as aliases and execute once;
package, Native, Wasm and differential boundaries remain independent. The
compatibility cost is retaining MoonBit functions for multi-process interaction.
Move such a function only if the same interaction and observations remain
expressible without weakening the contract. Evidence and the 240-invocation
migration map are in `docs/reports/2026-09-21-json-migration/`.

Filesystem requirements are explicit. Missing metadata observers are failures
of the verification environment, not successful comparisons. Hard links compare
relationships within a fixture, and time checks use fixed values or before/after
relations. They do not compare raw inode values or independent wall clocks
between candidate and oracle directories. Metadata is collected before content
reads that could alter atime. A before-command atime baseline is refreshed after
baseline content inspection so the observer's own read is not blamed on the
candidate. Cross-root mtime equality requires fixed fixture times; ctime and
atime relations use the same fixture in a boundary or stateful scenario.

## Versions and evidence

Baseline: moon/moonrun 0.1.20260915; moonc/core 0.10.13+cbb11c36f;
async 0.22.1; x 0.5.5; moonjq 0.1.2. The dependency refresh found no older external
versions in the resolved tree. Upgrade-only tests passed Native 104/104 and
Wasm 91/91 before behavior changes.

The [0.2.0 source gate](https://github.com/moonbit-community/cmd/actions/runs/35576541301)
passed Linux, macOS and Windows at source commit
`442015078b8dc01f64f499e5df0847d7c7458c3d`, including Linux Native/Wasm pinned
oracle checks. After that gate, `cli/core@0.2.0` was published first, followed
sequentially by 47 command modules. `timeout` remains local-only. Publication
receipts and the separate exact-version MoonX gate are recorded in
[release evidence](../reports/2026-09-21-release-0.2.0/README.md). The published
manifest selects 382 active cases; the frozen schema 1 manifests and candidate
preparation manifest retain their original roles.

The consumer driver inserts a MoonX argument separator after the exact package
coordinate. This preserves a command's own leading `--` without changing the
command contract. Do not alter expected command output to compensate for argv
lost in a launcher. Revisit this adapter if MoonX changes its parsing contract;
keep direct exact-version probes for commands that consume a leading separator.

The 2026-09-21 final migration check found a newer official toolchain manifest
(moonc 0.10.14+7d59c7ec9 and moon/moonrun 0.1.20260920). This release gate pins
CI binaries and core to the already validated 0.10.13+cbb11c36f archive, whose
official download was verified, so local and remote measurements share a
baseline. Floating `latest` was rejected because it silently changes the
compiler during acceptance. This does not claim validation of 0.10.14; lift the
pin in a separate toolchain change after repeating all three platform checks.

The [original audit](../reports/2026-09-19-command-fidelity-audit.md) and
[test-system audit](../reports/2026-09-21-test-system-audit.md) remain immutable
historical records. Current runtime reports describe what actually ran; CI
configuration alone does not establish a passing cross-platform result. Record
before/after execution counts and same-host timings without predicting a speedup.

## Revisit when

Recheck released dependencies or reported mismatches. Rerun affected behavior and
exact-version published-consumer gates before promoting support. Expand observer
capabilities when public APIs or fixed test oracles can measure a missing
dimension reliably. Change test frequency only after measured cost and a mapping
show that required behavior/platform coverage is preserved.
