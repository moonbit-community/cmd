# xargs

Read arguments from standard input and execute a command with bounded batches.
Supports `-0`/`--null`, `-n N`/`--max-args=N`, `-r`/`--no-run-if-empty`, and
`-t`/`--verbose`. Input size is controlled by the calling harness and is
parsed into argv entries; there is no shell evaluation. Each child argv batch
is kept below a conservative 64 KiB operating-system limit. Since it
starts child processes, it is not in the default policy allow-list.

Native children inherit the complete parent environment; Wasm children use the
explicit restricted environment and host process policy. `xargs` always reads
stdin silently until EOF, including on a terminal.
