# rmdir

Version **0.2.2** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Remove empty directories. Supports parent removal (`-p`), verbose output
(`-v`), and ignoring failures caused only by non-empty directories
(`-I`/`--ignore-fail-on-non-empty`). Failed operands do not stop later
directories from being attempted.
With `-p`, parent traversal stops before the current working directory, any of
its ancestors, or a filesystem root; the explicitly named operand is still
attempted.

## Standalone metadata

Standalone `--version` prints exactly `rmdir 0.2.2` followed by one
newline. Standalone `--help` starts with `Usage: rmdir`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
