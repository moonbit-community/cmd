# ADR-0007: Shell Sessions and Make Scheduling

Status: Accepted
Date: 2026-09-05
Updated: 2026-11-08

## Decision

Implement the shell and make in pure MoonBit. Opaque Session exposes async
feed/finish with NeedMoreInput, Completed and Exit results; run is an adapter
and capture returns output/status. Keep incomplete syntax distinct from invalid
syntax and loop control separate from exit status or signal origin.
Reserved words are contextual at command and pipeline-stage starts. Required
compound lists and logical right operands reject before execution; ordinary
arguments, quoted words, top-level emptiness and empty case arms remain valid.
EOF reparses a pending continued line and executes it if complete; incomplete
quotes, here-documents and compounds still reject with the parse cause retained
after the EOF diagnostic prefix. All Session adapters use that
actual finish status. Child launch OS errors are classified at the launch call,
outside stdout/stderr pumps; unexpected pump and other nonlanguage failures
propagate with their identity and stop subsequent commands. The explicit
closed-pipe path retains status 141. Substitution adds context only to
ShellError. Source-read errors in an external child's input pump propagate;
failure to write its owned stdin pipe stops feeding and leaves the child's exit
status authoritative, since the child may intentionally close stdin early.

Pipe-based sh sessions preserve cwd, variables, exports, functions and status.
PS1/PS2 use stderr; ENV, multiline input, syntax recovery, EOF and exit retain
their own rules. One-byte command reads preserve foreground-child/read input.
Stdin invocation names remove generated .exe/.wasm suffixes; explicit -c names
and script paths remain verbatim.

Expand ENV as one pathname without re-lexing, splitting or globbing. Preserve
literal quotes, spaces and ordinary backslashes while applying supported
parameter/arithmetic/command substitutions and double-quoted escape rules.
Split filters reuse this Session; env -S retains a distinct word grammar.

Arithmetic assignment, compound operations, increments and conditional/short-circuit
expressions preserve evaluation order. Increments and test's `==` remain project
extensions beyond Dash. Backticks and `$()` isolate state. For each candidate `)`,
the substitution scanner reuses the grammar to distinguish case patterns and
function/group syntax. Prefix reparsing favors one contextual grammar; reconsider
incremental parsing only with measured long-script need and retained regressions.

Here-documents retain expansion, quoting, tab stripping and continuation rules.
Expand argv and redirection targets before ordered opens, then apply temporary
prefix assignments. Preserve earlier file/output effects if a later step fails.
Stdout/stderr aliases use one actual child pipe for merged byte order. Capture
bytes before UTF-8 decoding and reject invalid textual captures.

