# printenv

Print environment values for MoonX.

```sh
moonx cli/printenv@0.2.3 [-0] [NAME...]
```

## Supported scope

Print all environment entries, or values for the named variables in operand order. Missing requested variables cause status 1.

## Options

| Option | Description |
| --- | --- |
| `-0, --null` | End values with NUL instead of newline. |
| `VARIABLE...` | Select variables; omit to list the environment. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Full environment listing order is unspecified.

## Examples

```sh
moonx cli/printenv@0.2.3 PATH
moonx cli/printenv@0.2.3 HOME PATH
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0006-process.md)
