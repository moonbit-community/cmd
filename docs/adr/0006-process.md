# ADR-0006: Direct Child Lifecycle and Public Process Limits

Status: Accepted
Date: 2026-09-05
Updated: 2026-09-21
Revision: Share direct-child cleanup and distinguish runner deadlines from command statuses.

## Target and decision

Forward argv, cwd, stdio and complete environment through public process APIs. Distinguish cancellation requests, signals, process exit, wait/reap and pipe EOF. Cancel all owned fixture processes before waiting for cleanup. async 0.22.1 ordinary catch does not catch cancellation; defer cleanup must be nocancel, using protect_from_cancel when required.

Both Native test drivers share process execution and fixture cleanup. Ordinary
local cases have a 15-second default deadline; Docker and MoonX cases have a
120-second default, with explicit per-case overrides. Expiry is reported as a
runner timeout, separately from a command deliberately returning 124. Cleanup
closes owned pipes, requests cancellation and waits for direct children in an
uncancellable region. Cleanup failures remain visible infrastructure failures.

## Alternatives and compatibility cost

Reject spawn+wait as exec replacement and direct-PID kill as descendant cleanup. Process groups are not authorization. handle_cancellation cannot clear current task cancellation. Timeout remains a local direct-child subset, not a published portable process-group guarantee.

Reject sleep-duration guesses as proof of concurrency. Ready/ack synchronization
establishes that independent make recipes overlap while shared prerequisites
run once; deadlines bound failures. Lifecycle scenarios run serially even when
ordinary independent contracts use bounded concurrency. No automatic retry
turns an unstable process test into a pass.

## Versions and evidence

Baseline: async 0.22.1, x 0.5.5, moonjq 0.1.2; MoonBit 2026-09-15.
Upgrade-only Native 104/104 and Wasm 91/91 tests passed after adapting fixture cleanup. Shell/process tests and continuous-input probes cover owned pipes and waiting. The upstream gap register separates exec, group signalling, terminal ownership and lifecycle events.
Historical results remain in [the audit](../reports/2026-09-19-command-fidelity-audit.md).
Candidate runtime results are recorded separately from published versions.

## Revisit when

Require released public exec/process-group/event APIs and validate descendant scope, cancellation, wait/reap and pipe closure separately on each backend.
