# ADR-0001: Evidence First

Status: Accepted
Date: 2026-09-05
Updated: 2026-10-11
Revision: Correct self-authored expected outputs, pin new strings/column oracles, and expand real CLI/alias/edge coverage before a repaired release.

## Target and decision

The 2026-10-11 repair treats an upstream disagreement as a failed contract,
even when old package tests encoded the same defect. Pin binutils 2.44 and
util-linux 2.40 alongside coreutils 9.11/jq 1.8.2. Correct known wrong golden
values with retained upstream evidence; do not auto-bless candidate output.
Separate semantic, availability and explicit rejection results throughout.
Review every command README/help, then execute long-option aliases against the
retained short-option byte/status/file contract rather than assuming parser
aliases work. Source review and case counts do not prove all possible inputs.
The cost is maintaining independent expected behavior and fixtures; retire
duplicate assertions only when their entrypoint/backend/observation survives.
Release requires second review, three-platform CI and exact-version MoonX,
as recorded in [the repair report](../reports/2026-10-11-fidelity-repair/README.md).

All product code, shared runtime code, test runners, fixtures, and automation
must be pure MoonBit. Project-owned C/C++/Rust/JavaScript/TypeScript, FFI,
native stubs, and host-command delegation are prohibited as implementation
workarounds. Host tools may only observe fixtures, collect diagnostics, or act
as fixed-version oracles.

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

Passing a self-authored contract proves that contract, not upstream equivalence.
The [2026-10-11 follow-up audit](../reports/2026-10-11-command-followups/README.md)
finds missing GNU meanings in strings, executable access in which, default/LF
behavior in column and caller TZ handling in date despite passing published
selections. These are explicit follow-ups in current support records. Keep old
reports immutable and correct faulty expectations only with upstream evidence.
The [79-command register](../command-followups.md) separates defects, project
work, public API gaps, platform behavior and missing measurements.

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

Current refresh (2026-09-26): the public registry resolves
`moonbitlang/async 0.22.4` (checksum
`2ffdb85cb229cfe9219161a7f2b959215a79a0d75b7e642cb346713f168a1457`) across
the 50 pre-existing workspace modules. The current published index did not contain a
released 0.22.5. Native and Wasm warning-denied checks passed after the
refresh; command completion evidence remains per-package and per-backend.

The 2026-10-11 P2 release adds `strings`, `column`, `which` and `date` as
independent 0.1.0 command modules and publishes `cli/core@0.4.0`. Their Native
and Wasm contract selections pass 19 semantic cases plus the explicit encoding
boundary. The published manifest contains 78 command coordinates and 554
selected cases. After clearing the account's 78 cached command assets, the
published-consumer runner re-downloaded every exact coordinate; the final smoke
run passed 447 semantic, 81 availability and 23 boundary observations, with 3
macOS platform skips and no failures. A transient TLS handshake failure for
`chmod@0.2.0` was rerun after its asset was re-downloaded and passed; it is
retained in the first redownload report as infrastructure evidence. The shared
testkit now expands the `${WORK}` placeholder in environment values as it
already does in arguments and fixture text. This is a test-observation
correction, not a product authorization rule.

Baseline: moon/moonrun 0.1.20260920; moonc/core 0.10.14+7d59c7ec9;
async 0.22.4; x 0.5.5; moonjq 0.1.2. The dependency refresh found no older external
versions in the resolved tree. Upgrade-only tests passed Native 104/104 and
Wasm 91/91 before behavior changes.

The [0.2.0 source gate](https://github.com/moonbit-community/cmd/actions/runs/35576541301)
passed Linux, macOS and Windows at source commit
`442015078b8dc01f64f499e5df0847d7c7458c3d`, including Linux Native/Wasm pinned
oracle checks. After that gate, `cli/core@0.2.0` was published first, followed
sequentially by 47 command modules. `timeout` remains local-only; the eight
new P0 command profiles are workspace-only until a later publication gate. Publication
receipts and the separate exact-version MoonX gate are recorded in
[release evidence](../reports/2026-09-21-release-0.2.0/README.md). The published
manifest selects 382 active cases; the frozen schema 1 manifests and candidate
preparation manifest retain their original roles.

The consumer driver inserts a MoonX argument separator after the exact package
coordinate. This preserves a command's own leading `--` without changing the
command contract. Do not alter expected command output to compensate for argv
lost in a launcher. Revisit this adapter if MoonX changes its parsing contract;
keep direct exact-version probes for commands that consume a leading separator.

The 0.2.0 release gate used the validated 0.10.13+cbb11c36f archive. The next
workspace baseline pins CI binaries and core to 0.10.14+7d59c7ec9
(moon/moonrun 0.1.20260920), matching the developer's upgraded toolchain.
The newer compiler deprecates implicit trait-method promotion; explicit public
extensions preserve the previous methods instead of suppressing warnings or
removing API. Black-box tests qualify the package under test. Registry refresh
still resolves async 0.22.4, x 0.5.5 and moonjq 0.1.2, including moonjq's
transitive imports. Floating `latest` remains rejected so acceptance cannot
silently change compiler. Local new-baseline results do not replace the required
three-platform CI gate or retroactively change published-release evidence.

The [original audit](../reports/2026-09-19-command-fidelity-audit.md) and
[test-system audit](../reports/2026-09-21-test-system-audit.md) remain immutable
historical records. Current runtime reports describe what actually ran; CI
configuration alone does not establish a passing cross-platform result. Record
before/after execution counts and same-host timings without predicting a speedup.

## Revisit when

2026-10-11 repair CI exposed oracle-fixture errors: the Docker entrypoint must
not overwrite explicit TZ (or other fixture environment), and `${WORK}` expands
to the candidate directory for the candidate and `/work` for its container
oracle. Docker ENV provides defaults; both runners preserve explicit fixture
values while pinning oracle PATH. Non-UTC and TZif fixture tests enforce this
end to end. Existing project-only long aliases such as ls `--access-time` and
`--change-time` have command-local contracts; GNU comparison uses the retained
`-u/-c` cases. Comparing an extension's spelling with an upstream that rejects
it is a test-definition error, not evidence to relax a product defect's assertion.

2026-10-10: The new 16-command batch uses a separate candidate manifest with
74 releasable coordinates; the 58 published coordinates keep their versions.
Candidate validation requires the complete current catalog. Frozen published
manifests validate their declared release inventory and selected cases, so
adding a new command does not invalidate old-version replay. Empty inventories,
unknown commands, missing selected coordinates and option claims still fail.
The compatibility cost is that completeness is a candidate gate rather than a
retroactive property of every old manifest. Revisit only with explicit release
inventory schemas, preserving historical replay tests.

Recheck released dependencies or reported mismatches. Rerun affected behavior and
exact-version published-consumer gates before promoting support. Expand observer
capabilities when public APIs or fixed test oracles can measure a missing
dimension reliably. Change test frequency only after measured cost and a mapping
show that required behavior/platform coverage is preserved.

2026-10-11: The P2 candidate was promoted only after CI run
`38103982048` passed Linux, macOS and Windows. Publication was serialized as
`cli/core@0.4.0`, then `column`, `date`, `strings` and `which` at `0.1.0`; each
registry upload returned `Server status: 200 OK` and exact `moon view` checks
confirmed immutable coordinates. The preparation manifest remains frozen; the
published manifest and final smoke report are the current release evidence.
