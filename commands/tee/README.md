# tee

Copy standard input to standard output and each file operand using bounded
streaming buffers. `-a`/`--append` appends instead of truncating files.

`tee` always reads stdin. When stdin and stderr are interactive terminals it
prints an EOF waiting prompt; pipes and redirections remain silent.
