# ls

List files and directories for MoonX.

```sh
moonx cli/ls@0.2.4 [-aAdF1RCxmrtucSbqNQ] [-w WIDTH] [-T TABSIZE] [-H|-L|-P] [FILE...]
```

## Supported scope

List names with hidden-entry selection, recursion, sorting, quoting, columns and explicit color. Default output is one entry per line.

## Options

| Option | Description |
| --- | --- |
| `-a / -A` | Include all dot entries / exclude . and ... |
| `-d / -R` | List directory operands themselves / recurse. |
| `-F` | Append type indicators. |
| `-1 / -C / -x / -m` | Line / column / row / comma layout. |
| `-r / -t / -S` | Reverse / time / regular-file-size sorting. |
| `-u / -c / --time=WORD` | Choose access / status-change / selected timestamp. |
| `-H / -L / -P` | Follow command-line links / all links / no links. |
| `-w, --width=COLS / -T, --tabsize=COLS` | Set layout width / tab width. |
| `-b / -N / -Q / --quoting-style=STYLE` | Choose escaping / literal / C / named quoting. |
| `-q / --show-control-chars` | Replace / retain control bytes after quoting. |
| `--color[=WHEN]` | Explicit always or never color; bare flag means always. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Long listings, ownership, permissions, inode/link counts and block counts are unsupported.
- --color=auto is rejected. Mode/capability/link-count color selectors must be disabled in LS_COLORS where the corresponding entries occur.
- Size sorting rejects nonregular entries. Names and ordering use C-byte rules.

## Examples

```sh
moonx cli/ls@0.2.4 -A
moonx cli/ls@0.2.4 -R -1 src
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0004-filesystem.md)
