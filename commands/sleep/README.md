# sleep

Pause execution for MoonX.

```sh
moonx cli/sleep@0.2.3 NUMBER[SUFFIX]...
```

## Supported scope

Wait for the sum of all nonnegative duration operands; plain numbers mean seconds.

## Options

| Option | Description |
| --- | --- |
| `NUMBER[s\|m\|h\|d]...` | Select seconds, minutes, hours or days. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- The total is rounded up to milliseconds and clamped at 2147483647 ms; negative or invalid operands fail.

## Examples

```sh
moonx cli/sleep@0.2.3 0.1
moonx cli/sleep@0.2.3 1s
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0006-process.md)
