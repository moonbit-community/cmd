# unlink

Remove one file name for MoonX.

```sh
moonx cli/unlink@0.1.5 FILE
```

## Supported scope

Remove exactly one non-directory entry. A symbolic link is removed without following its target.

## Options

| Option | Description |
| --- | --- |
| `FILE` | One pathname to remove. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Directories and multiple operands are rejected. Filesystem errors return 1.

## Examples

```sh
moonx cli/unlink@0.1.5 temporary.txt
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0004-filesystem.md)
