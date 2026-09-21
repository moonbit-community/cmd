# sh

For stdin mode, `$0` is the executable basename with the build suffix `.exe`
or `.wasm` removed, so both backends report `sh`. Script paths and explicit
`-c` command names retain their supplied value.

`cli/sh` interprets shell source in MoonBit. External commands execute as direct
child requests with the shell's cwd and exported environment. Authorization is
owned by the caller and runtime; the interpreter does not filter environment
names or delegate complete scripts to a host shell.

The following describes version **0.2.0**. Platform verification and exact
MoonX publication evidence are tracked in the
[support record](../../docs/compatibility.md).
The [support record](../../docs/compatibility.md) is the canonical release record.

## Invocation and sessions

`sh -c SOURCE [NAME [ARG...]]` executes a string. `sh FILE [ARG...]` executes a
file. `sh -s [ARG...]` and a bare invocation read commands from stdin, executing
complete commands before EOF without prompts. `sh -i` explicitly enables the
line-oriented interactive session, including `ENV`, `PS1`/`PS2` on stderr,
multiline input and recovery after a syntax or expansion error.

Command input is read one byte at a time through public async Reader methods,
so the parser does not prefetch bytes intended for `read` or a foreground child.
The session retains variables, exported names, cwd, functions, positional
arguments and status. `cd` updates `PWD`/`OLDPWD`; `-L` and `-P` select logical
and physical directory traversal. Pipeline stages and substitutions receive
isolated variable/function state; their IO streams run concurrently.

The shared shell package provides an opaque `Session` with `new`, asynchronous
`feed`/`finish`, `prompt`, and `load_startup`. Feed returns `NeedMoreInput`,
`Completed(status)` or `Exit(status)`. Reader/Writer injection supports embedding
and testing. `run` remains compatible, and `capture` returns `(status, stdout)`
without merging stderr.

## Language subset

The implementation includes quoting, local variables and explicit exports,
IFS field splitting, `*`/`?`/bracket pathname patterns, default/alternate/error/
assignment parameter words, command substitution, pipelines, redirections,
conditionals, case arms, loops, functions, grouping, positional parameters,
`shift`, and `set -e/-u`. Command substitution removes trailing LF characters
only, and a command consisting of assignments returns the last substitution's
status. Arithmetic supports integer literals/variables, parentheses, unary
operators and the usual binary arithmetic, bitwise, comparison and logical
operators; unsupported arithmetic syntax and division by zero fail explicitly.

Builtins include `read [-r] NAME...`, `printf`, `test`/`[`, `.`, `continue`, `cd`,
`pwd`, `export`, `unset`, `set`, `shift`, `return`, `break`, `exit`, `echo`, `:`,
`true` and `false`. Dot executes in the existing session. Read preserves the
remaining fields in its final variable and reports EOF even when it assigns a
partial final line.

This is a bounded shell, not a complete POSIX or Bash implementation. In
particular, the printf builtin currently implements `%s/%c/%b/%d/%i/%u/%o/%x/%X`,
`%%`, basic width/alignment and common ASCII escapes; unsupported conversions
fail explicitly. Test supports common string, integer, file-kind/access and
size predicates; compound expressions should use shell `&&`/`||`. Break and
continue support one loop level. Arithmetic assignment, increment, ternary
operators, fd duplication, backticks and background jobs are not supported.
Here-documents retain their existing literal-body subset.

## Upstream terminal limits

`-i` does not promise automatic TTY detection, raw mode, line editing, terminal
resize events, recoverable Ctrl-C, or job control. Async 0.22.1 does not expose
the complete public terminal/process-group interfaces needed for these
behaviors. `exec`, `fg`, `bg`, `jobs` and `wait` reject the request explicitly.
See the [upstream gap record](../../docs/async-upstream-gaps.md) and ADR-0007.

The workspace runner's `sh-interactive-session` scenario verifies persistent
open stdin, ENV, PS1/PS2, immediate execution, multiline input, variables,
functions, cwd, read, foreground input, error recovery, EOF and exit. Its
foreground helper reads one line in pure MoonBit. Run the prebuilt driver with
`--suite scenarios --case sh-interactive-session --backend native` or `wasm`.
See [test instructions](../../tests/runner/README.md). The original probe is
retained under `docs/reports/2026-09-21-test-cleanup-evidence/repro/`.
