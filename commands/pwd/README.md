# pwd

Support note (2026-09-05): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it separates native compatibility evidence from Wasm policy and smoke evidence. Options mentioned here but not promoted in that record are not compatibility guarantees.

Print the current working directory. The Wasm artifact accepts `-L` and `-P`;
their result follows the Wasm cwd contract. `-L` uses `PWD` only when it is an
absolute, dot-free path resolving to the current directory; otherwise it falls
back to the physical cwd. The default is `-P`, or `-L` when
`POSIXLY_CORRECT` is present; the last explicit `-L`/`-P` wins.
