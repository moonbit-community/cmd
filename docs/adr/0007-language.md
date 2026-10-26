# ADR-0007: Shell Sessions and Make Scheduling in MoonBit

Status: Accepted
Date: 2026-09-05
Updated: 2026-10-26
Revision note: stdin shell names strip generated `.exe` and `.wasm` suffixes
consistently. Explicit `-c` names and script paths remain verbatim. This chooses
the logical command basename over backend artifact naming; relocated binaries
with either suffix therefore expose the suffix-free name. The portable
`compat-text-line-165` JSON contract exercises the Wasm delivery path. Revisit only if
the launcher exposes a stable caller-supplied logical argv[0].
Revision: Retain persistent shell sessions and synchronized make scheduling under Wasm/MoonX delivery validation.

Delivery validation update (2026-10-26): [ADR-0001](0001-evidence.md) and the
[Wasm CI migration](../ci-wasm-migration.md) define current acceptance. Future
regressions and boundary unlock conditions below require Wasm on applicable
hosts and exact-version MoonX acceptance; Native command runs and backend
pairing are retired. Dated Native observations retain their historical scope.

## Target and decision

Opaque Session provides async feed/finish returning NeedMoreInput, Completed(status), Exit(status); run remains an adapter and capture returns output/status. sh -i persists cwd, variables/export state, functions/status; uses PS1/PS2 on stderr, interactive ENV, EOF/exit and syntax recovery. One-byte command input reads preserve read/foreground-child input. Make -j schedules dependency-ready targets concurrently, executes shared prerequisites once and propagates failures. $(shell ...) normalizes newlines and updates .SHELLSTATUS. No jobserver claim.

ENV is expanded as one pathname, without token recognition, field splitting or
globbing. Retain literal quotes, spaces and ordinary path backslashes; support
parameter, arithmetic and command substitution with double-quoted escape
rules. Re-lexing ENV as shell source was rejected after Windows CI exposed
lost path separators. Native/Wasm shell tests cover literal filenames and
startup loading; the continuous-input scenario verifies the real CLI path.

The published split filter reuses this Session and its existing grammar with
public pipes and a per-piece FILE variable. The small `last_signal` result
query retains signal termination separately from explicit exit 141; it does
not add signal control, terminal behavior or shell syntax. O13 env `-S` uses a
separate command-specific word grammar and passes literal metacharacters to
children; it does not route through a host shell or expand this language scope.

## Alternatives and compatibility cost

Reject host interpreter delegation, exec as an external command, CharDevice as isatty and cancellation handling as recoverable SIGINT. Raw mode, editing/completion, resize and fg/bg require distinct terminal APIs. Bounded printf/test, one-level loop control, arithmetic assignment/increment/ternary, backticks, fd duplication and background syntax are project limitations, not async blockers; unsupported forms fail explicitly.

## Versions and evidence

Commit `6fff343` introduced the persistent Session and dependency-ready
scheduler; `1c3dd27` corrected Windows startup paths and cancellation order.
The original Native/Wasm observations are summarized under 2026-09-20/21
in CHANGELOG.md. Current delivery scenarios execute Wasm or selected exact
MoonX coordinates, including their foreground children.

Continuous-input scenarios verify immediate execution, PS1/PS2, ENV,
multiline input, persistent state, read, foreground input, syntax recovery,
EOF and exit. Make tests use ready/ack synchronization for real overlap,
shared prerequisites and failure propagation. Passing pipe-based sessions
does not establish PTY, terminal editing or job-control support.

## Revisit when

Expand interpreter grammar through oracle-backed tests. Enable advanced terminal behavior only when public interfaces satisfy the documented lifecycle requirements.

## Source review (2026-10-26)

Current sources are [Session](../../core/shell/session.mbt), [executor](../../core/shell/executor.mbt), [make scheduler](../../commands/make/scheduler.mbt) and [shared scenarios](../../tests/runner/scenarios.mbt). Their tests preserve immediate input, dependency ordering and failure propagation; `db9dfe7` added the filter signal observation without expanding terminal support.
