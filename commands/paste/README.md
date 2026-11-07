# paste

Development candidate: `cli/paste@0.2.5`. Publication is separate;
[latest.json](../../tests/release/latest.json) records the uploaded coordinates.

Merge input lines for MoonX.

```sh
moonx cli/paste@0.2.5 [-s] [-d LIST] [-z] [FILE...]
```

## Supported scope

Combine corresponding records from files, separated by TAB by default. Use - for stdin.

## Options

| Option | Description |
| --- | --- |
| `-s, --serial` | Join each file's records into one output record. |
| `-d, --delimiters=LIST` | Cycle through delimiters. |
| `-z, --zero-terminated` | Use NUL-delimited records. |
| `--help` / `--version` | Show help / package version. |

## Argument and exit-status contract

Ordinary option/operand errors exit 1; documented capability refusals retain their own status.

See the [finite diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics).

## Limitations

- Delimiter processing uses byte rules, not multibyte characters.

## Examples

```sh
moonx cli/paste@0.2.5 first.txt second.txt
moonx cli/paste@0.2.5 -s -d, input.txt
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
