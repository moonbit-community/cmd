# expr

Evaluate integer and string expressions for MoonX.

```sh
moonx cli/expr@0.2.2 EXPRESSION
```

## Supported scope

Pass operators and operands separately. Supports arbitrary-size integer arithmetic, comparisons, logical operators, anchored BRE matching and string functions.

## Options

| Option | Description |
| --- | --- |
| `EXPRESSION` | Operators: \|, &, comparisons, +, -, *, /, %, : and parentheses. |
| `match / substr / index / length` | String functions using byte positions. |
| `+ ARG` | Treat the next argument literally. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- String operations and matching use C-byte rules, not locale-aware characters.
- Exit 0 for nonempty/nonzero, 1 for empty/zero, and 2 for invalid expressions.

## Examples

```sh
moonx cli/expr@0.2.2 2 + 3
moonx cli/expr@0.2.2 length example
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0007-language.md)
