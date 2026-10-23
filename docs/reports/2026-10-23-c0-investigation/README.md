# C0 oracle timeout and container lifecycle investigation

Date: 2026-10-23 (Asia/Shanghai).

Status at submission: the independent container-cleanup repair and local
development validation are complete; required exact-commit audit, PR and
actual-main acceptance remain pending. This is not C0 or release completion.

## Scope and preserved starting state

The authorized execution plan is the user's
`cmd-comprehensive-optimization-plan-2026-10-23.md`, SHA-256
`9c39170fdf528302e2c05c16ed782072aaf8aafb2bae4eb284276293f9cf6723`.
Its first gate is recovery of current-main evidence and investigation of the
`hexdump-empty` Linux oracle timeout. Functional stages and CI scope activation
remain pending.

The verified repository is `moonbit-community/cmd`, main commit
`5fef93ecec8cebeb7b4f9bdd479e8f3619d12513`. The starting checkout contained
13 modified generated interfaces and an untracked 666-line
`docs/algorithm-performance-plan.md`. Their original patch and file were
preserved in ignored `test-reports/2026-10-23-comprehensive/c0/`; none was
discarded. The interface differences are 51 substitutions of `Int` with
`Int32`, without added or removed declarations. This is consistent with
generator normalization; Git does not establish who generated them.
The testkit normalization was isolated in an independent generated-only
commit after reproducing it with the current `moon info`. Its spelling-only
changes are superseded by CI's pinned generator output described below. The
original checkout's complete starting patch and old draft were restored and
verified byte-for-byte; the other 12 interface files stay outside C0.

The current local toolchain is moon/moonrun `0.1.20261021 (a4f8933)` and
moonc `v0.10.17+093cb8f9c`, using the current PATH and the required
`MOON_HOME="$HOME/.moon-accounts/cli"` account. It differs from the plan's
October 20 toolchain, so later algorithm comparisons must rebuild both source
baselines with the same selected toolchain.

Inventory confirms 79 commands, 12 core packages, and 78 published command
coordinates. Core remains `cli/core@0.7.0`; curl/mv/wget remain `0.2.3`.
No package was published or version changed during this investigation.

## Historical failure and later regression evidence

