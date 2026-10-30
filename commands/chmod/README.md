# chmod

Change file permissions for MoonX.

```sh
moonx cli/chmod@0.2.4 [-R] [-v] MODE FILE...
```

## Supported scope

Set numeric modes on POSIX hosts. Complete symbolic assignments such as `u=rw,g=r,o=` are supported for regular files.

## Options

| Option | Description |
| --- | --- |
| `MODE` | Octal mode, or an explicit = assignment covering u, g and o. |
| `-R, --recursive` | Process directory contents recursively. |
| `-v, --verbose` | Describe processed entries. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Windows permission changes and `--reference` are unsupported.
- Symbolic modes reject incremental +/-, omitted classes, X/s/t, permission copies, directories and symlinks.
- Recursive walks skip encountered links; a command-line directory link changes only its target directory's mode.

## Examples

```sh
moonx cli/chmod@0.2.4 644 report.txt
moonx cli/chmod@0.2.4 u=rw,g=r,o= report.txt
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0004-filesystem.md)
