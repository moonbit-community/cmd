# dirname

Extract parent paths for MoonX.

```sh
moonx cli/dirname@0.2.3 [-z] NAME...
```

## Supported scope

Remove the final component of each path without accessing the filesystem. An empty operand produces `.`.

## Options

| Option | Description |
| --- | --- |
| `-z, --zero` | End each result with NUL. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Paths are processed textually; symbolic links are not resolved.

## Examples

```sh
moonx cli/dirname@0.2.3 /tmp/report.txt
moonx cli/dirname@0.2.3 first/file second/file
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0004-filesystem.md)
