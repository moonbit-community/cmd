# expand

Development candidate: `cli/expand@0.1.5`. Publication is separate;
[latest.json](../../tests/release/latest.json) records the uploaded coordinates.

Convert tabs to spaces for MoonX.

```sh
moonx cli/expand@0.1.5 [OPTION]... [FILE]...
```

## Supported scope

Process files or stdin, using eight-column tab stops by default. Tab lists support fixed stops and a final /N (absolute) or +N (relative) interval.

## Options

| Option | Description |
| --- | --- |
| `-i, --initial` | Convert only leading blanks. |
| `-t, --tabs=LIST` | Select ascending tab stops. |
| `--help` / `--version` | Show help / package version. |

## Argument and exit-status contract

Ordinary option/operand errors exit 1; documented capability refusals retain their own status.

See the [finite diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics).

## Limitations

- Columns use byte rules; locale-dependent Unicode widths are unsupported.

## Examples

```sh
moonx cli/expand@0.1.5 -t 4 notes.txt
printf 'a	b\n' | moonx cli/expand@0.1.5
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
