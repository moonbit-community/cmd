# echo

Published version: `cli/echo@0.2.4`. See the release inventory;
[latest.json](../../tests/release/latest.json) records the uploaded coordinates.

Print argument text for MoonX.

```sh
moonx cli/echo@0.2.4 [-n] [-e|-E] [STRING...]
```

## Supported scope

Join arguments with spaces and append a newline by default. Escape processing is selected explicitly.

## Options

| Option | Description |
| --- | --- |
| `-n` | Omit the final newline. |
| `-e / -E` | Enable / disable backslash escapes. |
| `--help` / `--version` | Show help / package version. |

## Extension and diagnostic contract

POSIXLY_CORRECT enables escapes; only an initial -n permits option parsing.
Standalone --help/--version retain the project metadata contract in that environment.

See [the finite option and diagnostic profile](../../docs/compatibility.md#extensions-and-diagnostics) for the scope and upstream distinction.

## Limitations

- -- is printed literally. --help and --version are metadata only when used alone.
- Use printf for unambiguous option-like text.

## Examples

```sh
moonx cli/echo@0.2.4 hello world
moonx cli/echo@0.2.4 -e 'one\ntwo'
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
