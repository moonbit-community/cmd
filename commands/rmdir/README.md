# rmdir

Remove empty directories for MoonX.

```sh
moonx cli/rmdir@0.2.3 [-p] [-I] [-v] DIRECTORY...
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

## Limitations

- Nonempty trees are not removed. Parent traversal stops before cwd, its ancestors or a root; the explicit operand is still attempted.

## Examples

```sh
moonx cli/rmdir@0.2.3 empty-dir
moonx cli/rmdir@0.2.3 -p empty-parent/empty-child
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0004-filesystem.md)
