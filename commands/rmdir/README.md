# rmdir

Development candidate: `cli/rmdir@0.2.4`. Publication is separate;
[latest.json](../../tests/release/latest.json) records the uploaded coordinates.

Remove empty directories for MoonX.

```sh
moonx cli/rmdir@0.2.4 [-p] [-I] [-v] DIRECTORY...
```

## Supported scope

Remove multiple empty directories, optionally walking upward through parents.

## Options

| Option | Description |
| --- | --- |
| `-p, --parents` | Remove empty parents after the operand. |
| `-v, --verbose` | Show removals. |
| `-I, --ignore-fail-on-non-empty` | Ignore failures caused only by nonempty directories. |
| `--help` / `--version` | Show help / package version. |

## Extension and diagnostic contract

  -p, --parents                  remove empty parents, stopping at the first failure
  -v, --verbose                  report each removal attempt before it runs
      --ignore-fail-on-non-empty  suppress only failures attributable to nonemptiness
  -I is a project short alias of --ignore-fail-on-non-empty, not a GNU option.

See [the finite option and diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics) for the scope and upstream distinction.

## Argument and exit-status contract

Ordinary option/operand errors exit 1; documented capability refusals retain their own status.

See the [finite diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics).

## Limitations

POSIX directory symlinks fail without removing their referents. Windows follows
the public removal result: a directory junction can be removed successfully
while its nonempty referent remains intact. This platform behavior is tested
separately from the GNU/POSIX link contract.

- Nonempty trees are not removed. Parent traversal stops before cwd, its ancestors or a root; the explicit operand is still attempted.

## Examples

```sh
moonx cli/rmdir@0.2.4 empty-dir
moonx cli/rmdir@0.2.4 -p empty-parent/empty-child
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0004-filesystem.md)
