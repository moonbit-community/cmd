# which

Find executables for MoonX.

```sh
moonx cli/which@0.1.4 [-as] NAME...
```

## Supported scope

Search PATH or inspect explicit paths without launching files. Windows lookup uses PATHEXT. Return 1 if any requested executable is missing.

## Options

| Option | Description |
| --- | --- |
| `-a, --all` | Print every match instead of the first. |
| `-s, --silent` | Suppress output and missing-command diagnostics. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Shell aliases and functions are not searched.

## Examples

```sh
moonx cli/which@0.1.4 moonx
moonx cli/which@0.1.4 -a moonx
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0006-process.md)
