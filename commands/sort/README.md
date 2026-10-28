# sort

Sort and merge records for MoonX.

```sh
moonx cli/sort@0.2.4 [-bcdfghinMruVz] [-s] [-m] [-o FILE] [-R|--sort=random] [--random-source=FILE] [-k KEY] [-t CHAR] [-c|-C] [-S SIZE] [-T DIR] [--batch-size=N] [FILE...]
```

## Supported scope

Sort files or stdin using C-byte order, selected keys and numeric/month/version/random modes. Supports stable, unique, check and merge modes.

## Options

| Option | Description |
| --- | --- |
| `-r / -u / -s` | Reverse / unique keys / stable key ties. |
| `-b / -d / -f / -i` | Ignore leading blanks / dictionary order / ASCII fold / ignore nonprinting bytes. |
| `-n / -g / -h / -M / -V` | Numeric / general numeric / human numeric / month / version order. |
| `-R, --random-sort / --random-source=FILE` | Random key order / select seed source. |
| `-k KEY / -t CHAR` | Select comparison keys / field separator. |
| `-z` | Use NUL-delimited records. |
| `-c, --check / -C, --check=quiet` | Check order with diagnostics / status only. |
| `-m, --merge` | Merge inputs already in order. |
| `-o, --output=FILE` | Write named output; - is a literal filename. |
| `-S, --buffer-size=SIZE` | Sorting budget; default 64 MiB; bare numbers use KiB. |
| `-T, --temporary-directory=DIR` | Select temporary directories; may repeat. |
| `--batch-size=N` | Maximum merge fan-in; at least 2, capped at 16. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Locale-dependent collation is unsupported. Nonzero percentage buffer sizes are rejected; the buffer budget is not a total memory cap.
- Merge into an existing output file is rejected. Large sorts and named merges require writable temporary storage.

## Examples

```sh
moonx cli/sort@0.2.4 names.txt
moonx cli/sort@0.2.4 -t, -k 2 -u data.csv
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
