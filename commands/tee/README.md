# tee

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Copy standard input to standard output and each file operand. The observed
`-a`/`--append` path appends instead of truncating files.

`tee` always reads stdin silently until EOF. Terminal, pipe, and redirection
paths do not receive a repository-specific prompt.
