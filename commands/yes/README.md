# yes

Version **0.1.0** behavior is documented here. The
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
