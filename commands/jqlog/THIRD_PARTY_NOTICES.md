# Third-party notices

The parser, AST and evaluator supplied by the `cli/jq/engine` dependency derive
from [MoonJQ](https://github.com/moonbit-community/moonbit-jq), distributed as
`bobzhang/moonjq@0.2.0` under the Apache License 2.0. The unmodified license
text is retained in [LICENSE-APACHE](LICENSE-APACHE).

The immutable Mooncakes source archive has SHA-256
`c3dafe143c2c50fcce57b417ed1b7d9e37dfb288903a5dc88ef2de71a78aec0a`,
verified against the registry index. The initial local runtime matches the
reviewed jq import at cmd commit `84c86292f13b43c163b5fd10039f702d08085efa`,
with package references changed to `cli/jqlog/internal`.

The previous command-local copy and its original expectations remain in Git at
`0fb45b941c92cfb7a2cee508331f26a346a5a603`. All 545 named parser/evaluator tests
have corresponding tests in jq, including two tests renamed when jq corrected
foreach output and lexical capture. The shared implementation and its current
license/source notices are maintained in `commands/jq`; there is no second
parser or evaluator in this module.

The JSONL input policy, CLI and rendering belong to `internal/driver`. Jqlog now
adopts jq's corrected value-filter semantics through its public engine interface;
it does not import jq's internal packages or resolve MoonJQ. Independent command
expectations and the unchanged 28-record adapter corpus remain regression inputs.
