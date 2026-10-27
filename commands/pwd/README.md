# pwd

Print the working directory for MoonX.

```sh
moonx cli/pwd@0.2.3 [-L|-P]
```

## Supported scope

Print an absolute working-directory path.

## Options

| Option | Description |
| --- | --- |
| `-L, --logical` | Use a valid logical PWD path. |
| `-P, --physical` | Resolve the physical directory path. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Invalid or mismatched logical PWD falls back to the runtime working directory. Default mode is physical unless POSIXLY_CORRECT is set.

## Examples

```sh
moonx cli/pwd@0.2.3
moonx cli/pwd@0.2.3 -P
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0004-filesystem.md)
