# ADR-0007: Shell Sessions and Make Scheduling in MoonBit

Status: Accepted
Date: 2026-09-05
Updated: 2026-09-21
Revision note: stdin shell names strip generated `.exe` and `.wasm` suffixes
consistently. Explicit `-c` names and script paths remain verbatim. This chooses
the logical command basename over backend artifact naming; relocated binaries
with either suffix therefore expose the suffix-free name. The portable
`compat-text-line-165` JSON contract exercises both backends. Revisit only if
the launcher exposes a stable caller-supplied logical argv[0].
Revision: Integrate persistent shell and synchronized make scenarios into both-backend validation.

## Target and decision

Opaque Session provides async feed/finish returning NeedMoreInput, Completed(status), Exit(status); run remains an adapter and capture returns output/status. sh -i persists cwd, variables/export state, functions/status; uses PS1/PS2 on stderr, interactive ENV, EOF/exit and syntax recovery. One-byte command input reads preserve read/foreground-child input. Make -j schedules dependency-ready targets concurrently, executes shared prerequisites once and propagates failures. $(shell ...) normalizes newlines and updates .SHELLSTATUS. No jobserver claim.

## Alternatives and compatibility cost

Reject host interpreter delegation, exec as an external command, CharDevice as isatty and cancellation handling as recoverable SIGINT. Raw mode, editing/completion, resize and fg/bg require distinct terminal APIs. Bounded printf/test, one-level loop control, arithmetic assignment/increment/ternary, backticks, fd duplication and background syntax are project limitations, not async blockers; unsupported forms fail explicitly.

## Versions and evidence

Baseline: async 0.22.1, x 0.5.5, moonjq 0.1.2; MoonBit 2026-09-15.
The 2026-09-20 Native/Wasm shell tests each passed 15/15, and the original
interactive probe passed on both with stdin held open. Current unified scenarios
retain those assertions, with a pure MoonBit one-line foreground helper instead
of host `head`. They test immediate execution, prompts, startup ENV, multiline
input, persistent state, read, foreground input, syntax recovery, EOF and exit.
Make scenarios use ready/ack synchronization for overlap, shared prerequisites
and failed dependencies. CI runs the applicable scenarios against both command
backends; reports, rather than workflow configuration alone, establish results.
Historical results remain in [the audit](../reports/2026-09-19-command-fidelity-audit.md).
Candidate runtime results are recorded separately from published versions.

## Revisit when

Expand interpreter grammar through oracle-backed tests. Enable advanced terminal behavior only when public interfaces satisfy the documented lifecycle requirements.
