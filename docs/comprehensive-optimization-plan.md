# Comprehensive algorithm, performance and CI optimization execution plan

Date: 2026-10-23; execution direction revised 2026-10-24

Repository: `moonbit-community/cmd`

Status: C0/C1/C3/C4 accepted. The benchmark pilot is merged; complete benchmarks, command algorithms and final publication remain pending.

Source: `cmd-comprehensive-optimization-plan-2026-10-23.md`, supplied by the user.

The user's 2026-10-24 direction removes C2. The execution baseline is accepted
main `f2769846996ec0dc9d03d55014aa2f749bf1fbb6`. Keep the unmerged C2 work
on its local branch; do not carry it into subsequent changes. Retain C1's full
three-platform checks, coverage audit and daily schedule. Do not introduce a
root PR coordinator, isolated guard, handoff-audit framework or scoped/weekly
activation. Reduce demonstrated duplication and runtime cost with small,
maintainable changes; avoid additional hash checks and defensive frameworks.
The scope design below remains C1 background, not a new activation stage.

This is the English repository counterpart of the selected comprehensive plan.
It does not certify completion of any stage. Existing historical reports remain
immutable. Preserve the pre-existing untracked `algorithm-performance-plan.md`
separately; do not silently overwrite it or treat its earlier planning-only
authorization as the current request. Current repository instructions remain in
force until their reviewed replacement takes effect.

Execution evidence begins with the
[C0 investigation](reports/2026-10-23-c0-investigation/README.md). That record
distinguishes the reproduced command-oracle cleanup defect from the historical
timeout whose cause remains unconfirmed. The separate
[C0 actual-main acceptance](reports/2026-10-23-c0-acceptance/README.md) records
the completed four-check gate at main `4180e527`. C1 subsequently completed at
`f2769846`, including actual-main run `39955744640`. Full/shadow execution stays
in effect.

## 1. Objective, decisions and boundaries

Complete selected algorithms, options, resource handling and performance work in
this fixed feature order: **#27 gzip -> #28 sed -> #30 diff/patch -> #33 common
options -> #32 streaming/resources**. Review and measure all **79 current
commands and 12 shared core packages**, including commands outside those issue
titles. Establish reliable mainline acceptance, change scope, execution reuse
and benchmarks before feature implementation. Each stage has independent PRs;
large stages split by command family. Finish a stage's selected implementation
and development validation before starting its successor. Merge completed work
as **awaiting combined publication and exact MoonX acceptance**. Close the
issues in the same order only after final acceptance.

| Question | Selected decision |
| --- | --- |
| Delivery performance | Actual, cached, exact-version MoonX invocation, including startup and exit |
| Native/direct Wasm | Independent development, algorithm, correctness and backend-pair evidence; no replacement for MoonX acceptance |
| Performance gate location | Fixed local macOS and Linux environments, outside required hosted CI timing statuses |
| Windows | Three-platform correctness; diagnostic timing only until a stable host exists |
| Candidate publication | Necessary final joint-acceptance `-rc.N` coordinates only; no ordinary-PR candidates |
| PR validation | Existing C1 full execution and current impact declaration |
| Ordinary main | Full validation of the real main commit |
| Periodic full runs | Existing daily full source/published checks; full before release |
| Scope inputs | Existing coverage prepare/verify and sole `tests/coverage/ci-change.json` |
| Freshness | Actual content, change set, dependency, registry, policy and base fingerprints |
| New commands | No awk/tar/zip/unzip in this round |

Unknown impact, broad shared infrastructure changes, release freezes and repairs
of full-regression failures may force full validation. Removing unrelated work
does not remove relevant semantics, platform checks, provenance or failure gates.
This round retains full execution after each merge.

All product, runtime, commands, runners, fixtures and repository automation use
pure MoonBit. Agent-authored automation uses `.mbtx`. Do not add project-owned
C/C++/Rust/JavaScript/TypeScript/Python/shell implementations, FFI, native stubs,
private dependency imports or host-command implementation fallbacks. Fixed
oracles, CI setup and external process/memory observers remain outside the
product boundary. Verify released public API capability before recording an API
gap; algorithm, parser, format and data-structure difficulty is project work.

Do not expand #31 shell/make language or #34 network/JSON features. Existing
sh/make/curl/wget/jq/jqlog still receive performance review. #10/#20/#38 remain
capability trackers. `timeout` remains local-only. Compatibility claims apply
only to the frozen version/platform/locale/option/behavior matrix, never complete
GNU/POSIX compatibility.

The performance target is parity or better; the maximum accepted cost is 1.5x
for **each applicable workload**. Averages, removed slow rows, changed
correctness and disabled upstream optimizations cannot establish acceptance.

Engineering defaults include the existing daily schedule, schema-v2 declarations,
105 paired samples with bootstrap, 64 KiB I/O,
64 MiB sort accounting and 16-way merge. Internal parameters may evolve with
reviewable evidence. Do not independently relax scope, the 1.5x ceiling,
evidence requirements or completion conditions. Explain contract changes with
their reason and old/new difference.

## 2. Starting snapshot and ordered preflight

The following is the plan's dated starting snapshot, not a substitute for live
verification:

| Item | Plan snapshot |
| --- | --- |
| Main source | `5fef93ecec8cebeb7b4f9bdd479e8f3619d12513` |
| Published shared package | `cli/core@0.7.0` |
| Stage-0 changed commands | curl/mv/wget at 0.2.3; other 75 coordinates retained |
| Commands | 79 total, 78 published, timeout local-only |
| Core packages | 12, enumerated in section 13 |
| Release record | `docs/reports/2026-10-20-stage0-release/README.md` |
| Coordinate authority | `tests/release_runner/current/published.json` |
| Pre-existing local draft | Untracked `docs/algorithm-performance-plan.md`, 666 lines |
| Pre-existing interfaces | 13 modified generated `.mbti` files, not authored as this plan's changes |
| Plan-time toolchain | moon/moonrun `0.1.20261020 (2284bd2)`; moonc `v0.10.16+b1a0e846e` |

The interface files belong to core/bytere, checksum, cli, fsops, gzipops,
netops, process, shell, stream, time_zone and tests/coverage, registry, testkit.
Determine provenance and expected API differences before adopting them in a
separate commit. Otherwise preserve them. Never manually edit generated files
or discard unknown changes to obtain a clean checkout.

The source run `39404396152` passed at
`7829269d1a3b751768e6f64a0d305cd76282ee02`. The later run `39438523360`
failed on Linux: `hexdump-empty` reported `oracle-timeout` at about 120084 ms;
macOS and Windows passed and coverage-audit rejected the incomplete matrix.
First inspect newer runs at the exact current main revision. Retain the failed
log and fixture, investigate empty-stdin EOF delivery, container/child completion,
cancellation and cleanup, and distinguish product, harness and environment
failures. Do not assume a hexdump algorithm defect, merely raise timeout, skip
the case or relabel an infrastructure failure as success. Restore valid full
mainline evidence before feature development.

Preflight order:

1. Verify Git root, checkout, branch, remotes, dirty content and unuploaded
   evidence; reuse an appropriate checkout and preserve unknown files.
2. Read current AGENTS, canonical ADRs, coverage, registry and release docs.
3. Reproduce/classify or fix the mainline timeout and obtain valid main checks.
4. Re-enumerate 79 commands, 12 core packages and every existing option/support
   status. Fill missing behavior without rewriting already implemented options.
5. Freeze source SHA, dependency resolution, moon/moonc/moonrun/moonx, compiler,
   OS/SDK, oracle and corpus identities.
6. Rebuild the pre-optimization source baseline with the same toolchain; separate
   compiler-upgrade improvements from algorithm improvements.
7. Start and freeze a native arm64 Linux VM; initial configuration is 4 CPUs,
   8 GiB RAM and at least 40 GiB free VM-local disk.
8. Measure real current published MoonX true, false, basename, cat, wc,
   sha256sum, grep and gzip on small and applicable large inputs early.
9. Reconcile stale stage-0 README/roadmap prose without rewriting historical
   release/test results as current acceptance.

Async 0.22.5 already has limited LZ/fixed-Huffman encoding. Verify source/tests
before defining reuse. The historical stored-block-only description is no
longer current; #27 still needs full-window matching, dynamic Huffman, effective
levels and incremental decoding.

## 3. CI costs and execution reuse

The successful run `39404396152` supplies the following historical Windows
breakdown. It is a measured starting point, not a future machine guarantee.

| Stage | Time | Direction |
| --- | --- | --- |
| Full Native release build | 11:19 | Target closure, valid incremental output, compile/link distribution |
| Registry package backend-pair | 7:13 | Prepare each compilation unit/backend once |
| Registry package Native-only | 4:22 | Reuse prepared artifacts and fixed identity |
| Ordinary package tests | 3:37 | Remove reruns only after exact inventory mapping |
| Command backend-pair | 2:49 | Reuse identical actual raw observations |
| Native/Wasm contracts | 0:47 / 1:03 | Scope and process preparation |
| Native/Wasm scenarios | 1:11 / 1:31 | Shared compilation, independent fixture state |
| Wasm release build | 0:12 | Not the primary bottleneck |
| Metadata/compatibility | 0:34 / 0:40 | Keep global invariants, scope behavior |
| Policy/stress/upload | 0:25 / 0:37 / 0:31 | Layer stress and trim report transfer |
| Windows total | 38:31 | Reduce unrelated work, then exact duplicates |

