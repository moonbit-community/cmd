# echo

Print argument text for MoonX.

```sh
moonx cli/echo@0.2.3 [-n] [-e|-E] [STRING...]
```

## Supported scope

Join arguments with spaces and append a newline by default. Escape processing is selected explicitly.

## Options

| Option | Description |
| --- | --- |
| `-n` | Omit the final newline. |
| `-e / -E` | Enable / disable backslash escapes. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- -- is printed literally. --help and --version are metadata only when used alone.
- Use printf for unambiguous option-like text.

## Examples

```sh
moonx cli/echo@0.2.3 hello world
moonx cli/echo@0.2.3 -e 'one\ntwo'
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
