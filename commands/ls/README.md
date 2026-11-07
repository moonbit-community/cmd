# ls

Development candidate: `cli/ls@0.2.5`. Publication is separate;
[latest.json](../../tests/release/latest.json) records the uploaded coordinates.

List files and directories for MoonX.

```sh
moonx cli/ls@0.2.5 [-aAdF1RCxmrtucSbqNQ] [-w WIDTH] [-T TABSIZE] [-H|-L|-P] [FILE...]
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

## Extension and diagnostic contract

Project aliases: --one = -1; --columns = -C; --across = -x; --commas = -m.
--sort-time = -t; --access-time = -u; --change-time = -c; --sort-size = -S.
-P/--no-dereference is a project no-follow extension.
-Q/--quote-name select C quotes; --quote is the accepted abbreviated spelling.

See [the finite option and diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics) for the scope and upstream distinction.

## Argument and exit-status contract

Option values and operands after -- remain literal during alias normalization.

See the [finite diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics).

## Limitations

- Long listings, ownership, permissions, inode/link counts and block counts are unsupported.
- --color=auto is rejected. Mode/capability/link-count color selectors must be disabled in LS_COLORS where the corresponding entries occur.
- Size sorting rejects nonregular entries. Names and ordering use C-byte rules.

## Examples

```sh
moonx cli/ls@0.2.5 -A
moonx cli/ls@0.2.5 -R -1 src
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0004-filesystem.md)
