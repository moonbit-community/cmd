# ln

Create symbolic links for MoonX.

```sh
moonx cli/ln@0.2.4 -s [-f|-i] [-r] [-n] [-T] [-b|--backup[=CONTROL]] [-S SUFFIX] TARGET... LINK_NAME
```

## Supported scope

Create POSIX symbolic links with explicit destinations or target directories, replacement, relative targets and backups.

## Options

| Option | Description |
| --- | --- |
| `-s, --symbolic` | Create a symbolic link; required. |
| `-f, --force / -i, --interactive` | Replace existing targets / ask first. |
| `-r, --relative` | Use a relative symbolic-link target. |
| `-t, --target-directory=DIR` | Create links in DIR. |
| `-T, --no-target-directory` | Treat destination as the complete link path. |
| `-n, --no-dereference` | Do not follow a destination directory symlink. |
| `-b, --backup[=CONTROL] / -S, --suffix=SUFFIX` | Back up replaced targets / choose backup suffix. |
| `-v, --verbose` | Show created links. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Hard links and Windows link creation are unsupported.
- Declining an overwrite, including EOF, returns 1.

## Examples

```sh
moonx cli/ln@0.2.4 -s target.txt link.txt
moonx cli/ln@0.2.4 -sr target.txt link.txt
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0004-filesystem.md)
