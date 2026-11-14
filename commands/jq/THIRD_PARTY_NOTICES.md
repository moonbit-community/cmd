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
are retained with unchanged expected values. The upstream Query wrapper,
convenience evaluation APIs, other commands, workspace/build configuration and
planning material are excluded.

Local modifications change package imports to `cli/jq/internal`, fold the two
helpers into the evaluator as private functions, and use the parser directly
instead of the Query wrapper. The current formatter also updates deprecated
derivation syntax without changing implementations or test expectations.
Existing command-owned AST adaptations, input
framing, stream events and rendering live in `internal/driver`. These packages
are maintained in this repository; jq no longer resolves the MoonJQ package.
Later behavior changes must retain independent command/oracle expectations.
