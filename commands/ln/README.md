# ln

Development candidate: `cli/ln@0.2.6`. Publication is separate;
[latest.json](../../tests/release/latest.json) records the uploaded coordinates.

Create symbolic links for MoonX.

```sh
moonx cli/ln@0.2.6 -s [-f|-i] [-r] [-n] [-T] [-b|--backup[=CONTROL]] [-S SUFFIX] TARGET... LINK_NAME
```

## Supported scope

Create POSIX symbolic links with explicit destinations or target directories, replacement, relative targets and backups.

In the unpublished development candidate, numbered backups use one more than
the highest existing positive, unpadded decimal version, retaining gaps and all
older backups. Existing mode uses the same numbering when such a backup exists,
and the simple suffix otherwise. Directory scan failures remain errors.
Filesystem case/Unicode aliases count as existing backups. Numbered selections
refuse a backup that appears before rename; simple suffixes still replace.
If link creation and backup restoration both fail, the diagnostic retains both
errors and names the destination and backup. A failed restore does not establish
which path still contains the old entry. Rollback remains cancellable so that
cancellation after committed creation does not replace the new entry.

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

## Argument and exit-status contract

Ordinary option/operand errors exit 1; documented capability refusals retain their own status.
Option values and operands after -- remain literal during alias normalization.

See the [finite diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics).

## Limitations

- Hard links and Windows link creation are unsupported.
- Declining an overwrite, including EOF, returns 1.

## Examples

```sh
moonx cli/ln@0.2.6 -s target.txt link.txt
moonx cli/ln@0.2.6 -sr target.txt link.txt
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0004-filesystem.md)
