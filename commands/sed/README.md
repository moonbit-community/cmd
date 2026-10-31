# sed

Edit text streams for MoonX.

```sh
moonx cli/sed@0.2.2 [-nE] [-e SCRIPT] [-f SCRIPTFILE] [SCRIPT] [FILE...]
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

## Limitations

- In-place editing and locale-aware matching are unsupported.
- Supported commands: p d q = s h H g G x : b t T n N P D a i c and addressed groups; unsupported syntax fails before input.

## Examples

```sh
moonx cli/sed@0.2.2 's/old/new/g' file.txt
moonx cli/sed@0.2.2 -n '2,5p' file.txt
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0007-language.md)
