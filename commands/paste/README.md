# paste

Merge input lines for MoonX.

```sh
moonx cli/paste@0.2.3 [-s] [-d LIST] [-z] [FILE...]
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

## Limitations

- Delimiter processing uses byte rules, not multibyte characters.

## Examples

```sh
moonx cli/paste@0.2.3 first.txt second.txt
moonx cli/paste@0.2.3 -s -d, input.txt
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
