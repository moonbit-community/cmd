# yes

Repeat text for MoonX.

```sh
moonx cli/yes@0.1.4 [STRING]...
```

## Supported scope

Write operands joined by spaces and a newline repeatedly. With no operands, repeat y. Stop when the downstream pipe closes.

## Options

| Option | Description |
| --- | --- |
| `STRING...` | Text to repeat. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Exact upstream signal diagnostics and terminal interaction are not promised.

## Examples

```sh
moonx cli/yes@0.1.4 hello | moonx cli/head@0.2.3 -n 2
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
