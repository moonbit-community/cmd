# xargs

Observed Wasm profile (2026-09-04): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Read arguments from standard input and execute a command with bounded batches.
Supports whitespace and NUL tokenization with quotes/backslashes, `-0`, `-n N`
(`--max-args=N`), `-L N`/`--max-lines=N`, `-s BYTES`/`--max-chars=BYTES`,
`-E EOF`/`--eof=EOF`, `-r`/`--no-run-if-empty`, `-t`/`--verbose`,
`--show-limits`, and `-I REPLACE`/`--replace=REPLACE` logical-line
replacement. Each child argv batch is kept below the configured limit (64 KiB
by default), and `-P N` runs at most N batches in one structured task window.
There is no shell evaluation; all children are direct process requests and
therefore require an explicit Wasm process policy.

Status classes match findutils for ordinary failures (123), status 255 (124),
signals (125), and launch failures (126/127). Parallel output ordering is
intentionally unspecified, but status aggregation is deterministic. The
runtime does not expose ambient host process authority or process-group
cancellation.

Wasm children use the explicit restricted environment and host process policy.
`xargs` always reads stdin silently until EOF, including on a terminal. Native
inheritance is outside this Wasm support record.