The main cost groups total about 29:20, or 76% of Windows. Linux was 30:23,
macOS 16:53 and coverage-audit about 1:27; combined raw job time was about
87:14. Windows occupied about 96% of the roughly 40-minute critical path but
44% of these job execution minutes. Do not confuse wall-clock contribution
with total computing cost. About 363 Native and 212 Wasm tasks were recorded;
there is no reliable compiler-task timing to attribute all Native cost to MSVC,
antivirus, disk or one MoonBit component. Docker preparation took seconds and
dependency updates about 1-6 seconds; mirrors are not the primary explanation.

Priority order:

1. Trusted PR impact closure, including negative and transitive cases and
   selected/full intersection equivalence.
2. One preparation/build plan/test inventory per module/package/backend;
   preserve case set and identities while reducing Moon calls/builds.
3. Exact ordinary-package/registry execution mapping; retain unmapped tests.
4. Backend-pair consumes this run's independently executed raw observations,
   including bytes, status and required side effects, never just pass labels.
5. Minimal audit artifacts with retrievable raw evidence and failure diagnostics.
6. Correct toolchain/dependency/build cache keys and cancellation of superseded
   runs belonging to the same PR only.
7. Measured concurrency 1/2/4 and Native internal build settings, including
   resources, stability and total CPU cost.

### 3.1 Package inventory and duplicate removal

The plan observed about 513 Native and 287 Wasm registered backend/test
combinations. Recount live. Group code-build, compiled-test inventory and
name-to-index mapping by compilation unit/backend; freeze output. Test names
must be unique and selected tests present. Explicitly parse attributes, skips
and target restrictions. Preserve doctests, JS, Wasm-GC and any tests outside
Native/Wasm registry responsibility.

Verify this toolchain's supported `--index`/`--frozen` contract before use;
continue selecting individual tests through supported Moon entrypoints. Do not
invent a direct-driver protocol or depend on a private generated-code ABI.
Generate source/test-name mappings after compilation. Prove that exactly
the expected tests actually ran; exit 0 can mean zero tests. Store one verified
shared artifact per build unit instead of copying and rereading every large
artifact for each case. Remove the duplicate ordinary
entrypoint only after every original inventory item has an execution owner.

### 3.2 Other reuse and cache conditions

Reuse requires identical run, attempt, checkout, backend, artifact, fixture,
argv, environment and observation contract. Native and Wasm each execute;
side-effect fixtures start independently clean. Oracle observations may be
shared only for deterministic inputs/behavior and identical identity. Network,
state, time and randomness cases remain independent by default; persistent
containers do not provide automatic isolation.

Linux smoke/freeze may reuse the same-source, same-configuration build, while
each required consumer check still executes. Split the roughly 475 MB platform
report transfer into compact audit receipts and detailed diagnostics. Raw
evidence must remain retrievable by content identity; a hash without available
content fails audit.

Cache allowed dependencies and intermediate artifacts using OS, architecture,
toolchain, SDK, dependency graph, backend and flags. Never cache developer
credentials/tokens or reusable passing test results. Validate identity and
execute correctness on cache hits; rebuild untrusted/mismatched entries. Main
never inherits PR pass results. Cancel only superseded runs of the same PR;
preserve failure logs and do not cancel main/daily/release for unrelated PRs.

Serialize Moon check/test/build/info/fmt because of `_build/.moon-lock`.
Measure Moon-internal concurrency separately. Initially allow at most two
already-built independent direct fixtures concurrently; network, lifecycle,
stress and time-sensitive cases remain serial unless stability and total CPU
measurements justify expansion.

Engineering goals are 5-10 minutes for small warm-cache PRs, about 20 minutes
maximum for warm full Windows, 25 minutes for the full pipeline, and at least
30% fewer raw runner minutes with the same full coverage. These are unproven
optimization goals, not timeout policies or permission to drop tests. Record
cold/warm build/test/oracle/upload/audit, task/Moon/case counts, transferred
bytes and CPU/wall time. Do one full cold/warm comparison, then evaluate three
naturally occurring successful runs instead of manufacturing repeated full CI.

## 4. Scope schema, closure and freshness

| File/layer | Responsibility |
| --- | --- |
| Existing coverage prepare/verify | Reuse C1 entrypoints without a new coordinator |
| `tests/coverage/ci-change.json` | Sole current impact declaration; schema upgrade; requirements only |
| `tests/coverage/` | Diff, dependency closure, declaration checks and evidence binding |
| `tests/registry/` | Stable command/behavior/case/owner/backend/observations and non-import associations |
| `tests/coverage/push.mbtx` | Existing exact-commit audit and controlled push |
| Coverage README/AGENTS | Operational contract, exceptions and freshness requirements |

The existing `prepare_ci_change.mbtx` hardcodes a historical base, reports and
cases. Generalize before use. `ci_input.mbt` strictly rejects unknown fields;
phase schema migration explicitly.

Minimum scope is **automatic closure union reviewed human additions**. Authors
may add indirect effects but cannot remove automatic consumers, cases, backends
or observations. Human review adds requirement semantics, unstructured coupling,
historical defects and multi-command scenarios. Unprovable impact expands scope.

Read the complete target-base/head diff, including add/modify/delete/rename,
type, Git mode and old/new blobs. Build both base and candidate dependency
graphs and use their union, including test dependencies, backend conditions and
external resolution. Read registry ownership plus shared fixtures, child
command launches, policy/scenario/cohort/catalog/release relationships. Include
toolchain, workspace, selection-policy and workflow widening rules.

Reverse dependency closure selects consumers/tests. Forward dependency closure
selects build prerequisites; it does not automatically retest every unchanged
prerequisite's behavior. A changed command selects its complete applicable
registered behavior collection and linked integrations, not only new cases.

| Change | Minimum selection |
| --- | --- |
| Command behavior/dependency/version | Complete related package, contract, metadata, policy, pair, applicable oracle/scenario and published association |
| Core implementation/API | Union of old/new reverse consumers; all compile consumers for API changes |
| Catalog literal row | Narrow only if strict recognition proves helpers/structure unchanged; corresponding commands plus global invariants |
| Catalog helper/control flow/unknown expression | Normal core closure |
| Registry/manifest data row | Compare stable IDs; select both-side owners and global uniqueness/reference checks |
| Shared runner/testkit/fixture | Every consumer of the layer; general layers normally full |
| Resolver/audit policy/toolchain/workspace global configuration | Full plus registered harness regressions |
| Command README/help/support | Check declared behavior/metadata/registry consistency; no blanket docs exemption |
| New narrative historical report/allowed index | Narrow docs-only rules and immutable-history/reference checks |
| Deleted test/command/module | Old-side consumers, removed acceptance conditions and replacement evidence |
| Unknown path/syntax/owner | Explain and run full; never silently empty |
| Malformed/missing/forged declaration | Reject; widening does not repair broken input |

AGENTS, ADRs, compatibility, README and `.mbt.md` are not general docs-only
directories. Preserve historical immutability checks for edits/deletes/moves.

### 4.1 Schema-v2 identities

Final field names are frozen by C1, not established APIs merely because this
table describes them.

| Group | Required identity |
| --- | --- |
| Schema/policy | Schema and parser/selector rule version or digest |
| Base | Target ref and exact base SHA aligned with actual PR target |
| Payload | Tree fingerprint of managed tracked content, excluding declaration itself |
| Change set | Full old/new paths, blob IDs, modes, change types and canonical digest |
| Dependency/registry | Both graph identities, registry and non-import rule identities |
| Impact | Commands/behaviors/options/operands/core and required backend/evidence/observations |
| Extra impact | Human additions and reasons; cannot narrow closure |
| Boundaries | Deferred/uncovered/boundary with ADR/unlock/rejection-test mapping |
| Published | Published-contract/manifest effect and affected exact coordinates |

Do not write pass labels, local report paths or historical run IDs into intent.
CI binds real execution receipts to its actual checkout. Do not embed the
self-containing commit SHA in intent; exact head/merge SHA belongs in execution
receipts. Any managed source/test/support/dependency/rule change must refresh
payload/change fingerprints. Whitespace, timestamps and nonces cannot repair
staleness. Identical tree/base with only a commit-message change or re-push needs
no meaningless declaration edit.

### 4.2 Prepare, verify and trusted execution

Finish implementation/tests/docs/format/interfaces, resolve and synchronize the
target base, and stage intended content. Preparation reads the intended staged
tree and rejects unstaged managed changes. Generate closure plus readable
explanation, retain reviewed extras, generate/stage intent, commit, recompute
against exact clean HEAD and run the required audit/push. Later content changes
return to preparation.

Remote preflight validates schema/base/head/synthetic merge/payload/closure and
requirements before expensive builds. PR receipts bind GitHub's synthetic merge
SHA and verify its parents are the expected base and PR head. Base advances
require synchronization and refreshed validation. Main computes the actual
first-parent/before..after range, retaining applicable reviewed extras and union
impact across multi-commit pushes; squash/merge cannot reuse a PR head receipt.

GitHub workflows run after a push is accepted. Remote failure blocks merge;
the local wrapper supplies rejection before push. Selection minimums use the
reviewed target-branch policy. Changes to resolver/policy/workflow/audit force
full validation and cannot approve their own reduced scope. No additional
trusted-base guard is part of this round.

Keep required status names `ubuntu-24.04`, `macos-15`, `windows-2025` and
`coverage-audit`. An optional selector preflight job is checked by final audit.
Legal empty scope requires an explicit valid classification and per-platform
executed/not-applicable responsibility. Missing jobs/evidence, failed selection
or skipped required jobs must never aggregate green.

## 5. Trigger matrix, migration and harness regressions

