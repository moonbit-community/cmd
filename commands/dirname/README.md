# dirname

Version **0.2.1** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Remove the final path component. Multiple operands and NUL-delimited output
with `-z` are supported. Empty operands produce `.`, root remains `/`, and
repeated separators are handled without filesystem access.

## Standalone metadata

Standalone `--version` prints exactly `dirname 0.2.1` followed by one
newline. Standalone `--help` starts with `Usage: dirname`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
