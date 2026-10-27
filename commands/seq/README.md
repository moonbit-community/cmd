# seq

Print numeric sequences for MoonX.

```sh
moonx cli/seq@0.2.4 [-w] [-f FORMAT] [-s STRING] [FIRST [INCREMENT]] LAST
```

## Supported scope

Accept LAST, FIRST LAST or FIRST INCREMENT LAST. Default increment is +1; use a negative increment to count down.

## Options

| Option | Description |
| --- | --- |
| `-s, --separator=STRING` | Replace the separator between values. |
| `-w, --equal-width` | Pad values to equal width. |
| `-f, --format=FORMAT` | Use one e/E/f/F/g/G/a/A conversion. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- -f conflicts with -w and rejects dynamic *, integer or multiple conversions.
- Unformatted operands allow at most 4096 characters and exponent/scale within -4096..4096. Formatted numbers use the GNU Linux amd64 profile.

## Examples

```sh
moonx cli/seq@0.2.4 1 5
moonx cli/seq@0.2.4 3 -1 1
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0008-data.md)
