# mkdir

Create directories for MoonX.

```sh
moonx cli/mkdir@0.2.3 [-p] [-m MODE] [-v] DIRECTORY...
```

## Supported scope

Create multiple directories and optional parents. Failed operands do not stop later attempts; -p preserves existing directory modes.

## Options

| Option | Description |
| --- | --- |
| `-p, --parents` | Create missing parent directories. |
| `-m, --mode=MODE` | Set the leaf mode, numeric or supported symbolic. |
| `-v, --verbose` | Show created directories. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Symbolic modes whose result depends on the current umask are rejected before creation.
- Windows permission-bit semantics and exact GNU parent permissions under restrictive umasks are unsupported.

## Examples

```sh
moonx cli/mkdir@0.2.3 -p output/reports
moonx cli/mkdir@0.2.3 -m 700 private-dir
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0004-filesystem.md)
