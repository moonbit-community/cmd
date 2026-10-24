# ADR-0006: Direct Child Lifecycle and Public Process Limits

Status: Accepted
Date: 2026-09-05
Updated: 2026-10-25
Revision: Add split filter sessions, env split strings and xargs byte/confirmation boundaries without expanding process or shell guarantees.

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

The unpublished O5 split filter reuses the pure MoonBit shell Session with
public pipes and a per-piece FILE environment. The small public `last_signal`
query preserves raw signal termination separately from an ordinary exit 141;
pipeline status follows the last command. This is observation of the public
process result, not signal sending, exec replacement or descendant control.
No host shell implements a product command.

O13 env `-S` parses its selected quote, escape, comment and stop grammar,
expands `${NAME}` from the original environment, and splices words back into
option processing. Shell metacharacters remain literal child arguments. The
grammar is env-specific and does not widen the shell profile in ADR-0007.

Xargs `-d` scans raw bytes with the selected named/octal/hex escape rules;
`-0` and `-d` use last-option precedence. Existing batching and child-tail
arguments remain distinct from command options. A valid UTF-8 argument prefix
can use String argv, while an invalid-byte prefix rejects before launch.
Lift that transport boundary only after a released raw-byte argv API and
Native/Wasm child-observed byte, NUL and size-limit comparisons pass.

Xargs `-p` independently opens the confirmation channel and serializes prompts
before each child; argument stdin is never the confirmation reader. On hosts
without that channel it fails before reading argument stdin or launching,
including the explicit empty `-r` preflight. This stronger preflight is a
documented boundary rather than GNU empty-input parity. A host exposing the
independent channel can lift its host limitation through yes/no/EOF and child
effect tests. Opening a character device is public; absence of a usable
console is not a missing character-device API.
The no-channel fixtures apply to the observed POSIX CI profile. Windows CI
opens `CONIN$`: nonempty `-p` waits for confirmation and empty `-p -r` exits 0
without a prompt or child. The latter has its own Windows contract. Separate
confirmation-reader tests cover yes/no/EOF; unattended console availability
must not be relabeled as a missing-channel rejection.

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

`which` uses public `fs.can_execute` plus regular-file kind on POSIX. Access
checks do not require missing mode metadata. Preserve PATH ordering, direct
operands, empty PATH entries, symlink following and POSIX backslash filenames.
Reject the former regular-file-only approximation and never launch a candidate
to test whether it is executable. Windows uses PATHEXT, with the default
`.COM;.EXE;.BAT;.CMD`; this explicit platform contract does not emulate shell
aliases/functions, which belong to a different process's state.

The change intentionally stops reporting mode-0644 POSIX files as commands.
Evidence: async 0.22.4 public access APIs, the original
[Native/Wasm/MoonX probe](../reports/2026-10-11-command-followups/README.md),
and repaired 0644/0755/symlink/PATH/backslash/Windows fixtures. Add shell-aware
lookup only through an explicitly supplied shell session; ordinary PATH lookup
does not depend on a future metadata API. Mode-query absence
remains real for cp/chmod, but must not be reused to justify this false success.

## Revisit when

Require released public exec/process-group/event APIs and validate descendant scope, cancellation, wait/reap and pipe closure separately on each backend.
