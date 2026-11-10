# nl

Published version: `cli/nl@0.2.7`. See the release inventory;
[latest.json](../../tests/release/latest.json) records the uploaded coordinates.

Number input lines for MoonX.

```sh
moonx cli/nl@0.2.7 [-b STYLE] [-h STYLE] [-f STYLE] [-v NUMBER] [-i NUMBER] [-l NUMBER] [-n FORMAT] [-w NUMBER] [-s STRING] [-d STRING] [-p] [FILE...]
```

## Supported scope

This version pads unnumbered lines with spaces across the number
field and separator width. Exact ordinary blank-line and custom-separator
cases complement complete-source comparisons.

Read files or stdin and number body, header and footer sections. Default body style numbers nonempty lines, with width 6 and TAB separation.

## Options

| Option | Description |
| --- | --- |
| `-b / -h / -f STYLE` | Set body / header / footer style: a (all), t (nonempty), n (none). |
| `-w N / -s SEP` | Set number width / separator. |
| `-v N / -i N` | Set starting number / increment. |
| `-d STRING` | Set section delimiter; default \:; empty disables markers. |
| `-p` | Do not restart numbers at logical pages. |
| `-n ln\|rn\|rz` | Left-align / right-align / zero-pad numbers. |
| `-l N` | Number the last line of each N blank lines in style a. |
| `--help` / `--version` | Show help / package version. |

## Argument and exit-status contract

Ordinary option/operand errors exit 1; documented capability refusals retain their own status.

See the [finite diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics).

## Limitations

- The pBRE numbering style is unsupported.

## Examples

```sh
moonx cli/nl@0.2.7 notes.txt
moonx cli/nl@0.2.7 -b a -w 3 -s ' ' notes.txt
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
