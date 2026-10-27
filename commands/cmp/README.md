# cmp

Compare two byte streams for MoonX.

```sh
moonx cli/cmp@0.2.3 [-b] [-s|-l] [-n LIMIT] [-i SKIP[:SKIP2]] FILE1 [FILE2]
```

## Supported scope

Compare files or stdin; omitted FILE2 means stdin. Exit 0 for equal inputs, 1 for differences and 2 for errors.

## Options

| Option | Description |
| --- | --- |
| `-b, --print-bytes` | Show differing byte values. |
| `-s, --silent, --quiet` | Report status only. |
| `-l, --verbose` | List every differing byte. |
| `-n, --bytes=LIMIT` | Compare at most LIMIT bytes. |
| `-i, --ignore-initial=SKIP[:SKIP2]` | Skip initial bytes independently. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- -l and -s cannot be combined.

## Examples

```sh
moonx cli/cmp@0.2.3 first.bin second.bin
moonx cli/cmp@0.2.3 -n 16 first.bin second.bin
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
