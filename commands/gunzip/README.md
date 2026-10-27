# gunzip

Decompress gzip data for MoonX.

```sh
moonx cli/gunzip@0.1.3 [OPTION]... [FILE]...
```

## Supported scope

Read stdin or named gzip files, including concatenated members. Verify header/data checksums and uncompressed size.

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

- Named inputs require -c unless testing. In-place replacement, other compression formats, metadata restoration, recursion and force/pass-through are unsupported.
- Late errors preserve emitted bytes; trailing garbage returns 2, and format failures return 1.

## Examples

```sh
moonx cli/gunzip@0.1.3 -c notes.txt.gz
moonx cli/gunzip@0.1.3 -t notes.txt.gz
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0008-data.md)
