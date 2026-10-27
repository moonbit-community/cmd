# tr

Translate and delete bytes for MoonX.

```sh
moonx cli/tr@0.2.3 [-dscCt] SET1 [SET2]
```

## Supported scope

Read stdin and translate, squeeze or delete selected bytes. Sets support escapes, ranges, C classes, equivalence classes and repetitions.

## Options

| Option | Description |
| --- | --- |
| `-d, --delete` | Delete SET1 bytes. |
| `-s, --squeeze-repeats` | Collapse repeated selected bytes. |
| `-c, -C, --complement` | Complement SET1. |
| `-t, --truncate-set1` | Truncate SET1 to SET2's length. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Uses raw bytes and C-locale classes; multibyte locale transformations are unsupported.

## Examples

```sh
printf 'hello' | moonx cli/tr@0.2.3 'a-z' 'A-Z'
printf 'a  b' | moonx cli/tr@0.2.3 -s ' '
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
