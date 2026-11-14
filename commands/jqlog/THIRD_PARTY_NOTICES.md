# Third-party notices

The parser, AST and evaluator in `internal/parser` and `internal/ast` derive
from [MoonJQ](https://github.com/moonbit-community/moonbit-jq), distributed as
`bobzhang/moonjq@0.2.0` under the Apache License 2.0. The unmodified license
text is retained in [LICENSE-APACHE](LICENSE-APACHE).

The immutable Mooncakes source archive has SHA-256
`c3dafe143c2c50fcce57b417ed1b7d9e37dfb288903a5dc88ef2de71a78aec0a`,
verified against the registry index. The initial local runtime matches the
reviewed jq import at cmd commit `84c86292f13b43c163b5fd10039f702d08085efa`,
with package references changed to `cli/jqlog/internal`.

Only the lexer/parser, expression and operator types, evaluator builtins and
two private JSON helpers are retained, together with their original package
regressions and expected values. The upstream Query convenience wrapper,
commands and workspace/build configuration are excluded. The current formatter
updates deprecated syntax without changing behavior.

The JSONL input policy, CLI, rendering and AST adaptations belong to
`internal/driver`. The parser and evaluator are maintained in this command;
jqlog no longer resolves the MoonJQ package. Independent command expectations
and the shared adapter corpus remain the regression authority.
