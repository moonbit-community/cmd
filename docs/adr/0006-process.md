# ADR-0006: Direct Child Lifecycle and Public Process Limits

Status: Accepted
Date: 2026-09-05
Updated: 2026-10-11
Revision: Record yes pipe termination and which lookup choices; correct the executable-access API attribution without claiming platform-complete command resolution.

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

## Migrated process-adjacent profiles

`yes@0.1.1` uses a repeated byte producer, public stream writes and downstream
closure to terminate. The target is an unbounded producer without unbounded
allocation. Reject generating an infinite in-memory string, swallowing a write
failure as success, or invoking host yes. Exact SIGPIPE status/diagnostic parity
is still unverified and is distinct from observing EOF/termination. Evidence:
`tests/cases/yes.json`, pipe lifecycle coverage and the 0.1.1 release report on
async 0.22.4 / MoonBit 2026-09-20. Expand the signal claim only after closed-pipe
status/cleanup comparisons on Native/Wasm per host; ordinary output is usable.

`which@0.1.0` currently splits PATH by actual host platform, preserves its
ordering, checks direct operands and supports `-a/-s`. The initial regular-file
test was chosen to avoid depending on absent mode metadata, but that reasoning
overlooked public `fs.can_execute`: access permission is different from reading
mode bits. A mode-0644 file returns success from all three current entrypoints
(Native, Wasm and exact MoonX) while public can_execute and macOS which reject
it. This is a **known defect**, not an accepted approximation or async blocker.
Evidence: [2026-10-11 probe](../reports/2026-10-11-command-followups/README.md),
async 0.22.4 `fs/pkg.generated.mbti` and `access_test.mbt`.

Use public access checks plus file kind for a future POSIX fix; do not infer
executable access from suffixes or read mode through host tools. PATH errors,
symlinks, empty entries and backslash filenames need separate tests. Windows
PATHEXT/executable lookup is a platform-specific project decision, not solved
by POSIX chmod/access. Shell aliases/functions belong to shell state and cannot
be inferred from an unrelated process. Close the issue only after pinned POSIX
oracle cases and explicit Windows lookup fixtures pass. Mode-query absence
remains real for cp/chmod, but must not be reused to justify this false success.

## Revisit when

Require released public exec/process-group/event APIs and validate descendant scope, cancellation, wait/reap and pipe closure separately on each backend.
