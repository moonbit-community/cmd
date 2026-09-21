# xargs

Version **0.2.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Read arguments from standard input and execute a command with bounded batches.
Supports whitespace and NUL tokenization with quotes/backslashes, `-0`, `-n N`
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
