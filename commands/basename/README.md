# basename

Version **0.2.2** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Remove directory components from path operands. Supports `-a`/`--multiple`,
`-s`/`--suffix`, and NUL-delimited output with `-z`.

An empty operand produces an empty record; repeated separators and root paths
follow the coreutils byte-oriented path rules.

## Standalone metadata

Standalone `--version` prints exactly `basename 0.2.2` followed by one
newline. Standalone `--help` starts with `Usage: basename`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
