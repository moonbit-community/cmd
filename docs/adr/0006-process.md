# ADR-0006: Direct-Child Lifecycle and Process Limits

Status: Accepted
Date: 2026-09-05
Updated: 2026-10-30

## Decision

Forward literal argv, cwd, stdio and complete environment through public
process APIs. Own direct children and pipes explicitly. Cancellation requests,
signals, exit status, wait/reap and pipe EOF are separate observations.

Cleanup closes owned streams in the required order, cancels and waits for
direct children in an uncancellable region, and reports cleanup failure.
Pipe handles outlive the task group performing their I/O so Windows pending
completion cannot race handle closure. Ordinary catch does not catch async
cancellation; use protected deferred cleanup where required.

Neither spawn-and-wait nor task cancellation implements exec replacement,
arbitrary signal sending or descendant-tree control. Timeout remains a local
direct-child subset. Cancellation wrappers that discard OS errors cannot
implement a faithful kill command.

## Command contracts

| Command | Ownership and boundary |
| --- | --- |
| rg --pre | Backpressure child stdout while draining stderr concurrently. Normal EOF checks exit and finishes stderr; early close cancels owned tasks and reaps the direct child. Retained diagnostics may grow with child stderr. No process-tree guarantee. |
| split --filter | Reuse the pure MoonBit Session and public pipes with per-piece FILE. Keep signal termination separate from explicit exit 141; pipeline status follows its last command. |
| env -S | Parse its own quote/escape/comment grammar and expand variables from the original environment. Splice literal words into option processing; shell metacharacters stay child arguments. |
| xargs -0/-d | Last delimiter option wins; preserve raw-byte scanning. Invalid UTF-8 argv prefixes reject before launch until a public raw-byte argv API exists. |
| xargs -p | Use an independent confirmation channel, never argument stdin. Hosts without a channel reject before input/launch; this includes the documented empty -r preflight. Windows CONIN$ availability and empty-input success have separate contracts. |
| yes | Repeated bounded output stops on real write failure. Do not swallow that failure; exact SIGPIPE status/diagnostic parity remains unverified. |
| which | POSIX regular-file plus public can_execute, preserving PATH order, empty entries and symlinks. Windows uses PATHEXT. Never execute a candidate to test access or claim another shell's alias/function state. |

Released async 0.22.5 has a Windows Native empty-environment construction
defect. The historical Native env guard rejects an empty final child environment
with 125; it does not restrict current Wasm empty-environment behavior. Never
inject a variable to approximate emptiness. Remove that guard only after a
released fix and child-observed environment/stream/status tests.

## Verification and reconsideration

The shared test drivers default to fifteen-second local deadlines and
120-second Docker/MoonX deadlines, with explicit case overrides. A runner
timeout differs from a command intentionally returning 124. Preserve partial
output and lifecycle phase diagnostics; missing cleanup cannot pass.

Use ready/ack synchronization to establish concurrency, not sleep guesses.
Keep lifecycle fixtures serial and do not automatically retry unstable cases
into success. Process-group, exec and signal claims require their own released
public APIs and actual Wasm-host tests for scope, errors, waits and pipe closure.

Implementation: [process](../../core/process/process.mbt),
[execution](../../tests/testkit/execute.mbt),
[process scenarios](../../tests/runner/scenario_process.mbt),
[rg child ownership](../../commands/rg/internal/sys/process.mbt).
