# P2 command candidate: strings, column, which and date

Date: 2026-10-11

This validation-only candidate adds four independent pure MoonBit packages at
version 0.1.0 and advances the local `cli/core` module to 0.4.0 for catalog
contracts. Published registry versions remain unchanged.

The candidate manifest is
[`candidate-2026-10-11.json`](../../tests/release_runner/candidate-2026-10-11.json).
Its release-runner validation passed with 78 command coordinates and 554
selected cases. The workspace runner selected 19 semantic contract cases and
one explicit `strings -e l` boundary for the new commands; Native and Wasm
both passed all selected cases.

The package and workspace checks used MoonBit 2026-09-20, async 0.22.4 and
x 0.5.5. `moon check --target all --deny-warn` and `moon test --target all`
passed. Native and Wasm release artifacts built with warnings denied. The
shared testkit now expands `${WORK}` in environment values, which is required
for PATH fixtures such as `which`; this fixes test observation rather than
changing command authorization.

Publication is deliberately deferred until the source commit passes the
required Linux, macOS and Windows CI checks. If the gate passes, publish
`cli/core@0.4.0` first, then `column@0.1.0`, `date@0.1.0`, `strings@0.1.0` and
`which@0.1.0` serially, followed by exact MoonX consumer acceptance.
