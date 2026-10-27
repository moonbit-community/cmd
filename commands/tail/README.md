# tail

Print and follow input endings for MoonX.

```sh
moonx cli/tail@0.2.3 [-fz] [-qv] [-s SEC] [-n NUM|-c NUM] [FILE...]
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

## Limitations

- -F/name replacement following is unsupported. Stdin follow exits at EOF.

## Examples

```sh
moonx cli/tail@0.2.3 -n 20 app.log
moonx cli/tail@0.2.3 -f app.log
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0004-filesystem.md)
