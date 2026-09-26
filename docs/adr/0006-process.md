# ADR-0006: Direct Child Lifecycle and Public Process Limits

Status: Accepted
Date: 2026-09-05
Updated: 2026-09-21
Revision: Recheck public cancellation callbacks as a signal workaround; retain direct-child cleanup and deadline/status separation.

## Target and decision

Forward argv, cwd, stdio and complete environment through public process APIs. Distinguish cancellation requests, signals, process exit, wait/reap and pipe EOF. Cancel all owned fixture processes before waiting for cleanup. async 0.22.4 ordinary catch does not catch cancellation; defer cleanup must be nocancel, using protect_from_cancel when required.

Both Native test drivers share process execution and fixture cleanup. Ordinary
local cases have a 15-second default deadline; Docker and MoonX cases have a
120-second default, with explicit per-case overrides. Expiry is reported as a
runner timeout, separately from a command deliberately returning 124. Cleanup
closes owned pipes, requests cancellation and waits for direct children in an
uncancellable region. Cleanup failures remain visible infrastructure failures.
Pipe handles outlive the task group that performs their IO: pending reads and
writes must finish cancellation before closing the handles. Closing a handle
from the group's main task can race Windows completion delivery. The direct
child timeout scenario retains partial output and records each lifecycle phase
so a cleanup stall remains diagnosable in CI.

## Alternatives and compatibility cost

Reject spawn+wait as exec replacement and direct-PID kill as descendant cleanup. Process groups are not authorization. handle_cancellation cannot clear current task cancellation. Timeout remains a local direct-child subset, not a published portable process-group guarantee.

The public CancellationHandler wrapper can expose the supplied cancellation
function, but using it as a kill command loses errors: async 0.22.4 Native
kill wrappers discard the syscall result. A macOS probe on the 2026-09-20
toolchain confirms an absent PID is rejected by host kill but returns Unit
through hard_cancel. graceful_cancel additionally escalates after a timeout.
Reject this workaround because it would reintroduce false success; release a
standalone kill subset only when signal/target selection and failure reporting
are faithful. The needed API is public signal sending with observable OS errors,
separate from task cancellation. Probe: ../reports/2026-09-21-api-probes/cancellation-is-not-kill.mbtx.

Reject sleep-duration guesses as proof of concurrency. Ready/ack synchronization
establishes that independent make recipes overlap while shared prerequisites
run once; deadlines bound failures. Lifecycle scenarios run serially even when
ordinary independent contracts use bounded concurrency. No automatic retry
turns an unstable process test into a pass.

## Versions and evidence

Baseline: async 0.22.4, x 0.5.5, moonjq 0.1.2; MoonBit 2026-09-20.
Upgrade-only Native 104/104 and Wasm 91/91 tests passed after adapting fixture cleanup. Shell/process tests and continuous-input probes cover owned pipes and waiting. The upstream gap register separates exec, group signalling, terminal ownership and lifecycle events.
Historical results remain in [the audit](../reports/2026-09-19-command-fidelity-audit.md).
Candidate runtime results are recorded separately from published versions.

## Revisit when

Require released public exec/process-group/event APIs and validate descendant scope, cancellation, wait/reap and pipe closure separately on each backend.
