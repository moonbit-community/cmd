# pwd

Development candidate: `cli/pwd@0.2.4`. Publication is separate;
[latest.json](../../tests/release/latest.json) records the uploaded coordinates.

Print the working directory for MoonX.

```sh
moonx cli/pwd@0.2.4 [-L|-P]
```

## Supported scope

Print an absolute working-directory path.

## Options

| Option | Description |
| --- | --- |
| `-L, --logical` | Use a valid logical PWD path. |
| `-P, --physical` | Resolve the physical directory path. |
| `--help` / `--version` | Show help / package version. |

## Argument and exit-status contract

Ordinary option/operand errors exit 1; documented capability refusals retain their own status.

See the [finite diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics).

## Limitations

- Invalid or mismatched logical PWD falls back to the runtime working directory. Default mode is physical unless POSIXLY_CORRECT is set.

## Examples

```sh
moonx cli/pwd@0.2.4
moonx cli/pwd@0.2.4 -P
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0004-filesystem.md)
