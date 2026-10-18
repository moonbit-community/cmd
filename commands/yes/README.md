# yes

Version **0.1.3** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Write the operand text followed by a newline repeatedly:

```sh
moonx cli/yes hello | moonx cli/head -n 2
```

With no operands the line is `y`; multiple operands are joined with one space.
`--help` and `--version` report package information. The producer exits when a
downstream pipe closes; exact signal diagnostics and terminal interaction are
not claimed.

## Standalone metadata

Standalone `--version` prints exactly `yes 0.1.3` followed by one
newline. Standalone `--help` starts with `Usage: yes`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
