# rmdir

Version **0.2.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Remove empty directories. Supports parent removal (`-p`), verbose output
(`-v`), and ignoring failures caused only by non-empty directories
(`-I`/`--ignore-fail-on-non-empty`). Failed operands do not stop later
directories from being attempted.
