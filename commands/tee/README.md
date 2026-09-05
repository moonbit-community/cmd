# tee

Support note (2026-09-05): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it separates native compatibility evidence from Wasm policy and smoke evidence. Options mentioned here but not promoted in that record are not compatibility guarantees.

Copy standard input to standard output and each file operand. The observed
`-a`/`--append` path appends instead of truncating files.
If one output cannot be opened or written, `tee` continues writing stdout and
the remaining outputs, then exits nonzero.

`tee` always reads stdin silently until EOF. Terminal, pipe, and redirection
paths do not receive a repository-specific prompt.
