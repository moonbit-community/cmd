# tail

Development candidate: `cli/tail@0.2.5`. Publication is separate;
[latest.json](../../tests/release/latest.json) records the uploaded coordinates.

Print and follow input endings for MoonX.

```sh
moonx cli/tail@0.2.5 [-fz] [-qv] [-s SEC] [-n NUM|-c NUM] [FILE...]
```

## Supported scope

Print the last ten lines by default. +K starts at the Kth record/byte. File follow keeps the same open file across renames and handles truncation.

## Options

| Option | Description |
| --- | --- |
| `-n, --lines=N` | Select records; +K starts at record K. |
| `-c, --bytes=N` | Select bytes; +K starts at byte K. |
| `-q, --quiet / -v, --verbose` | Suppress / always print headers. |
| `-z, --zero-terminated` | Use NUL-delimited records. |
| `-f, --follow` | Follow an open regular file. |
| `-s, --sleep-interval=SECONDS` | Set follow polling interval; default 1. |
| `--help` / `--version` | Show help / package version. |

## Argument and exit-status contract

Ordinary option/operand errors exit 1; documented capability refusals retain their own status.

See the [finite diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics).

## Limitations

- Streamed last-N selection retains the selected suffix plus at most one input
  chunk of backing bytes. Completed discarded records are released, including
  a long record before an unterminated final record. Output is written from
  retained chunks without concatenating the whole selection. A selected long
  record still requires storage proportional to that record.

- -F/name replacement following is unsupported. Stdin follow exits at EOF.

## Examples

```sh
moonx cli/tail@0.2.5 -n 20 app.log
moonx cli/tail@0.2.5 -f app.log
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0004-filesystem.md)
