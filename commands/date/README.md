# date

Display dates and times for MoonX.

```sh
moonx cli/date@0.1.4 [OPTION]... [+FORMAT]
```

## Supported scope

Print the current time or an ISO date/time or @SECONDS value using TZ, the host timezone, or UTC. Fractional seconds accept up to nine digits.

## Options

| Option | Description |
| --- | --- |
| `-u, --utc` | Use UTC. |
| `-d, --date=TEXT` | Read an ISO date/time or @SECONDS. |
| `-I[PRECISION], --iso-8601[=PRECISION]` | ISO output: date, hours, minutes, seconds or ns. |
| `-R, --rfc-email` | Print an RFC email timestamp. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Relative date expressions and setting the system clock are unsupported.
- Formats: %Y %y %m %d %e %H %M %S %j %a %A %b %h %B %F %T %R %s %N %z %Z and %%.

## Examples

```sh
moonx cli/date@0.1.4 -u +%FT%TZ
moonx cli/date@0.1.4 -u -d @0 +%F
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0008-data.md)
