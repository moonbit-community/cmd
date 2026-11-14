# Third-party notices

The parser, AST and evaluator in `internal/parser` and `internal/ast` derive
from [MoonJQ](https://github.com/moonbit-community/moonbit-jq), distributed as
`bobzhang/moonjq@0.2.0` under the Apache License 2.0. The unmodified license
text is retained in [LICENSE-APACHE](LICENSE-APACHE).

The import source is the immutable Mooncakes 0.2.0 archive, whose SHA-256 is
`c3dafe143c2c50fcce57b417ed1b7d9e37dfb288903a5dc88ef2de71a78aec0a`.
This was checked against the registry index before extraction. The old
repository spelling `moonbit-community/moobit-jq` redirects to the repository
linked above; no claim that its current branch equals the release is made.

The retained runtime consists of the lexer/parser, expression and operator
types, evaluator builtins and two JSON helpers. All are reachable through the
existing command's filter language. Their original package regression tests
were retained with unchanged expected values at the initial import commit
`47f86ea34261c24c3d3f95b8f80eaf833bda7fac`. Later generator and closure repairs
correct old defect observations against the fixed jq 1.8.2 records in
`tests/fixtures/jq/evaluation.json` and `runtime.json`. Original source and
expectations remain available at that commit and in the immutable archive.
The nonterminating `limit(5; repeat(empty))` query is recorded beside its bounded
zero-limit replacement. The upstream Query wrapper,
convenience evaluation APIs, other commands, workspace/build configuration and
planning material are excluded.

Local modifications change package imports to `cli/jq/internal`, fold the two
helpers into the evaluator as private functions, and use the parser directly
instead of the Query wrapper. The current formatter also updates deprecated
derivation syntax. Subsequent local work replaces eager expression composition
with resumable streams, lexical scopes and compile validation, and adds module
syntax and source locations. Atomic operations retain the imported algorithms.
Existing command-owned AST adaptations, input
framing, stream events and rendering live in `internal/driver`. These packages
are maintained in this repository; jq no longer resolves the MoonJQ package.
Later behavior changes must retain independent command/oracle expectations.