| Trigger | Source | Published | Required identity |
| --- | --- | --- | --- |
| PR | Existing full three-platform/backend execution | Current C1 publication conditions | Fresh intent; actual synthetic merge |
| Main push | Full validation of the actual merge | Current C1 publication conditions | Fresh actual-main evidence |
| Daily schedule | All 79 commands/core and applicable source regressions | All current 78 coordinates | Existing UTC `17 3 * * *` |
| Manual full | Full source | Source/published/both selectable | Selection recorded in receipt |
| Freeze/RC/formal | Full actual-main source and release closure | Baseline before release, exact new coordinates after; linked unchanged consumers | Run before release, independently of the schedule |
| Global selector/policy/toolchain | Full | Full when published interpretation/execution affected | Prevent self-authorized scope reduction |

Schedules may run late. Daily full executes even when source is unchanged; build
cache is allowed, prior passing results are not. Schedule/manual full use
explicit `regression-only/full`: derive requirements from current main and full
registry, without fabricated PR changes or stale-intent filtering. Receipts
record trigger, full/scoped, source, run/attempt, scope fingerprint and execution
responsibility. Unresolvable before SHA, rewritten history or unknown base on
main means full, not empty. Future merge queue support must validate its real
queue SHA before using it. Benchmark parser/statistics/sampling/gate unit tests
run in normal CI; noisy hosted timings never become required performance gates.

Linux runs applicable contracts/policy/Native/Wasm/pair, immutable oracle and
relevant consumers plus Linux boundaries. macOS runs real source/consumer,
filesystem/process and pair checks, not compilation alone. Windows retains
real path/link/locking/output behavior including stage-0 mv directory-entry and
referent observations and separate Native/Wasm runtime identity. Missing Windows
permission/observer/host capability is unfinished or an explicit boundary;
nonzero status alone does not prove no damage. Targeted affected resource,
process and network stress stays in PRs; retain current full stress execution.
Never move sole semantic evidence away just because its name contains stress.

| PR label | Work | Its own acceptance |
| --- | --- | --- |
| C0 | Mainline timeout classification/fix and valid current evidence | Existing full three-platform/audit |
| C1 | Schema v2, generic parsing/closure/freshness and negatives; explicit old-schema transition | Full execution, selector shadow, expected-scope comparison |
| C3 | Package precompile/inventory/duplicate removal/pair reuse | Equivalent complete execution and observation set; retain unmapped tests |
| C4 | Artifacts/cache/release build reuse/timing/controlled concurrency | Relevant regressions and complete cold/warm comparison |

C2 is removed. Continue directly from accepted C1 to C3/C4, which may split.
Keep full execution and avoid new coordination or proof layers. Old schema is
accepted only through the explicit migration path; ordinary new PRs ultimately
require freshness. Never alter historical reports retroactively.

Register meaningful regressions for stale content, timestamp/whitespace-only
intent refresh, missing direct/transitive consumers and lost human extras;
base advance, wrong merge parents/source SHA, unstaged changes and post-prepare
edits; deletion/rename/import removal and old/new graph/backend differences;
non-import scenarios; literal catalog narrowing versus helper/unknown widening;
global uniqueness; legal-empty versus corrupt intent and unknown-owner full;
selector/audit changes forcing full; duplicate/missing/attributed test inventory,
zero-test success, wrong index and changing artifact; wrong backend/artifact/
oracle/run/attempt, missing raw observations, tampered cache/frozen files and
both pair sides reusing one execution; scoped/full intersection equality;
main/daily triggers resisting PR intent; unchanged-source daily execution;
and missing/failed/skipped mandatory platform/selector aggregation.

On full-regression failure retain source/package/toolchain/oracle/logs and
classify source, published, infrastructure or observation deficiency. Pause
affected changes/releases after impact analysis. Unrelated PRs require explicit
dependency analysis; neither freeze the whole repository automatically nor
continue releases unattended. Fix with the complete relevant matrix and one
full recovery run, not only the single failing case.

## 6. Performance acceptance contract

For every registered command/workload/host/input/cache row independently:

```text
R50 = median(full MoonX time) / median(full upstream time)
R95 = p95(full MoonX time) / p95(full upstream time)
target: R50 <= 1.00
required: R50 <= 1.50, R95 <= 1.50,
          upper bound of the 95% interval for R50 <= 1.50
```

Every measurement starts a new process and includes cached exact-package
resolution, moonrun startup, command execution, flush and exit. No daemon,
persistent service or empty-runtime subtraction. Upstream is an explicit
executable, never a shell builtin or deliberately added MoonX-like wrapper.
Geometric means, throughput aggregates and fast large files cannot compensate
for small-row failure. Claim faster only when the R50 95% upper bound is below
1. A 1-1.5 result is tolerated cost. Wrong output, early termination, timeout,
OOM, policy refusal and missing measurement do not pass.

All 78 published commands enter real MoonX acceptance. Timeout still receives
review, correctness and Native/Wasm development data; its registry row is N/A
and it is not published for table completeness. Unsupported capabilities get
rejection correctness/cost, not successful-workload performance claims.

| Measurement role | Meaning | 1.5x delivery gate |
| --- | --- | --- |
| Delivery | Cached exact coordinate; fresh process each time | Yes |
| First use | Empty-cache download/resolve/compile/first run with network/build provenance | No, separate |
| Development | Release Native/direct Wasm/core in-process microbenchmark | No, causal diagnostics |

Delivery includes warm filesystem-cache profiles. Report cold-data results only
with reproducible cache control; a renamed file is not cold cache. Each
side-effect run has a separate equivalent starting fixture. Setup/cleanup is
outside timing, while the command's actual reads/writes stay inside.

### 6.1 Frozen hosts, oracle and environment

Freeze macOS host CPU/RAM/OS/power/temperature/disk and same-version native
upstream compiler/flags/ABI/libraries/executable checksum. Linux uses one native
arm64 VM with fixed CPU/RAM/disk and the driver inside the VM; exclude
docker-run/exec wrapping from both sides. Label virtualized arm64 and do not
extrapolate to bare-metal x86. Freeze Linux semantic image digest, version
inventory, source/distribution checksums and configuration. Freeze Windows
runner image, tools, SDK, permissions, backend and host boundaries; timing is
diagnostic. macOS and VM performance runs are serial without host competition.

Semantic versions remain coreutils 9.11, gzip 1.14, sed 4.9, diffutils 3.12,
patch 2.8, findutils 4.10.0, grep 3.12, util-linux 2.40, binutils 2.44,
curl 8.22.0, wget 1.25.0, make 4.4.1, jq 1.8.2, dash 0.5.12 and recorded
xxd/jqlog identities. Identify/hash actual rev/tree/which providers. BSD names
cannot stand in for GNU. The recorded Linux image is
`sha256:f82510ba6c5c5ff537008d5b9dbbf7799515b226e7c75493b79fe7e9cb56f8c2`;
verify current availability/identity. New arm64 images and native macOS tools
need distinct sealed profiles. Rebuilding from checksummed source creates a
new profile requiring documented differences and new relevant evidence.

Fix `LC_ALL=C`, `LANG=C`, `TZ=UTC`, required widths and environmental inputs
for comparison; products still honor real user environments. Retain upstream
normal optimization, SHA hardware acceleration and sort default parallelism.
Scalar/single-thread controls are diagnostics only.

### 6.2 Sampling and statistics

1. Install/build/warm caches and prepare fixtures outside timing. Record argv,
   allowed environment, sink/source, package/archive/artifact, tools, oracle,
   host and corpus identity.
2. Five warmups per executable, then five blocks of 21 pairs: **105 measured
   independent invocations per side**, balanced recorded fixed AB/BA order.
3. One experiment at a time. Tiny commands still launch each process. Increase
   batch measurement if timer resolution requires, without in-process loops.
4. Report median, p95 and MAD. P95 is nearest-rank `ceil(0.95*n)` after sort;
   freeze the even-count median definition in the harness.
5. Resample pairs, fixed seed, 10,000 bootstrap iterations, two-sided 95%
   percentile interval for median ratio; retain implementation/raw order.
6. Mark noisy if MAD/median >5% or largest/smallest block-median difference
   exceeds 10% of overall median; investigate load/thermal/VM/disk conditions.
7. Preserve noisy attempts/corrections; at most two full retests, then
   inconclusive. No slow-sample deletion, best-attempt selection or fewer
   repetitions for slow commands.
8. Smaller iteration samples are development smoke only.

### 6.3 Correctness, resources and corpus

Compare stdout/stderr bytes, exit status and filesystem/wire/process effects
before timing; recheck deterministic output outside timing afterward. Use
streaming sinks/hash/files for large output; controllers must not hold 512 MiB
outputs. Null sinks are allowed only for registered throughput workloads, with
real output-target workloads retained.

Record wall/CPU, first output, throughput, output size, peak RSS, explicitly owned
buffer/record/index memory, temporary-disk peak and necessary syscall/allocation
diagnostics. Attribute MoonX/moonrun/requested children separately; do not add
asynchronous process peaks and call that an instantaneous tree peak. Profile
separately so the observer does not pollute timing. Missing permission/API is
missing observation, never a guessed peak. Investigate memory growth above
`max(10%, 16 MiB)` against the same-toolchain baseline. Explicitly revise
justified algorithmic resource contracts; correctness, committed space bounds
and cleanup remain mandatory.

Freeze 0 B/1 B/4 KiB startup cases; no-input/stdin/files/options; 8/64/512 MiB
fixed records and applicable binary; individual 1 KiB/64 KiB/1 MiB/8 MiB/64 MiB
records; ASCII/NUL/invalid UTF-8/no final LF, entropy/repetition/sorted/reverse/
random/skew/long-prefix data; multiple files, later failure, empty/deep/wide
trees and duplicates; 1/1,000/100,000 entries within OS depth limits; no/late/
alternation/empty/capture/backreference regex matches; varied diff edit density,
repeated lines/equal shortest scripts/common edges; checksummed real source/log/
JSON/text and held-out corpus; input/output/temp failures, broken pipes,
cancellation, prefixes and cleanup. Sizes are evidence, not supported maxima.
Combine complexity, integer limits and sparse large-offset tests; error-path
speed cannot substitute for successful processing.

