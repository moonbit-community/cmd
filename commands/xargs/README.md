# xargs

Read arguments from standard input and execute a command with bounded batches.
Supports `-0`/`--null`, `-n N`/`--max-args=N`, `-r`/`--no-run-if-empty`, and
`-t`/`--verbose`. Input size is controlled by the calling harness and is
parsed into argv entries; there is no shell evaluation. Each child argv batch
is kept below a conservative 64 KiB operating-system limit. Since it
starts child processes, it is not in the default policy allow-list.

`xargs` always reads stdin. When stdin and stderr are interactive terminals
it prints an EOF waiting prompt; pipes and redirections remain silent.
