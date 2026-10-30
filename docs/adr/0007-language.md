# ADR-0007: Shell Sessions and Make Scheduling

Status: Accepted
Date: 2026-09-05
Updated: 2026-10-30

## Decision

Implement the shell and make in pure MoonBit. Opaque Session exposes async
feed/finish with NeedMoreInput, Completed and Exit results; run is an adapter
and capture returns output/status. Keep incomplete syntax distinct from invalid
syntax and loop control separate from exit status or signal origin.

Pipe-based sh sessions preserve cwd, variables, exports, functions and status.
PS1/PS2 use stderr; ENV, multiline input, syntax recovery, EOF and exit retain
their own rules. One-byte command reads preserve foreground-child/read input.
Stdin invocation names remove generated .exe/.wasm suffixes; explicit -c names
and script paths remain verbatim.

Expand ENV as one pathname without re-lexing, splitting or globbing. Preserve
literal quotes, spaces and ordinary backslashes while applying supported
parameter/arithmetic/command substitutions and double-quoted escape rules.
Split filters reuse this Session; env -S retains a distinct word grammar.

Make -j schedules dependency-ready targets concurrently, runs shared prerequisites
once and propagates failures. Command substitution normalizes newlines and
updates .SHELLSTATUS. This is not a jobserver implementation.

## Limits and rejected alternatives

Do not delegate interpretation to a host shell, treat an external command as
exec replacement, or use character-device kind as isatty. Terminal editing,
completion, resizing, recoverable SIGINT and job control need distinct APIs.
Grammar limits such as background syntax, fd duplication, backticks and wider
arithmetic/loop forms are project work, not automatically runtime blockers.
Unsupported forms fail explicitly rather than producing successful empty output.

Session::finish currently contains no async operation, but its async type is
already public. A successful synchronous trial is only a candidate for an
intentional core API revision; see [ADR-0003](0003-streams.md#pending-cleanup-decisions).

## Verification and reconsideration

Continuous-input scenarios observe immediate execution, prompts, ENV, persistent
state, child input and recovery. Make uses ready/ack tests for real overlap,
shared prerequisites and failure propagation. Pipe tests do not establish PTY
or job-control support. Expand grammar with oracle-backed regressions and
terminal features only with public lifecycle interfaces.

Implementation: [Session](../../core/shell/session.mbt),
[executor](../../core/shell/executor.mbt),
[make scheduler](../../commands/make/scheduler.mbt),
[scenarios](../../tests/runner/scenarios.mbt).
