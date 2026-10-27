# test

Evaluate conditions for MoonX.

```sh
moonx cli/test@0.2.3 EXPRESSION
```

## Supported scope

Evaluate string/integer comparisons and file type, access, size and timestamp predicates. Exit 0 for true, 1 for false and 2 for errors.

## Options

| Option | Description |
| --- | --- |
| `-n / -z STRING` | Test nonempty / empty strings. |
| `= / != / -eq / -ne / -gt / -ge / -lt / -le` | Compare strings or integers. |
| `-e / -f / -d / -L / -h / -p / -S / -b / -c` | Test existence or file type. |
| `-r / -w / -x / -s / -N` | Test access, nonempty size or modification since access. |
| `-nt / -ot` | Compare file modification times. |
| `! / -a / -o / ( )` | Negate or combine expressions. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Terminal -t, permission-bit/owner predicates and same-file -ef are unsupported.

## Examples

```sh
moonx cli/test@0.2.3 -f notes.txt
moonx cli/test@0.2.3 3 -gt 2
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0004-filesystem.md)