Curl/wget use shared pure-MoonBit loopback payload/chunk/retry/connection/Range
fixtures. Server throughput must reach twice the faster client or results are
fixture-limited; optimize/refreeze the fixture rather than slowing oracle.
Sleep/timeout report wakeup/CPU/cancel overhead separately from intentional
delay. Yes has a fixed-byte consumer that closes its pipe and reports prefix,
first output, throughput and close response. Env/xargs/sh/make use the same
pure-MoonBit child/work/jobs/input/status and separate scheduler/launcher cost.
Normalize mktemp names only through predeclared identity/effect relations while
checking exclusive creation/modes. Gzip must pass speed and size, never all
stored blocks for speed. Keep hash hardware optimization and report genuine
public-API/runtime limits as failed rows.

## 7. Benchmark infrastructure and optimization decisions

Planned files are `tests/benchmark/manifest.json` (stable workload/owner/behavior/
size/oracle/role/observations), `profile.json` (frozen host/VM/tools/oracle/cache,
no secrets or pass claims), thin `run.mbtx` (prepare/run/compare/gate/report CLI
to be implemented and verified), pure `.mbt` corpus/sampling/statistics/resource
logic, and immutable `test-reports/performance/<run-id>/` evidence. Reuse
testkit fixtures/process/deadlines/provenance and add only small streaming-sink
or observer APIs; do not create a parallel correctness registry. Workloads
reference existing behavior IDs; performance, contract, oracle and boundary
remain different evidence.

Harness tests cover statistics/quantiles, AB/BA, fixed bootstrap, missing samples,
noisy/fail, zero duration/overflow, identity mismatch, streaming stdout and
cleanup. Add tests for actual risk, not each JSON field's mirror implementation.

Codec belongs in gzipops/necessary internal raw DEFLATE, with retained Bytes
adapters and new Reader path, without speculative archive APIs. Regex belongs
in bytere with preserved Pattern::find/Hit and safe lazy capture materialization.
Scanning/buffers belong in stream, hashes/manifests in checksum, commands in
argument/state/effect orchestration. Existing independent command root/module
rules remain; no excluded commands are added.

Optimize complexity, repeated work/copying, representation, I/O and hot loops in
that order. Do not hash every tiny argv, build all catalog entries for every
invocation, add persistent caches/daemons, or weaken permission/input/error
checks. Each hotspot records evidence, change, correctness impact, same-toolchain
baseline/candidate and time/memory/complexity effect. Already-fast code may stay
with measured justification.

If startup already exceeds 1.5x, feature work may proceed while overall delivery
stays unfinished. Verify equivalent work, isolate launcher/runtime/I/O/core,
apply smallest justified changes and remeasure semantics first. After three
distinct unsuccessful strategies on one bottleneck, record feasibility instead
of blind tuning. Functional PRs may merge pending release; failed selected
performance rows block formal release/completion until solved or the user
explicitly changes acceptance. A child issue does not make the target pass.

## 8. G: #27 gzip and incremental decoding

Separate RFC-1951 raw bits from gzip envelope, consumed by gzip/gunzip/zcat.
Use 32 KiB LZ77 history, length 3-258, hash chains and bounded search/reusable
tables. Support stored/fixed/dynamic blocks and select by complete header/tree/
padding/EOB cost. Dynamic canonical Huffman needs valid maximum lengths,
code-length encoding and degenerate-frequency handling. Target about 64 KiB
blocks, split stored lengths correctly and preserve history across blocks.
Decode with Reader refill/bit buffer, main plus secondary/slow tables, 32 KiB
ring history and incremental CRC/ISIZE. Bytes APIs adapt without claiming their
callers no longer hold input.

Levels `-1` through `-9`, `--fast`, `--best`, default 6 must alter search, not
only headers. Initial levels 1-3 greedy, 4-9 lazy; chain limits
`[4,8,16,32,64,128,256,512,1024]`; nice lengths
`[16,32,64,64,128,128,258,258,258]`. Tune internal values against frozen/held-out
corpus. Verify repeated-level/alias ordering against GNU.

Stream headers/extras/name/comment/FHCRC/trailers through all byte splits.
Validate CRC, ISIZE, multiple/empty members, padding, trailing junk, truncated
header/block/trailer, invalid trees/distances, overlap, ring wrap and cross-block
matches. Do not retain all decoded output as history. Keep GNU error prefixes,
including decoded body before trailer failure, and preserve established output/
format/read error ordering. Account encoder window/tables/block/tokens and
decoder window/I/O/bounded tables separately from Bytes caller memory.

G1 delivers raw codec/levels/cost selection with independent vectors/properties,
GNU two-way interoperability and size/development data. G2 delivers Reader and
envelope/three-CLI prefix/status/effects, byte-feed, corruption/members,
Native/Wasm/pair and resources. GNU 1.14 decodes project output and the project
decodes every GNU level; compressed bytes need not match. Every level actually
shrinks designated compressible data. At least 8 MiB compressible target size
is <=1.05x same-level GNU; incompressible overhead <=`max(1 KiB, 0.1% input)`.
Report ratio, speed and memory independently. Include short/long/cross-window
matches, repeated/entropy/all-byte/empty data and every truncation/corruption.
Metadata/time/permission replacement gaps get precise child items. Incremental
decoding finishes here, not deferred to #32.

## 9. S: #28 shared matcher and sed instruction machine

Parse BRE/ERE once into AST. Ordinary patterns use a tagged/capture-capable
Thompson-like path with POSIX leftmost-longest and capture selection, plus fast
literal/prefix paths. Keep byte spans and materialize capture content only when
needed; eliminate recompilation/allocation for every right boundary.
Backreferences use explicit stack/state and capture-aware comparisons with only
proven pruning. Never merge distinct-capture states unsafely or add hidden step
limits; report worst-case resources without claiming linearity. Support captures,
pattern backreferences, C-byte classes/word assertions including applicable
`\<`, `\>`, `\b`, `\B`. Preserve Pattern::find/Hit; verify expr and separately
register changes for grep/csplit/tac/other consumers.

Sed explicitly owns PC, pattern/hold spaces, address-range state, substitution
flag, deferred append queue and input state. Compile labels/groups/jumps.
Support h/H/g/G/x empty/multiline/newline/swap; :/b/t/T label resolution,
unlabelled branch and flag consumption/reset; nested addressed/inverted groups;
n/N auto-print/read/EOF/multifile/flag/deferred output; P/D first-line printing,
deletion/restart/state; a/i/c immediate/deferred/range/escape/newline behavior;
existing numeric/regex/range addresses, empty-match progress, captures and no LF.
Report static errors before input/file/output effects. Freeze cycle/N-last/D/q/
auto-print/append and multi-file numbering/state by byte differential.

S1: AST/matcher/adapters/expr; test empty/leftmost-longest/capture precedence,
repeated groups/backrefs/assertions/invalid patterns. S2: instruction/PC/hold/
groups/branches; test missing/duplicate labels, nesting, flags and finite loops.
S3: n/N/P/D/a/i/c full cycle; EOF/multifile/no LF/order/long spaces/error prefix.
Measure compile separately from repeated find and prevent old repeated-right-
boundary degradation. Harness deadlines for backreferences/infinite scripts
are external observations, not product limits. Pattern/hold accumulation means
sed is not generally constant-memory. Keep `-i` metadata and excluded GNU
extensions as precise child boundaries; no complete GNU sed claim.

## 10. D: #30 diff/patch

Diff implements `-i -w -b -B -Z --strip-trailing-cr`, ordinary files/directories,
`-r -N --unidirectional-new-file`. Separate comparison keys from original bytes
used for output. `-B` affects change decisions, not pre-deletion of blank lines.
Freeze normalization ordering. Reconstruct Myers via bidirectional middle-snake
and explicit stack for O(N+M) auxiliary space. Safe common-edge trimming/key
interning cannot alter selection; verify byte equality after hash matches.
Account inputs/keys/output separately; no linear-time/constant-memory claim.
Repeated lines, equal shortest scripts, GNU heuristics/hunk boundaries need
output-byte parity, not just patch roundtrip. Freeze directory order, types,
missing/unreadable sides, diagnostics/status and public link boundaries.

Patch retains per-file/per-hunk exact/offset/fuzz/rejected/fatal results,
cumulative displacement, candidate order, used regions, context trim and reverse
state. A rejected hunk writes applicable reject data and allows later hunks;
aggregate mixed success with applicable 0/1/2 statuses. Implement `-F/--fuzz`
(default 2), offset signs/equidistant selection/fuzz tiers/empty context, default
new rejects and `-r/--reject-file`, byte-exact reject order/path/failure behavior.
Dry-run creates neither target nor reject, including temporary side effects.
Separate stdout/diagnostics and verify -R/output/stdout/multifile combinations.
Implement safe new-file/new-reject creation within public APIs. Existing-file
identity/metadata gaps cannot block all patch work; unsafe existing target/reject
replacement is rejected before damage, not disguised as inode-preserving rename.

D1: comparison keys/options/directories with whitespace/case/CR/blank/type/
missing/order/diagnostic matrix. D2: linear-space reconstruction/hunks, repeated
and equal scripts, edit densities, long prefixes, memory and GNU bytes. D3:
offset/fuzz/reject/mixed results, multifile/hunk, duplicate candidates, reverse,
dry-run/effects/failure order/two-way roundtrip. Roundtrip supplements bytes/
status/reject evidence. Transfer exact metadata/link/writeback limitations with
their original conditions and no-side-effect rejection evidence.

