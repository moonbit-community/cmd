# mv

Move files and directories for MoonX.

```sh
moonx cli/mv@0.2.5 [-f|-i|-n] [-u|--update=MODE] [-b|--backup[=CONTROL]] [-S SUFFIX] [-T] [-v] SOURCE... DEST
```

## Supported scope

Rename or move into directories, with overwrite selection, update modes and backups.

## Options

| Option | Description |
| --- | --- |
| `-f, --force` | Replace without asking. |
| `-i, --interactive` | Ask before replacing; refusal or EOF returns 1. |
| `-n, --no-clobber` | Skip existing targets successfully. |
| `-u, --update[=MODE]` | Select older (bare -u/--update), all, none or none-fail. |
| `-b, --backup[=CONTROL]` | Back up targets: none, simple, numbered or existing; bare flag selects existing. |
| `-S, --suffix=SUFFIX` | Set simple backup suffix; default ~. |
| `-T, --no-target-directory` | Treat target as a complete path; one source only. |
| `-v, --verbose` | Show moves. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Cross-filesystem moves are unsupported.
- Windows rejects moving symlinks/junctions and backing up destination links; explicit skip modes remain available.
- -i/-u reject equal source/target timestamps. Same-path and same-file hard-link moves fail, except explicit skip modes.

## Examples

```sh
moonx cli/mv@0.2.5 old.txt new.txt
moonx cli/mv@0.2.5 -n report.txt archive/
moonx cli/mv@0.2.5 --backup=simple report.txt archive/
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0004-filesystem.md)
