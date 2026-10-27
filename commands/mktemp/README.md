# mktemp

Create unique temporary paths for MoonX.

```sh
moonx cli/mktemp@0.1.4 [OPTION]... [TEMPLATE]
```

## Supported scope

Create a file or directory without overwriting existing entries. The final X run in a template must contain at least three characters.

## Options

| Option | Description |
| --- | --- |
| `-d, --directory` | create a directory |
| `-p DIR, --tmpdir[=DIR]` | use DIR, then TMPDIR, then /tmp |
| `-t` | prefer TMPDIR; reject template directories |
| `--suffix=SUFFIX` | append SUFFIX to a template ending in X |
| `-q, --quiet` | suppress creation and output errors |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Unsafe -u dry runs are unsupported. Suffixes cannot contain directory separators.
- Without a destination, the default uses TMPDIR or /tmp; that directory must exist.

## Examples

```sh
moonx cli/mktemp@0.1.4 -p . sample.XXXXXX
moonx cli/mktemp@0.1.4 -d -p . sample.XXXXXX
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0004-filesystem.md)