## 11. O: #33 selected option families

Before each family classify current source/README/help/registry as implemented,
repair, new or API boundary. Freeze/review an oracle-backed conflict table with
aliases, value forms/defaults/repeats/mutual exclusions, stdin/operand effects,
target effects, error precedence and case IDs. There is no global last-option-
wins rule. Oracle-resolvable details require no fresh user decision. Finish each
family before its successor; review-size PR splits do not remove unfinished
items. Complete selected #33 work before #32.

| Family/command | Selected exact scope | Required distinctions |
| --- | --- | --- |
| O1 cut | `--complement --output-delimiter` | Normalized intervals/complements, byte/field modes, empty delimiter, overlaps, no LF |
| O1 uniq | `-D --all-repeated[=none,prepend,separate] --group[=separate,prepend,append,both]` | Singleton/repeated groups, separators, count/unique/repeated combinations |
| O1 comm | `--output-delimiter --total` | Suppressed columns, empty columns, duplicate equality, totals/tags, sorted diagnostics |
| O1 join | `-i/--ignore-case --header -o auto` | Original fields/keys, headers, duplicate-key Cartesian output, empty/unpaired fields |
| O1 wc | `--total=auto,always,only,never` | Single/multiple/stdin/error files, totals/name suppression and counting modes |
| O2 sort | `-s/--stable -m/--merge -o/--output -R/--random-sort/--sort=random --random-source` | Cached keys, stable versus whole-line fallback, unique selection, safe output and GNU random source |
| O3 seq | `-f/--format` | One supported float conversion, literal prefix/suffix, percent/width/precision, multiple conversions, -w, endpoints/rounding |
| O3 fmt | `-c/--crown-margin -t/--tagged-paragraph -p/--prefix` | Paragraphs/indent/prefix preservation and matching, short paragraphs/width/long words |
| O3 printf | `%a/%A %q` with existing width/precision/flags | Hex floats/quoting, negative zero/specials/rounding, missing/extra/repeated args, error prefix |
| O4 expand/unexpand | `/N` repeating and `+N` relative trailing tab stops | Increasing prefix, positive/zero/overflow, backspace/CR, initial/all whitespace modes |
| O5 split | `-n/--number` forms `N`, `K/N`, `l/N`, `l/K/N`, `r/N`, `r/K/N`; `-C/--line-bytes --filter --numeric-suffixes[=FROM] -x/--hex-suffixes[=FROM]`, applicable `-e/--elide-empty-files` | Selected chunk stdout, long/empty input, suffix growth/exhaustion/start, filter lifecycle/partial files |
| O6 csplit | `-b/--suffix-format --suppress-matched` | One integer conversion/%%/width/zero pad, invalid format, matched-line removal, negative offset/repeat/collision/cleanup |
| O6 rev/tac | Ordered multiple files; tac `-r/--regex` | No extra inter-file bytes, no LF/later failure, separator/before/empty/overlap matches |
| O7 od | Every frozen-oracle float representation/alias; `-S/--strings[=N]`, traditional offset/label | ABI width/endian/short element/repetition/radix/modern-option conflicts |
| O7 hexdump | `-e/-f`, explicit `-L/--color=always,never`, `_L` color units, forward stdin skip | Format/repetition/read count/address/final address/char/number/color ranges/multiple formats/empty |
| O7 cmp | `-b/--print-bytes` | First/verbose difference, octal/character, offsets/limits/EOF/binary |
| O7 strings | `-s/--output-separator` | Existing min/encoding/offset modes, empty separator, cross-block candidate/no final LF |
| O8 xxd | `-a -b -e -E -g -u -o`, relative/end-relative `-s`, reverse output-address adjustment, second output operand | Autoskip/case/group/endian/binary/EBCDIC/reverse conflicts, forward discard/backward seek, safe creation/overwrite |
| O9 cksum | `-a/--algorithm` sysv/bsd/crc/crc32b/md5/sha1/sha2/sha3/blake2b/sm3; `-l/--length --check`, modern tagged default, `--untagged --base64 --raw`, applicable manifest flags | Algorithm/length/output/check conflicts; SHA2/SHA3 224/256/384/512; positive byte-multiple BLAKE2b <=512 bits |
| O9 md5sum/sha1sum/sha256sum/sha512sum | Consistent `--tag`, tagged checking, manifest escaping, malformed/empty manifest behavior | Backslash/newline names, text/binary markers, existing quiet/status/warn/strict, read failure versus digest mismatch |
| O10 realpath | `-s/--strip/--no-symlinks`, lexical `-m`, `--relative-to --relative-base -q` | Roots/dot/dotdot/base/target/missing modes; lexical operations cannot fake physical links |
| O10 mktemp | `-p/--tmpdir -t --suffix`, GNU default template rules, `-q`; no `-u` | X position/count/path, environment/temp precedence, exclusive retry/mode and applicable quiet diagnostics |
| O10 mkdir | Symbolic `-m` | who/op/rwxXst/copied classes/comma/omitted-who umask, leaf versus -p parents, actual per-platform setters |
| O10 rm | `-i -I --interactive=never,once,always` | Repeated -f, recurse/count thresholds, refusal/EOF, per-item/once prompt ordering and explicit input channel |
| O11 ls | `-C -x -m -w/--width -T/--tabsize -b/-q/-N/-Q`, GNU C-locale quoting, `--color=always,never` | Row/column/comma layouts, post-quote display width, escaped names, explicit type/executable/extension color; no new auto detection or metadata long format |
| O12 tree | `-J -H BASE -T TITLE -P/-I --matchdirs --ignore-case --prune --filelimit --du -s/-h/--si -C/-n`, supported reporting | JSON/HTML escaping, filter/traverse/prune order, counts/ordinary-file bytes, base/title, structured-color conflicts |
| O13 env | `-S/--split-string` | GNU quote/escape/variable split, empty args/bad quote/escape, existing unset/chdir/exec; no host shell |
| O13 xargs | `-d/--delimiter`, supportable `-p/--interactive` | Byte/escape/NUL/EOF/empty args with -0/-n/-L/-I; prompts cannot consume argument stdin |
| O13 tail | `-z/--zero-terminated` | Counts/positive origin/empty/NUL/unterminated records/multiple-file headers |
| O13 tee | `--output-error=warn,warn-nopipe,exit,exit-nopipe -p` | Multi-sink continue/exit order, pipe/file classification, prefixes and aggregated errors |

Freeze GNU random-source consumption/hash/order/equal-key grouping/duplicates/
exhaustion; arbitrary shuffle/PRNG is insufficient. Register source identity,
read calls/bytes and error prefixes. Merge mode validates the existing key
order, not silently sorting invalid inputs.

Sort consumes/spools necessary inputs before opening output, including same-path
inputs. Implement safe new targets; refuse existing/hard-link alias operations
when identity/truncate/metadata public APIs are insufficient, rather than
replace an inode and claim GNU in-place writes. Apply the same xxd boundaries.

Seq/printf/od precision/representation/rounding follow frozen ABI. Use pure
MoonBit byte/BigInt conversions if Float64 is insufficient; numerical work is
not an API gap. Enumerate od width aliases machine-readably per profile; do
not invent uniform long double. Non-C locale is excluded.

Split filter uses current pure shell/process capability for user-requested
work, checking $FILE/stdin/status/EOF/wait/cleanup. Unsupported #31 syntax stays
explicit; no host shell fallback. Xargs -p needs a separate confirmation channel
from argument stdin; if absent, reject before reading/launching and name the
missing public API. Check rm's own oracle interaction source without guessed
terminal state. Forward hexdump/xxd stdin skip reads/discards; only backward or
end-relative positioning needs seekable input or declared spool. Use checked
offsets and preserve error prefixes.

Reuse suitable public incremental digest libraries; implement gaps in pure
MoonBit with independent standard vectors/padding/length/endian/chunk/GNU tests.
Do not invent legacy check support or new digest commands. Use real observable
directory type/size and explicit color input; do not fabricate inode sizes,
targets/owner/modes or zero for unknown ls metadata. Record exact readlink,
identity,setter,auto-terminal,process-observation/locale child conditions. Tee
is an API boundary only after proving inability to distinguish pipe/file errors.
Ls quoting covers literal, shell, shell-always, shell-escape,
shell-escape-always, c, escape, locale, clocale with environment/short-option
precedence. Locale styles are C-profile only. Disabled color removes all control
sequences; tree structured output follows oracle conflict rules and stays valid.

Every option includes canonical/alias/cluster/long=value where applicable,
missing/invalid/zero/negative/overflow and operands after `--`; conflicts/repeats/
ordering and valid combinations; empty/stdin/multifile/binary/no delimiter/later
failure/prefix/collision/permission cases; bytes/status/effects, Native/Wasm/pair
and applicable platforms. Update source/tests/README/help/catalog/support/ADR/
registry together, including shared existing behavior impact.

## 12. R: #32 streaming and resources

Define access pattern, necessary retained state, temporary disk, first output,
partial-error effects and cleanup before buffering changes. 64 KiB is I/O block
size, not an input cap. Splitting read_all into reads that still accumulate all
input does not establish streaming.

