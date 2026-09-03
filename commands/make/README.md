# make

Observed Wasm profile (2026-09-03): this README is supplementary. The [support record](../../docs/compatibility.md) is the only capability authority; it lists the repeatable `moon run --target wasm --release` results and exclusions. Options mentioned here but not promoted in that record are not compatibility guarantees.

`cli/make` provides a measured Make subset. The Wasm audit verified one
target/dependency rule, an included variable,
command-line variable precedence, dry run, recipe execution, and silent mode.

`include` and command-line variable assignment worked in that slice.
`-include`, `sinclude`, recursive expansion limits, broader dependency-graph
behavior, built-ins, pattern rules, and job control remain unverified.
The observed Wasm `-C` path selects the Makefile, but recipe process lookup and
working directory remain controlled by the Wasm host; do not assume GNU
`make -C` recipe-directory parity.

Each external command in a recipe is launched through the policy-visible
MoonBit process API. Unsupported Make extensions fail explicitly; the complete
Makefile is never forwarded to a host `make` executable. The remaining
language surface is listed in the
[support record](../../docs/compatibility.md).

Wasm recipes start from the explicit restricted environment and remain subject
to the host process policy. Native inheritance is outside this Wasm support
record.