Builtin printf uses 64-bit integer parsing, binary64 formats and the fixed Linux
Dash 8192-byte output profile. Allocation state survives builtin output but empty
conversions do not allocate. Large conversions flush bounded storage; submitted
failed writes are not replayed. Width/precision is bounded at 1,000,000. Test uses
finite argument-count grammar, checked decimal integers and raw paths. Ordinary
typed lookup errors become false predicates; cancellation and other errors
propagate. File-size tests validate the raw lookup, resolve final links, then
query the target's metadata without opening or reading its contents. The raw
lookup matters because canonicalization alone can remove a non-directory parent
component. The separate queries do not establish an atomic identity snapshot.
On POSIX, every file predicate and both timestamp-comparison operands require
a Directory result for an operand ending in a slash: macOS 15 can otherwise
report a regular symlink target for that spelling. After the raw lookup succeeds,
resolve the directory so -L/-h do not classify its final link as the operand.
Directory and directory-link operands with trailing slashes still use their
actual metadata. Unsuffixed links retain their ordinary follow/nofollow policy.
Timestamp comparisons retain the public API's seconds and nanoseconds. The
local Darwin Dash 0.5.12 build lacks HAVE_ST_MTIM and compares only seconds;
its subsecond results do not establish the Linux oracle's precision or justify
discarding available timestamp precision. Raw-path regression controls use
different whole-second timestamps.
An actual ENOTSUP size result becomes an explicit status-2 capability error,
including within negation and compound test expressions. Do not fabricate zero
or uniformly reject directories: Linux exposes directory sizes, whereas the
current macOS API rejects them. Keep this boundary until the released public
API returns real sizes, with directory and directory-link regressions.
Forward raw paths to the host without a project-level lexical simplification.
Windows retains its [documented path normalization](https://learn.microsoft.com/dotnet/standard/io/file-path-formats#path-normalization),
for ordinary paths, including a missing component followed by `..`; device paths
may bypass that normalization. POSIX component lookup instead
fails. Keep a native Windows file observer and separate CLI expectation for this
platform distinction, without claiming POSIX resolution on Windows.

Make -j schedules dependency-ready targets and shared prerequisites once.
Computed names, assignment flavors, exports, MAKELEVEL and MAKEFLAGS retain their
separate phases. Shell-valued export recursion can use the original environment;
ordinary recursive variables fail. Preserve explicit export/unexport independently
from the default export policy and initial environment/command-line origin.
Default export requires an ASCII identifier and excludes unmodified builtin
defaults. Named directives create empty simple variables before later `?=`;
assignment modifier chains retain their final export/unexport decision without
reinterpreting ordinary variable-name lists. `.EXPORT_ALL_VARIABLES` applies only
after reading makefiles, including when a bare unexport appeared later.

Expand a target's complete recipe list before executing its first command.
Construct its environment lazily once and reuse it for that target. Empty
recipes, pure colon no-ops and unexecuted dry-run recipes do not trigger export
side effects. Expanded command echo precedes environment construction. Variable
recursion during recipe/environment expansion is fatal even with `-k`; actual
recipe exit failures retain keep-going behavior. These phases are serialized
while target execution remains concurrent. `$(shell ...)` and `!=` preserve
distinct trailing-newline rules and actual .SHELLSTATUS. Secondary expansion
resolves automatic-variable prerequisites before planning, retaining observed GNU
4.4.1 recipe-bearing declaration order and `$<`/`$^`/`$+` semantics.

Construct make shell-function argv before its exported environment. The default
Unix GNU fast path preserves literal LF as argument bytes; represent those argv
values with shell quoting for the pure interpreter. The shell path removes raw
LF through GNU's escape/reparse rule, preserving original backslash-LF pairs.
Use the make variables SHELL, .SHELLFLAGS and IFS, not only exported environment,
to choose the path. No-command results preserve the last status without export
side effects. Shell-language exceptions become shell status 2 for both captures
and recipes; make expansion errors, cancellation and I/O failures retain their
own propagation. A recipe's `-` flag applies after obtaining its shell status.
Capture stdout bytes until the first NUL, then decode that prefix as UTF-8;
invalid bytes after NUL do not affect the value or actual shell status, while
invalid bytes before it reject explicitly. Keep the private adapter and finite
CLI regressions together; it does not establish every external GNU utility's
behavior or arbitrary interpreter selection.

Recipe `$?` snapshots distinct changed prerequisites once per target, including
phony/missing dependencies, -B and -W virtual times. Secondary expansion sees
the GNU empty `$?` context. -W retains dependency planning and does not suppress
rebuilding requested by -B or changed phony dependencies. Inline recipes share
the same recipe-bearing group order and preserve literal hash bytes. Parse rule
separators outside balanced references, retaining shell punctuation inside them.

Explicit SHELL selects only the literal built-in `sh`/`/bin/sh` profile and
.SHELLFLAGS only literal -c, including rejection of an inherited empty value.
Reject custom or computed selectors before their
side effects; never invoke a host interpreter. Inherited environment SHELL is
not an interpreter selector and remains in child environments unless explicitly
exported. Known unsupported GNU functions are recognized using GNU's six ASCII
space characters and reject before expanding arguments, so a lazy unselected
branch cannot execute. Unknown variable names retain normal variable semantics.

Inherited POSIX FIFO jobservers are separate from local -j. Track one implicit
slot and borrowed exact bytes independently. Serialized acquisition races the
implicit slot against a token, returning any simultaneously acquired extra byte
before execution. Protected cleanup returns owned tokens once on success, failure
or cancellation. Failed returns propagate without retrying possibly submitted
bytes. Close owned handles without removing the server's FIFO. `$(MAKE)` launches
this Wasm command; without an inherited server, recursive children receive -j1
to stay within the occupied parent slot.

## Limits and rejected alternatives

Do not delegate interpretation to a host shell, treat an external command as
exec replacement, or use character-device kind as isatty. Terminal editing,
completion, resizing, recoverable SIGINT and job control need distinct APIs.
Descriptor numbers above 2, closure and access-direction changes require public
descriptor import/duplication/closure APIs. Standard output aliases do not establish
arbitrary inheritance. Test identity, owner/group/mode-bit and terminal predicates
need their public metadata/terminal APIs. Make descriptor-pipe authentication and
Windows semaphores require public import/semaphore APIs; new FIFO servers need a
public FIFO creation API. These operations reject and reopen only with the
relevant public API and actual platform regressions.

Complete POSIX/Bash grammar, background jobs, GNU make builtin rule/function
databases, archive/order-only/target-specific semantics and override/private assignments remain
outside this finite profile. Grammar gaps are project work, not automatically
runtime blockers.

Session::finish reparses pending source and can run a complete continued command
through async run_jobs. Its async public type is required by that execution
contract. The earlier synchronous trial predates EOF execution and is no longer
applicable; see [ADR-0003](0003-streams.md#pending-cleanup-decisions).

## Verification and reconsideration

Stdin-script parsing consumes options, including `--`, before assigning
positional operands even after `-s`. Keep exact tests for stdin, command-string
and named-script branches; current repairs do not rewrite frozen published
expectations.

Continuous-input scenarios observe immediate execution, prompts, ENV, persistent
state, child input, fragmented substitutions and recovery. Make ready/ack tests
observe overlap, shared prerequisites, recursive children and exact FIFO byte
return. Private tests inject cancellation and token-return failure. The Linux
GNU server scenario passes authentication from an actual GNU child through a
shared-file test bridge to the host Wasm client. It validates FIFO protocol, not
an operating-system parent/child relationship, and avoids mounting account
credentials inside the oracle container. The sealed Linux profile separately
checks printf buffer boundaries and diagnostic positions. Definitions are not
execution receipts; local checks do not establish three-platform or published
acceptance. Pipe tests do not establish PTY or job-control support.

Implementation: [Session](../../core/shell/session.mbt),
[executor](../../core/shell/executor.mbt),
[file predicates](../../core/shell/test_file.mbt),
[make scheduler](../../commands/make/scheduler.mbt),
[scenarios](../../tests/scenarios/dispatch.mbt).
Raw-path regressions exercise the same predicates through actual
[sh invocations](../../tests/cases/sh.json),
[make recipes](../../tests/cases/make.json) and
[split filters](../../tests/cases/split.json), including asymmetric timestamp
fixtures that expose an incorrectly accepted operand.
