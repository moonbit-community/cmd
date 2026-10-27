# make

Run a Make language subset for MoonX.

```sh
moonx cli/make@0.2.3 [-B] [-k] [-n] [-s] [-j [N]] [-W FILE] [-C DIR] [-f FILE] [VARIABLE=VALUE] [TARGET...]
```

## Supported scope

Build targets with dependencies, variables, includes, conditionals, patterns, automatic variables, exports and parallel recipe chains.

## Options

| Option | Description |
| --- | --- |
| `-f, --file FILE` | Select a makefile. |
| `-C DIR` | Change working directory. |
| `-n, --just-print` | Print recipes without running them. |
| `-s, --silent` | Suppress recipe echo. |
| `-B, --always-make` | Force rebuilding. |
| `-j [N]` | Run up to N recipe chains; bare -j allows all ready targets. |
| `-k` | Continue independent targets after failures. |
| `-W FILE` | Treat FILE as newly modified. |
| `NAME=VALUE / TARGET` | Set variables / select targets. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Short flags must be separate: use -n -s, not -ns.
- GNU's complete built-in database, jobserver, secondary expansion and recursive shell-valued exports are unsupported.
- Recipes use the supported sh language subset.

## Examples

```sh
moonx cli/make@0.2.3 -n
moonx cli/make@0.2.3 -f build.mk -j 2 all
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0007-language.md)
