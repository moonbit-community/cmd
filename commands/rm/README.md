# rm

Remove files and directory trees for MoonX.

```sh
moonx cli/rm@0.2.3 [OPTION]... FILE...
```

## Supported scope

Remove operands without following symbolic links. Explicit confirmation modes read stdin; recursive removal protects filesystem roots by default.

## Options

| Option | Description |
| --- | --- |
| `-r, -R, --recursive` | Remove directory trees. |
| `-d, --dir` | Remove empty directories. |
| `-f, --force` | Ignore missing files and disable prompts. |
| `-i / -I / --interactive[=WHEN]` | Ask always / once / always, once or never. |
| `-v, --verbose` | Show removals. |
| `--preserve-root / --no-preserve-root` | Enable / disable root protection. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Implicit terminal-sensitive write-protection prompts are unsupported.
- Final . and .. operands are refused. Earlier successful removals are not rolled back after errors.

## Examples

```sh
moonx cli/rm@0.2.3 temporary.txt
moonx cli/rm@0.2.3 -i unwanted.txt
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0004-filesystem.md)
