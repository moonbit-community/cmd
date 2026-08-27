# xargs

Read arguments from standard input and execute a command with bounded batches.
Supports `-0`/`--null`, `-n N`/`--max-args=N`, `-r`/`--no-run-if-empty`, and
`-t`/`--verbose`. Input is capped at 16 MiB and is parsed into argv entries;
there is no shell evaluation. Parsing accepts at most 100,000 entries, and
each child argv batch is kept below a conservative 64 KiB limit. Since it
starts child processes, it is not in the default policy allow-list.
