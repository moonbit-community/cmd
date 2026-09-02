# tee

Copy standard input to standard output and each file operand using bounded
streaming buffers. `-a`/`--append` appends instead of truncating files.

`tee` always reads stdin silently until EOF. Terminal, pipe, and redirection
paths do not receive a repository-specific prompt.
