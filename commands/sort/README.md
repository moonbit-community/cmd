# sort

Development candidate: `cli/sort@0.2.7`. Publication is separate;
[latest.json](../../tests/release/latest.json) records the uploaded coordinates.

Sort and merge records for MoonX.

```sh
moonx cli/sort@0.2.7 [-bcdfghinMruVz] [-s] [-m] [-o FILE] [-R|--sort=random] [--random-source=FILE] [-k KEY] [-t CHAR] [-c|-C] [-S SIZE] [-T DIR] [--batch-size=N] [FILE...]
```

## Supported scope

Sort files or stdin using C-byte order, selected keys and numeric/month/version/random modes. Supports stable, unique, check and merge modes.

Version 0.2.6 compares `-n` decimal prefixes exactly, including
large integers and long fractions. Unique, stable, check and disk merge modes
use the same ordering. `-g` retains floating-point general-number semantics.

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

## Argument and exit-status contract

Option values and operands after -- remain literal during alias normalization.

See the [finite diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics).

## Limitations

- Multiple explicit keys share one field-boundary scan per record. Preparation
  borrows selected byte ranges before producing owned keys; numeric fields retain
  exact canonical decimal digits, including across temporary runs.

- Locale-dependent collation is unsupported. Nonzero percentage buffer sizes are rejected; the buffer budget is not a total memory cap.
- Merge into an existing output file is rejected. Large sorts and named merges require writable temporary storage.

## Examples

```sh
moonx cli/sort@0.2.7 names.txt
moonx cli/sort@0.2.7 -t, -k 2 -u data.csv
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
