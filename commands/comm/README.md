# comm

Published version: `cli/comm@0.2.7`. See the release inventory;
[latest.json](../../tests/release/latest.json) records the uploaded coordinates.

Compare sorted text files for MoonX.

```sh
moonx cli/comm@0.2.7 [-123] [-z] FILE1 FILE2
```

## Supported scope

Print records unique to the first file, unique to the second, and common to both. Use `-` for stdin; inputs must use C-byte sort order.

## Options

| Option | Description |
| --- | --- |
| `-1` | Suppress column 1 (lines unique to FILE1). |
| `-2` | Suppress column 2 (lines unique to FILE2). |
| `-3` | Suppress column 3 (lines in both files). |
| `--output-delimiter=STR` | Separate columns with STR (empty means NUL). |
| `--total` | Print counts for all three columns and a total label. |
| `--check-order` | Diagnose unsorted input. |
| `--nocheck-order` | Do not diagnose unsorted input. |
| `-z, --zero-terminated` | End records with NUL instead of newline. |
| `--help` / `--version` | Show help / package version. |

## Extension and diagnostic contract

Project aliases: --suppress-1 = -1; --suppress-2 = -2; --suppress-3 = -3.
-h is a project alias of --help.

See [the finite option and diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics) for the scope and upstream distinction.

## Argument and exit-status contract

Ordinary option/operand errors exit 1; documented capability refusals retain their own status.

See the [finite diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics).

## Limitations

- Locale-dependent collation is unsupported.
- Default order checking is conditional; use --check-order to reject disorder immediately.

## Examples

```sh
moonx cli/comm@0.2.7 left.txt right.txt
moonx cli/comm@0.2.7 -12 left.txt right.txt
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
