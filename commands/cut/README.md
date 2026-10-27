# cut

Select fields and byte positions for MoonX.

```sh
moonx cli/cut@0.2.4 (-b LIST | -c LIST | -f LIST [-d CHAR] [-s]) [--complement] [--output-delimiter=STRING] [-z] [FILE...]
```

## Supported scope

Select positions from files or stdin. Lists accept N, N-M, N- and -M; output preserves input order. The default field separator is TAB.

## Options

| Option | Description |
| --- | --- |
| `-b, --bytes=LIST` | Select bytes. |
| `-c, --characters=LIST` | Select characters under the C-byte profile. |
| `-f, --fields=LIST` | Select fields. |
| `-d, --delimiter=CHAR` | Set the field delimiter; empty means NUL. |
| `-s, --only-delimited` | Skip undelimited records in field mode. |
| `--complement` | Invert the selected positions. |
| `--output-delimiter=STRING` | Join selected fields/ranges; empty means NUL. |
| `-z, --zero-terminated` | Use NUL-delimited records. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- -c counts bytes, not Unicode characters.
- -d and -s require field mode. Equal field and record delimiters make field positions span the input file.

## Examples

```sh
printf 'x,y,z\n' | moonx cli/cut@0.2.4 -d, -f1,3
moonx cli/cut@0.2.4 -b 1-4 fixed.txt
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
