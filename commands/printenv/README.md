# printenv

Version **0.2.2** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Print selected environment values, or the complete environment when no names
are supplied. `-0` emits NUL-delimited records. Existing names are emitted in
operand order; any missing name makes the final status 1 without suppressing
values found earlier or later. It reads the environment exposed by the host;
the command does not filter variable names or force locale values.

## Standalone metadata

Standalone `--version` prints exactly `printenv 0.2.2` followed by one
newline. Standalone `--help` starts with `Usage: printenv`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