| Component | Algorithm/memory | Required checks |
| --- | --- | --- |
| LineScanner | Separate read/search/consume cursors, amortized compaction or chunk queue, O(bytes) scan | No refill prefix rescans/full-tail copies per record; view lifetimes |
| rev | Per-record, O(block + longest live record) additional memory | C-byte reversal, not Unicode; multifile/no delimiter |
| strings | Retain only candidate needed for minimum length; stream accepted continuation | Offset/separator/encoding/cross-block/error prefix |
| split | Stream byte/line; measure/spool total-dependent modes; bounded round-robin handles | Long lines, exact distribution, filters/FD/name/cleanup |
| csplit | Spool/lookback, paged offsets/index/cache for rescan/negative offsets | No all-line arrays; all-offset indexing is O(records), not bounded |
| tac fixed | Reverse blocks for seekable files, stdin spool, separator overlap plus largest record | Cross-block/start/end/before/binary |
| tac regex | Correct forward match/index/spool | Arbitrarily spanning separators, no fixed-overlap loss, empty progress/order |
| column | Width pass plus same-input-snapshot spool and second layout pass; indexed spool as needed | No rereading mutable input; row/index/huge cell costs |
| sort | 64 MiB explicitly accounted data budget, at most 16-way external merge | Record/key/offset/buffer accounting, stability, rounds/oversize record |
| diff | D-stage O(N+M) auxiliary space | Inputs/keys/results separate, not constant memory |
| gzip/gunzip/zcat | G-stage incremental codec | No delayed incremental-decoder promise |

Sort computes keys once and assigns stable sequence IDs. Generate stable runs
and use up to 16-way heap merge; -m shares it. Preserve cross-run stability,
unique representative, terminators, applicable headers, random keys and error
order. Implement `-S/--buffer-size -T/--temporary-directory --batch-size` with
GNU numbers/units/conflicts. The 64 MiB budget accounts explicit records/keys/
offsets/merge buffers; measure runtime overhead separately rather than claiming
an RSS cap. Process/measure oversize individual records without silent truncation
or rejection of previously supported input. Begin with maintainable stable
algorithms/heap; reuse suitable measured adaptive sort, and introduce radix/
loser-tree complexity only for proven benefit. Never truncate input early.

Every invocation owns exclusively created restrictive temp files/directories
and cleanup scopes for normal/error/observable cancel. Random names alone do
not prove exclusivity. Never delete unowned files. Inject open/read/write/temp,
observable ENOSPC, closed-output, corrupt/unreadable run, later-input and cancel
failures. Record committed/retained/deleted outputs rather than exit alone.
No unconditional cleanup promise for SIGKILL/crash/missing recoverable signal
API. Any recovery feature is separate. Report file/handle/child/filter/index/
temporary-disk peaks.

Verify 8/64/512 MiB and independent long-record bytes/status/effects/first-output/
time/RSS/explicit memory/temp disk. Use checked 64-bit logical byte/record/file
offsets where required and allocation-bounded indexes; check add/multiply/
conversions/normalization. Add near-2/4-GiB arithmetic and sparse seek without
huge in-memory fixtures. Existing numeric/parser bounds remain explicit.

R1 scanner/rev/strings/split: small/long growth, prefixes and consumers. R2
csplit/tac/column spool/index: stable snapshot, reverse/regex/temp cleanup. R3
sort runs/merge/controls: budget, stable/unique/random, safe output/errors. R4
joint resources/cancel/large input: full sizes, actual platform boundaries and
no unexplained regressions.

## 13. Complete 79-command and 12-core review register

Each row needs owning stage, source hotspot review, normal/small/error inputs,
applicable scaling, Native/Wasm development data and final real MoonX data.
Allowed dispositions are optimized with evidence; already satisfactory with
evidence; explicit capability boundary; failed performance target. The latter
two are not performance passes. Source plus measurement must justify no change.
The directions below supplement, never replace, full registry/policy/prefix/
platform obligations. Full review follows the relevant feature stages.

| Command | Stage | Review and workload emphasis |
| --- | --- | --- |
| base32 | Full review | Block transforms/lookup/reused output; padding/wrap/invalid-ignore/cross-block/binary sizes |
| base64 | Full review | Block/classification tables; padding/newlines/corrupt prefix/block tails |
| basename | Full review | Path slices/suffix/startup; root/slashes/multiple operands/1 B and 4 KiB names |
| cat | Full review | 64 KiB copy/selective formatting; numbering/display/pipe close/later file failure |
| chmod | Full review | Compile symbolic mode once; host refusal/link/no damage/wide trees |
| cksum | O9/full | Hash blocks/schedules/manifests; every algorithm/length/tag/check/hardware/long input |
| cmp | O7/full | Chunk equality/first difference/lazy format; start/middle/end/EOF/display/offset/limit |
| column | R2 | Two-pass spool/width/layout; grid/table/wide/many columns/single snapshot/temp disk |
| comm | O1 | Dual-stream merge/record reuse; duplicates/columns/totals/delimiters/sorted errors |
| cp | Full review | Copy buffer/scoped metadata; identity/link/policy/partial writes/recovery/size scaling |
| csplit | O6/R2 | Regex reuse/paged indexes/lookback; repeats/negative offsets/suffix/suppress/cleanup |
| curl | Full review | HTTP parser/sinks/headers/cookies; stage-0 error precedence/prefix/files/zero-body/throughput |
| cut | O1 | Normalized intervals/single pass/batched delimiters; complement/empty/unseparated/long records |
| date | Full review | Parse/format/TZ lookup; TZ/TZDIR/boundary times/formats/errors/startup |
| diff | D1-D2 | Cached keys/linear-space reconstruction; ties/hunks/directories/edit density/repetition |
| dirname | Full review | Boundary indexes/no fragmented arrays; roots/slashes/multifile/C-byte names |
| echo | Full review | Direct argv/selective escapes; option rules/no newline/startup |
| env | O13/full | Environment overlay/one split; empty/unset/escapes/argv/status/minimal child |
| expand | O4 | Tab cursor/batched spaces; /N/+N/CR/backspace/long mixed input |
| expr | S1 | Shared matcher/lazy captures/numbers; precedence/numeric strings/captures/exit/errors |
| false | Full review | Minimal initialization; correct exit/standalone metadata/real startup |
| find | Full review | Iterative traversal/short circuit/lazy metadata; deep/wide/order/actions/link boundaries |
| fmt | O3 | Word spans/one width pass; crown/tag/prefix/long words/empty/large paragraphs |
| fold | Full review | Incremental columns/output; byte/width/space/tab/backspace/no LF |
| grep | Full/S1 reuse | Literal/prefix/compile once/fewer captures; flags/multiple/empty/exit/long lines |
| gunzip | G2 | Reader/table/window; CRC/ISIZE/members/corrupt prefixes/long output |
| gzip | G1-G2 | LZ77/dynamic/cost; levels/window/speed/size/memory |
| head | Full review | Locate end within chunks/minimal reads; bytes/records/negative counts/pipes/multifile |
| hexdump | O7 | Compile format/block layout/buffers; custom/color/stdin skip/empty oracle/tails |
| join | O1 | Dual key scan/necessary equal groups; case/header/auto/Cartesian/long repeated keys |
| jq | Full review | Parse/lower once/reduce JSON intermediates; current moonjq/numbers/order/errors/nesting |
| jqlog | Full review | Record JSON framing/field/output buffers; malformed/partial/current formats/long logs/prefix |
| ln | Full review | Path/state reuse; link type/existing target/platform/API/no damage |
| ls | O11 | One collection/sort/lazy metadata/quoting; layout/color/width/names/1/1k/100k entries |
| make | Full review | Existing AST/graph/ready queue/env; jobs/failure/shared deps without language additions |
| md5sum | O9/full | Blocks/schedule/check manifests; tagged/escaped names/padding/long/many small files |
| mkdir | O10 | Symbolic mode/path layers; umask/parents/leaf/existing/partial failure |
| mktemp | O10 | Parse/retry; exclusive creation/suffix/tmpdir/quiet/collision/startup |
| mv | Full review | Same-volume/fallback state; Windows symlink/junction/-n/-T/backup/recovery |
| nl | Full review | Classify once/reuse numeric format; sections/blank groups/overflow/long lines |
| od | O7 | Compile format/types/block decode; ABI/offset/label/strings/tails/repeats |
| paste | Full review | Multi-stream/delimiter cursors; serial/parallel/empty/NUL/FD counts |
| patch | D3 | Hunk index/candidate pruning/results; offset/fuzz/reject/mixed/dry-run/later hunk |
| printenv | Full review | Selective lookup/no whole copy; missing/multiple/NUL/output/status |
| printf | O3 | Format IR/integer fast path/exact floats; hex/quote/flags/repeat/error prefixes |
| pwd | Full review | Necessary paths/minimal startup; logical/physical/current boundary/env |
| realpath | O10 | Segment stack/relative computation; -m/-s/base/missing physical API/no fake links |
| rev | O6/R1 | Incremental C-byte records/reuse; multifile/NUL/invalid UTF-8/no LF/64 MiB line |
| rm | O10 | Iterative traversal/lazy state; prompt-force order/EOF/recurse/no damage |
| rmdir | Full review | Parent cursor/lazy query; empty/nonempty/parents/later failure/depth |
| sed | S1-S3 | Compile/PC/spaces; hold/branch/group/cycle/order/long/backrefs |
| seq | O3 | Checked integer/exact-format fallback; endpoints/steps/rounding/-f/-w/long output |
| sh | Full review | Current lexer/AST/expansion/session; quote/argv/pipes/lifecycle/errors, no #31 additions |
| sha1sum | O9/full | Reuse block/schedule/manifests; vectors/padding/tag/small/large/throughput |
| sha256sum | O9/full | Dependency/adapter copying; vectors/chunk equivalence/upstream acceleration |
| sha512sum | O9/full | 64-bit state/hot loops; lengths/padding/endian/tag/check/long input |
| sleep | Full review | Parse/deadline/wait; fixed-delay lateness/CPU/errors/cancel |
| sort | O2/R3 | Cached keys/stable runs/16-way; source/output safety/unique/random/multiple rounds |
| split | O5/R1 | Stream/measure/spool/bounded outputs; all chunks/long records/suffix/partial/FD/filter |
| strings | O7/R1 | Minimal candidate/direct continuation; separator/offset/encoding/cross-block/long span |
| tac | O6/R2 | Reverse blocks or forward regex index/spool; before/separator/stdin/multifile/no LF |
| tail | O13/full | Record ring/reverse file/-z; origins/short tail/stdin/files |
| tee | O13/full | Shared read/per-sink state; four modes/pipe/file/prefix/continuation |
| test | Full review | Short circuit/number/path reuse; argc/precedence/errors/fs boundary/startup |
| timeout | Full review | Deadline/child state; local-only/status/cancel/direct-child boundary/MoonX N/A |
| touch | Full review | Argument batching/query/path; timestamp/create API/existing-file no damage |
| tr | Full review | Byte translation/classes/state; squeeze/delete/complement/NUL/duplicates/throughput |
| tree | O12 | Iterative filter/postorder totals/render; JSON/HTML/prune/du/names/deep/wide |
| true | Full review | Minimal entry/no unrelated catalog/env; exit/help/version/startup floor |
| unexpand | O4 | Space run/tab cursor; first/all//N/+N/backspace/CR/mixed tabs |
| uniq | O1 | Adjacent key/record reuse/group state; repeats/group/count/separator/long groups |
| unlink | Full review | Minimal path/error conversion; operand/directory/link/permission/no damage/startup |
| wc | O1 | Single-pass/selective counts; totals/binary/long records/current counting modes |
| wget | Full review | Response/sink/retry/resume; GNU truncated-success boundary/requests/Range/prefix/files |
| which | Full review | PATH split/candidate reuse; empty/duplicate items/executable/platform/multiple names |
| xargs | O13/full | Delimiter/batching/launch; -d/-p/empty/ARG boundary/failures/same fixture child |
| xxd | O8 | Lookup/format/seek/spool; reverse/offset/endian/second output/conflicts |
| yes | Full review | Prebuilt repeat blocks/batch writes; fixed consumer/close/prefix/first output/throughput |
| zcat | G2 | Incremental codec/operand envelopes; members/files/corrupt prefix/status/throughput |