[Push run 39438523360, attempt 1](https://github.com/moonbit-community/cmd/actions/runs/39438523360)
ran the exact main commit above. Its Native oracle row reported
`hexdump-empty` as infrastructure failure after 120084 ms:
`oracle-timeout: partial streams retained`. Candidate and oracle stdout/stderr
files for that case are all empty. The fixture is `hexdump -C`, empty stdin,
no files, empty expected streams, and status 0. The command backend pair
passed; the subsequent Wasm oracle comparison passed in 233 ms. The failed
Linux job correctly prevented the required coverage audit from succeeding.

[Scheduled run 39748584464](https://github.com/moonbit-community/cmd/actions/runs/39748584464)
later passed all three platforms on the same source SHA. Native and Wasm
`hexdump-empty` oracle rows passed in 222 and 225 ms. Its Linux run used the
same immutable oracle image, Docker 28.0.4, moon `0.1.20261012`, and moonc
`v0.10.15+943464bfa` as the failed run, but a different hosted Linux kernel.
Its audit explicitly records `not-applicable` for change coverage because it
is a scheduled regression run. That result is full regression evidence, not
a replacement for the failed push's change-range audit.

The historical oracle image ID is
`sha256:f82510ba6c5c5ff537008d5b9dbbf7799515b226e7c75493b79fe7e9cb56f8c2`.
The original logs, failed row, four stream files, run metadata, profile and
tool inventory were retained before requesting attempt 2 of the original
push run. That rerun changes neither source nor timeouts and remains a
separate attempt; it cannot erase attempt 1 or identify its root cause.

## Local EOF and cancellation observations

Inspection of released async 0.22.5 shows that an empty `Writer.write`
returns immediately, closing the process writer synchronously closes the
descriptor, and spawned pipe descriptors are close-on-exec. The shared
deadline helper defers closing the input writer. These observations do not
prove delivery of EOF inside the historical failed container.

Two existing deadline/cancellation tests passed. A diagnostic using the actual
shared helper passed 64 `/bin/cat` invocations: 32 empty EOF cases and 32
binary controls, with eight concurrent workers. Every invocation returned
exact expected bytes, status 0, and no timeout or cleanup error.

The existing `cmd-oracle` Colima VM was started with 4 CPUs, 8 GiB RAM, and
an arm64 guest. Its 40 GiB data disk had 36 GiB free, below the plan's initial
40 GiB-free performance-host target. The only existing oracle image is
Linux **amd64**, ID
`sha256:05e320ad56f11fc1207b0946b414468b90fc0c8bf8e65d32eb2ba48f682589b7`.
It runs through emulation and is a different identity from the historical
oracle. It can diagnose container lifecycle, but establishes neither exact
historical reproduction nor native-arm64 performance acceptance. Docker's
global context remained `default`; diagnostics selected `colima-cmd-oracle`
explicitly.

On that diagnostic image, 12 empty and 12 binary `hexdump -C` invocations
through the actual helper passed, including serial and four-worker execution.
Elapsed times were approximately 99--197 ms. The historical empty-input
timeout was not reproduced.

A separate deterministic cancellation control **did reproduce a cleanup
defect**. The actual helper ran an exclusively named and labelled
`docker run --rm -i ... sleep 60` with a 3000 ms deadline. It returned at
3005 ms with status -9, `timed_out=true`, and `cleanup_error=null`.
An immediate Docker inspect showed `Running=true` and PID 3700. Reaping the
direct Docker CLI process therefore did not establish container cleanup.
The diagnostic then removed only its owned container and verified its
absence, including a label-filtered inventory.

This establishes an oracle container ownership/cleanup defect. It does not
establish that an orphan or a lost EOF caused the historical hexdump timeout.
The generic deadline helper already documents its direct-child boundary;
the repair belongs in the Docker oracle execution layer.

## Repair and local development validation

The shared `run_oracle_with_deadline` adapter reserves an invocation-specific
directory, Docker name and ownership label. Workspace command differential,
published command differential and their shared network scenario executor
use that adapter. Normal status-0 `docker run --rm` completion avoids extra
Docker subprocesses. Abnormal execution retains daemon state, checks full
container ID/name/label before exact-ID removal, and verifies absence by ID
and ownership. Ordinary automatic-removal races require independent absence
observations. Unavailable controls, delayed creation without an observed
identity, ownership mismatch and lost lifecycle evidence remain infrastructure
errors, with the ownership reservation retained. Evidence-sink failures do
not prevent the cleanup attempt or erase an observed command status/streams.

Twelve registered tests exercise the normal fast path, timeout cleanup,
identity/name/label mismatch, control/removal/absence failures, startup
exceptions, outer cancellation, completed abnormal exits, ownership-option
overrides, unresolved interrupted creation, automatic-removal races,
unavailable evidence storage and concurrent invocation isolation. Their
daemon responses are injected in pure MoonBit and are not live Docker
compatibility evidence. Registry inventory is now 1660 behaviors; an increased
count is not coverage-completeness evidence.

All-target `moon check --target all --deny-warn` passed. The relevant Native
testkit, runner, release-runner and network-scenario suites passed **168/168**
after registry refresh and execution with loopback access. The earlier
sandbox run's nine failures were retained: three rejected the then-unregistered
new tests and six could not create loopback fixtures. The assertions were
unchanged. Selective `moon info tests/testkit` and formatting were completed;
the only added public testkit declaration is the new oracle adapter.

The live after-repair diagnostic uses the same emulated diagnostic image
described above. Both its deadline and outer-cancellation controls first
observed the owned container as `Running=true`, then verified it absent after
protected wrapper return. Empty-input hexdump also passed. The final owner-label
inventory contained no containers. Evidence is retained in
`_build/verification/2026-10-23-c0/owned-results-1792717010654/` and
`launcher-after.stdout.txt`. These are development observations, not final
three-platform acceptance or native-arm64 performance measurements.

The verified helper SHA-256 is
`35b6e1a4b4a3babb028ea512cffd6fd8db2f4ce243e6347ab9cbb466dc2bfd21`;
its regression source SHA-256 is
`fd78b90431bd0524d200e1833c04ab770771c2354a4574804691b09e964149d7`.

## Main restoration and PR validation corrections

The original actual-main push run's attempt 2 completed successfully. Its
audit reports `passed`, no findings, and the exact change range
`7829269d1a3b751768e6f64a0d305cd76282ee02` to
`5fef93ecec8cebeb7b4f9bdd479e8f3619d12513`. Native/Wasm hexdump-empty
passed in 264/304 ms against the same sealed `f82510ba...` image. The retry
host's kernel also matches the failed attempt. This restores mainline
acceptance evidence without establishing why the earlier invocation timed out.
The original failure remains retained. It is separate from acceptance of
[the C0 repair PR #42](https://github.com/moonbit-community/cmd/pull/42).

The PR's first Windows package run exposed a test prerequisite error: the
outer-cancellation regression started a 100 ms timeout before asynchronous
filesystem setup and then required a simulated removal. Cancellation before
the fake run starts does not require removal of a nonexistent container.
The revised test acknowledges fake execution through a queue, cancels that
task explicitly, joins its protected cleanup, and still requires removal and
absence. A deliberate 150 ms startup delay exercises the old timing
assumption. All 12 owned-oracle tests pass locally after this correction;
Windows revalidation remains a required gate. The raw failed Windows log is
retained rather than changing the assertion or the oracle deadline.

An isolated credentials-free Linux rehearsal used the exact CI toolchain,
moonc `v0.10.15+943464bfa`, and its matching bundled core. Full `moon info`,
the CI harness formatting commands and all 10 automation-format checks passed.
Only the testkit interface differed: this generator emits `Int`, whereas the
current host generator emits the equivalent `Int32` spelling. The tracked
file uses that actual CI-generated output, SHA-256
`921175d297d5607c53005d038177b685dc320879eda3dc421aea58326bfcede1`.
It was not manually edited, and the workflow/toolchain pins were unchanged.
The rehearsal at `a60e427` preceded the test synchronization correction;
that correction changes no public API. Official archive hashes, exact version
output, generated file and full drift comparison are retained under
`/private/tmp/cmd-ci-info-20261023/evidence/`.

## Evidence locations and pending exit conditions

The local diagnostic implementation, actual argv, stream bytes, result JSON,
container state before and after cleanup, and source observations are retained
under `_build/verification/2026-10-23-c0/`. The failed run's selected raw
evidence and logs were also copied to ignored
`test-reports/2026-10-23-comprehensive/c0/remote-attempt1/`; the scheduled
regression audit is under `later-scheduled-regression/` beside it. Complete
downloads and additional source-selection checks are retained under
`/private/tmp/cmd-c0-remote-evidence-2026-10-23/` during this execution.
These directories are not substitutes for exact-source CI acceptance.

The C0 repair is limited to command-oracle invocations, including the shared
network scenario executor. Oracle sealing/version-inventory subprocesses
still use their existing direct-child execution boundary; they do not gain a
container-cleanup guarantee from this change. Their lifecycle review remains
open in the CI infrastructure work. No universal process-tree or Docker
daemon cancellation guarantee is claimed.

Before C0 can be accepted, collect exact-commit registered regression receipts,
pass the controlled push audit, and obtain the required PR and actual-main
three-platform and coverage results. Keep the original timeout's unresolved
causal boundary explicit.
No timeout increase, fixture skip, automatic retry, product fallback, or
performance pass is authorized by these observations.
