# join

Published version: `cli/join@0.2.7`. See the release inventory;
[latest.json](../../tests/release/latest.json) records the uploaded coordinates.

Join sorted text files for MoonX.

```sh
moonx cli/join@0.2.7 [options] FILE1 FILE2
```

## Supported scope

Join two files on matching fields; default keys are the first blank-separated field. Either input may be stdin, but not both.

## Options

| Option | Description |
| --- | --- |
| `-1 N / -2 N` | Choose each file's join field. |
| `-t CHAR` | Set a single-byte field separator. |
| `-a 1\|2 / -v 1\|2` | Include / select only unpairable rows. |
| `-e STRING` | Replace missing or empty fields. |
| `-i, --ignore-case` | Compare keys ignoring ASCII case. |
| `-o LIST\|auto` | Choose output fields. |
| `--header` | Join first records without comparing their keys. |
| `--check-order / --nocheck-order` | Enable immediate order checking / disable checks. |
| `-z, --zero-terminated` | Use NUL-delimited records. |
| `--help` / `--version` | Show help / package version. |

## Extension and diagnostic contract

Project aliases: --field1 = -1; --field2 = -2; --separator = -t.
--after = -a; --only = -v; --empty = -e; --output = -o; -h = --help.

See [the finite option and diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics) for the scope and upstream distinction.

## Argument and exit-status contract

Ordinary option/operand errors exit 1; documented capability refusals retain their own status.

See the [finite diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics).

## Limitations

- Inputs must be sorted on the selected keys using the C-byte profile; locale-aware collation is unsupported.

## Examples

```sh
moonx cli/join@0.2.7 people.txt colors.txt
moonx cli/join@0.2.7 -t, -1 2 -2 1 a.csv b.csv
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
