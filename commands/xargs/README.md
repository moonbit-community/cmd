# xargs

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Read arguments from standard input and execute a command with bounded batches.
Supports `-0`/`--null`, `-n N`/`--max-args=N`, `-r`/`--no-run-if-empty`, and
`-t`/`--verbose`, plus `-I REPLACE`/`--replace=REPLACE` logical-line
replacement. Input size is controlled by the calling harness and is
parsed into argv entries; there is no shell evaluation. Each child argv batch
is kept below a conservative 64 KiB operating-system limit. Since it
starts child processes, it is not in the default policy allow-list.

Only successful `printf` child batches and policy-denied launches have been
observed in the current Wasm audit. The exit mapping for ordinary child
failure, status 255, and signal termination, plus `-L`/`-P`/size-limit
behavior and signal precedence, remains unverified.

Wasm children use the explicit restricted environment and host process policy.
`xargs` always reads stdin silently until EOF, including on a terminal. Native
inheritance is outside this Wasm support record.
