# xargs

Version **0.2.2** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Read arguments from standard input and execute a command with bounded batches.
Supports whitespace tokenization with quotes/backslashes, byte tokenization
with `-0` or `-d CHAR` / `--delimiter=CHAR`, and `-n N`
(`--max-args=N`), `-L N`/`--max-lines=N`, `-s BYTES`/`--max-chars=BYTES`,
`-E EOF`/`--eof=EOF`, `-r`/`--no-run-if-empty`, `-t`/`--verbose`,
`--show-limits`, and `-I REPLACE`/`--replace=REPLACE` logical-line
replacement. Each child argv batch is kept below the configured limit (64 KiB
by default), and `-P N` runs at most N batches in one structured task window.
There is no shell evaluation; all children are direct process requests. Wasm
hosts may require process authorization supplied by the caller.

Status classes match findutils for ordinary failures (123), status 255 (124),
signals (125), and launch failures (126/127). Parallel output ordering is
intentionally unspecified, but status aggregation is deterministic. The
runtime does not expose portable process-group cancellation.

Both backends inherit the complete caller environment; authorization belongs
to the host or caller. Environment names and locale variables are not filtered
or rewritten by this command.
`xargs` always reads stdin silently until EOF, including on a terminal. Native
behavior is measured separately from Wasm host authorization.

Delimiter mode preserves empty items, treats quotes/backslashes in input
literally, and accepts one byte or a GNU named, octal, or hexadecimal escape.
The last `-0` / `-d` wins. `-E` has no effect in either byte mode and emits the
GNU warning. The selected immutable findutils oracle uses signed `char`, so
delimiter bytes above 127 do not match input bytes; valid UTF-8 items still
work. A raw non-UTF-8 argument prefix cannot cross the public process API's
`String` argv and is rejected with status 2 before any child is launched.
Bytes after a NUL inside an item are excluded from its C argv string but still
count toward the byte limit.

`-p` / `--interactive` opens a separate confirmation input (`/dev/tty` on
POSIX, `CONIN$` on Windows), leaving argument stdin separate. Each proposed
command is printed on stderr; a line starting with `y` or `Y` accepts it in
the C locale. If that channel cannot be opened, the command returns status 2
before consuming argument stdin or launching children. This explicit boundary
also applies to `-p -r` with empty input; GNU may exit before opening its TTY in
that case. When the channel opens, empty `-p -r` input exits 0 without prompting
or launching a child. Windows CI can provide `CONIN$` even when nobody is
available to answer, so a nonempty interactive request correctly waits for
confirmation. Confirmation choices are exercised with the existing separate
input tests; unattended CLI cases do not assume a missing Windows console.

## Standalone metadata

Standalone `--version` prints exactly `xargs 0.2.2` followed by one
newline. Standalone `--help` starts with `Usage: xargs`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
