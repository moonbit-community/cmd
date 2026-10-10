# expr

Version **0.1.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; this version is an unpublished candidate.

Evaluate integer and string expressions. Pass each operator and operand as a
separate argument; quote operators that the calling shell would interpret.

```sh
moonx cli/expr 2 + 3
moonx cli/expr length example
moonx cli/expr filename.txt : '.*\.\(.*\)'
```

Supports `|`, `&`, comparisons (`=`, `==`, `!=`, `<`, `<=`, `>`, `>=`),
integer `+`, `-`, `*`, `/`, `%`, anchored BRE matching with `:`, and parentheses.
Integer arithmetic is not limited to machine-word size. Logical operators
short-circuit evaluation; skipped expressions still require valid syntax.

`length`, `index`, `substr`, and `match` provide string operations. Prefix `+`
quotes the next argument as a string, including keywords and operators.
Matching returns the first captured group when present, otherwise the matched
byte count. Strings use byte offsets and C-locale ordering. Pattern
backreferences, word assertions and locale-aware character operations are
not included. `--help`, `--version`, and the leading `--` separator are available.

Exit status is 0 for a nonempty, nonzero result, 1 for an empty or zero result,
and 2 for invalid expressions or evaluation errors.
