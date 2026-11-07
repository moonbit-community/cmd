# head

Development candidate: `cli/head@0.2.5`. Publication is separate;
[latest.json](../../tests/release/latest.json) records the uploaded coordinates.

Print the beginning of inputs for MoonX.

```sh
moonx cli/head@0.2.5 [-qvz] [-n NUM|-c NUM] [FILE...]
```

## Supported scope

Print the first ten lines by default. Read files or stdin; negative counts omit the last N units instead.

## Options

| Option | Description |
| --- | --- |
| `-n, --lines=N` | Select N records. |
| `-c, --bytes=N` | Select N bytes. |
| `-q, --quiet, --silent` | Suppress file headers. |
| `-v, --verbose` | Always show file headers. |
| `-z, --zero-terminated` | Use NUL-delimited records. |
| `--help` / `--version` | Show help / package version. |

## Argument and exit-status contract

Ordinary option/operand errors exit 1; documented capability refusals retain their own status.

See the [finite diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics).

## Limitations

- Counts measure bytes or records, not Unicode characters. Negative counts may retain the excluded suffix in memory.

## Examples

```sh
moonx cli/head@0.2.5 -n 5 notes.txt
moonx cli/head@0.2.5 -c 16 data.bin
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
