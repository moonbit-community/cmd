# dirname

Development candidate: `cli/dirname@0.2.5`. Publication is separate;
[latest.json](../../tests/release/latest.json) records the uploaded coordinates.

Extract parent paths for MoonX.

```sh
moonx cli/dirname@0.2.5 [-z] NAME...
```

## Supported scope

Remove the final component of each path without accessing the filesystem. An empty operand produces `.`.

## Options

| Option | Description |
| --- | --- |
| `-z, --zero` | End each result with NUL. |
| `--help` / `--version` | Show help / package version. |

## Argument and exit-status contract

Ordinary option/operand errors exit 1; documented capability refusals retain their own status.

See the [finite diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics).

## Limitations

- Paths are processed textually; symbolic links are not resolved.

## Examples

```sh
moonx cli/dirname@0.2.5 /tmp/report.txt
moonx cli/dirname@0.2.5 first/file second/file
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0004-filesystem.md)
