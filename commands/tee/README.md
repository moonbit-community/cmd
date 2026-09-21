# tee

Version **0.2.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Copy standard input to standard output and each file operand. The observed
`-a`/`--append` path appends instead of truncating files.
If one output cannot be opened or written, `tee` continues writing stdout and
the remaining outputs, then exits nonzero.

`tee` always reads stdin silently until EOF. Terminal, pipe, and redirection
paths do not receive a repository-specific prompt.
