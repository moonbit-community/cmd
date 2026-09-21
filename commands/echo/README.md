# echo

Version **0.2.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Write arguments separated by one space. Supports `-n`, `-e`, and `-E`,
including the common backslash escapes and byte-valued octal/hex escapes.
Escapes are evaluated per argument, so a trailing backslash cannot consume the
space inserted before the next argument. `--help` and `--version` are metadata
options only when they are the sole argument. The version token matches the
package version in `moon.mod`.

The normally special `--` operand is printed literally, matching GNU echo's
historical ambiguity. Use `printf` when option-like input must be unambiguous.
