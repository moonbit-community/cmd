# echo

Support note (2026-09-05): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it separates native compatibility evidence from Wasm policy and smoke evidence. Options mentioned here but not promoted in that record are not compatibility guarantees.

Write arguments separated by one space. Supports `-n`, `-e`, and `-E`,
including the common backslash escapes and byte-valued octal/hex escapes.
Escapes are evaluated per argument, so a trailing backslash cannot consume the
space inserted before the next argument. `--help` and `--version` are metadata
options only when they are the sole argument.

The normally special `--` operand is printed literally, matching GNU echo's
historical ambiguity. Use `printf` when option-like input must be unambiguous.
