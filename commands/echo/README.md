# echo

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

Write arguments separated by one space. Supports `-n`, `-e`, and `-E`,
including the common backslash escapes and byte-valued octal/hex escapes.

```sh
moonx cli/echo -- -e 'hello\nworld'
```
