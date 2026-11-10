# which

Published version: `cli/which@0.1.6`. See the release inventory;
[latest.json](../../tests/release/latest.json) records the uploaded coordinates.

Find executables for MoonX.

```sh
moonx cli/which@0.1.6 [-as] NAME...
```

## Supported scope

Search PATH or inspect explicit paths without launching files. Windows lookup uses PATHEXT. Return 1 if any requested executable is missing.

## Options

| Option | Description |
| --- | --- |
| `-a, --all` | Print every match instead of the first. |
| `-s, --silent` | Suppress output and missing-command diagnostics. |
| `--help` / `--version` | Show help / package version. |

## Extension and diagnostic contract

-s/--silent follows this project's explicit quiet-status profile; it does not
claim the option surface of every GNU/BSD which implementation.

See [the finite option and diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics) for the scope and upstream distinction.

## Limitations

- Shell aliases and functions are not searched.

## Examples

```sh
moonx cli/which@0.1.6 moonx
moonx cli/which@0.1.6 -a moonx
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0006-process.md)
