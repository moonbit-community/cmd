# expr

Version **0.2.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

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
byte count. Strings use byte offsets and C-locale ordering. The shared BRE
matcher supports pattern backreferences, byte classes and word assertions.
Repeated nullable captures follow the tested GNU candidate and capture-register
selection, including counted repeats and references. See the
[workspace support record](../../docs/compatibility.md#workspace-matcher-and-sed-candidates).
Locale-aware character operations are not included. `--help`, `--version`, and
the leading `--` separator are available.

Exit status is 0 for a nonempty, nonzero result, 1 for an empty or zero result,
and 2 for invalid expressions or evaluation errors.

## Standalone metadata

Standalone `--version` prints exactly `expr 0.2.0` followed by one
newline. Standalone `--help` starts with `Usage: expr`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
