# csplit

Split files at line or pattern boundaries for MoonX.

```sh
moonx cli/csplit@0.2.3 [OPTION]... FILE PATTERN...
```

## Supported scope

Split a file or stdin (`-`) using line numbers, `/BRE/[OFFSET]`, `%BRE%[OFFSET]`, `{N}` and `{*}`. Print fragment sizes by default.

## Options

| Option | Description |
| --- | --- |
| `-f, --prefix=PREFIX` | Use PREFIX instead of xx. |
| `-n, --digits=NUMBER` | Use at least NUMBER suffix digits (default 2). |
| `-b, --suffix-format=FORMAT` | Use one d/i/u/o/x/X conversion for suffixes. |
| `--suppress-matched` | Omit the offset-adjusted split boundary line. |
| `-s, --silent` | Suppress output byte counts. |
| `-q, --quiet` | Same as --silent. |
| `-k, --keep-files` | Keep created fragments after a split error. |
| `-z, --elide-empty-files` | Omit empty output fragments. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Existing output paths are rejected. Windows names ending in spaces or dots are rejected.
- Requires temporary storage for the complete input and line index. Locale-specific matching is unsupported.

## Examples

```sh
moonx cli/csplit@0.2.3 input.txt 10
moonx cli/csplit@0.2.3 -f part- input.txt '/^SECTION/' '{*}'
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
