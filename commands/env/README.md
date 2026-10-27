# env

Inspect environments and launch commands for MoonX.

```sh
moonx cli/env@0.2.3 [-i] [-0] [-u NAME] [-C DIR] [-S STRING] [NAME=VALUE]... [COMMAND [ARG]...]
```

## Supported scope

Print the environment or apply assignments/unsets and run one executable with separate arguments. The first assignment ends option scanning.

## Options

| Option | Description |
| --- | --- |
| `-i, --ignore-environment` | Start with an empty environment; bare - is equivalent. |
| `-u, --unset=NAME` | Remove a variable. |
| `-0, --null` | Separate printed entries with NUL. |
| `-C, --chdir=DIR` | Set the child working directory. |
| `-S, --split-string=STRING` | Split quotes, escapes and original-environment substitutions. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- --null cannot be used with a child command. Environment listing order is unspecified.
- Split-string parsing is not shell evaluation.

## Examples

```sh
moonx cli/env@0.2.3
moonx cli/env@0.2.3 MODE=test moonx cli/printenv@0.2.3 MODE
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0006-process.md)