| Core | Review and proof obligations |
| --- | --- |
| cli | Lookup/repeated occurrences/catalog/startup; short/long argv and option counts without expensive universal maps/catalogs or changed error order |
| stream | Scanner/refill/copy/write/ownership; amortized copies/cursors/long records/segmented input/all consumer closure |
| bytere | Compile/find/capture and literal/regular/backref paths; separate compile/scan, POSIX/C-byte semantics and explicit exponential paths |
| gzipops | LZ77/Huffman/CRC/envelope/Reader; three consumers/block/member/size/speed/space |
| checksum | Blocks/schedules/manifests/tags/escaping; vectors/chunks/algorithms/lengths/public adapter cost |
| fsops | Paths/copy/traverse/metadata/recovery; valid query reuse without removed policy/identity/preflight checks |
| netops | Framing/parser/sinks/headers/cookies/redirect/retry; stage-0 wire/prefix/Range/zero-body/error precedence |
| process | Env/argv/start/tasks/status; isolate child work, queues/cancel/direct child versus process tree |
| shell | Current lexer/parser/expansion/AST/session; invocation reuse invalidated by session changes; no language expansion |
| jq_filter | Parse/lower/intermediates/moonjq adapters; numbers/order/errors/prefix and current support boundary |
| time_zone | TZif/POSIX parse/transition binary search/invocation cache; TZ/TZDIR/session invalidation/time edges/formats |
| platform | Backend/capability/startup; real Windows link effects/conservative rejection/public API limits |

Core microbenchmarks compare the same operation against rebuilt same-toolchain
core; integrated commands demonstrate user-visible value. Unrelated C
microbenchmarks/FFI wrappers are not equivalent core implementations. Inspect
profiles/generated code to distinguish algorithm, adapter, compiler and runtime.

## 14. Correctness, compatibility and synchronized records

Package invariants do not replace CLI bytes/effects; contracts do not establish
upstream agreement; scenarios do not cover every option; nonzero exit does not
prove no filesystem/network/process damage; rejection does not implement a
capability; actual Native/Wasm pair does not imply GNU parity; floating PATH
tools/availability do not establish immutable differential; source/moonrun does
not establish exact published behavior; timing does not establish correctness
or an untested platform. Preserve pass/fail/skip/infra separately from semantic/
availability/boundary evidence. Counts and percentages do not prove original
acceptance completeness.

Every feature PR synchronizes implementation and relevant package/contract/
scenario/policy/platform tests; README/help/catalog/compatibility; the relevant
canonical ADR Updated date, tradeoff/evidence/unlock; stable registry ownership,
consumer/fixture/backend/oracle/observations; fresh full-range intent and
benchmark behavior links; and versions/dependencies/support plus candidate
metadata when changed. ADR owners are 0001 evidence, 0002 policy, 0003 streams,
0004 filesystem, 0005 transfer, 0006 process, 0007 language, 0008 data, 0009
safety. Do not create competing decisions or leave current limits only in chat.

Standalone version is exactly `<command> <package-version>\n`; help starts
`Usage: <command>`, includes help/version, ends in newline. Both stdout/status 0,
no stdin consumption. Keep workspace and frozen published expectations separate.
Retain this run's source/artifact/oracle/profile/run/attempt and failures; do
not add historical backfill/old-image restoration/GitHub Release archives as
test-maintenance scope.

Keep stage-0 exact GNU transfer behavior, including Wget's applicable chunk/
trailer truncation success and curl simultaneous interruption/output-error
priority. Regress curl connection/header/body classes, short length/chunks/
zero terminator/trailer/zero body, complete/close-delimited/HEAD/204/304, prefix/
partial file/remove-on-error/-OJ/output failures; wget stdout/-O/default/-c,
fail-then-success requests/Range/final bytes/no duplicates or extra files;
Windows mv file/directory/dangling links/junctions, same-volume -T/replacement/
-n/backup/recovery with entries/targets/referents/Native/Wasm moonrun. Preserve
safe conservative rejection if host defects persist; optimization cannot remove
the checks that prevent damage.

## 15. Existing push and merge gates

Reuse C1's prepare, verify, audit and push entrypoints. C2's handoff and AGENTS
migration are removed. Apply the existing rules to the actual change: harness
changes require their registered regression evidence; command behavior changes
require the existing command-by-command coverage audit. PR, actual-main and
release acceptance retain the full three-platform checks and coverage-audit.
Pending checks stay pending. Do not add duplicate evidence systems or rerun
unchanged checks without a new reason.

For this comprehensive B2/G/S/D/O/R round, the user's 2026-10-24 authorization
permits new and corrective PR branch pushes once relevant local correctness
passes and the existing C1 prepare/verify and coverage audit run. Preserve
nonzero findings for missing exact-revision or remote evidence as pending;
do not manufacture a passing audit. A non-force direct Git push may bootstrap
CI when the existing push launcher stops on those findings. Authorization
continues across corrective commits without per-SHA confirmation; local
correctness and scope defects still require repair. All three platform checks
and coverage-audit must pass before merge, then validate actual main. This
round-specific exception does not change the original per-row MoonX
performance, resource, RC, publication or completion gates.

Daily sequence: existing PATH and `MOON_HOME="$HOME/.moon-accounts/cli"`; freeze
the PR's behaviors/options/conflicts/cases/workloads; implement/relevant serial
check/test/build; finally info/fmt and review generated diffs; rerun checks only
for actual new impact; staged prepare/review scope; commit,
verify/audit/wrapper push; PR checks/merge/new actual-main evidence; report stage
as merged pending combined publication and keep issue open.

## 16. Order and stage exits

```text
C0 main/evidence and workspace preservation
 -> accepted C1 baseline (C2 removed; retain full daily CI)
 -> C3/C4 execution/build reuse/cache/artifacts/timing
 -> B1/B2 benchmark/oracle/corpus/startup floor
 -> G1/G2 -> S1/S2/S3 -> D1/D2/D3 -> O1..O13 -> R1..R4
 -> remaining 79-command/12-core review and integrated optimization
 -> source freeze/full actual-main checks/RC publication
 -> real RC MoonX semantics and macOS/Linux performance
 -> formal publication/exact formal MoonX acceptance
 -> release-record PR/actual-main validation/ordered issue closure
```

B1 supplies sampling/statistics/streaming observations; B2 seals profiles/corpus/
oracle and current-package/same-toolchain source baseline. Lightweight startup
probes may accompany CI preparation; formal feature order stays fixed. Keep
CI and benchmark prerequisite PRs separate from gzip algorithms.

Preparation exits only with main failure handled, pinned identities, trustworthy
scope/harness, inventory and first floor. Each feature exits with implementation,
package/CLI/effect/policy/pair/oracle, synchronized records, development resource/
timing and fresh scope. Each G/S/D/O/R stage finishes all selected implementable
algorithms/options plus explicit legitimate child boundaries before advancing.
Full review exits with measured disposition on all 91 rows and no unexplained
semantic/resource regression. RC and formal exits require their exact artifacts
and applicable matrices; closure requires complete original-bullet mapping.

