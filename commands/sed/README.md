# sed

Published version: `cli/sed@0.2.5`. See the release inventory;
[latest.json](../../tests/release/latest.json) records the uploaded coordinates.

Edit text streams for MoonX.

```sh
moonx cli/sed@0.2.5 [-nE] [-e SCRIPT] [-f SCRIPTFILE] [SCRIPT] [FILE...]
```

## Supported scope

Read files or stdin with BRE/ERE substitutions, line/pattern addresses, ranges, hold space, groups, branches and text insertion. Files share numbering and state.

## Options

| Option | Description |
| --- | --- |
| `-n, --quiet, --silent` | Suppress automatic output. |
| `-e, --expression=SCRIPT` | Append a script; may repeat. |
| `-f, --file=FILE` | Read a script file; may repeat. |
| `-E, -r` | Use extended regular expressions. |
| `--help` / `--version` | Show help / package version. |

## Extension and diagnostic contract

Project alias: --extended selects -r/-E; the GNU long name is --regexp-extended.

See [the finite option and diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics) for the scope and upstream distinction.

## Limitations

- In-place editing and locale-aware matching are unsupported.
- Supported commands: p d q = s h H g G x : b t T n N P D a i c and addressed groups; unsupported syntax fails before input.

## Examples

```sh
moonx cli/sed@0.2.5 's/old/new/g' file.txt
moonx cli/sed@0.2.5 -n '2,5p' file.txt
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0007-language.md)
