# printf

Print formatted values for MoonX.

```sh
moonx cli/printf@0.2.3 FORMAT [ARGUMENT...]
```

## Supported scope

Reuse FORMAT until arguments are consumed. Supports strings, characters, escaped strings, integers, floats, shell quoting, width and precision.

## Options

| Option | Description |
| --- | --- |
| `FORMAT [ARG...]` | Conversions: s c b d i u o x X f F e E g G a A q and %. |
| `--` | End options before a format beginning with -. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- %q accepts no flags, width or precision. Non-C locales are unsupported.
- Floating output follows GNU Linux amd64 extended precision, not the host's floating ABI.

## Examples

```sh
moonx cli/printf@0.2.3 '%s=%d\n' answer 42
moonx cli/printf@0.2.3 '%s\n' one two three
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0008-data.md)
