# printenv

Version **0.2.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Print selected environment values, or the complete environment when no names
are supplied. `-0` emits NUL-delimited records. Existing names are emitted in
operand order; any missing name makes the final status 1 without suppressing
values found earlier or later. It reads the environment exposed by the host;
the command does not filter variable names or force locale values.
