# zcat

Write decompressed gzip data for MoonX.

```sh
moonx cli/zcat@0.1.4 [OPTION]... [FILE]...
```

## Supported scope

Decode files or stdin to stdout, retaining input files. Supports concatenated members and checksum/size verification.

## Options

| Option | Description |
| --- | --- |
| `-c, --stdout` | Write to stdout and keep input files. |
| `-d, --decompress` | Decompress (default for gunzip and zcat). |
| `-t, --test` | Validate compressed input without output. |
| `-n, --no-name` | Omit name/time metadata when compressing. |
| `-q, --quiet` | Suppress trailing-garbage warnings. |
| `-1 .. -9` | Compression level (default: -6; last option wins). |
| `--fast` | Same as -1. |
| `--best` | Same as -9. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Only gzip is supported; no suffix searching, force/pass-through or metadata restoration.
- Invalid input returns 1 after any decoded prefix; trailing garbage returns 2.

## Examples

```sh
moonx cli/zcat@0.1.4 first.gz second.gz
moonx cli/zcat@0.1.4 < first.gz
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0008-data.md)
