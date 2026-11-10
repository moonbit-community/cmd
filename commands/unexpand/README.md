# unexpand

Published version: `cli/unexpand@0.1.6`. See the release inventory;
[latest.json](../../tests/release/latest.json) records the uploaded coordinates.

Convert spaces to tabs for MoonX.

```sh
moonx cli/unexpand@0.1.6 [OPTION]... [FILE]...
```

## Supported scope

Read files or stdin and replace eligible blanks with tabs. Default tab width is eight; default conversion affects leading blanks only.

## Options

| Option | Description |
| --- | --- |
| `-a, --all` | Convert blanks throughout each record. |
| `-t, --tabs=LIST` | Select ascending stops; implies --all. Final /N or +N extends stops. |
| `--first-only` | Convert leading blanks only, overriding -a and -t. |
| `--help` / `--version` | Show help / package version. |

## Argument and exit-status contract

Ordinary option/operand errors exit 1; documented capability refusals retain their own status.

See the [finite diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics).

## Limitations

- Uses byte columns, not locale-dependent Unicode display widths.

## Examples

```sh
moonx cli/unexpand@0.1.6 -t 4 notes.txt
moonx cli/unexpand@0.1.6 -a notes.txt
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
