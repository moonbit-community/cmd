# gzip

Compress and decompress gzip data for MoonX.

```sh
moonx cli/gzip@0.1.4 [OPTION]... [FILE]...
```

## Supported scope

Compress stdin, compress named files with -cn, or decode/test gzip streams. Supports concatenated members and levels 1 through 9 (default 6).

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

- Named-file compression requires -cn; named-file decompression requires -c unless testing.
- In-place replacement, saved metadata, recursion, listing and force/pass-through are unsupported.
- Encoded bytes may differ from GNU gzip. Late decode failures preserve emitted bytes.

## Examples

```sh
printf 'hello\n' | moonx cli/gzip@0.1.4 > hello.gz
moonx cli/gzip@0.1.4 -cn notes.txt > notes.txt.gz
moonx cli/gzip@0.1.4 -t notes.txt.gz
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0008-data.md)