Already-implemented options retain code and fill evidence gaps. Fixed GNU wins
over intuition/old goldens while historical records stay intact. Choose the
simplest correct maintainable algorithm, then profile. Public-API gaps require
minimal reproduction, precise capability/scenes, no-side-effect rejection,
ADR/support and child/unlock. Missing Windows observations stay incomplete.
Unknown shared impact becomes full. Revert changes whose complexity exceeds
unproven benefit. Startup/hardware threshold failure blocks formal acceptance;
unstable environment remains infra/noisy. New options outside this plan are
explicit later work, not scope creep.

Estimate from measured preparation costs and frozen workload counts, not an
invented completion date. Each update reports completed work, current blocker,
next item and evidence. No unchanged reruns/reports. Prepare reproducible,
reviewable material before necessary decisions; execute already-decided details.

## 17. Combined RC, formal publication and exact consumers

Do not republish stage-0 core/curl/mv/wget merely because this plan exists.
Compute release closure from actual API/source/dependency-resolution/support
changes and frozen published coordinates. The 75 pending async candidates count
as dependency changes, so most/all commands may change; verify each module.
Unchanged packages retain their coordinates; core releases only for real shared
behavior/API changes. Timeout stays absent.

At freeze query unused registry versions. Feature additions normally take next
minor, preserving optimization/dependency fixes an appropriate patch, added core
API normally next minor; breaking changes need explicit migration. Synchronize
module/runtime/README/help/version/candidate/active/compatibility/regressions.
First verify actual registry/resolver support for semver `-rc.N` and exact RC
core dependencies. If unsupported, record blockage; do not disguise scripts/local
modules as RC consumers or publish formal versions around the gate.

Freeze complete scope/91 reviews and actual integrated-source full three-platform
coverage. Run full current-published baseline before release. Source-gate run
must be exact/full/success, not collected feature heads. Verify candidate,
account with prefixed moon whoami and unused coordinates; freeze benchmark
rows/profile/corpus/thresholds before RC results. Commit/review/controlled push,
PR and actual final-main full gate precede release from a clean exact revision.

All Moon/MoonX operations inherit `MOON_HOME="$HOME/.moon-accounts/cli"` and
current PATH. Upload changed core first, then changed commands lexically and
serially. Each needs `Server status: 200 OK`, verified exact registry version,
archive identity and resolution before proceeding. Unknown network outcome
requires querying that same coordinate before retry/new number. Never overwrite
immutable versions or continue while core is unresolved. Failed RCs remain;
repairs use new -rc.N.

RCs are `<final-version>-rc.N`; pin changed commands to the exact corresponding
core RC and verify resolver selected it rather than workspace/foreign cache.
Prepare consumer caches, then execute actual exact coordinates under verified
MoonX argument rules. Require metadata/smoke/contracts/applicable immutable
differential/effects; full fixed-host delivery 105-pair/1.5x/confidence-interval/resources; Windows
consumer semantics/permissions without performance claims; source/artifact/
dependency/environment correspondence. Rebuild/republish/revalidate real shared
consumer closure after RC core changes, not mechanical all-package increments
or omitted implicit consumers.

Only after every RC gate passes select unused formal coordinates, change versions/
dependencies/metadata/manifests, obtain corresponding PR and real-main full gate,
then upload. Version-only changes may alter artifacts. Repeat exact formal
semantics/differential/full delivery benchmarks, including version-sensitive
startup, emitted versions/archive/dependencies/warm/first-use. Preserve unchanged
coordinates and validate relevant cross-consumers. Formal acceptance failures
remain recorded; immutable uploaded facts differ from accepted delivery. Repair
at new versions and do not close issues. Update current manifest/report with
accepted coordinates only, pass their PR and final-main checks. Report source/
main/full/oracle/RC/formal receipts/consumer/per-row timing and residual limits.

## 18. Original acceptance mapping, closure and completion

Assign stable IDs to every original issue bullet and map implementation/tests/
profile/package or a fully responsible child. Children retain exact original
condition, unfinished observable behavior, classification, missing API/unverified
platform, minimal reproduction, current rejection and unlock, linked back to
parent. API metadata/readlink/identity/input limitations and excluded extensions
may transfer precisely. Unverified required Windows acceptance still blocks its
claim. Selected algorithms/options and failed performance cannot be transferred
away to manufacture completion; tracking issues leave formal gate blocked.

After formal exact consumers and final-main acceptance close #27 -> #28 -> #30
-> #33 -> #32, in English, including implementation/original mappings/exact
CI/profile/package/performance applicability/remaining children/unlocks. Do not
close on stage merge, automatically close #10/#20/#38, begin #35 or imply another
round after this finish.

Deliver canonical current plan/status; fixed scope/freshness/association and
harness tests; same-coverage cold/warm CI cost evidence; exact option/conflict
matrix; 79/12 source/hotspot/baseline/candidate/time/memory/complexity/disposition;
sealed host/VM/tools/oracle/corpus/held-out; raw pairs/statistics/per-row gate/
noisy/fail/inconclusive/resources/floor; current package/CLI/scenario/policy/
pair/upstream/published/platform/rejection audit; candidate/RC/formal manifests,
account-check record without secrets, upload/registry/consumer evidence; original
issue/child mapping; and concise final report with exact coordinates, residual
local work and no implicit follow-on task.

Completion requires all of the following together:

- Scope/freshness/reuse regressions pass, mandatory platforms/audit cannot be
  skipped green, and current daily/release full execution remains intact.
- All selected #27/#28/#30/#33/#32 algorithms/options finish in order.
- Gzip incremental decode, diff linear space and resource/failure contracts
  have measured evidence.
- Every command/core row has actual review and measurement; timeout is local.
- Relevant correctness/upstream/backends/policy/platform/effects are proven.
- Every applicable exact MoonX row passes fixed macOS/Linux hard limits without
  concealed failures or averaging.
- Necessary RC and formal uploads/consumers complete; current manifest and true
  main evidence agree.
- Every original issue condition is handled with only legitimate precise child
  boundaries; selected algorithm/performance failures are not false completion.
- User receives reproducible coordinates/reports/residuals; excluded work did not
  begin and no unrequested continuation is assumed.

## 19. Execution entry and references

Read plan/current rules, verify source/dirty/main/published baseline; preserve
interfaces/old draft; resume accepted C1 with C2 removed; finish
C3/C4 with equivalent-set comparison; finish B1/B2 and disclose real startup/algorithm
risks; proceed G/S/D/O/R/full review/RC/formal/closure. Planned paths/subcommands
become executable instructions only after implementation/verification. C/G/S/D/
O/R labels are work packages, not existing GitHub PR numbers.

Relevant repository sources are [coverage](../tests/coverage/README.md),
[registry](../tests/registry/README.md),
[release runner](../tests/release_runner/README.md),
[ADRs](adr/README.md), [compatibility](compatibility.md),
[stage-0 release](reports/2026-10-20-stage0-release/README.md), command READMEs,
core/stream, core/bytere, core/gzipops and commands/diff/compare.mbt. Original
issues are [#27](https://github.com/moonbit-community/cmd/issues/27),
[#28](https://github.com/moonbit-community/cmd/issues/28),
[#30](https://github.com/moonbit-community/cmd/issues/30),
[#33](https://github.com/moonbit-community/cmd/issues/33),
[#32](https://github.com/moonbit-community/cmd/issues/32), plus the scope/boundary
trackers named above. The attached Chinese source supplies the detailed
historical timing/decision rationale; this repository plan keeps its acceptance
contracts and never promotes an intended state into measured completion.

## Appendix A. Preserved future work outside this round

This appendix preserves requirements from the predecessor proposals; it adds
neither an implementation stage nor a completion gate to this round. Do not
automatically start #35 after #32 and combined acceptance. Future authorization
must recheck public APIs, registry and oracle and establish a separate plan.

### A.1 Deferred #35 awk proposal

The future proposal is a practical C-byte POSIX-style interpreter: program
arguments/multiple `-f`, `-F/-v`, multiple files, field assignment,
FS/OFS/RS/ORS/NR/FNR/NF; BEGIN/END, range patterns, expressions, control flow,
associative arrays, user functions/recursion; print/printf, common string/math
builtins, ordinary getline, file redirection and close. Initial RS modes are
single-byte and paragraph.

Future fixed gawk POSIX/C-profile tests cover numeric strings, field coupling,
command-line assignment order, empty matches, function scope/parameters and file
effects. System commands, pipes, gawk extensions, non-C locale and RNG extensions
remain separate child work. None is implemented or promised for publication
by this execution plan.

### A.2 Deferred #35 tar/zip/unzip proposal

The future ordinary-file/directory subset comprises USTAR tar creation/listing/
disk extraction/stdout extraction reusing gzip, and ZIP32 stored/DEFLATE
creation/listing/checking/extraction for zip/unzip. Creation explicitly requires
the project extension `--metadata=normalized`; disk extraction explicitly
requires `--metadata=none`. Listing/stdout extraction do not need that option.
Never silently discard metadata by default.

An initial implementation writes only new archives and absent destination
entries, rejecting overwrite/update/append, archive links/special items, path
escape, encryption and unsupported formats. Path-content source handling does
not claim complete hard-link identification; extraction does not restore
owner/time/ACL/xattr. PAX, ZIP64, links and metadata fidelity retain complete
child conditions. All four future commands use independent `cli/<cmd>` modules
and root `main.mbt`, normally an unused 0.1.0 unless explicitly selected
otherwise. This round neither reserves nor publishes those coordinates.

### A.3 Other preserved boundaries

New #31 shell/make language, extra #34 network/JSON, readlink/identity/metadata
setters, automatic terminal detection, process observation and non-C locale
remain explicit future boundaries. Existing related implementations still enter
this round's algorithm review. Stage-0 dependency/publication work is not
repeated, while its network/Windows regressions continue to guard optimization.
